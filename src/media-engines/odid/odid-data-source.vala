/*
 * Copyright (C) 2013  Cable Television Laboratories, Inc.
 *
 * Author: Craig Pratt <craig@ecaspia.com>
 *         Parthiban Balasubramanian <P.Balasubramanian-contractor@cablelabs.com>
 *         Doug Galligan <doug@sentosatech.com>
 *
 * This file is part of Rygel.
 *
 * Rygel is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
 * IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL CABLE TELEVISION LABORATORIES
 * INC. OR ITS CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 * TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/**
 * An async data source for use with the ODID media engine.
 */
using Dtcpip;
using GUPnP;

internal class Rygel.ODIDDataSource : DataSource, Object {
    protected string source_uri;
    protected string content_uri;
    protected int64 range_start = 0;
    protected bool frozen = false;
    protected HTTPSeekRequest seek_request;
    protected PlaySpeedRequest playspeed_request = null;
    protected MediaResource res;
    protected bool content_protected = false;
    protected int dtcp_session_handle = -1;
    protected Gee.ArrayList<int64?> range_length_list = new Gee.ArrayList<int64?> ();
    protected KeyFile keyFile = new KeyFile ();
    
    // Keep track as the progress through the byte range.
    protected int64 total_bytes_read = 0;
    
    // Post condition to preroll.
    protected int64 total_bytes_requested = 0;
    
    // Track alignment position in list if required for 
    // VOBU alignment of PCPs.
    private int alignment_pos = 0;
    
    private IOChannel output;
    private uint output_watch_id = -1;
    
    // Pipe channel support
    private static const string READ_CMD = "read-cmd";
    private string read_cmd = null;
    private Pid child_pid = 0;
    
    private GLib.Regex FB_REGEX;
    private GLib.Regex LB_REGEX;
    private GLib.Regex NB_REGEX;
    private GLib.Regex FILE_REGEX;
      
    public ODIDDataSource (string source_uri, MediaResource ? res) {
        this.source_uri = source_uri;
        this.res = res;
        
        // Pipe channel initialization.
        try {
            FB_REGEX = new GLib.Regex (GLib.Regex.escape_string ("%firstByte"));
            LB_REGEX = new GLib.Regex (GLib.Regex.escape_string ("%lastByte"));
            NB_REGEX = new GLib.Regex (GLib.Regex.escape_string ("%numBytes"));
            FILE_REGEX = new GLib.Regex (GLib.Regex.escape_string ("%file"));
        } catch (GLib.RegexError e) {
            warning ("Regex Error");
        }
    }

    ~ODIDDataSource () {
        this.stop ();
        this.clear_dtcp_session ();
        debug ("Stopped data source");
    }

    public Gee.List<HTTPResponseElement> ? preroll ( HTTPSeekRequest? seek_request,
                                                     PlaySpeedRequest? playspeed_request)
       throws Error {
        debug ("source uri: " + source_uri);

        var response_list = new Gee.ArrayList<HTTPResponseElement> ();

        this.seek_request = seek_request;
        this.playspeed_request = playspeed_request;

        if (res == null) {
            throw new DataSourceError.GENERAL ("null resource");
        }
        debug ("Resource " + res.to_string ());
        File odidItem = File.new_for_uri (source_uri);

        this.keyFile.load_from_file (odidItem.get_path (),
                               KeyFileFlags.KEEP_COMMENTS |
                               KeyFileFlags.KEEP_TRANSLATIONS);

        string odid_item_path = null;
        if (this.keyFile.has_key ("item", "odid_uri"))    {
            odid_item_path = this.keyFile.get_string ("item", "odid_uri");
        } else {
            // If the odid_uri property is not available, assume this file exists in
            // the correct directory.
            if (odidItem.get_parent () != null) {
                odid_item_path = odidItem.get_parent ().get_uri () + "/";
            } else {
                throw new DataSourceError.GENERAL ("Root level odid items not supported");
            }
        }

        debug ("Source item path: %s", odid_item_path);

        // The resources are published by this engine according to the resource directory name
        //  i.e. the MediaResource "name" field was set to the directory name when
        //  get_resources() was called
        string resource_dir = res.get_name ();
        string resource_path = odid_item_path + resource_dir + "/";
        debug ("  resource directory: %s", resource_dir);

        string basename = get_resource_property (resource_path, "basename");

        string file_extension;
        string content_filename = ODIDMediaEngine.content_filename_for_res_speed (
                                                      odid_item_path + resource_dir,
                                                      basename,
                                                      (playspeed_request==null)
                                                       ? null
                                                       : playspeed_request.speed,
                                                      out file_extension );
        this.content_uri = resource_path + content_filename;
        debug ("    content file: %s", content_filename);

        this.content_protected = ( res.dlna_flags
                                   & DLNAFlags.LINK_PROTECTED_CONTENT ) != 0;
        if (this.content_protected) {
            // Sanity check
            if (!res.dlna_profile.has_prefix ("DTCP_")) {
                throw new DataSourceError.GENERAL
                              ("Request to stream protected content in non-protected profile: "
                               + res.dlna_profile );
            }
            debug ("      Content is protected");
        } else {
            debug ("      Content is not protected");
        }

        // Get the size for the content file
        File content_file = File.new_for_uri (this.content_uri);
        FileInfo content_info = content_file.query_info (GLib.FileAttribute.STANDARD_SIZE, 0);
        int64 total_size = content_info.get_size ();
        debug ("      Total size is " + total_size.to_string ());

        // Process PlaySpeed
        if (playspeed_request != null) {
            int framerate = 0;
            string framerate_for_speed = get_content_property
                                             (content_uri, "framerate");
            if (framerate_for_speed == null) {
                framerate = PlaySpeedResponse.NO_FRAMERATE;
            } else {
                framerate = int.parse ((framerate_for_speed == null)
                                       ? "" : framerate_for_speed);
                if (framerate == 0) {
                    framerate = PlaySpeedResponse.NO_FRAMERATE;
                }
            }
            debug ( "    framerate for speed %s: %s",
                    playspeed_request.speed.to_string (),
                    ( (framerate == PlaySpeedResponse.NO_FRAMERATE) ? "None"
                      : framerate.to_string () ) );
            var speed_response
                 = new PlaySpeedResponse.from_speed ( playspeed_request.speed,
                                                     (framerate > 0) ? framerate
                                                     : PlaySpeedResponse.NO_FRAMERATE );
            response_list.add (speed_response);
        }

        bool perform_cleartext_response;

        // Process HTTPSeekRequest
        if (seek_request == null) {
            debug ("No seek request received");
            // Set range end to 0
            this.range_length_list.add (0);
            perform_cleartext_response = false;
        } else if (seek_request is HTTPTimeSeekRequest) {
            //
            // Time-based seek
            //
            var time_seek = seek_request as HTTPTimeSeekRequest;
            bool is_reverse = (playspeed_request != null)
                              && (!playspeed_request.speed.is_positive ());

            // Calculate the effective range of the time seek using the appropriate index file

            int64 time_offset_start = time_seek.start_time;
            int64 time_offset_end;
            if (time_seek.end_time == HTTPSeekRequest.UNSPECIFIED) {
                // For time-seek, the "end" of the time range depends on the direction
                time_offset_end = is_reverse ? 0 : int64.MAX;
            } else {
                time_offset_end = time_seek.end_time;
            }

            string index_path = resource_path + "/"
                                + content_filename + ".index";
            int64 total_duration = (time_seek.total_duration
                                    != HTTPSeekRequest.UNSPECIFIED)
                                   ? time_seek.total_duration : int64.MAX;
            debug ("      Total duration is " + total_duration.to_string ());
            debug ("Processing time seek (time %lldns to %lldns)",
                   time_offset_start, time_offset_end);

            // Now set the effective time/data range and duration/size for the time range
            offsets_for_time_range (index_path, is_reverse,
                                   ref time_offset_start, ref time_offset_end,
                                   total_duration,
                                   out this.range_start, this.range_length_list,
                                   total_size );
            if (this.content_protected) {
                // We don't currently support Range on link-protected binaries. So leave out
                //  the byte range from the TimeSeekRange response
                var seek_response
                    = new HTTPTimeSeekResponse.time_only (time_offset_start,
                                                          time_offset_end,
                                                          total_duration );
                debug ("Time range for time seek: %lldms through %lldms",
                         seek_response.start_time, seek_response.end_time);
                response_list.add (seek_response);
                perform_cleartext_response = true; // We'll packet-align the range below
            } else { // No link protection
                int64 range_end = this.range_length_list[0];
                var seek_response = new HTTPTimeSeekResponse
                                            (time_offset_start, time_offset_end,
                                             total_duration,
                                             this.range_start, range_end-1,
                                             total_size);
                debug ("Time range for time seek response: %lldms through %lldms",
                       seek_response.start_time, seek_response.end_time);
                debug ("Byte range for time seek response: bytes %lld through %lld",
                       seek_response.start_byte, seek_response.end_byte );
                response_list.add (seek_response);
                perform_cleartext_response = false;
            }
        } else if (seek_request is HTTPByteSeekRequest) {
            //
            // Byte-based seek (only for non-protected content currently)
            //
            if (this.content_protected) { // Sanity check
                throw new DataSourceError.GENERAL
                              ("Byte seek not supported on protected content");
            }

            var byte_seek = seek_request as HTTPByteSeekRequest;
            debug ("Processing byte seek (bytes %lld to %s)", byte_seek.start_byte,
                   (byte_seek.end_byte == HTTPSeekRequest.UNSPECIFIED)
                   ? "*" : byte_seek.end_byte.to_string () );
            this.range_start = byte_seek.start_byte;
            if (byte_seek.end_byte == HTTPSeekRequest.UNSPECIFIED) {
                this.range_length_list.add (total_size);
            } else {
                int64 end = int64.min (byte_seek.end_byte + 1, total_size);
                this.range_length_list.add (end);
            }
            
            var seek_response = new HTTPByteSeekResponse (this.range_start,
                                                          this.range_length_list[0]-1,
                                                          total_size);
            debug ("Byte range for byte seek response: bytes %lld through %lld",
                   seek_response.start_byte, seek_response.end_byte );
            response_list.add (seek_response);
            perform_cleartext_response = false;
        } else if (seek_request is DTCPCleartextRequest) {
            //
            // Cleartext-based seek (only for link-protected content)
            //
            if (!this.content_protected) { // Sanity check
                throw new DataSourceError.GENERAL ("Cleartext seek not supported on unprotected content");
            }
            var cleartext_seek = seek_request as DTCPCleartextRequest;
            debug ( "Processing cleartext byte request (bytes %lld to %s)",
                      cleartext_seek.start_byte,
                      (cleartext_seek.end_byte == HTTPSeekRequest.UNSPECIFIED)
                      ? "*" : cleartext_seek.end_byte.to_string () );
            this.range_start = cleartext_seek.start_byte;
            if (cleartext_seek.end_byte == HTTPSeekRequest.UNSPECIFIED) {
                this.range_length_list.add (total_size);
            } else {
                int64 end = int64.min (cleartext_seek.end_byte + 1, total_size);
                this.range_length_list.add (end);
            }
            perform_cleartext_response = true; // We'll packet-align the range below
        } else {
            throw new DataSourceError.SEEK_FAILED ("Unsupported seek type");
        }

        string index_file = resource_path + "/" + content_filename + ".index";
        if (this.content_protected) {
            // The range needs to be packet-aligned, which can affect range returned
            get_packet_aligned_range( res, index_file, 
                                      this.range_start, this.range_length_list[0],
                                      total_size,
                                      out this.range_start, this.range_length_list );
        }
        if (perform_cleartext_response) {
            int64 range_end = 0;
            int64 encrypted_length = 0;
            int64 byte_range = 0;
            int64 start = this.range_start;
            foreach (int64 range_val in this.range_length_list) {
                byte_range = range_val  - start;
                range_end += byte_range;
                encrypted_length += (int64) Dtcpip.get_encrypted_length (byte_range, ODIDMediaEngine.chunk_size);
                start = range_val;
            }
            // Final element in the list becomes range_end 
            range_end = start;
            debug ("encrypted_length: %lld", encrypted_length);
            // 
            var seek_response = new DTCPCleartextResponse (this.range_start,
                                             range_end-1,
                                             total_size, encrypted_length);

            response_list.add (seek_response);
            debug ("Byte range for cleartext byte seek response: bytes %lld through %lld",
                   seek_response.start_byte, seek_response.end_byte );
        }
        
        // Command line to pipe if defined, search content, resource, item, then config.
        this.read_cmd = get_content_property (this.content_uri, READ_CMD);
        if (this.read_cmd == null) {
            this.read_cmd = get_resource_property (resource_path, READ_CMD);
            if (this.read_cmd == null) {
                if (this.keyFile.has_key ("item", READ_CMD)) {
                    this.read_cmd = this.keyFile.get_string ("item", READ_CMD);
                }
                if (this.read_cmd == null) {
                    try {
                        this.read_cmd = MetaConfig.get_default ().get_string ("OdidMediaEngine", READ_CMD);
                        if (this.read_cmd != null) {
                            debug (@"$(READ_CMD) $(this.read_cmd) defined in rygel config.");
                        }
                    } catch (Error error) {
                        // Can ignore errors
                    }
                } else {
                    debug (@"$(READ_CMD) $(this.read_cmd) defined in item property.");
                }
            } else {
                debug (@"$(READ_CMD) $(this.read_cmd) defined in resource property.");
            }
        } else {
            debug (@"$(READ_CMD) $(this.read_cmd) defined in content property.");
        }
        
        if(this.read_cmd == null) {
            debug (@"No $(READ_CMD) defined for pipe, using direct file access.");
        }
        
        // If requested bytes are not set, go for largest amount of data
        // possible.  Should get to EOF or client termination.
        if (this.range_length_list[0] == 0) {
            this.total_bytes_requested = int64.MAX;
        } else {
            this.total_bytes_requested = 
                this.range_length_list[this.range_length_list.size - 1] - range_start;
        }
        
        return response_list;
        // Wait for a start() before sending anything
    }

    /**
     * Note: range_end and aligned_end are non-inclusive
     */
    internal void get_packet_aligned_range (MediaResource res, string index_file,
                                            int64 range_start, int64 req_end_val,
                                            int64 total_size,
                                            out int64 aligned_start,
                                            Gee.ArrayList<int64?> aligned_range_list) 
       throws Error {
        //Get the transport stream packet size for the profile
        string profile = res.dlna_profile;
        aligned_start = range_start;
        // Transport streams
        if ((profile.has_prefix ("DTCP_MPEG_TS") ||
             profile.has_prefix ("DTCP_AVC_TS")) ) {
            // Align the bytes to transport packet boundaries
            int64 packet_size = ODIDUtil.get_profile_packet_size (profile);
            // TODO: Align beginning of the packet also??
            if (packet_size > 0) {
                // DLNA Link Protection : 8.9.5.4.2
                int64 aligned_end = ODIDUtil.get_dtcp_aligned_end (range_start, req_end_val,
                                                                   packet_size);
                aligned_end = int64.min (aligned_end, total_size);
                aligned_range_list[0] = aligned_end;
            }
            else {
                aligned_range_list[0] = req_end_val;
            }
        } 
        // Program streams
        else if ((profile.has_prefix ("DTCP_MPEG_PS"))) {
            // Align the 'end' to VOBU boundary
            // This can be a list of vobu offsets
            ODIDUtil.vobu_aligned_offsets_for_range (index_file,
                           range_start, req_end_val,
                           out aligned_start, aligned_range_list,
                           total_size );
        } 
        else {
            warning ("Attemped to DTCP-align unsupported protocol: "
                     + profile);
        }
    }
    
    /**
     * Find the time/data offsets that cover the provided time range start_time to end_time.
     *
     * Note: This method will clamp the end time/offset to the duration/total_size if not
     *       present in the index file.
     */
    internal void offsets_for_time_range (string index_path, bool is_reverse,
                                          ref int64 start_time, ref int64 end_time,
                                          int64 total_duration,
                                          out int64 start_offset, Gee.ArrayList<int64?> end_offset_list,
                                          int64 total_size)
         throws Error {
        debug ("offsets_for_time_range: %s, %lld-%s",
               index_path, start_time,
               ((end_time != int64.MAX) ? end_time.to_string () : "*") );
        bool start_offset_found = false;
        bool end_offset_found = false;

        var file = File.new_for_uri (index_path);
        var dis = new DataInputStream (file.read ());
        string line;
        int64 cur_time_offset = 0;
        string cur_data_offset = null;
        int64 last_time_offset = is_reverse ? total_duration : 0; // Time can go backward
        string last_data_offset = "0"; // but data offsets always go forward...
        start_offset = int64.MAX;
        int line_count = 0;
        end_offset_list.clear ();
        // Read lines until end of file (null) is reached
        while ((line = dis.read_line (null)) != null) {
            line_count++;
            // Entry Type (V: Video Frame)
            // | Video Frame Type (I,B,P)
            // | | Time Offset (seconds.milliseconds) (fixed decimal places, 8.3)
            // | | |            File Byte Offset (fixed decimal places, 19)
            // | | |            |                   Frame size (fixed decimal places, 10)
            // | | |            |                   |
            // v v v            v                   v
            // V F 00000000.000 0000000000000000000 0000000000<16 spaces><newline>
            if (line.length != ODIDMediaEngine.INDEXFILE_ROW_SIZE-1) {
                throw new ODIDMediaEngineError.INDEX_FILE_ERROR (
                              "Bad index file entry size (line %d of %s is %d bytes - should be %d bytes): '%s'",
                              line_count, index_path, line.length,
                              ODIDMediaEngine.INDEXFILE_ROW_SIZE, line);
            }
            var index_fields = line.split (" "); // Could use fixed field positions here...
            if ((index_fields[0][0] == 'V') && (index_fields[1][0] == 'I')) {
                string time_offset_string = index_fields[2];
                string extended_time_string = time_offset_string[0:7]
                                              + time_offset_string[8:11]
                                              + "000";
                // Leading "0"s cause parse() to assume the value is octal (see Vala bug 656691)
                cur_time_offset = int64.parse (strip_leading_zeros
                                                   (extended_time_string));
                cur_data_offset = index_fields[3]; // Convert this only when needed
                // debug ("offsets_for_time_range: keyframe at %s (%s) has offset %s",
                //       extended_time_string, cur_time_offset.to_string(), cur_data_offset);
                if (!start_offset_found) {
                    if ( (is_reverse && (cur_time_offset < start_time))
                         || (!is_reverse && (cur_time_offset > start_time)) ) {
                        start_time = last_time_offset;
                        start_offset = int64.parse (strip_leading_zeros
                                                        (last_data_offset));
                        start_offset_found = true;
                        debug ("offsets_for_time_range: found start of range (%s): time %lld, offset %lld",
                               (is_reverse ? "reverse" : "forward"),
                               start_time, start_offset);
                    }
                } else {
                    if ( (is_reverse && (cur_time_offset < end_time))
                         || (!is_reverse && (cur_time_offset > end_time)) ) {
                        int64 end_offset = int64.parse (strip_leading_zeros (cur_data_offset));
                        end_time = cur_time_offset;
                        end_offset_list.add (end_offset);
                        end_offset_found = true;
                        debug ("offsets_for_time_range: found end of range (%s): time %lld, offset %lld",
                               (is_reverse ? "reverse" : "forward"),
                               end_time, end_offset);
                        break;
                    }
                }
                last_time_offset = cur_time_offset;
                last_data_offset = cur_data_offset;
            }
        }

        if (!start_offset_found) {
            throw new DataSourceError.SEEK_FAILED ("Start time %lld is out of index file range",
                                                  start_time);
        }

        if (!end_offset_found) {
            // Modify the end byte value to align to start/end of the file, if necessary
            //  (see DLNA 7.5.4.3.2.24.4)
            int64 end_offset = total_size;
            if (is_reverse) {
                end_time = 0;
            } else {
                end_time = total_duration;
            }
            end_offset_list.add (end_offset);
            debug ("offsets_for_time_range: end of range beyond index range (%s): time %lld, offset %lld",
                   (is_reverse ? "reverse" : "forward"), end_time, end_offset);
        }
    }

    internal static string strip_leading_zeros (string number_string) {
        return ODIDMediaEngine.strip_leading_zeros (number_string);
    }

    internal string ? get_resource_property (string odid_resource_uri,
                                             string property_name)
         throws Error {
        return get_property_from_file (odid_resource_uri + "resource.info",
                                       property_name);
    }

    internal string ? get_content_property (string odid_content_uri,
                                            string property_name)
         throws Error {
        string content_info_filename = odid_content_uri + ".info";
        try {
            return get_property_from_file (content_info_filename, property_name);
        } catch (Error error) {
            debug ("Content info file %s not found (non-fatal)", content_info_filename);
            return null;
        }
    }

    internal string ? get_property_from_file (string uri, string property_name)
         throws Error {
        var file = File.new_for_uri (uri);
        var dis = new DataInputStream (file.read ());
        string line;
        // Read lines until end of file (null) is reached
        while ((line = dis.read_line (null)) != null) {
            if (line[0] == '#') continue;
            var equals_pos = line.index_of ("=");
            var name = line[0:equals_pos].strip ();
            if (name == property_name) {
                var value = line[equals_pos+1:line.length].strip ();
                return ((value.length == 0) ? null : value);
            }
        }

        return null;
    }

    public void start () throws Error {
        debug ("Starting data source for %s", content_uri);

        if (this.content_protected) {
            Dtcpip.server_dtcp_open (out dtcp_session_handle, 0);

            if (dtcp_session_handle == -1) {
                warning ("DTCP-IP session not opened");
                throw new DataSourceError.GENERAL ("Error starting DTCP session");
            } else {
                debug ("Entering DTCP-IP streaming mode (session handle 0x%X)",
                         dtcp_session_handle);
            }
        }

        var file = File.new_for_uri (this.content_uri);
            
        // Create channel for piped command or file on disk.
        this.output = this.read_cmd == null ? 
            channel_from_disk (file) : channel_from_pipe (file);

        // If something is wrong throw execption.
        if (this.output == null) {
            throw new DataSourceError.GENERAL ("Unable to access data source.");
        }
            
        // Set channel options
        this.output.set_encoding (null);
        // Set channel buffer to be required chunk size.  In an effort to not
        // block when we are called to read.
        if (this.range_length_list.size > 1) {
            this.output.set_buffer_size 
                ((size_t) (this.range_length_list[this.alignment_pos++] - 
                this.range_start));
        } else {
            this.output.set_buffer_size ((size_t) ODIDMediaEngine.chunk_size);
        }

        // Async event callback when data is available from channel.  We expect
        // our set buffer worth or data will be available on the channel
        // without blocking.    
        this.output_watch_id =          
            this.output.add_watch 
                (IOCondition.IN | IOCondition.ERR | IOCondition.HUP, read_data);
    }

    public void freeze () {
        // This will cause the async event callback to remove itself from
        // the main event loop.
        this.frozen = true;
    }

    public void thaw () {
        if (this.frozen) {
            // We need to add the async event callback into the main event
            // loop.
            this.frozen = false;
            this.output.add_watch
                (IOCondition.IN | IOCondition.ERR | IOCondition.HUP, read_data);            
        }
    }

    public void stop () {
        // If pipe used, reap child otherwise shut down channel.
        // Make sure event callback is removed from main loop.
        if ((int)this.child_pid != 0) {
            debug (@"Stopping pid: $(this.child_pid)");
            Posix.kill (this.child_pid, Posix.SIGTERM);
        } else {
            GLib.Source.remove (this.output_watch_id);
        }
    }

    public void clear_dtcp_session () {
        if (dtcp_session_handle != -1) {
            int ret_close = Dtcpip.server_dtcp_close (dtcp_session_handle);
            debug ("Dtcp session closed : %d",ret_close);
            dtcp_session_handle = -1;
        }
    }
    
    // Creates a channel to read data from a command's stdout through a pipe.
    private IOChannel channel_from_pipe (File file) throws IOChannelError {
        IOChannel channel = null;
        
        try {
            // Fill in any runtime parameters
            this.read_cmd = FB_REGEX.replace_literal (
                this.read_cmd, -1, 0, this.range_start.to_string ());
            this.read_cmd = LB_REGEX.replace_literal (
                this.read_cmd, -1, 0, (this.range_start +
                    this.total_bytes_requested).to_string ());
            this.read_cmd = NB_REGEX.replace_literal (
                this.read_cmd, -1, 0, this.total_bytes_requested.to_string ());
            this.read_cmd = FILE_REGEX.replace_literal (
                this.read_cmd, -1, 0, file.get_path ());
            
            string[] spawn_args = this.read_cmd.split (" ");
            
            string[] spawn_env = Environ.get ();
            
            int standard_output;
            
            Process.spawn_async_with_pipes ("/",
                spawn_args,
                spawn_env,
                SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
                null,
                out this.child_pid,
                null,
                out standard_output,
                null);
                
            debug (@"Spawned pid: $(child_pid) $(READ_CMD): $(this.read_cmd)");
            
            channel = new IOChannel.unix_new (standard_output);
        
            ChildWatch.add (this.child_pid, (pid, status) => {
                debug (@"Closing child pid: $(pid)");
                done ();
                Process.close_pid (pid);
                try {
                    if (this.output != null) {
                        this.output.shutdown (true);
                    }
                } catch (IOChannelError ioce) {
                    message (@"Error shutting down IOChannel: $(ioce.message)");
                }
                
                if (this.output_watch_id != -1)
                {
                    GLib.Source.remove (this.output_watch_id);
                }
            });
        } catch (SpawnError se) {
            message (@"Error opening pipe: $(se.message)");
        } catch (GLib.RegexError re) {
            message (@"Error in regexp: $(re.message)");
        }
            
        return channel;
    }
    
    // Creates a channel to read data from a file on disk.
    private IOChannel channel_from_disk (File file) throws IOChannelError {
        IOChannel channel = null;
        try {
            channel = new IOChannel.file (file.get_path (), "r");
            channel.seek_position (this.range_start, SeekType.CUR);
        } catch (GLib.FileError e) {
            message (@"Error opening file: $(e.message)");
        }
        
        return channel;
    }
    
    // Async event callback is called when data is available on a channel, this
    // method will be called mulitple times till the data source has exhausted
    // the requested bytes or the channel closes (in the case of a pipe).
    private bool read_data (IOChannel channel, IOCondition condition) {
        if (condition == IOCondition.HUP || condition == IOCondition.ERR) {
            done ();
            return false;
        }
        
        size_t bytes_read = 0;
        int64 bytes_left_to_read = this.total_bytes_requested - this.total_bytes_read;

        char[] read_buffer = null;
        
        int64 max_bytes = this.output.get_buffer_size ();
        
        // Truncate to remaining bytes if needed.
        max_bytes = max_bytes < bytes_left_to_read ? 
                max_bytes : bytes_left_to_read;
        
        // Create a read buffer of approprate size
        read_buffer = new char[max_bytes];
        
        try {
            // Read data off of channel
            IOStatus status = channel.read_chars (read_buffer, out bytes_read);         
            if (status == IOStatus.EOF) {
                done ();
                return false;
            }
                        
            this.total_bytes_read += bytes_read;
            
            debug (@"buffer=$(max_bytes) read=$(bytes_read) left=$(bytes_left_to_read)");
                        
            if (this.dtcp_session_handle == -1) {
                // No content protection
                // Call event to send buffer to client
                data_available ((uint8[])read_buffer[0:bytes_read]);
            } else {
                // Encrypted data has to be unowned as the reference will be passed
                // to DTCP libraries to perform the cleanup, else vala will be
                //performing the cleanup by default.
                unowned uint8[] encrypted_data = null;
                uchar cci = 0x3; // TODO: Put the CCI bits in resource.info

                // Encrypt the data
                int return_value = Dtcpip.server_dtcp_encrypt
                                  ( dtcp_session_handle, cci,
                                    (uint8[])read_buffer[0:bytes_read], 
                                    out encrypted_data );
                
                debug ("Encryption returned: %d and the encryption size : %s",
                  return_value,
                  (encrypted_data == null)
                   ? "NULL" : encrypted_data.length.to_string ());
                            
                // Call event to send buffer to client
                data_available (encrypted_data);
                
                int ret_free = Dtcpip.server_dtcp_free (encrypted_data);
                debug ("DTCP-IP data reference freed : %d", ret_free);
            }
        } catch (IOChannelError e) {
            message (@"IOChannelError: $(e.message)");
            done ();
            return false;
        } catch (ConvertError e) {
            message (@"ConvertError: $(e.message)");
            done ();
            return false;
        }
        
        debug (@"bytes written $(this.total_bytes_read)");
        
        // If we are aligning VOBU per PCP, we need to set the channel buffer to 
        // the next VOBU buffer size.  This way we won't block when we get called
        // to read again.
        int list_size = this.range_length_list.size; // just for short hand
        if (list_size > 1 && list_size - 1 >= this.alignment_pos) {
            this.output.set_buffer_size 
                ((size_t) (this.range_length_list[this.alignment_pos++] 
                - this.total_bytes_read));
        }

        if (this.total_bytes_read >= this.total_bytes_requested) {
            done ();
        }

        // Keep reading from channel if data left and not frozen.
        return !this.frozen && this.total_bytes_read < this.total_bytes_requested;
    }
}

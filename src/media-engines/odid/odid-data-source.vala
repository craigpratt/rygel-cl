/* 
 * Copyright (C) 2013  Cable Television Laboratories, Inc.
 * Contact: http://www.cablelabs.com/
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
 *
 * Author: Craig Pratt <craig@ecaspia.com>
 * Author: Parthiban Balasubramanian <P.Balasubramanian-contractor@cablelabs.com>
 */

/*
 * Based on Rygel SimpleDataSource
 * Copyright (C) 2012 Intel Corporation.
 *
 */
 
/**
 * A simple data source for use with the ODID media engine.
 */
using GUPnP;

internal class Rygel.ODIDDataSource : DataSource, Object {
    private string source_uri; 
    private Thread<void*> thread;
    private string content_uri;
    private Mutex mutex = Mutex ();
    private Cond cond = Cond ();
    private int64 range_start = 0;
    private int64 range_end = 0; // non-inclusive
    private bool frozen = false;
    private bool stop_thread = false;
    private HTTPSeekRequest seek_request;
    private DLNAPlaySpeedRequest playspeed_request = null;
    private MediaResource res;
    private bool content_protected = false;
    private int dtcp_session_handle = -1;

    public ODIDDataSource(string source_uri, MediaResource ? res) {
        debug ("Creating data source for %s resource %s", source_uri, res.get_name());
        this.source_uri = source_uri;
        this.res = res;
    }

    ~ODIDDataSource() {
        this.stop ();
        this.clear_dtcp_session();
        debug ("Stopped data source");
    }

    public Gee.List<HTTPResponseElement> ? preroll ( HTTPSeekRequest? seek_request,
                                                     DLNAPlaySpeedRequest? playspeed_request)
       throws Error {
        debug("source uri: " + source_uri);

        var response_list = new Gee.ArrayList<HTTPResponseElement>();

        this.seek_request = seek_request;
        this.playspeed_request = playspeed_request;

        if (res == null) {
            throw new DataSourceError.GENERAL("null resource");
        }

        debug("Resource %s size: %lld", res.get_name(), res.size);
        debug("Resource %s duration: %lld", res.get_name(), res.duration);
        debug("Resource %s protocol_info: %s", res.get_name(), res.protocol_info.to_string());
        debug("Resource %s profile: %s", res.get_name(), res.protocol_info.dlna_profile);

        KeyFile keyFile = new KeyFile();
        keyFile.load_from_file(File.new_for_uri (source_uri).get_path (),
                               KeyFileFlags.KEEP_COMMENTS |
                               KeyFileFlags.KEEP_TRANSLATIONS);

        string odid_item_path = keyFile.get_string ("item", "odid_uri");
        debug ("Source item path: %s", odid_item_path);

        // The resources are published by this engine according to the resource directory name
        //  i.e. the MediaResource "name" field was set to the directory name when
        //  get_resources_for_uri() was called
        string resource_dir = res.get_name();
        string resource_path = odid_item_path + resource_dir + "/";
        debug ("  resource directory: %s", resource_dir);

        string basename = get_resource_property(resource_path,"basename");

        string file_extension;
        string content_filename = ODIDMediaEngine.content_filename_for_res_speed (
                                                            odid_item_path + resource_dir,
                                                            basename,
                                                            (playspeed_request==null)
                                                              ? null : playspeed_request.speed,
                                                            out file_extension );
        this.content_uri = resource_path + content_filename;
        debug ("    content file: %s", content_filename);

        this.content_protected = ( res.protocol_info.dlna_flags
                                   & DLNAFlags.LINK_PROTECTED_CONTENT ) != 0;
        if (this.content_protected) {
            // Sanity check
            if (!res.protocol_info.dlna_profile.has_prefix("DTCP_")) {
                throw new DataSourceError.GENERAL("Request to stream protected content in non-protected profile: "
                                                  + res.protocol_info.dlna_profile );
            }
            debug ("      Content is protected");
        } else {
            debug ("      Content is not protected");
        }
        
        // Get the size for the content file 
        File content_file = File.new_for_uri(this.content_uri);
        FileInfo content_info = content_file.query_info(GLib.FileAttribute.STANDARD_SIZE, 0);
        int64 total_size = content_info.get_size();
        debug ("      Total size is " + total_size.to_string());

        // Process PlaySpeed
        if (playspeed_request != null) {
            int framerate = 0;
            string framerate_for_speed = get_content_property(content_uri, "framerate");
            if (framerate_for_speed == null) {
                framerate = DLNAPlaySpeedResponse.NO_FRAMERATE;
            } else {
                framerate = int.parse((framerate_for_speed == null) ? "" : framerate_for_speed);
                if (framerate == 0) {
                    framerate = DLNAPlaySpeedResponse.NO_FRAMERATE;
                }
            }
            debug ( "    framerate for speed %s: %s",
                      playspeed_request.speed.to_string(),
                      ( (framerate == DLNAPlaySpeedResponse.NO_FRAMERATE) ? "None"
                        : framerate.to_string() ) );
            var speed_response
                 = new DLNAPlaySpeedResponse.from_speed( playspeed_request.speed,
                                                         (framerate > 0) ? framerate
                                                         : DLNAPlaySpeedResponse.NO_FRAMERATE );
            response_list.add(speed_response);
        }

        bool perform_cleartext_response;

        // Process HTTPSeekRequest
        if (seek_request == null) {
            debug ("No seek request received");
            perform_cleartext_response = false;
        } else if (seek_request is HTTPTimeSeekRequest) {
            //
            // Time-based seek
            //
            var time_seek = seek_request as HTTPTimeSeekRequest;
            bool is_reverse = (playspeed_request != null) && (playspeed_request.speed.is_negative());

            // Calculate the effective range of the time seek using the appropriate index file
            
            int64 time_offset_start = time_seek.start_time;
            int64 time_offset_end;
            if (time_seek.end_time == HTTPSeekRequest.UNSPECIFIED) {
                // For time-seek, the "end" of the time range depends on the direction
                time_offset_end = is_reverse ? 0 : int64.MAX;
            } else { 
                time_offset_end = time_seek.end_time;
            }

            string index_path = resource_path + "/" + content_filename + ".index";
            int64 total_duration = (time_seek.total_duration != HTTPSeekRequest.UNSPECIFIED)
                                   ? time_seek.total_duration
                                   : int64.MAX;
            debug ("      Total duration is " + total_duration.to_string());
            debug ("Processing time seek (time %lldns to %lldns)", time_offset_start, time_offset_end);
            
            // Now set the effective time/data range and duration/size for the time range
            offsets_for_time_range(index_path, is_reverse,
                                   ref time_offset_start, ref time_offset_end, total_duration,
                                   out this.range_start, out this.range_end, total_size );

            if (this.content_protected) {
                // We don't currently support Range on link-protected binaries. So leave out
                //  the byte range from the TimeSeekRange response
                var seek_response
                    = new HTTPTimeSeekResponse.time_only( time_offset_start, time_offset_end,
                                                          total_duration );
                debug ("Time range for time seek: %lldms through %lldms",
                         seek_response.start_time, seek_response.end_time);
                response_list.add(seek_response);
                perform_cleartext_response = true; // We'll packet-align the range below
            } else { // No link protection
                var seek_response = new HTTPTimeSeekResponse( time_offset_start, time_offset_end,
                                                              total_duration,
                                                              this.range_start, this.range_end-1,
                                                              total_size );
                debug ("Time range for time seek response: %lldms through %lldms",
                         seek_response.start_time, seek_response.end_time);
                debug ("Byte range for time seek response: bytes %lld through %lld",
                         seek_response.start_byte, seek_response.end_byte );
                response_list.add(seek_response);
                perform_cleartext_response = false;
            }
        } else if (seek_request is HTTPByteSeekRequest) {
            //
            // Byte-based seek (only for non-protected content currently)
            //
            if (this.content_protected) { // Sanity check
                throw new DataSourceError.GENERAL("Byte seek not supported on protected content");
            }
            var byte_seek = seek_request as HTTPByteSeekRequest;
            debug ("Processing byte seek (bytes %lld to %s)", byte_seek.start_byte,
                     (byte_seek.end_byte == HTTPSeekRequest.UNSPECIFIED)
                     ? "*" : byte_seek.end_byte.to_string() );
            this.range_start = byte_seek.start_byte;
            if (byte_seek.end_byte == HTTPSeekRequest.UNSPECIFIED) {
                this.range_end = total_size;
            } else {
                this.range_end = int64.min(byte_seek.end_byte + 1, total_size);
            }
            var seek_response = new HTTPByteSeekResponse( this.range_start, this.range_end-1,
                                                          total_size);
            debug ("Byte range for byte seek response: bytes %lld through %lld",
                     seek_response.start_byte, seek_response.end_byte );
            response_list.add(seek_response);
            perform_cleartext_response = false;
        } else if (seek_request is DTCPCleartextByteSeekRequest) {
            //
            // Cleartext-based seek (only for link-protected content)
            //
            if (!this.content_protected) { // Sanity check
                throw new DataSourceError.GENERAL("Cleartext seek not supported on unprotected content");
            }
            var cleartext_seek = seek_request as DTCPCleartextByteSeekRequest;
            debug ( "Processing cleartext byte seek (bytes %lld to %s)",
                      cleartext_seek.start_byte,
                      (cleartext_seek.end_byte == HTTPSeekRequest.UNSPECIFIED)
                      ? "*" : cleartext_seek.end_byte.to_string() );
            this.range_start = cleartext_seek.start_byte;
            if (cleartext_seek.end_byte == HTTPSeekRequest.UNSPECIFIED) {
                this.range_end = total_size;
            } else {
                this.range_end = int64.min(cleartext_seek.end_byte + 1, total_size);
            }
            perform_cleartext_response = true; // We'll packet-align the range below
        } else {
            throw new DataSourceError.SEEK_FAILED("Unsupported seek type");
        }

        if (perform_cleartext_response) {
            // The range needs to be packet-aligned, which can affect range returned
            get_packet_aligned_range( res, this.range_start, this.range_end,
                                      total_size,
                                      out this.range_start, out this.range_end );
            var seek_response
                = new DTCPCleartextByteSeekResponse(this.range_start,this.range_end-1,total_size);
            
            seek_response.encrypted_length = 
                               (int64)DTCPShim.get_encrypted_length( seek_response.range_length,
                                                                     ODIDUtil.get_chunk_size());
            
            response_list.add(seek_response);
            debug ("Byte range for cleartext byte seek response: bytes %lld through %lld",
                     seek_response.start_byte, seek_response.end_byte );
        }

        return response_list;
        // Wait for a start() before sending anything
    }

    /**
     * Note: range_end and aligned_end are non-inclusive
     */
    internal void get_packet_aligned_range ( MediaResource res,
                                             int64 range_start, int64 range_end, int64 total_size,
                                             out int64 aligned_start, out int64 aligned_end ) {
        //Get the transport stream packet size for the profile
        string profile_name = res.protocol_info.dlna_profile;
        // Align the bytes to transport packet boundaries
        int64 packet_size = ODIDUtil.get_profile_packet_size(profile_name);
        aligned_start = range_start;
        if (packet_size > 0) {
            // DLNA Link Protection : 8.9.5.4.2
            aligned_end = ODIDUtil.get_dtcp_aligned_end(range_start, range_end, packet_size);
            aligned_end = int64.min(aligned_end, total_size);
        } else {
            warning("Attemped to DTCP-align unsupported protocol: " + profile_name);
            aligned_end = range_end;
        }
    }
    
    /**
     * Find the time/data offsets that cover the provided time range start_time to end_time.
     *
     * Note: This method will clamp the end time/offset to the duration/total_size if not
     *       present in the index file.
     */
    internal void offsets_for_time_range(string index_path, bool is_reverse, 
                                         ref int64 start_time, ref int64 end_time, int64 total_duration, 
                                         out int64 start_offset, out int64 end_offset, int64 total_size)
         throws Error {
        debug ("offsets_for_time_range: %s, %lld-%s",
                 index_path,start_time, ((end_time != int64.MAX) ? end_time.to_string() : "*") );
        bool start_offset_found = false;
        bool end_offset_found = false;

        var file = File.new_for_uri(index_path);
        var dis = new DataInputStream(file.read());
        string line;
        int64 cur_time_offset = 0;
        string cur_data_offset = null;
        int64 last_time_offset = is_reverse ? total_duration : 0; // Time can go backward
        string last_data_offset = "0"; // but data offsets always go forward...
        start_offset = int64.MAX;
        end_offset = int64.MAX;
        // Read lines until end of file (null) is reached
        while ((line = dis.read_line (null)) != null) {
            // Entry Type (V: Video Frame)
            // | Video Frame Type (I,B,P)
            // | | Time Offset (seconds.milliseconds) (fixed decimal places, 8.3)
            // | | |            File Byte Offset (fixed decimal places, 19)
            // | | |            |                   Frame size (fixed decimal places, 10)
            // | | |            |                   |
            // v v v            v                   v
            // V F 00000000.000 0000000000000000000 0000000000<16 spaces><newline>
            var index_fields = line.split(" "); // Could use fixed field positions here...
            if ((index_fields[0][0] == 'V') && (index_fields[1][0] == 'I')) {
                string time_offset_string = index_fields[2];
                string extended_time_string = time_offset_string[0:7]+time_offset_string[8:11]+"000";
                // Leading "0"s cause parse() to assume the value is octal (see Vala bug 656691)
                cur_time_offset = int64.parse(strip_leading_zeros(extended_time_string));
                cur_data_offset = index_fields[3]; // Convert this only when needed
                // debug ("offsets_for_time_range: keyframe at %s (%s) has offset %s",
                //       extended_time_string, cur_time_offset.to_string(), cur_data_offset);
                if (!start_offset_found) {
                    if ( (is_reverse && (cur_time_offset < start_time))
                         || (!is_reverse && (cur_time_offset > start_time)) ) {
                        start_time = last_time_offset;
                        start_offset = int64.parse(strip_leading_zeros(last_data_offset));
                        start_offset_found = true;
                        debug ("offsets_for_time_range: found start of range (%s): time %lld, offset %lld",
                                 (is_reverse ? "reverse" : "forward"), start_time, start_offset);
                    }
                } else {
                    if ( (is_reverse && (cur_time_offset < end_time))
                         || (!is_reverse && (cur_time_offset > end_time)) ) {
                        end_time = cur_time_offset;
                        end_offset = int64.parse(strip_leading_zeros(cur_data_offset));
                        end_offset_found = true;
                        debug ("offsets_for_time_range: found end of range (%s): time %lld, offset %lld",
                                 (is_reverse ? "reverse" : "forward"), end_time, end_offset);
                        break;
                    }
                }
                last_time_offset = cur_time_offset;
                last_data_offset = cur_data_offset;
            }
        }

        if (!start_offset_found) {
            throw new DataSourceError.SEEK_FAILED("Start time %lld is out of index file range",
                                                  start_time);
        }

        if (!end_offset_found) {
            // Modify the end byte value to align to start/end of the file, if necessary
            //  (see DLNA 7.5.4.3.2.24.4)
            end_offset = total_size;
            if (is_reverse) {
                end_time = 0;
            } else {
                end_time = total_duration;
            }
            debug ("offsets_for_time_range: end of range beyond index range (%s): time %lld, offset %lld",
                     (is_reverse ? "reverse" : "forward"), end_time, end_offset);
        }
    }

    internal static string strip_leading_zeros(string number_string) {
        return ODIDMediaEngine.strip_leading_zeros(number_string);
    }

    internal string ? get_resource_property(string odid_resource_uri, string property_name)
         throws Error {
        return get_property_from_file(odid_resource_uri + "resource.info", property_name);
    }

    internal string ? get_content_property(string odid_content_uri, string property_name)
         throws Error {
        return get_property_from_file(odid_content_uri + ".info", property_name);
    }

    internal string ? get_property_from_file(string uri, string property_name)
         throws Error {
        var file = File.new_for_uri(uri);
        var dis = new DataInputStream(file.read());
        string line;
        // Read lines until end of file (null) is reached
        while ((line = dis.read_line(null)) != null) {
            if (line[0] == '#') continue;
            var equals_pos = line.index_of("=");
            var name = line[0:equals_pos].strip();
            if (name == property_name) {
                var value = line[equals_pos+1:line.length].strip();
                return ((value.length == 0) ? null : value);
            }
        }

        return null;
    }
    
    public void start () throws Error {
        debug ("Starting data source for %s", content_uri);

        if (this.content_protected) {
            DTCPShim.server_dtcp_open (out dtcp_session_handle, 0);

            if (dtcp_session_handle == -1) {
                warning ("DTCP-IP session not opened");
                throw new DataSourceError.GENERAL("Error starting DTCP session");
            } else {
                debug ("Entering DTCP-IP streaming mode (session handle 0x%X)",
                         dtcp_session_handle);
            }
        }

        // TODO: Change this to use a persistent thread or thread pool...
        this.thread = new Thread<void*>("ODIDDataSource Serving thread",
                                         this.thread_func);
    }

    public void freeze () {
        if (this.frozen) {
            return;
        }

        this.mutex.lock();
        this.frozen = true;
        this.mutex.unlock ();
    }

    public void thaw() {
        if (!this.frozen) {
            return;
        }

        this.mutex.lock();
        this.frozen = false;
        this.cond.broadcast();
        this.mutex.unlock();
    }

    public void stop() 
    {
        if (this.stop_thread) 
        {
            return;
        }

        this.mutex.lock();
        this.frozen = false;
        this.stop_thread = true;
        this.cond.broadcast();
        this.mutex.unlock();
    }

    public void clear_dtcp_session() {
        if (dtcp_session_handle != -1) {
            int ret_close = DTCPShim.server_dtcp_close (dtcp_session_handle);
            debug ("Dtcp session closed : %d",ret_close);
            dtcp_session_handle = -1;
        }
    }
    private void* thread_func() {
        var file = File.new_for_uri (this.content_uri);
        debug ("Spawned new thread for streaming %s", this.content_uri);
        try {
            var mapped = new MappedFile(file.get_path (), false);

            if (this.range_end == 0) {
                this.range_end = mapped.get_length();
            }
            
            debug ( "Sending bytes %lld-%lld (%lld bytes) of %s",
                      this.range_start, this.range_end, this.range_end-this.range_start,
                      this.content_uri );

            while (true) {
                bool exit;
                this.mutex.lock ();
                while (this.frozen) {
                    this.cond.wait (this.mutex);
                }

                exit = this.stop_thread;
                this.mutex.unlock ();

                if (exit || this.range_start >= this.range_end) {
                    debug ("Done streaming!");
                    break;
                }

                var start = this.range_start;
                var stop = start + ODIDUtil.get_chunk_size();
                if (stop > this.range_end) {
                    stop = this.range_end;
                }

                // debug ( "Sending range %lld-%lld (%lld bytes)",
                //           start, stop, stop-start );

                unowned uint8[] data = (uint8[]) mapped.get_contents ();
                data.length = (int) mapped.get_length ();
                uint8[] slice = data[start:stop];
                this.range_start = stop; // Move forward

                if (this.dtcp_session_handle == -1) {
                    // There's a potential race condition here.
                    Idle.add ( () => {
                        if (!this.stop_thread) {
                            this.data_available (slice);
                        }
                        return false;
                    });
                } else {
                    // Encrypted data has to be unowned as the reference will be passed
                    // to DTCP libraries to perform the cleanup, else vala will be
                    //performing the cleanup by default.
                    unowned uint8[] encrypted_data = null;
                    uchar cci = 0x3; // TODO: Put the CCI bits in resource.info

                    // Encrypt the data
                    int return_value = DTCPShim.server_dtcp_encrypt ( dtcp_session_handle, cci,
                                                                      slice, out encrypted_data );
                    debug ("Encryption returned: %d and the encryption size : %s",
                           return_value,
                           (encrypted_data == null) ? "NULL" : encrypted_data.length.to_string() );
                    // There's a potential race condition here.
                    Idle.add ( () => {
                        if (!this.stop_thread) {
                            this.data_available (encrypted_data);
                        }

                        int ret_free = DTCPShim.server_dtcp_free (encrypted_data);
                        debug ("DTCP-IP data reference freed : %d", ret_free);

                        return false;
                    });
                }
            }
        } catch (Error error) {
            warning ("Failed to stream: %s", error.message);
        }

        // Signal that we're done streaming
        Idle.add ( () => { this.done (); return false; });

        return null;
    }
}

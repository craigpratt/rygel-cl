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
    public static const int64 DEFAULT_CHUNK_SIZE = 1536 * KILOBYTES_TO_BYTES;
    public static const uint LIVE_CHUNKS_PER_SECOND = 2;

    protected string resource_uri;
    protected string content_uri;
    protected string index_uri;
    protected int64 range_start = 0;
    protected bool frozen = false;
    protected bool stopped = false;
    protected HTTPSeekRequest seek_request;
    protected PlaySpeedRequest playspeed_request = null;
    protected bool speed_files_scaled;
    protected MediaResource res;
    protected bool content_protected = false;
    protected int dtcp_session_handle = -1;
    protected int64 chunk_size; // HTTP chunk size to use (when chunking)
    protected Gee.ArrayList<int64?> range_offset_list = new Gee.ArrayList<int64?> ();
    protected ODIDLiveSimulator live_sim = null;
    protected DataInputStream index_stream;
    protected uint pacing_timer;
    protected bool pacing;

    // Post condition to preroll (int64.MAX: send indefinitely)
    protected int64 total_bytes_requested = 0;
    
    // Keep track as the progress through the byte range.
    protected int64 total_bytes_read = 0;
    protected int64 total_bytes_written = 0;
    
    // Track position in the range_offset_list (for VOBU alignment of PCPs) 
    private int range_offset_index;
    
    private IOChannel output;
    private uint output_watch_id = -1;
    
    // Pipe channel support
    private static const string READ_CMD = "read-cmd";
    private string read_cmd = null;
    private Pid child_pid = 0;

    // MP4 container source support (for MP4 time-seek response generation)
    private IsoFileContainerBox mp4_container_source = null;

    // MP2 restamping support (for MP2 playspeed response generation)
    private MP2TSRestamper mp2ts_restamper = null;
    private bool restamp_mp2_files = false;

    private BufferGeneratingOutputStream bufgen_stream = null;
    private Thread bufgen_thread = null;
    
    private GLib.Regex FB_REGEX;
    private GLib.Regex LB_REGEX;
    private GLib.Regex NB_REGEX;
    private GLib.Regex FILE_REGEX;
      
    public ODIDDataSource (string resource_uri, MediaResource ? res, int64 chunk_size) {
        this.resource_uri = resource_uri;
        this.res = res;
        this.chunk_size = (chunk_size > 0) ? chunk_size : DEFAULT_CHUNK_SIZE;
    }

    public ODIDDataSource.from_live (ODIDLiveSimulator live_sim, MediaResource res,
                                     int64 chunk_size) {
        this.live_sim = live_sim;
        this.resource_uri = live_sim.resource_uri;
        this.res = res;
        this.chunk_size = chunk_size;
        
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
    }

    public Gee.List<HTTPResponseElement> ? preroll ( HTTPSeekRequest? seek_request,
                                                     PlaySpeedRequest? playspeed_request)
       throws Error {
        debug ("resource uri: " + this.resource_uri);
        debug ("Resource " + this.res.to_string ());

        this.restamp_mp2_files = ODIDUtil.get_resource_property (this.resource_uri, "restamp")
                                 == "true";
        //
        // Setup and checks...
        //
        this.seek_request = seek_request;
        this.playspeed_request = playspeed_request;

        string basename = ODIDUtil.get_resource_property (this.resource_uri, "basename");
        string file_extension;
        string content_filename = ODIDUtil.content_filename_for_res_speed (
                                                      this.resource_uri,
                                                      basename,
                                                      (this.playspeed_request==null)
                                                       ? null // indicates normal-rate
                                                       : this.playspeed_request.speed,
                                                      out file_extension );
        this.content_uri = this.resource_uri + content_filename;
        this.index_uri = this.content_uri + ".index";
        debug ("  content file: %s", content_filename);

        File content_file = File.new_for_uri (this.content_uri);
        File content_index_file = File.new_for_uri (this.index_uri);
        this.content_protected = (DLNAFlags.LINK_PROTECTED_CONTENT in this.res.dlna_flags);
        if (this.content_protected) {
            if (!this.res.dlna_profile.has_prefix ("DTCP_")) {
                throw new DataSourceError.GENERAL
                              ("Request to stream protected content in non-protected profile: "
                               + this.res.dlna_profile );
            }
            debug ("    Content is protected");
        } else {
            debug ("    Content is not protected");
        }

        //
        // Process the request...
        //
        var response_list = new Gee.ArrayList<HTTPResponseElement> ();

        // Process PlaySpeed
        if (this.playspeed_request != null) {
            debug ( "    Content speed requested: %s", this.playspeed_request.speed.to_string ());
            int framerate = PlaySpeedResponse.NO_FRAMERATE;
            string framerate_for_speed = ODIDUtil.get_content_property (this.content_uri,
                                                                        "framerate");
            this.speed_files_scaled = true;
            if (framerate_for_speed != null) {
                framerate = int.parse ((framerate_for_speed == null)
                                       ? "" : framerate_for_speed);
                if (framerate == 0) {
                    throw new DataSourceError.GENERAL
                                  ("Invalid framerate value '%s' for %s"
                                   .printf (framerate_for_speed, this.content_uri));
                }
                // The stream is decimated (not scaled)
                this.speed_files_scaled = false;
            }
            if (this.speed_files_scaled) {
                debug ( "    Content files for this speed are scaled (not decimated)");
            } else {
                debug ( "    Content files for this speed are decimated (framerate %s)",
                        ( (framerate == PlaySpeedResponse.NO_FRAMERATE) ? "INVALID"
                          : framerate.to_string () ) );
            }
            var speed_response
                 = new PlaySpeedResponse.from_speed (this.playspeed_request.speed, framerate);
            response_list.add (speed_response);
        }
        debug ( "    Restamping is %s", (this.restamp_mp2_files ? "enabled" : "disabled"));
        if (this.live_sim == null) {
            if (ODIDUtil.resource_has_mp4_container (this.res)) {
                preroll_mp4_resource (content_file, content_index_file, response_list);
            } else if (ODIDUtil.resource_has_mpts_container (this.res)) {
                preroll_mp2ts_resource (content_file, content_index_file, response_list);
            } else {
                preroll_static_resource (content_file, content_index_file, response_list);
            }
        } else {
            preroll_livesim_resource (content_file, content_index_file, response_list);
        }

        if (this.mp4_container_source != null) {
            this.total_bytes_requested = (int64)(this.mp4_container_source.size);
            debug ("preroll: staging %llu bytes for MP4 BufferGeneratingOutputStream sender",
                   this.total_bytes_requested);
        } else if (this.mp2ts_restamper != null) {
            this.total_bytes_requested = (int64)(this.mp2ts_restamper.end_offset
                                                 - this.mp2ts_restamper.start_offset);
            debug ("preroll: staging %llu bytes for MP2 TS restamper/BufferGeneratingOutputStream sender",
                   this.total_bytes_requested);
        } else {
            // We're using a IOChannel
            // Command line to pipe if defined, search content, resource, item, then config.
            this.read_cmd = ODIDUtil.get_content_property (this.content_uri, READ_CMD);
            if (this.read_cmd == null) {
                this.read_cmd =  ODIDUtil.get_resource_property (this.resource_uri, READ_CMD);
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
                    debug (@"$(READ_CMD) $(this.read_cmd) defined in resource property.");
                }
            } else {
                debug (@"$(READ_CMD) $(this.read_cmd) defined in content property.");
            }
            
            if (this.read_cmd == null) {
                debug (@"No $(READ_CMD) defined for pipe, using direct file access.");
            }

            if (this.range_offset_list.size > 0) {
                // If requested bytes are not set, go for largest amount of data
                // possible.  Should get to EOF or client termination.
                int64 last_offset = this.range_offset_list.last ();
                debug ("preroll: staging bytes %s-%s for IOChannel sender",
                       (this.range_start==int64.MAX ? "*" : this.range_start.to_string ()),
                       (last_offset==int64.MAX ? "*" : last_offset.to_string ()) );
                if ((last_offset == 0) || (last_offset == int64.MAX)){
                    this.total_bytes_requested = last_offset; // 0 for none, MAX for everything
                } else {
                    this.total_bytes_requested = last_offset - this.range_start;
                }
            }
        }
        return response_list;
    }

    internal void preroll_static_resource (File content_file,
                                           File index_file,
                                           Gee.ArrayList<HTTPResponseElement> response_list)
            throws Error {
        bool perform_cleartext_response;
        int64 content_size = ODIDUtil.file_size (content_file);
        debug ("    Total content size is " + content_size.to_string ());

        // Process HTTPSeekRequest
        if (this.seek_request == null) {
            //
            // No seek
            //
            debug ("preroll_static_resource: No seek request received");
            // Note: The upstream code assumes the entire binary will be sent (res@size)
            this.range_start = 0;
            this.range_offset_list.add (content_size); // Send the whole thing
            perform_cleartext_response = false;
        } else if (this.seek_request is HTTPTimeSeekRequest) {
            //
            // Time-based seek
            //
            var time_seek = this.seek_request as HTTPTimeSeekRequest;
            // Note: Static range/duration checks are already expected to be performed by
            //       librygel-server. We just need to perform dynamic checks here...

            int64 time_offset_start = time_seek.start_time;
            int64 time_offset_end;
            bool is_reverse = (this.playspeed_request == null)
                               ? false : (!this.playspeed_request.speed.is_positive ());
            if (time_seek.end_time == HTTPSeekRequest.UNSPECIFIED) {
                // For time-seek, the "end" of the time range depends on the direction
                time_offset_end = is_reverse ? 0 : int64.MAX;
            } else { // End time specified
                time_offset_end = time_seek.end_time;
            }

            int64 total_duration = (time_seek.total_duration != HTTPSeekRequest.UNSPECIFIED)
                                   ? time_seek.total_duration : int64.MAX;
            debug ("    Total duration is " + total_duration.to_string ());
            debug ("Processing time seek (time %0.3fs to %0.3fs)",
                   ODIDUtil.usec_to_secs (time_offset_start),
                   ODIDUtil.usec_to_secs (time_offset_end));

            // Now set the effective time/data range and duration/size for the time range
            int64 range_end;
            ODIDUtil.offsets_covering_time_range (index_file, is_reverse,
                                                  ref time_offset_start, ref time_offset_end,
                                                  total_duration,
                                                  out this.range_start, out range_end,
                                                  content_size);
            if (range_end <= this.range_start) {
                throw new DataSourceError.SEEK_FAILED ("Effective TimeSeekRange byte range end (%lld) is before/at effective range start (%lld)",
                                                       range_end, this.range_start);
            }
            
            this.range_offset_list.add (range_end);
            if (this.content_protected) {
                // We don't currently support Range on link-protected binaries. So leave out
                //  the byte range from the TimeSeekRange response
                var seek_response
                    = new HTTPTimeSeekResponse.time_only (time_offset_start,
                                                          time_offset_end,
                                                          total_duration );
                debug ("Time range for time seek response: %0.3fs through %0.3fs",
                       ODIDUtil.usec_to_secs (seek_response.start_time),
                       ODIDUtil.usec_to_secs (seek_response.end_time));
                response_list.add (seek_response);
                perform_cleartext_response = true; // We'll packet-align the range below
            } else { // No link protection
                var seek_response = new HTTPTimeSeekResponse
                                            (time_offset_start, time_offset_end,
                                             total_duration,
                                             this.range_start, range_end-1,
                                             content_size);
                debug ("Time range for time seek response: %0.3fs through %0.3fs",
                       ODIDUtil.usec_to_secs (seek_response.start_time),
                       ODIDUtil.usec_to_secs (seek_response.end_time));
                debug ("Byte range for time seek response: bytes %lld through %lld",
                       seek_response.start_byte, seek_response.end_byte );
                response_list.add (seek_response);
                perform_cleartext_response = false;
            }
        } else if (this.seek_request is HTTPByteSeekRequest) {
            //
            // Byte-based seek (only for non-protected content currently)
            //
            if (this.content_protected) { // Sanity check
                throw new DataSourceError.SEEK_FAILED
                              ("Byte seek not supported on protected content");
            }

            var byte_seek = this.seek_request as HTTPByteSeekRequest;
            debug ("Processing byte seek (bytes %lld to %s)", byte_seek.start_byte,
                   (byte_seek.end_byte == HTTPSeekRequest.UNSPECIFIED)
                   ? "*" : byte_seek.end_byte.to_string () );

            this.range_start = byte_seek.start_byte;

            int64 range_end; // Inclusive range end
            if (byte_seek.end_byte == HTTPSeekRequest.UNSPECIFIED) {
                range_end = content_size-1;
            } else { // Range end specified (but fence it in)
                range_end = int64.min (byte_seek.end_byte, content_size-1);
            }
            this.range_offset_list.add (range_end+1); // List is non-inclusive

            var seek_response = new HTTPByteSeekResponse (this.range_start,
                                                          range_end,
                                                          content_size);
            debug ("Byte range for byte seek response: bytes %lld through %lld of %lld",
                   seek_response.start_byte, seek_response.end_byte, content_size );
            response_list.add (seek_response);
            perform_cleartext_response = false;
        } else if (this.seek_request is DTCPCleartextRequest) {
            //
            // Cleartext-based seek (only for link-protected content)
            //
            if (!this.content_protected) { // Sanity check
                throw new DataSourceError.SEEK_FAILED
                              ("Cleartext seek not supported on unprotected content");
            }
            var cleartext_seek = this.seek_request as DTCPCleartextRequest;
            debug ( "Processing cleartext byte request (bytes %lld to %s)",
                      cleartext_seek.start_byte,
                      (cleartext_seek.end_byte == HTTPSeekRequest.UNSPECIFIED)
                      ? "*" : cleartext_seek.end_byte.to_string () );
            this.range_start = cleartext_seek.start_byte;
            int64 range_end; // Inclusive range end
            if (cleartext_seek.end_byte == HTTPSeekRequest.UNSPECIFIED) {
                range_end = content_size-1;
            } else {
                range_end = int64.min (cleartext_seek.end_byte, content_size-1);
            }
            this.range_offset_list.add (range_end+1); // List is non-inclusive
            perform_cleartext_response = true; // We'll packet-align the range below
        } else {
            throw new DataSourceError.SEEK_FAILED ("Unsupported seek type");
        }

        if (this.content_protected) {
            // The range needs to be packet-aligned, which can affect range returned
            ODIDUtil.get_dtcp_aligned_range (res, index_file, 
                                             this.range_start, this.range_offset_list[0],
                                             content_size,
                                             out this.range_start, this.range_offset_list);
        }

        if (perform_cleartext_response) {
            int64 encrypted_length = ODIDUtil.calculate_dtcp_encrypted_length
                                                (this.range_start, this.range_offset_list,
                                                 this.chunk_size);
            debug ("encrypted_length: %lld", encrypted_length);
            var range_end = this.range_offset_list.last () - 1;
            var seek_response = new DTCPCleartextResponse (this.range_start,
                                                           range_end,
                                                           content_size, encrypted_length);
            response_list.add (seek_response);
            debug ("Byte range for cleartext byte seek response: bytes %lld through %lld",
                   seek_response.start_byte, seek_response.end_byte );
        }
    }

    internal void preroll_mp4_resource (File content_file,
                                        File index_file,
                                        Gee.ArrayList<HTTPResponseElement> response_list)
            throws Error {
        if (this.playspeed_request != null) {
            if (!this.speed_files_scaled) {
                throw new DataSourceError.GENERAL
                          ("preroll_mp4_time_seek: PlaySpeed only supported for scaled MP4 profiles currently");
            }
        }

        if ((this.seek_request == null)
            || (this.seek_request is HTTPByteSeekRequest)
            || (this.seek_request is DTCPCleartextRequest)) {
            debug ("    No time-seek request received - delegating to preroll_static_resource");
            // Note: The upstream code assumes the entire binary will be sent (res@size)
            preroll_static_resource (content_file,index_file,response_list);
            return;
        }

        assert (this.seek_request is HTTPTimeSeekRequest);

        var time_seek = this.seek_request as HTTPTimeSeekRequest;

        int64 content_size = ODIDUtil.file_size (content_file);
        debug ("    Total content size is " + content_size.to_string ());
        debug ("    prerolling MP4 container file for time-seek (%s)",
                 content_file.get_basename ());

        var new_mp4 = new Rygel.IsoFileContainerBox (content_file);
        // Fully load/parse the input file (0 indicates full-depth parse)
        new_mp4.load_children (0);

        //message ("preroll_mp4_time_seek: DUMPING PARSED FILE");
        //new_mp4.to_printer ( (line) => {message (line);}, "  ");

        uint64 time_offset_start = time_seek.start_time;
        uint64 time_offset_end;
        bool is_reverse = (this.playspeed_request == null)
                           ? false : (!this.playspeed_request.speed.is_positive ());
        if (time_seek.end_time == HTTPSeekRequest.UNSPECIFIED) {
            // For time-seek, the "end" of the time range depends on the direction
            time_offset_end = is_reverse ? 0 : int64.MAX;
        } else { // End time specified
            time_offset_end = time_seek.end_time;
        }

        int64 total_duration = (time_seek.total_duration != HTTPSeekRequest.UNSPECIFIED)
                               ? time_seek.total_duration : int64.MAX;
        debug ("    Total duration is %llu (%0.3fs)", 
               total_duration, (float)total_duration/MICROS_PER_SEC);
        debug ("    Processing MP4 time seek (time %0.3fs to %0.3fs)",
               ODIDUtil.usec_to_secs (time_offset_start),
               ODIDUtil.usec_to_secs (time_offset_end));

        Rygel.IsoAccessPoint start_point, end_point;
        HTTPTimeSeekResponse seek_response;
        if ((time_offset_start == 0) && (time_offset_end == int64.MAX)) {
            debug ("    Request is for entire MP4 - no trimming required");
            if (this.content_protected) {
                seek_response
                    = new HTTPTimeSeekResponse.time_only (0, total_duration, total_duration );
                debug ("Time range for time seek response: 0.000s through %0.3fs",
                       ODIDUtil.usec_to_secs (total_duration));

                this.range_offset_list.add (content_size);
                int64 encrypted_length = ODIDUtil.calculate_dtcp_encrypted_length
                                                    (0, this.range_offset_list, this.chunk_size);
                debug ("encrypted_length: %lld", encrypted_length);
                var range_end = content_size - 1;
                var seek_response_cleartext = new DTCPCleartextResponse (0, range_end,
                                                                         content_size,
                                                                         encrypted_length);
                response_list.add (seek_response);
                response_list.add (seek_response_cleartext);
            } else {
                seek_response = new HTTPTimeSeekResponse
                                        (0, total_duration, total_duration,
                                         0, content_size-1, content_size);
                debug ("    generated response: " + seek_response.to_string());
                response_list.add (seek_response);
            }
        } else {
            double scale_factor = 0.0;
            if (this.playspeed_request != null) {
                // We need to adjust any requested speed into the time range of the scaled file
                // Note: We only support scaled-rate (restamped) mp4s currently
                var speed = this.playspeed_request.speed;
                scale_factor = speed.is_positive () ? speed.to_float () : -speed.to_float ();
                if (is_reverse) {
                    time_offset_start = total_duration - time_offset_start;
                    time_offset_end = total_duration - time_offset_end;
                    debug ("    Negative-rate-adjusted time range: %0.3fs to %0.3fs",
                           ODIDUtil.usec_to_secs (time_offset_start),
                           ODIDUtil.usec_to_secs (time_offset_end));
                }
                time_offset_start = (int64)(time_offset_start / scale_factor);
                if (time_offset_end != int64.MAX) {
                    time_offset_end = (int64)(time_offset_end / scale_factor);
                }
                debug ("    Speed-adjusted time range: %0.3fs to %0.3fs",
                       ODIDUtil.usec_to_secs (time_offset_start),
                       ODIDUtil.usec_to_secs (time_offset_end));
            }
            bool insert_edit_lists = true; // TODO: Make configurable   
            new_mp4.trim_to_time_range (time_offset_start, time_offset_end,
                                        out start_point, out end_point,
                                        insert_edit_lists);
            time_offset_start = start_point.time_offset * MICROS_PER_SEC
                                / start_point.get_timescale ();
            time_offset_end = end_point.time_offset  * MICROS_PER_SEC
                                / end_point.get_timescale ();
            if (this.playspeed_request != null) {
                debug ("    Speed-adjusted effective time range: %0.3fs to %0.3fs",
                       ODIDUtil.usec_to_secs (time_offset_start),
                       ODIDUtil.usec_to_secs (time_offset_end));
                time_offset_start = (int64)(time_offset_start * scale_factor);
                if (time_offset_end != int64.MAX) {
                    time_offset_end = (int64)(time_offset_end * scale_factor);
                }
                if (is_reverse) {
                    time_offset_start = total_duration - time_offset_start;
                    time_offset_end = total_duration - time_offset_end;
                }
            }

            if (this.content_protected) {
                seek_response = new HTTPTimeSeekResponse.time_only ((int64)time_offset_start,
                                                                    (int64)time_offset_end,
                                                                    total_duration );
                debug ("Time range for time seek response: %0.3fs through %0.3fs",
                       ODIDUtil.usec_to_secs (time_offset_start),
                       ODIDUtil.usec_to_secs (time_offset_end));
                response_list.add (seek_response);
                var range_offsets = new Gee.ArrayList<int64?> ();
                range_offsets.add ((int64)new_mp4.size);
                int64 encrypted_length = ODIDUtil.calculate_dtcp_encrypted_length
                                                    (0, range_offsets, this.chunk_size);
                debug ("encrypted_length: %lld", encrypted_length);
                var seek_response_cleartext = new DTCPCleartextResponse ((int64)start_point.byte_offset,
                                                                         (int64)end_point.byte_offset,
                                                                         content_size,
                                                                         encrypted_length);
                message ("Byte range for dtcp cleartext response: bytes %lld through %lld",
                         seek_response_cleartext.start_byte, seek_response_cleartext.end_byte );
                response_list.add (seek_response_cleartext);
            } else {
                seek_response = new HTTPTimeSeekResponse.with_length
                                        ((int64)time_offset_start, (int64)time_offset_end,
                                         total_duration,
                                         (int64)start_point.byte_offset,
                                         (int64)end_point.byte_offset,
                                         content_size,
                                         (int64)new_mp4.size);
                message ("Time range for time seek response: %0.3fs through %0.3fs",
                       ODIDUtil.usec_to_secs (seek_response.start_time),
                       ODIDUtil.usec_to_secs (seek_response.end_time));
                message ("Byte range for time seek response: bytes %lld through %lld",  
                       seek_response.start_byte, seek_response.end_byte );
                response_list.add (seek_response);
            }
        }

        this.mp4_container_source = new_mp4;
    }

    internal void preroll_mp2ts_resource (File content_file,
                                          File index_file,
                                          Gee.ArrayList<HTTPResponseElement> response_list)
            throws Error {
        preroll_static_resource (content_file,index_file,response_list);
        if (this.restamp_mp2_files && (this.playspeed_request != null)) {
            int64 range_end = this.range_offset_list.last ();
            var bytes_per_packet = ODIDUtil.mp2ts_bytes_per_packet_for_profile 
                                                                (this.res.dlna_profile);
            debug ("    MP2TS (%u bytes per packet) will be restamped for speed %s", 
                   bytes_per_packet, this.playspeed_request.speed.to_string ());
            var restamper = new MP2TSRestamper.from_file_subrange (content_file, this.range_start, 
                                                                   range_end, bytes_per_packet);
            this.mp2ts_restamper = restamper;
            foreach (var response in response_list) {
                if (response is PlaySpeedResponse) {
                    ((PlaySpeedResponse)response).framerate = PlaySpeedResponse.NO_FRAMERATE;
                }
            }
        }
    }

    internal void preroll_livesim_resource (File content_file,
                                            File index_file,
                                            Gee.ArrayList<HTTPResponseElement> response_list)
            throws Error {
        assert (this.live_sim != null);
        debug ("    content is live (%s is %s)", live_sim.name, live_sim.get_state_string ());

        ODIDLiveSimulator.Mode sim_mode = this.live_sim.get_mode ();
        ODIDLiveSimulator.State sim_state = this.live_sim.get_state ();
        this.live_sim.enable_autoreset (); // Reset the autoreset timer (if set)

        if (! index_file.query_exists ()) {
            throw new DataSourceError.GENERAL
                          ("Request to stream live resource without index file: "
                           + this.resource_uri);
        }
        bool is_reverse = (this.playspeed_request == null)
                           ? false : (!this.playspeed_request.speed.is_positive ());

        var content_size = ODIDUtil.file_size (content_file);
        debug ("    Source content size: " + content_size.to_string ());
        var total_duration_ms = ODIDUtil.duration_from_index_file_ms 
                                          (index_file, is_reverse);
        debug ("    Source content duration: %lldms (%0.3fs)",
               total_duration_ms, (float)total_duration_ms/MILLIS_PER_SEC);
        var byterate = (content_size * MILLIS_PER_SEC) / total_duration_ms;
        debug ("    Source content byterate: %lld bytes/second", byterate);
        if (this.chunk_size > 0) {
            debug ("    Using config-specified chunk size: %lld bytes", this.chunk_size);
        } else {
            this.chunk_size = int64.min (byterate / LIVE_CHUNKS_PER_SECOND, DEFAULT_CHUNK_SIZE);
            debug ("    Reducing chunk size using %u chunks_per_second: %lld bytes",
                   LIVE_CHUNKS_PER_SECOND, this.chunk_size);
        }
            
        this.chunk_size = byterate / 2; // use 1/2 second chunk sizes for 

        int64 timelimit_start; // The earliest time that can be requested right now
        int64 timelimit_end; // The latest time that can be requested right now
        int64 bytelimit_start; // The earliest byte that can be requested right now
        int64 bytelimit_end; // The latest byte that can be requested right now
        int64 total_duration = total_duration_ms * MICROS_PER_MILLI;

        if (this.live_sim.lop_mode == 1) { // We're not constrained by the sim range
            timelimit_start = 0;
            timelimit_end = total_duration;
            bytelimit_start = 0;
            bytelimit_end = content_size;
            // TODO: Utilize the live-nontimely-delay setting
        } else { // Get the time constraints from the sim        
            this.live_sim.get_available_time_range (out timelimit_start, out timelimit_end);
            debug ("    sim time availability: %0.3fs-%0.3fs",
                   ODIDUtil.usec_to_secs (timelimit_start), ODIDUtil.usec_to_secs (timelimit_end));
            ODIDUtil.offsets_within_time_range (index_file, is_reverse,
                                                ref timelimit_start, ref timelimit_end, 
                                                total_duration,
                                                out bytelimit_start, out bytelimit_end,
                                                content_size);
            debug ("    effective time constraints: %0.3fs-%0.3fs",
                   ODIDUtil.usec_to_secs (timelimit_start), ODIDUtil.usec_to_secs (timelimit_end));
            debug ("    effective byte constraints: %lld-%lld",
                   bytelimit_start, bytelimit_end);
            if (sim_state != ODIDLiveSimulator.State.STOPPED
                && sim_mode == ODIDLiveSimulator.Mode.S0_INCREASING) { // Per DLNA 7.5.4.3.2.20.4
                // Adding this unconditionally when legal - which doesn't seem to be verboten
                // TODO: Add a way for DLNAAvailableSeekRangeRequest to be passed to preroll()
                response_list.add (new DLNAAvailableSeekRangeResponse
                                            (this.live_sim.lop_mode,
                                             timelimit_start,
                                             timelimit_end,
                                             bytelimit_start,
                                             bytelimit_end-1) );
            }
        }

        if (this.seek_request == null) {
            //
            // No seek
            //
            debug ("preroll_livesim_resource: No seek request received (state/mode %s/%s)",
                   this.live_sim.get_state_string (), this.live_sim.get_mode_string ());
            if (sim_state == ODIDLiveSimulator.State.STOPPED) {
                this.range_start = bytelimit_start;
                this.range_offset_list.add (bytelimit_end);
            } else {
                if (sim_mode == ODIDLiveSimulator.Mode.S0_FIXED) {
                    this.range_start = bytelimit_start;
                    debug ("    sim is active/S0-fixed - starting playback at %0.3fs/%lld",
                           ODIDUtil.usec_to_secs (timelimit_start), this.range_start);
                } else {
                    this.range_start = bytelimit_end;
                    debug ("    sim is active/S0-increasing - starting playback at %0.3fs/%lld",
                           ODIDUtil.usec_to_secs (timelimit_end), bytelimit_end);
                }
                this.range_offset_list.add (int64.MAX);
            }
        } else if (this.seek_request is HTTPTimeSeekRequest) {
            //
            // Time-based seek
            //
            var time_seek = this.seek_request as HTTPTimeSeekRequest;
            // Note: Static range/duration checks are already expected to be performed by
            //       librygel-server. We just need to perform dynamic checks here...
            int64 adjusted_seek_start;
            int64 adjusted_seek_end;
            bool send_unbound = false;

            if (this.playspeed_request != null
                 && !this.playspeed_request.speed.is_normal_rate ()
                 && (time_seek.end_time == HTTPSeekRequest.UNSPECIFIED)
                 && this.live_sim.is_s0_increasing ()) {
                    // Per DLNA 7.5.4.3.2.20.3, end time must be specified at trick rates when
                    //  in limited random access mode
                    throw new HTTPSeekRequestError.INVALID_RANGE
                                  ("End time not specified for trick rate limited access");
            }

            if (sim_mode == ODIDLiveSimulator.Mode.S0_EQUALS_SN) { // Sanity check
                throw new DataSourceError.SEEK_FAILED
                              ("Random access not supported on this resource (S0==Sn)");
            }

            // If the sim is stopped, we need to 0-base the time/data offsets
            int64 time_offset = 0;
            int64 data_offset = 0;
            if (sim_state == ODIDLiveSimulator.State.STOPPED) {
                time_offset = timelimit_start;
                data_offset = bytelimit_start;
                debug ("    sim is stopped - applying time/byte adjustment: %0.3fs/%lld",
                       ODIDUtil.usec_to_secs (time_offset), data_offset);
            }

            if (!is_reverse) { // Forward range check
                if ((time_seek.start_time + time_offset < timelimit_start)
                    || (time_seek.start_time + time_offset > timelimit_end) ) {
                    throw new HTTPSeekRequestError.OUT_OF_RANGE
                                  ("Seek start time %0.3fs is outside valid time range (%0.3fs-%0.3fs)",
                                   ODIDUtil.usec_to_secs (time_seek.start_time),
                                   ODIDUtil.usec_to_secs (timelimit_start - time_offset),
                                   ODIDUtil.usec_to_secs (timelimit_end - time_offset));
                }
                adjusted_seek_start = time_seek.start_time + time_offset;

                if (time_seek.end_time == HTTPSeekRequest.UNSPECIFIED) {
                    adjusted_seek_end = timelimit_end;
                    send_unbound = !this.live_sim.stopped; // DLNA 7.5.4.3.2.19.2/20.1
                } else {
                    if (time_seek.end_time + time_offset > timelimit_end) {
                        throw new HTTPSeekRequestError.OUT_OF_RANGE
                                      ("Seek end time %0.3fs is after valid time range (%0.3fs-%0.3fs)",
                                       ODIDUtil.usec_to_secs (time_seek.end_time),
                                       ODIDUtil.usec_to_secs (timelimit_start - time_offset),
                                       ODIDUtil.usec_to_secs (timelimit_end - time_offset));
                    }
                    adjusted_seek_end = time_seek.end_time + time_offset;
                }
            } else { // reverse
                if (time_seek.start_time + time_offset > timelimit_end) {
                    throw new HTTPSeekRequestError.OUT_OF_RANGE
                                  ("Reverse seek start time %0.3fs is after valid time range (%0.3fs-%0.3fs)",
                                   ODIDUtil.usec_to_secs (time_seek.start_time),
                                   ODIDUtil.usec_to_secs (timelimit_start - time_offset),
                                   ODIDUtil.usec_to_secs (timelimit_end - time_offset) );
                }
                adjusted_seek_start = time_seek.start_time + time_offset;
                if (time_seek.end_time == HTTPSeekRequest.UNSPECIFIED) {
                    adjusted_seek_end = timelimit_start; // DLNA 7.5.4.3.2.20.1
                } else {
                    if (time_seek.end_time + time_offset < timelimit_start) {
                        throw new HTTPSeekRequestError.OUT_OF_RANGE
                                      ("Seek end time %0.3fs is before valid time range (%0.3fs-%0.3fs)",
                                       ODIDUtil.usec_to_secs (time_seek.end_time),
                                       ODIDUtil.usec_to_secs (timelimit_start - time_offset),
                                       ODIDUtil.usec_to_secs (timelimit_end - time_offset) );
                    }
                    adjusted_seek_end = time_seek.end_time + time_offset;
                }
            } // END seek range check

            // Assert: adjusted_seek_start/end are checked/fenced into the valid time range
            // Assert: send_unbound is set if we should send data live data after the range

            debug ("    sim-adjusted time range: %0.3fs-%0.3fs",
                   ODIDUtil.usec_to_secs (adjusted_seek_start),
                   ODIDUtil.usec_to_secs (adjusted_seek_end));
            // Now lookup the effective range
            int64 range_end;
            ODIDUtil.offsets_within_time_range (index_file, is_reverse,
                                                ref adjusted_seek_start, ref adjusted_seek_end, 
                                                total_duration,
                                                out this.range_start, out range_end,
                                                content_size);
            debug ("    index-adjusted time/data range: %0.3fs-%0.3fs/%lld-%lld",
                   ODIDUtil.usec_to_secs (adjusted_seek_start),
                   ODIDUtil.usec_to_secs (adjusted_seek_end),
                   this.range_start, range_end);

            int64 response_start_time = adjusted_seek_start - time_offset;
            int64 response_end_time, response_total_duration;
            int64 response_start_byte = this.range_start - data_offset;
            int64 response_end_byte, response_total_size;

            if (this.live_sim.stopped) {
                assert (!send_unbound);
                this.range_offset_list.add (range_end);
                response_end_time = adjusted_seek_end - time_offset;
                response_total_duration = timelimit_end - timelimit_start;
                response_end_byte = range_end - data_offset - 1; // Response is inclusive range
                response_total_size = bytelimit_end - bytelimit_start;
            } else { // sim still active
                if (send_unbound) {
                    this.range_offset_list.add (int64.MAX);
                    response_end_time = HTTPSeekRequest.UNSPECIFIED;
                    response_end_byte = HTTPSeekRequest.UNSPECIFIED;
                } else { // Closed range on active sim
                    this.range_offset_list.add (range_end);
                    response_end_time = adjusted_seek_end - time_offset;
                    response_end_byte = range_end - data_offset - 1; // Response is inclusive range
                }
                response_total_duration = HTTPSeekRequest.UNSPECIFIED;
                response_total_size = HTTPSeekRequest.UNSPECIFIED;
            }
            debug ("    sim-adjusted time range: %0.3fs-%0.3fs",
                   ODIDUtil.usec_to_secs (adjusted_seek_start),
                   ODIDUtil.usec_to_secs (adjusted_seek_end));

            HTTPResponseElement seek_response;
            if (this.content_protected) {
                // We don't currently support Range on link-protected binaries. So leave out
                //  the byte range from the TimeSeekRange response
                seek_response
                    = new HTTPTimeSeekResponse.time_only (response_start_time, response_end_time,
                                                          response_total_duration );
                response_list.add (seek_response);
                debug ("    generated response: " + seek_response.to_string());
                ODIDUtil.get_dtcp_aligned_range (res, index_file, 
                                                 this.range_start, this.range_offset_list[0],
                                                 content_size,
                                                 out this.range_start, this.range_offset_list);
                if (!send_unbound) {
                    // We can generate a cleartext response (the range is known)
                    int64 encrypted_length = ODIDUtil.calculate_dtcp_encrypted_length
                                                        (this.range_start,
                                                         this.range_offset_list,
                                                         this.chunk_size);
                    seek_response = new DTCPCleartextResponse (response_start_byte,
                                                               response_end_byte,
                                                               response_total_size,
                                                               encrypted_length);
                    response_list.add (seek_response);
                    debug ("    generated response: " + seek_response.to_string());
                }
            } else { // No link protection
                seek_response = new HTTPTimeSeekResponse
                                            (response_start_time, response_end_time,
                                             response_total_duration,
                                             response_start_byte, response_end_byte,
                                             response_total_size);
                response_list.add (seek_response);
                debug ("    generated response: " + seek_response.to_string());
            }
            debug ("Time seek response: " + seek_response.to_string ());
        } else if (this.seek_request is HTTPByteSeekRequest) {
            //
            // Byte-based seek (only for non-protected content currently)
            //
            if (this.content_protected) { // Sanity check
                throw new DataSourceError.SEEK_FAILED
                              ("Byte seek not supported on protected content");
            }
            var byte_seek = this.seek_request as HTTPByteSeekRequest;
            debug ("preroll_livesim_resource: Processing byte seek (bytes %lld to %s)",
                   byte_seek.start_byte,
                   (byte_seek.end_byte == HTTPSeekRequest.UNSPECIFIED)
                    ? "*" : byte_seek.end_byte.to_string () );
            int64 data_offset = 0;
            if (sim_state == ODIDLiveSimulator.State.STOPPED) {
                data_offset = bytelimit_start;
                debug ("    sim is stopped - applying byte adjustment: %lld", data_offset);
            }

            if ((byte_seek.start_byte + data_offset < bytelimit_start)
                || (byte_seek.start_byte + data_offset >= bytelimit_end) ) {
                throw new HTTPSeekRequestError.OUT_OF_RANGE
                              ("Seek start byte %lld is outside valid data range (%lld-%lld)",
                               byte_seek.start_byte,
                               bytelimit_start - data_offset, bytelimit_end - data_offset);
            }

            this.range_start = byte_seek.start_byte + data_offset;

            if (byte_seek.end_byte == HTTPSeekRequest.UNSPECIFIED) { // No end time in request
                debug ("    unbound range request on %s sim: request range %lld-",
                       this.live_sim.get_state_string (), byte_seek.start_byte);
                if (this.live_sim.stopped) { // Give what we have
                    this.range_offset_list.add (bytelimit_end);
                    var seek_response = new HTTPByteSeekResponse (byte_seek.start_byte,
                                                                  bytelimit_end - data_offset - 1,
                                                                  bytelimit_end - bytelimit_start);
                    response_list.add (seek_response);
                    debug ("    generated response: " + seek_response.to_string());
                } else { // Give what we have, and then some...
                    this.range_offset_list.add (int64.MAX);
                    // Note: We can't include a Content-Range in this case (end is indefinite)
                }
            } else { // End specified in request
                // Note: HTTPByteSeekRequest already checks that end > start
                if (byte_seek.end_byte + data_offset + 1 > bytelimit_end) {
                    throw new HTTPSeekRequestError.OUT_OF_RANGE
                                  ("Seek end byte %lld is after valid data range (%lld-%lld)",
                                   byte_seek.end_byte + data_offset,
                                   bytelimit_start, bytelimit_end);
                }
                this.range_offset_list.add (byte_seek.end_byte + data_offset + 1);
                var seek_response = new HTTPByteSeekResponse
                                        (byte_seek.start_byte,
                                         byte_seek.end_byte,
                                         byte_seek.end_byte - byte_seek.start_byte + 1);
                debug ("    bound range request on sim: request range %lld-%lld",
                       byte_seek.start_byte, byte_seek.end_byte);
                response_list.add (seek_response);
                debug ("    generated response: " + seek_response.to_string());
            }
        } else if (this.seek_request is DTCPCleartextRequest) {
            //
            // Cleartext-based seek (only for link-protected content)
            //
            if (!this.content_protected) { // Sanity check
                throw new DataSourceError.SEEK_FAILED
                              ("Cleartext seek not supported on unprotected content");
            }
            var cleartext_seek = this.seek_request as DTCPCleartextRequest;
            debug ( "preroll_livesim_resource: Processing cleartext byte request (bytes %lld to %s)",
                      cleartext_seek.start_byte,
                      (cleartext_seek.end_byte == HTTPSeekRequest.UNSPECIFIED)
                      ? "*" : cleartext_seek.end_byte.to_string () );

            int64 data_offset = 0;
            if (sim_state == ODIDLiveSimulator.State.STOPPED) {
                data_offset = bytelimit_start;
                debug ("    sim is stopped - applying byte adjustment: %lld", data_offset);
            }

            if ((cleartext_seek.start_byte + data_offset < bytelimit_start)
                || (cleartext_seek.start_byte + data_offset >= bytelimit_end) ) {
                throw new HTTPSeekRequestError.OUT_OF_RANGE
                              ("cleartext start byte %lld is outside valid data range (%lld-%lld)",
                               cleartext_seek.start_byte,
                               bytelimit_start - data_offset, bytelimit_end - data_offset);
            }

            this.range_start = cleartext_seek.start_byte + data_offset;

            int64 response_start_byte = cleartext_seek.start_byte;
            int64 response_end_byte, response_total_size;
            bool send_unbound = false;
            if (cleartext_seek.end_byte == HTTPSeekRequest.UNSPECIFIED) { // No end time in request
                debug ("    unbound cleartext request on %s sim: request range %lld-",
                       this.live_sim.get_state_string (), cleartext_seek.start_byte);
                this.range_offset_list.add (content_size); // We'll calc offsets for the rest
                send_unbound = !this.live_sim.stopped;
                response_end_byte = bytelimit_end - data_offset - 1;
                response_total_size = bytelimit_end - bytelimit_start;
            } else { // End specified in request
                // Note: DTCPCleartextRequest already checks that end > start
                if (cleartext_seek.end_byte + data_offset >= bytelimit_end) {
                    throw new HTTPSeekRequestError.OUT_OF_RANGE
                                  ("cleartext end byte %lld is after valid data range (%lld-%lld)",
                                   cleartext_seek.end_byte + data_offset,
                                   bytelimit_start, bytelimit_end);
                }
                this.range_offset_list.add (cleartext_seek.end_byte + data_offset + 1);
                response_end_byte = cleartext_seek.end_byte;
                response_total_size = cleartext_seek.end_byte - cleartext_seek.start_byte + 1;
                debug ("    bound cleartext request on sim: request range %lld-%lld",
                       cleartext_seek.start_byte, cleartext_seek.end_byte);
            }

            ODIDUtil.get_dtcp_aligned_range (res, index_file, 
                                             this.range_start, this.range_offset_list[0],
                                             content_size,
                                             out this.range_start, this.range_offset_list);
            if (!send_unbound) {
                // We can generate a cleartext response (the range is known)
                int64 encrypted_length = ODIDUtil.calculate_dtcp_encrypted_length
                                                    (this.range_start,
                                                     this.range_offset_list,
                                                     this.chunk_size);
                var seek_response = new DTCPCleartextResponse (response_start_byte,
                                                               response_end_byte,
                                                               response_total_size,
                                                               encrypted_length);
                response_list.add (seek_response);
                debug ("    generated response: " + seek_response.to_string());
            }
        } else {
            throw new DataSourceError.SEEK_FAILED ("Unsupported seek type");
        }
    }

    public void start () throws Error {
        debug ("Starting data source for %s", ODIDUtil.short_content_path (this.content_uri));

        if (this.total_bytes_requested == 0) {
            message ("0 bytes to send for %s - signaling done()...",
                     ODIDUtil.short_content_path (this.content_uri));
            Idle.add ( () => { this.done (); return false; });
            return;
        }

        if (this.content_protected) {
            Dtcpip.server_dtcp_open (out this.dtcp_session_handle, 0);

            if (this.dtcp_session_handle == -1) {
                warning ("DTCP-IP session not opened");
                throw new DataSourceError.GENERAL ("Error starting DTCP session");
            } else {
                debug ("Entering DTCP-IP streaming mode (session handle 0x%X)",
                         this.dtcp_session_handle);
            }
        }

        if (this.mp4_container_source != null) {
            start_mp4_container_source ();
        } else if (this.mp2ts_restamper != null) {
            start_mp2ts_source ();
        } else {
            start_iochannel_source ();
        }
        message ("start(): " + ODIDUtil.short_content_path (this.content_uri));
    }

    /**
     * Used to perform IOChannel-based streaming.
     *
     * This is used for both piped data source and file based source, with or without live
     * simulation.
     */
    protected void start_iochannel_source () throws Error {
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
        if (this.range_offset_list.size > 1) {
            this.range_offset_index = 0;
            this.output.set_buffer_size 
                ((size_t) (this.range_offset_list[this.range_offset_index] - this.range_start));
        } else {
            this.output.set_buffer_size ((size_t) this.chunk_size);
        }

        bool start_reading = true;

        if (this.live_sim != null) {
            // Keep the sim alive so long as we're serving data
            this.live_sim.cancel_autoreset (); 
            done.connect ((t) => {
                debug ("Processing done signal for " + this.content_uri);
                // And restart the timer when we're done sending
                this.live_sim.enable_autoreset (); // Restart the autoreset timer (if set)
                if (this.pacing && this.index_stream != null) {
                    try {
                        this.index_stream.close ();
                    } catch (Error err) {
                    }
                    this.index_stream = null;
                }
            });

            if ((!this.live_sim.stopped) && this.total_bytes_requested == int64.MAX) {
                // Need to pace our sending to the sim using the index file
                this.pacing = true;
                var index_file = File.new_for_uri (this.index_uri);
                this.index_stream = new DataInputStream (index_file.read ());
                if (!this.live_sim.started) {
                    debug ("sim is setup but not started. Will wait for sim to start.");
                    start_reading = false;
                    // TODO: Register sim start signal
                } else { // sim is active
                    int time_to_next_buf_ms = time_to_next_buffer ();
                    if (time_to_next_buf_ms > 0) {
                        start_reading = false;
                        this.pacing_timer = Timeout.add (time_to_next_buf_ms, on_paced_data_ready);
                        debug ("Scheduled pacing %u for %dms from now",
                               this.pacing_timer, time_to_next_buf_ms);
                    }
                }
            }
        }

        if (start_reading) {
            // Async event callback when data is available from channel.  We expect
            // our set buffer worth or data will be available on the channel
            // without blocking.
            initiate_reading ();
        }
    }

    private static uint32 generator_count = 0;
    /**
     * Used to perform BufferGeneratingOutputStream-based streaming of a reserialized 
     * MP4 (IsoFileContainerBox) object tree.
     *
     * This is used for streaming data from a serialized MP4 container.
     * (e.g. a MP4 generated in response to a time-seek request)
     */
    protected void start_mp4_container_source () throws Error {
        debug ("start_mp4_container_source: Using buffer/chunk size %llu (0x%llx)",
               this.chunk_size, this.chunk_size);
        // This BufferGeneratingOutputStream.BufferReady delegate will invoke data_available()
        //  for each buffer returned. It will not be invoked after stop() returns.
        this.bufgen_stream = new BufferGeneratingOutputStream ((uint32)this.chunk_size,
                                                               on_buf_generated,
                                                               true /* paused at start */);

        // Start a thread that will serialize the MP4/ISO representation - inducing buffer
        //  generation via the BufferGeneratingOutputStream created above. The thread will
        //  exit when the entire representation is serialized or when write_to_stream()
        //  throws an error (which should necessarily occur if/when
        //  BufferGeneratingOutputStream.stop() is called).
        generator_count = (generator_count+1) % uint32.MAX;
        this.total_bytes_read = 0;
        string generator_name = "mp4 time-seek generator " + generator_count.to_string ();
        debug ("mp4_container_source: starting " + generator_name);
        this.bufgen_thread = new Thread<void*> ( generator_name, () => {
            debug (generator_name + " started");
            Rygel.ExtDataOutputStream out_stream;
            string container_source_name = (this.mp4_container_source == null)
                                           ? "null"
                                           : this.mp4_container_source.iso_file.get_basename ();
            try {
                debug (generator_name + ": Starting write of mp4 box tree from %s (%llu bytes)",
                       container_source_name, this.mp4_container_source.size);
                out_stream = new Rygel.ExtDataOutputStream (this.bufgen_stream);
                this.mp4_container_source.write_to_stream (out_stream);
                debug (generator_name + ": Completed writing mp4 box tree from %s (%llu bytes written)",
                       container_source_name, this.total_bytes_read);
            } catch (Error err) {
                message (generator_name + ": Error during write of mp4 box tree from %s (%llu bytes written): %s",
                         container_source_name, this.total_bytes_read, err.message);
            }
            if (out_stream != null) {
                try {
                    out_stream.close ();
                } catch (Error err) {
                message (generator_name + ": Error closing mp4 box tree stream from %s (%llu bytes written): %s",
                       container_source_name, this.total_bytes_read, err.message);
                }
            }
            debug (generator_name + " done/exiting");
            return null;
        } );

        // The stream starts out paused. Now let it run...
        this.bufgen_stream.resume ();
    }

    /**
     * Used to perform BufferGeneratingOutputStream-based streaming of a restamped 
     * MPEG2 Transport Stream.
     */
    protected void start_mp2ts_source () throws Error {
        debug ("start_mp2ts_source: Using buffer/chunk size %llu (0x%llx)",
               this.chunk_size, this.chunk_size);
        // This BufferGeneratingOutputStream.BufferReady delegate will invoke data_available()
        //  for each buffer returned. It will not be invoked after stop() returns.
        this.bufgen_stream = new BufferGeneratingOutputStream ((uint32)this.chunk_size,
                                                               on_buf_generated,
                                                               true /* paused at start */);

        // Start a thread that will restamp the MPEG2 Transport Stream - inducing buffer
        //  generation via the BufferGeneratingOutputStream created above. The thread will
        //  exit when the restamped stream is completely consumed or when write_to_stream()
        //  throws an error (which should necessarily occur if/when 
        //  BufferGeneratingOutputStream.stop() is called).
        generator_count = (generator_count+1) % uint32.MAX;
        this.total_bytes_read = 0;
        string generator_name = "mpeg2 TS restamping generator " + generator_count.to_string ();
        debug ("starting " + generator_name);
        this.bufgen_thread = new Thread<void*> ( generator_name, () => {
            debug (generator_name + " started");
            Rygel.ExtDataOutputStream out_stream;
            var source_name = this.mp2ts_restamper.source_file.get_basename ();
            try {
                out_stream = new Rygel.ExtDataOutputStream (this.bufgen_stream);
                var scale_ms = (int32)(this.playspeed_request.speed.to_float() * 1000);
                debug (generator_name + ": Starting %0.3fx MP2 TS restamping from %s (bytes %llu-%llu)",
                       scale_ms/1000.0, source_name, this.mp2ts_restamper.start_offset, 
                       this.mp2ts_restamper.end_offset);
                this.mp2ts_restamper.restamp_to_stream_scaled (out_stream, scale_ms, null, null);
                debug (generator_name + ": Completed restamping %s (%llu bytes written)",
                       source_name, this.total_bytes_read);
            } catch (Error err) {
                message (generator_name + ": Error during MP2 TS restamping of %s (%llu bytes written): %s",
                         source_name, this.total_bytes_read, err.message);
            }
            if (out_stream != null) {
                try {
                    out_stream.close ();
                } catch (Error err) {
                message (generator_name + ": Error closing MP2 TS restamp stream %s (%llu bytes written): %s",
                       source_name, this.total_bytes_read, err.message);
                }
            }
            debug (generator_name + " done/exiting");
            return null;
        } );

        // The stream starts out paused. Now let it run...
        this.bufgen_stream.resume ();
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

    private void initiate_reading () {
        this.output_watch_id
            = this.output.add_watch (IOCondition.IN | IOCondition.ERR | IOCondition.HUP,
                                     read_data);
    }

    /**
     * Number of milliseconds until the next buffer should be available.
     *
     * Note that the index file stream must be open and the buffer size set on the
     * output IOChannel.
     *
     * This will be negative if the next buffer is already available.
     */
    private int time_to_next_buffer () {
        assert (this.live_sim != null);
        size_t buf_size = this.output.get_buffer_size ();
        int64 next_offset = this.range_start + this.total_bytes_read + buf_size;
        try {
            int64 next_offset_time_ms = ODIDUtil.advance_index_to_offset (this.index_stream,
                                                                          ref next_offset);
            return (int)(next_offset_time_ms - (this.live_sim.get_elapsed_live_time ()
                                                /  MICROS_PER_MILLI ) );
        } catch (Error error) {
            warning ("time_to_next_buffer: Error finding offset %lld in %s: %s",
                     next_offset, this.index_uri, error.message);
            return 0;
        }
    }

    public void freeze () {
        debug ("Freezing data source for %s", ODIDUtil.short_content_path (this.content_uri));
        // This will cause the async event callback to remove itself from the main event loop.
        this.frozen = true;
        if (this.bufgen_stream != null) {
            this.bufgen_stream.pause ();
        }
    }

    public void thaw () {
        debug ("Thawing data source for %s", ODIDUtil.short_content_path (this.content_uri));
        if (this.frozen) {
            this.frozen = false;
            if (this.bufgen_stream == null) {
                // We need to add the async event callback into the main event loop.
                initiate_reading ();
            } else {
                this.bufgen_stream.resume ();
            }
        }
    }

    public void stop () {
        debug ("Stopping data source for %s", ODIDUtil.short_content_path (this.content_uri));
        if (this.stopped) {
            return; // Shouldn't happen
        }
        if (this.bufgen_stream == null) {
            // If pipe used, reap child otherwise shut down channel.
            if ((int)this.child_pid != 0) {
                debug (@"Stopping pid: $(this.child_pid)");
                Posix.kill (this.child_pid, Posix.SIGTERM);
            } else { // Make sure event callback is removed from main loop.
                GLib.Source.remove (this.output_watch_id);
            }
        } else {
            this.bufgen_stream.stop ();
            this.bufgen_stream = null;
            this.mp4_container_source = null;
            this.mp2ts_restamper = null;
        }
        this.stopped = true;
        message ("stop(): " + ODIDUtil.short_content_path (this.content_uri));
    }

    public bool on_paced_data_ready () {
        // A buffer's worth of data is ready
        this.pacing_timer = 0;
        initiate_reading ();
        return false; // Don't repeat - this is a one-shot
    }

    public void clear_dtcp_session () {
        if (this.dtcp_session_handle != -1) {
            int ret_close = Dtcpip.server_dtcp_close (this.dtcp_session_handle);
            debug ("Dtcp session closed : %d",ret_close);
            this.dtcp_session_handle = -1;
        }
    }
    
    // Async event callback is called when data is available on a channel, this
    // method will be called mulitple times till the data source has exhausted
    // the requested bytes or the channel closes (in the case of a pipe).
    private bool read_data (IOChannel channel, IOCondition condition) {
        if (condition == IOCondition.HUP || condition == IOCondition.ERR) {
            message ("Received " + condition.to_string () + "for "
                     + ODIDUtil.short_content_path (this.content_uri) + " - signaling done()");
            done ();
            return false;
        }

        if (this.stopped) {
            return false;
        }

        size_t bytes_read = 0;
        size_t bytes_written = 0;
        int64 bytes_left_to_read = (this.total_bytes_requested == int64.MAX) ? int64.MAX
                                   : (this.total_bytes_requested - this.total_bytes_read);

        // Create a read buffer of appropriate size
        var read_buffer = new char[int64.min (this.output.get_buffer_size (),
                                              bytes_left_to_read ) ];
        try {
            // Read data off of channel
            IOStatus status = channel.read_chars (read_buffer, out bytes_read);
            if (status == IOStatus.EOF) {
                message ("Hit EOF for " + ODIDUtil.short_content_path (this.content_uri)
                         + " signaling done()");
                done ();
                return false;
            }

            this.total_bytes_read += bytes_read;
            if (this.total_bytes_requested != int64.MAX) {
                bytes_left_to_read -= bytes_read;
            }

            if (this.dtcp_session_handle == -1) {
                // No content protection
                // Call event to send buffer to client
                data_available ((uint8[])read_buffer[0:bytes_read]);
                bytes_written = bytes_read;
            } else {
                // Encrypted data has to be unowned as the reference will be passed
                // to DTCP libraries to perform the cleanup, else vala will be
                //performing the cleanup by default.
                unowned uint8[] encrypted_data = null;
                uchar cci = 0x3; // TODO: Put the CCI bits in resource.info

                // Encrypt the data
                int return_value = Dtcpip.server_dtcp_encrypt
                                  ( this.dtcp_session_handle, cci,
                                    (uint8[])read_buffer[0:bytes_read],
                                    out encrypted_data );

                debug ("Encryption returned: %d and the encryption size : %s",
                       return_value, (encrypted_data == null)
                                     ? "NULL" : encrypted_data.length.to_string ());

                // Call event to send buffer to client
                data_available (encrypted_data);
                bytes_written = encrypted_data.length;

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
        this.total_bytes_written += bytes_written;

        debug (@"read $(bytes_read) (total $(this.total_bytes_read), %s remaining), wrote $(bytes_written) (total $(this.total_bytes_written))",
               ((bytes_left_to_read == int64.MAX) ? "*" : bytes_left_to_read.to_string ()) );

        bool all_data_read = (this.total_bytes_read >= this.total_bytes_requested);
        if (all_data_read) {
            message ("All requested data sent for %s (%lld bytes) - signaling done()",
                     ODIDUtil.short_content_path (this.content_uri), this.total_bytes_read);
            done ();
        }

        // If we are aligning VOBU per PCP, we set the channel buffer to
        // the next VOBU size so we can encrypt it as a single unit
        if (!all_data_read && (this.range_offset_list.size > 1)) {
            assert (this.range_offset_index < this.range_offset_list.size);
            this.output.set_buffer_size
                ((size_t) (this.range_offset_list[++this.range_offset_index]
                           - this.range_offset_list[this.range_offset_index-1] ) );
        }

        bool pace = false;
        if (!all_data_read && this.pacing) {
            int time_to_next_buf_ms = time_to_next_buffer ();
            if (time_to_next_buf_ms > 0) {
                pace = true; // We need to wait for the next buffer of data
                this.pacing_timer = Timeout.add (time_to_next_buf_ms, on_paced_data_ready);
                debug ("pacing: Waiting %dms to send next buffer (timer %u)",
                       time_to_next_buf_ms, this.pacing_timer);
            }
        }

        // Keep reading from channel if data left and not frozen or not
        return !this.frozen && !all_data_read && !pace;
    }

    /**
     * Called by the BufferGeneratingOutputStream whenever a buffer of data is ready.
     */
    private void on_buf_generated (Bytes ? new_buffer, bool last_buffer) {
        if (this.stopped) {
            return;
        }
        if (new_buffer != null) {
            var buffer = new_buffer.get_data ();
            debug ("on_buf_generated: received %u bytes (%02x %02x %02x %02x %02x %02x) - offset %llu (0x%llx)",
                   buffer.length, buffer[0], buffer[1], buffer[2],
                   buffer[3], buffer[4], buffer[5], this.total_bytes_read, this.total_bytes_read);
            this.total_bytes_read += buffer.length;
            // Run this through the glib queue to ensure non-reentrance to Rygel/Soup
            if (this.dtcp_session_handle == -1) {
                Idle.add ( () => {
                    data_available (buffer);
                    return false;
                }, Priority.HIGH_IDLE);
            } else {
                // Encrypted data has to be unowned as the reference will be passed
                // to DTCP libraries to perform the cleanup, else vala will be
                // performing the cleanup by default.
                unowned uint8[] encrypted_data = null;
                uchar cci = 0x3; // TODO: Put the CCI bits in resource.info

                int return_value = Dtcpip.server_dtcp_encrypt ( this.dtcp_session_handle, cci,
                                                                (uint8[])buffer,
                                                                out encrypted_data );
                message ("on_buf_generated: Encryption returned %d, encrypted size %s",
                         return_value, (encrypted_data == null)
                                       ? "n/a" : encrypted_data.length.to_string ());
                Idle.add ( () => {
                    data_available (encrypted_data);
                    int ret_free = Dtcpip.server_dtcp_free (encrypted_data);
                    debug ("on_buf_generated: server_dtcp_free returned %d", ret_free);
                    return false;
                }, Priority.HIGH_IDLE);
            }
        }
        if (last_buffer) {
            debug ("on_buf_generated: last buffer received. Total bytes received: %llu",
                   this.total_bytes_read);
            Idle.add ( () => {
                message ("on_buf_generated: All requested data sent for %s (%lld bytes) - signaling done()",
                         ODIDUtil.short_content_path (this.content_uri), this.total_bytes_read);
                done ();
                return false;
            }, Priority.HIGH_IDLE);
        }
    }
}

/* 
 * Copyright (C) 2013  Cable Television Laboratories, Inc.
 * Contact: http://www.cablelabs.com/
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
 * IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL APPLE INC. OR ITS CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 *
 */

/*
 * Based on Rygel SimpleDataSource
 * Copyright (C) 2012 Intel Corporation.
 *
 */
 
/**
 * A simple data source for use with the ODID media engine.
 */
 using Dtcpip;
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
    private HTTPSeek seek;
    private DLNAPlaySpeed playspeed = null;
    private MediaResource res;
    private int session_handle = -1;

    public ODIDDataSource(string source_uri, MediaResource ? res) {
        message ("Creating data source for %s resource %s", source_uri, res.get_name());
        this.source_uri = source_uri;
        this.res = res;
    }

    ~ODIDDataSource() {
        this.stop ();
        this.clear_dtcp_session();
        message ("Stopped data source");
    }

    public void preroll (HTTPSeek? seek, DLNAPlaySpeed? playspeed) throws Error {
        message("source uri: " + source_uri);

        this.seek = seek;
        this.playspeed = playspeed;

        if (res == null) {
            throw new DataSourceError.GENERAL("null resource");
        }
        
        debug("Resource %s size: %lld", res.get_name(), res.size);
        debug("Resource %s duration: %lld", res.get_name(), res.duration);
        debug("Resource %s protocol_info: %s", res.get_name(), res.protocol_info.to_string());
        debug("Resource %s profile: %s", res.get_name(), res.protocol_info.dlna_profile);

        if (res != null &&
            res.protocol_info.dlna_profile.has_prefix ("DTCP_") &&
            ODIDMediaEngine.is_dtcp_loaded()) {
            message ("Entering DTCP-IP streaming mode");
            Dtcpip.server_dtcp_open (out session_handle, 0);
        }

        if (session_handle == -1) {
            debug ("DTCP-IP session not opened");
        } else {
            message ("Got DTCP-IP session handle : %d", session_handle);
        }

        KeyFile keyFile = new KeyFile();
        keyFile.load_from_file(File.new_for_uri (source_uri).get_path (),
                               KeyFileFlags.KEEP_COMMENTS |
                               KeyFileFlags.KEEP_TRANSLATIONS);

        string odid_item_path = keyFile.get_string ("item", "odid_uri");
        message ("Source item path: %s", odid_item_path);

        // The resources are published by this engine according to the resource directory name
        //  i.e. the MediaResource "name" field was set to the directory name when
        //  get_resources_for_uri() was called
        string resource_dir = res.get_name();
        string resource_path = odid_item_path + resource_dir + "/";
        message ("  resource directory: %s", resource_dir);

        string basename = get_resource_property(resource_path,"basename");

        string file_extension;
        string content_filename = ODIDMediaEngine.content_filename_for_res_speed (
                                                            odid_item_path + resource_dir,
                                                            basename,
                                                            playspeed,
                                                            out file_extension );
        this.content_uri = resource_path + content_filename;
        message ("    content file: %s", content_filename);

        // Get the size for the scaled content file 
        File content_file = File.new_for_uri(this.content_uri);
        FileInfo content_info = content_file.query_info(GLib.FileAttribute.STANDARD_SIZE, 0);
        int64 total_size = content_info.get_size();
        seek.total_size = total_size;
        message ("      Total size is is " + total_size.to_string());
                                                            
        // Process HTTPSeek
        if (seek == null) {
            message ("No seek request received");
        } else if (seek is HTTPTimeSeek) {
            var time_seek = seek as HTTPTimeSeek;
            //
            // Convert the HTTPTimeSeek to a byte range and update the HTTPTimeSeek response params
            //
            bool is_reverse = (playspeed != null) && (playspeed.is_negative());

            // Calculate the effective range of the time seek using the appropriate index file
            
            int64 time_offset_start = time_seek.requested_start;
            int64 time_offset_end;
            if (time_seek.end_time_requested()) {
                time_offset_end = time_seek.requested_end;
            } else { // The "end" of the time range depends on the direction
                time_offset_end = is_reverse ? 0 : int64.MAX;
            }

            string index_path = resource_path + "/" + content_filename + ".index";
            int64 total_duration = time_seek.total_duration_set() ? time_seek.get_total_duration()
                                                                  : int64.MAX;
            message ("      Total duration is " + total_duration.to_string());
            message ("Processing time seek (time %lldns to %lldns)", time_offset_start, time_offset_end);
            
            offsets_for_time_range(index_path, is_reverse,
                                   ref time_offset_start, ref time_offset_end, total_duration,
                                   out this.range_start, out this.range_end, total_size );

            message ("Data range for time seek: bytes %lld through %lld",
                     this.range_start, this.range_end-1);
                     
            // Now set the effective time/data range and duration/size (if known)
            time_seek.set_effective_time_range(time_offset_start, time_offset_end);
            
            time_seek.set_byte_range(this.range_start, this.range_end-1); // inclusive offset
        } else if (seek is HTTPByteSeek) {
            //
            // Byte-based seek - no conversion required (*)
            //
            // TODO: Add DTCPRangeSeek class and a "seek is DTCPRangeSeek" case
            var byte_seek = seek as HTTPByteSeek;
            message ("Received data seek (bytes %lld to %lld)",
                     byte_seek.start_byte, byte_seek.end_byte);
            offsets_for_byte_seek(byte_seek.start_byte, byte_seek.end_byte, byte_seek.total_size);
            message ("Modified data seek (bytes %lld to %lld)",
                     this.range_start, this.range_end);
        } else {
            throw new DataSourceError.SEEK_FAILED("Unsupported seek type");
        }

        // Process PlaySpeed
        if (playspeed == null) {
            message ("No playspeed request received");
        } else {
            message ("Received playspeed " + playspeed.to_string()
                     + " (" + playspeed.to_float().to_string() + ")");
            try {
                string framerate_for_speed = get_content_property(content_uri, "framerate");
                message ("  Framerate for speed %s: %s", playspeed.to_string(),
                                                         framerate_for_speed);
                int framerate = int.parse(framerate_for_speed);
                if (framerate > 0) {
                    playspeed.set_framerate(framerate);
                } else {
                    warning("Invalid framerate found for %s: %s", content_filename,
                            framerate_for_speed);
                }
            } catch (Error err) {
                debug("Error reading framerate property (continuing): " + err.message);
            }
        }
        // Wait for a start() before sending anything
    }

    internal void offsets_for_byte_seek (int64 start, int64 end, int64 total_size) {
            this.range_start = start;

            if (this.seek.msg.request_headers.get_one ("Range.dtcp.com") != null) {
                //Get the transport stream packet size for the profile
                string profile_name = res.protocol_info.dlna_profile;

                // Align the bytes to transport packet boundaries
                int64 packet_size = ODIDUtil.get_profile_packet_size(profile_name);
                if (packet_size > 0) {
                // DLNA Link Protection : 8.9.5.4.2
                    this.range_end = ODIDUtil.get_dtcp_algined_end
                              (start, end, ODIDUtil.get_profile_packet_size(profile_name));
                }
                if (this.range_end > total_size) {
                    this.range_end = total_size;
                }
            } else {
                // Range requests are inclusive, but range_end is not. So add 1 to capture the
                //  last range byte
                this.range_end = end+1; 
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
        message ("offsets_for_time_range: %s, %lld-%s",
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
                        message ("offsets_for_time_range: found start of range (%s): time %lld, offset %lld",
                                 (is_reverse ? "reverse" : "forward"), start_time, start_offset);
                    }
                } else {
                    if ( (is_reverse && (cur_time_offset < end_time))
                         || (!is_reverse && (cur_time_offset > end_time)) ) {
                        end_time = cur_time_offset;
                        end_offset = int64.parse(strip_leading_zeros(cur_data_offset));
                        end_offset_found = true;
                        message ("offsets_for_time_range: found end of range (%s): time %lld, offset %lld",
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
            message ("offsets_for_time_range: end of range beyond index range (%s): time %lld, offset %lld",
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
        message ("Starting data source for %s", content_uri);

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
        if (session_handle != -1) {
            int ret_close = Dtcpip.server_dtcp_close (session_handle);
            message ("Dtcp session closed : %d",ret_close);
            session_handle = -1;
        }
    }
    private void* thread_func() {
        var file = File.new_for_uri (this.content_uri);
        message ("Spawned new thread for streaming %s", this.content_uri);
        try {
            var mapped = new MappedFile(file.get_path (), false);

            if (this.range_end == 0) {
                this.range_end = mapped.get_length();
            }
            
            message ( "Sending bytes %lld-%lld (%lld bytes) of %s",
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
                    message ("Done streaming!");
                    break;
                }

                var start = this.range_start;
                var stop = start + uint16.MAX;
                if (stop > this.range_end) {
                    stop = this.range_end;
                }

                // message ( "Sending range %lld-%lld (%lld bytes)",
                //           start, stop, stop-start );

                unowned uint8[] data = (uint8[]) mapped.get_contents ();
                data.length = (int) mapped.get_length ();
                uint8[] slice = data[start:stop];

                // Encrypted data has to be unowned as the reference will be passed
                // to DTCP libraries to perform the cleanup, else vala will be
                //performing the cleanup by default.
                unowned uint8[] encrypted_data = null;
                int64 encrypted_data_length =-1;
                uchar cci = 0x3;

                // Encrypt the data here
                if (this.session_handle != -1) {
                    int return_value = Dtcpip.server_dtcp_encrypt (session_handle, cci, slice, out encrypted_data);
                    encrypted_data_length = encrypted_data.length;
                    debug ("Encryption returned : %d and the encryption size : %lld",return_value,encrypted_data_length);
                }

                this.range_start = stop;

                // There's a potential race condition here.
                Idle.add ( () => {
                    if (!this.stop_thread) {
                        if (this.session_handle != -1) {
                            debug ("Sending encrypted data.");
                            this.data_available (encrypted_data);
                        } else {
                            debug ("Sending unencrypted data.");
                            this.data_available (slice);
                        }

                    }

                    if (encrypted_data != null) {
                        int ret_free = Dtcpip.server_dtcp_free (encrypted_data);
                        debug ("DTCP-IP data reference freed : %d", ret_free);
                    }
                    return false;
                });
            }
        } catch (Error error) {
            warning ("Failed to map file: %s", error.message);
        }

        // Signal that we're done streaming
        Idle.add ( () => { this.done (); return false; });

        return null;
    }
}

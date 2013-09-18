/*
 * Copyright (C) 2013 CableLabs
 */
 
/*
 * Based on Rygel SimpleDataSource
 * Copyright (C) 2012 Intel Corporation.
 *
 */
 

/**
 * A simple data source for use with the ODID media engine.
 */
internal class Rygel.ODIDDataSource : DataSource, Object {
    private string source_uri; 
    private Thread<void*> thread;
    private string content_path;
    private Mutex mutex = Mutex ();
    private Cond cond = Cond ();
    private uint64 first_byte = 0;
    private uint64 last_byte = 0;
    private bool frozen = false;
    private bool stop_thread = false;
    private HTTPSeek offsets;
    private DLNAPlaySpeed playspeed = null;
    private MediaResource res;

    public ODIDDataSource(string source_uri, MediaResource ? res) {
        message ("Creating a data source for URI %s", source_uri);
        this.source_uri = source_uri;
        this.res = res;
    }

    ~ODIDDataSource() {
        this.stop ();
        message ("Stopped data source");
    }

    public void start (HTTPSeek? offsets, DLNAPlaySpeed? playspeed) throws Error {
        message("ODIDDataSource.start: source uri: " + source_uri);

        this.offsets = offsets;
        this.playspeed = playspeed;

        if (res == null) {
            message("ODIDDataSource.start: null resource");
        } else {
            message("ODIDDataSource.start: size: %lld", res.size);
            message("ODIDDataSource.start: duration: %lld", res.duration);
            message("ODIDDataSource.start: protocol_info: " + res.protocol_info.to_string());
            message("ODIDDataSource.start: profile: " + res.protocol_info.dlna_profile);
        }


        KeyFile keyFile = new KeyFile();
        keyFile.load_from_file(File.new_for_uri (source_uri).get_path (),
                               KeyFileFlags.KEEP_COMMENTS |
                               KeyFileFlags.KEEP_TRANSLATIONS);

        string odid_item_path = keyFile.get_string ("item", "odid_uri");
        message ("Start datasource using %s", odid_item_path);

        // The resources are published by this engine according to the resource directory name
        string resource_dir = res.get_name();
        string resource_path = odid_item_path + resource_dir + "/";

        string basename = get_resource_property(resource_path,"basename");
        message ("ODIDDataSource.start: basename is " + basename);

        string file_extension;

        string content_filename = ODIDMediaEngine.content_filename_for_res_speed (
                                                            odid_item_path + resource_dir,
                                                            basename,
                                                            playspeed,
                                                            out file_extension );
        // Process HTTPSeek
        if (offsets == null) {
            message ("ODIDDataSource.start: Received null seek");
        } else if (offsets.seek_type == HTTPSeekType.TIME) {
            message ("ODIDDataSource.start: Received time seek (time %lld to %lld)",
                     offsets.start, offsets.stop);
            uint64 time_offset_start = offsets.start;
            uint64 time_offset_end = offsets.stop;
            string index_path = resource_path + "/" + content_filename + ".index";
            bool is_reverse = (playspeed != null) && (playspeed.numerator < 0);
            offsets_for_time_range(index_path, ref time_offset_start, ref time_offset_end,
                                   is_reverse, out this.first_byte, out this.last_byte);
            message ("ODIDDataSource.start: Data range for time seek: bytes %lld to %lld",
                     this.first_byte, this.last_byte);
        } else if (offsets.seek_type == HTTPSeekType.BYTE) {
            message ("ODIDDataSource.start: Received data seek (bytes %lld to %lld)",
                     offsets.start, offsets.stop);
            this.first_byte = offsets.start;
            this.last_byte = offsets.stop;
        }

        // Process PlaySpeed
        if (playspeed == null) {
            message ("ODIDDataSource.start: Received null playspeed");
        } else {
            message ("ODIDDataSource.start: Received playspeed " + playspeed.to_string()
                     + " (" + playspeed.to_float().to_string() + ")");
        }
        content_path = resource_path + content_filename;
        message ("Starting data source for %s", content_path);

        this.thread = new Thread<void*>("ODIDDataSource Serving thread",
                                         this.thread_func);
    }
    
    internal void offsets_for_time_range(string index_path, ref uint64 start_time, ref uint64 end_time,
                                         bool is_reverse, out uint64 start_offset, out uint64 end_offset)
         throws Error {
        message ("ODIDDataSource.offsets_for_time_range: %s, %lld-%lld",
                 index_path,start_time,end_time);
        bool start_offset_found = false;
        bool end_offset_found = false;

        var file = File.new_for_uri(index_path);
        var dis = new DataInputStream(file.read());
        string line;
        uint64 cur_time_offset = 0;
        string cur_data_offset = null;
        uint64 last_time_offset = 0;
        string last_data_offset = "0";
        start_offset = 0;
        end_offset = 0;
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
                cur_time_offset = uint64.parse(strip_leading_zeros(extended_time_string));
                cur_data_offset = index_fields[3]; // Convert this only when needed
                // message ("ODIDDataSource.offsets_for_time_range: keyframe at %s (%s) has offset %s",
                //          extended_time_string, cur_time_offset.to_string(), cur_data_offset);
                if (!start_offset_found) {
                    if (!is_reverse) {
                        if (cur_time_offset > start_time) {
                            start_time = last_time_offset;
                            start_offset = uint64.parse(strip_leading_zeros(last_data_offset));
                            start_offset_found = true;
                            message ("ODIDDataSource.offsets_for_time_range: found start of range (forward): time %lld, offset %lld",
                                     start_time, start_offset);
                        }
                    } else {
                        if (cur_time_offset < end_time) {
                            end_time = last_time_offset;
                            start_offset = uint64.parse(strip_leading_zeros(last_data_offset));
                            start_offset_found = true;
                            message ("ODIDDataSource.offsets_for_time_range: found start of range (reverse): time %lld, offset %lld",
                                     start_time, start_offset);
                        }
                    }
                } else {
                    if (!is_reverse) {
                        if (cur_time_offset > end_time) {
                            end_time = cur_time_offset;
                            end_offset = uint64.parse(strip_leading_zeros(cur_data_offset));
                            end_offset_found = true;
                            message ("ODIDDataSource.offsets_for_time_range: found end of range (forward): time %lld, offset %lld",
                                     end_time, end_offset);
                            break;
                        }
                    } else {
                        if (cur_time_offset < start_time) {
                            start_time = cur_time_offset;
                            end_offset = uint64.parse(strip_leading_zeros(cur_data_offset));
                            end_offset_found = true;
                            message ("ODIDDataSource.offsets_for_time_range: found end of range (reverse): time %lld, offset %lld",
                                     end_time, end_offset);
                            break;
                        }
                    }
                }
                last_time_offset = cur_time_offset;
                last_data_offset = cur_data_offset;
            }
        }

        if (start_offset_found && !end_offset_found) {
            if (!is_reverse) {
                end_time = cur_time_offset;
                end_offset = uint64.parse(strip_leading_zeros(cur_data_offset));
                message ("ODIDDataSource.offsets_for_time_range: end of range beyond index range (forward): time %lld, offset %lld",
                         end_time, end_offset);
            } else {
                start_time = cur_time_offset;
                end_offset = uint64.parse(strip_leading_zeros(cur_data_offset));
                message ("ODIDDataSource.offsets_for_time_range: end of range beyond index range (reverse): time %lld, offset %lld",
                         end_time, end_offset);
            }
        }
    }

    internal static string strip_leading_zeros(string number_string) {
        return ODIDMediaEngine.strip_leading_zeros(number_string);
    }


    string ? get_resource_property(string odid_resource_path, string property_name)
         throws Error {
        var file = File.new_for_uri(odid_resource_path + "resource.info");
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

    private void* thread_func() {
        var file = File.new_for_uri (this.content_path);
        message ("Spawned new thread for streaming %s", this.content_path);
        try {
            var mapped = new MappedFile(file.get_path (), false);

            if (this.last_byte == 0) {
                this.last_byte = mapped.get_length();
            }
            
            message ( "Sending bytes %lld-%lld (%lld bytes) of %s",
                      this.first_byte, this.last_byte, this.last_byte-this.first_byte+1,
                      this.content_path );

            while (true) {
                bool exit;
                this.mutex.lock ();
                while (this.frozen) {
                    this.cond.wait (this.mutex);
                }

                exit = this.stop_thread;
                this.mutex.unlock ();

                if (exit || this.first_byte >= this.last_byte) {
                    message ("Done streaming!");
                    break;
                }

                var start = this.first_byte;
                var stop = start + uint16.MAX;
                if (stop > this.last_byte) {
                    stop = this.last_byte+1; // Need to capture the last byte in the slice...
                }

                // message ( "Sending range %lld-%lld (%ld bytes)",
                //           start, stop, stop-start );

                unowned uint8[] data = (uint8[]) mapped.get_contents ();
                data.length = (int) mapped.get_length ();
                uint8[] slice = data[start:stop];
                this.first_byte = stop;
                
                // There's a potential race condition here.
                Idle.add ( () => {
                    if (!this.stop_thread) {
                        this.data_available (slice);
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

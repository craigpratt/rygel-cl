/*
 * Copyright (C) 2013 CableLabs
 */

/*
 * Based on Rygel SimpleMediaEngine
 * Copyright (C) 2012 Intel Corporation.
 */

using Gee;
using GUPnP;

/**
 * This media engine is intended to be the basis for the CL 
 * reference DMS. Long-term, this could be moved outside the Rygel
 * source tree and built stand-alone.
 */
internal class Rygel.ODIDMediaEngine : MediaEngine {
    private  GLib.List<DLNAProfile> profiles 
        = new GLib.List<DLNAProfile>();

    private GLib.List<Transcoder> transcoders = null;

    // Entry Type (V: Video Frame)
    // | Video Frame Type (I,B,P)
    // | | Time Offset (seconds.milliseconds) (fixed decimal places, 8.3)
    // | | |           File Byte Offset (fixed decimal places, 19)
    // | | |           |                   Frame size (fixed decimal places, 10)
    // | | |           |                   |
    // v v v           v                   v
    // V F 0000000.000 0000000000000000000 0000000000<15 spaces><newline>
        
    public static const uint INDEXFILE_ROW_SIZE = 62;
    public static const uint INDEXFILE_FIELD_ENTRYTYPE_OFFSET = 0;
    public static const uint INDEXFILE_FIELD_FRAMETYPE_OFFSET = 2;
    public static const uint INDEXFILE_FIELD_TIME_OFFSET = 4;
    public static const uint INDEXFILE_FIELD_TIMESECONDS_LENGTH = 7;
    public static const uint INDEXFILE_FIELD_TIMEMS_LENGTH = 3;
    public static const uint INDEXFILE_FIELD_TIME_LENGTH = 11;
    public static const uint INDEXFILE_FIELD_BYTEOFFSET_OFFSET = 17;
    public static const uint INDEXFILE_FIELD_BYTEOFFSET_LENGTH = 19;
    public static const uint INDEXFILE_FIELD_FRAMESIZE_OFFSET = 37;
    public static const uint INDEXFILE_FIELD_FRAMESIZE_LENGTH = 10;

    internal class ConfigProfileEntry {
        public string profile;
        public string mimetype;
        public string extension;

        public ConfigProfileEntry(string profile, string mimetype, string extension) {
            this.profile = profile;
            this.mimetype = mimetype;
            this.extension = extension;
        }
    }

    private GLib.List<ConfigProfileEntry> config_entries = null;

    public ODIDMediaEngine() {
        message("constructing");

        var profiles_config = new Gee.ArrayList<string>();
        config_entries = new GLib.List<ConfigProfileEntry>();
                
        var config = MetaConfig.get_default();
        try {
            profiles_config = config.get_string_list( "OdidMediaEngine", "profiles");
        } catch (Error err) {
            error("Error reading CL-ODIDMediaEngine profiles: " + err.message);
        }

        foreach (var row in profiles_config) {
            var columns = row.split(",");
            if (columns.length < 3)
            {
                message( "OdidMediaEngine profile entry \""
                         + row + "\" is malformed: Expected 3 entries and found "
                         + columns.length.to_string() );
                break;
            }
            string profile = columns[0];
            string mimetype = columns[1];
            string extension = columns[2];

            message("OdidMediaEngine: configuring profile entry: " + row);
            config_entries.append(new ConfigProfileEntry(profile, mimetype, extension));
            // Note: This profile list won't affect what profiles are included in the 
            //       primary res block
            profiles.append(new DLNAProfile(profile,mimetype));
            // The transcoders will become secondary res blocks
            this.transcoders.prepend(
                    new ODIDFakeTranscoder(mimetype,profile,extension) );
        }
    }
	
    public override unowned GLib.List<DLNAProfile> get_renderable_dlna_profiles() {
        message("get_renderable_dlna_profiles");
        return this.profiles;
    }

    public override Gee.List<MediaResource>? get_resources_for_uri(string source_uri) {
        message("OdidMediaEngine:get_resources_for_uri");
        var resources = new Gee.ArrayList<MediaResource>();

        // TODO: FIX ME. This will be determined from the source uri
        string odid_item_path = "file:///home/craig/odid/item-2/";

        try {
            var directory = File.new_for_uri(odid_item_path);
            var enumerator = directory.enumerate_children(FileAttribute.STANDARD_NAME, 0);

            FileInfo file_info;
            while ((file_info = enumerator.next_file ()) != null) {
                if (file_info.get_file_type () == FileType.DIRECTORY) {
                    message( "OdidMediaEngine:get_resources_for_uri: configuring profile entry: "
                             + file_info.get_name());
                    // A directory in an item directory is a resource
                    var res = create_resource_from_resource_dir( odid_item_path
                                                                 + file_info.get_name() + "/");
                    if (res != null) {
                        resources.add(res);
                        message("get_resources_for_uri: created " + res.get_name());
                    }
                }
            }
        } catch (Error err) {
            error("Error creating resources for source %s: %s", odid_item_path, err.message);
        }
         
        return resources;
    }

    internal MediaResource ? create_resource_from_resource_dir(string res_dir_path)
         throws Error {
        message( "OdidMediaEngine:create_resource_from_resource_dir: configuring resources for "
                 + res_dir_path);
        MediaResource res = null;

        var res_dir = File.new_for_uri(res_dir_path);
        FileInfo res_dir_info = res_dir.query_info(GLib.FileAttribute.STANDARD_NAME, 0);

        res = new MediaResource(res_dir_info.get_name());

        string basename = null;

        // Construct the ProtocolInfo
        res.protocol_info = create_protocol_info_from_resource_dir(res_dir_path);

        // Process fields set in the resource.info
        {
            File res_info_file = File.new_for_uri(res_dir_path + "/resource.info");
            var dis = new DataInputStream(res_info_file.read());
            string line;
            while ((line = dis.read_line(null)) != null) {
                if (line[0] == '#') continue;
                var equals_pos = line.index_of("=");
                var name = line[0:equals_pos].strip();
                var value = line[equals_pos+1:line.length].strip();
                message( "OdidMediaEngine:create_resource_from_resource_dir: processing resource.info line: "
                         + line );
                if (name == "basename") {
                    basename = value;
                    continue;
                }
                if (name.length > 0 && value.length > 0) {
                    set_resource_field(res, name, value);
                }
            }
        }

        string file_extension;
        string content_filename;

        // Set the size according to the normal-rate file (speed "1/1")
        {
            content_filename = ODIDMediaEngine.content_filename_for_res_speed (
                                                                res_dir_path,
                                                                basename,
                                                                new DLNAPlaySpeed(1,1),
                                                                out file_extension );
            message( "OdidMediaEngine:Getting size for " + res_dir_path + content_filename);
            File content_file = File.new_for_uri(res_dir_path + content_filename);
            FileInfo content_info = content_file.query_info(GLib.FileAttribute.STANDARD_SIZE, 0);
            res.size = content_info.get_size();
            res.extension = file_extension;
            message( "OdidMediaEngine:create_resource_from_resource_dir: size for "
                     + content_filename + " is " + res.size.to_string() );
        }

        // Set the duration according to the last entry in the normal-rate index file
        res.duration = duration_for_content_file(res_dir_path + content_filename);
        message( "OdidMediaEngine:create_resource_from_resource_dir: duration for "
                 + content_filename + " is " + res.duration.to_string() );

        return res;
    }

    internal ProtocolInfo create_protocol_info_from_resource_dir(string res_dir_path)
         throws Error {
        // Note: It's not our job to set everything - only fields related to the content.
        //       e.g. it's the HTTP server's place to set transfer parameters
        // TODO: Enumerate speed files
        var protocol_info = new ProtocolInfo();

        return protocol_info;
    }

    void set_resource_field(MediaResource res, string name, string value) {
        if (name == "profile") {
            res.protocol_info.dlna_profile = value;
        } else if (name == "mime-type") {
            res.protocol_info.mime_type = value;
        } else if (name == "uri") {
            res.uri = value;
        } else if (name == "bitrate") {
            res.bitrate = int.parse(value);
        } else if (name == "audio-bits-per-sample") {
            res.bits_per_sample = int.parse(value);
        } else if (name == "video-color-depth") {
            res.color_depth = int.parse(value);
        } else if (name == "video-resolution") {
            var res_fields = value.split("x");
            res.width = int.parse(res_fields[0]);
            res.height = int.parse(res_fields[1]);
        } else if (name == "audio-channels") {
            res.audio_channels = int.parse(value);
        } else if (name == "audio-sample-frequency") {
            res.sample_freq = int.parse(value);
        }
    }

    internal static string? content_filename_for_res_speed( string resource_dir_path,
                                                            string basename,
                                                            DLNAPlaySpeed? playspeed,
                                                            out string extension )
            throws Error {
        message ("ODIDMediaEngine.content_filename_for_res_speed: %s, %s, %s\n",
                 resource_dir_path,basename,playspeed.to_string() );
        string rate_string;
        if (playspeed == null) {
            rate_string = "1_1";
        } else {
            rate_string = playspeed.numerator.to_string() + "_" + playspeed.denominator.to_string();
        }

        string content_filename = null;
        extension = null;

        message ("ODIDMediaEngine.content_filename_for_res_speed: resource_path: %s\n", resource_dir_path);

        var directory = File.new_for_uri(resource_dir_path);
        var enumerator = directory.enumerate_children(GLib.FileAttribute.STANDARD_NAME, 0);

        FileInfo file_info;
        while ((file_info = enumerator.next_file ()) != null) {
            var cur_filename = file_info.get_name();
            // Check for content file for the requested rate (<basename>.<rate>.<extension>)
            var split_name = cur_filename.split(".");
            if ( (split_name.length == 3)
                 && (split_name[0] == basename) && (split_name[1] == rate_string) ) {
                content_filename = cur_filename;
                extension = split_name[2];
                message ("ODIDMediaEngine.content_filename_for_res_speed: FOUND MATCH: %s (extension %s)\n",
                         content_filename, extension);
            }
        }

        return content_filename;
    }

    internal static long duration_for_content_file(string content_path)
            throws Error {
        message ("ODIDDataSource.duration_for_content_file: %s",
                 content_path);
        string index_path = content_path + ".index";
        
        File index_file = File.new_for_uri(index_path);
        FileInfo index_info = index_file.query_info(GLib.FileAttribute.STANDARD_SIZE, 0);

        // Last entry will be 62 bytes from the end of the file...

        var dis = new DataInputStream(index_file.read());
        dis.skip((size_t)(index_info.get_size()-INDEXFILE_ROW_SIZE));
        string line = dis.read_line(null);
        
        uint time_field_start = INDEXFILE_FIELD_TIME_OFFSET;
        uint time_field_end = INDEXFILE_FIELD_TIME_OFFSET+INDEXFILE_FIELD_TIME_LENGTH;
        string seconds_field = line[time_field_start:time_field_end];
        double duration_val;
        if (double.try_parse(seconds_field, out duration_val))
        {
            return (long)(duration_val+0.5); // For rounding
        } else {
            throw new IOError.FAILED("Ill-formed duration in last index file entry: " + line, index_file);
        }
    }

    internal static string strip_leading_zeros(string number_string) {
        int i=0;
        while ((number_string[i] == '0') && (i < number_string.length)) {
            i++;
        }
        if (i == 0) {
            return number_string;
        } else {
            return number_string[i:number_string.length];
        }
    }
                                                        
    public override unowned GLib.List<Transcoder>? get_transcoders() {
        message("get_transcoders");
        return this.transcoders;
    }

    public override DataSource? create_data_source_for_resource
                                (string uri, MediaResource ? resource) {
        if (!uri.has_prefix ("file://")) {
            return null;
        }

        message("create_data_source_for_resource: source uri: " + uri);
        if (resource == null) {
            message("create_data_source_for_resource: null resource");
        } else {
            message("create_data_source_for_resource: size: %lld", resource.size);
            message("create_data_source_for_resource: duration: %lld", resource.duration);
            message("create_data_source_for_resource: protocol_info: " + resource.protocol_info.to_string());
            message("create_data_source_for_resource: profile: " + resource.protocol_info.dlna_profile);
        }
        
        return new ODIDDataSource(uri, resource);
    }
}

public static Rygel.MediaEngine module_get_instance() {
        message("module_get_instance");
        return new Rygel.ODIDMediaEngine();
}


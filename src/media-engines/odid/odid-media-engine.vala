/*
 * Copyright (C) 2013 CableLabs
 */

/*
 * Based on Rygel SimpleMediaEngine
 * Copyright (C) 2012 Intel Corporation.
 */

using Gee;
using GUPnP;
using Dtcpip;
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

    //DTCP Related variabled
    private static bool dtcp_supported = false;
    private static bool dtcp_loaded = false;
    private string dtcp_storage = null;

    public ODIDMediaEngine() {
        message("constructing");
        var profiles_config = new Gee.ArrayList<string>();
        config_entries = new GLib.List<ConfigProfileEntry>();
        var config = MetaConfig.get_default();
        //char version_str[512];
        ushort dtcp_port = 8999; // Default set it to 8999.

        try {
            dtcp_supported = config.get_bool ("OdidMediaEngine", "engine-dtcp");
            profiles_config = config.get_string_list( "OdidMediaEngine", "profiles");
        } catch (Error err) {
            error("Error reading CL-ODIDMediaEngine properties " + err.message);
        }

        if (ODIDUtil.is_rygel_dtcp_enabled() && dtcp_supported) {
            try {
                dtcp_storage = config.get_string ("general", "dtcp-storage");
                dtcp_port = (ushort)config.get_int ("general", "dtcp-port", 6000, 8999);
            } catch (Error err) {
                error("Error reading CL-ODIDMediaEngine dtcp properties " + err.message);
            }
            if (Dtcpip.init_dtcp_library (dtcp_storage) != 0){
                warning ("DTCP-IP storage path set failed : %s",dtcp_storage);
            } else {
                message ("DTCP-IP storage loaded successfully");
            }

            //else {
                //cmn_get_version (version_str, 512);
                //message ("DTCP String version : %s",(string)version_str);
            //}

            if (Dtcpip.server_dtcp_init (8999) != 0) {
                warning ("DTCP-IP source init failed.");
            } else {
                message ("DTCP-IP source initialized");
                dtcp_loaded = true;
            }
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
        }

    }

    public override unowned GLib.List<DLNAProfile> get_renderable_dlna_profiles() {
        message("get_renderable_dlna_profiles");
        return this.profiles;
    }

    public override Gee.List<MediaResource>? get_resources_for_uri(string source_uri) {
        message("OdidMediaEngine:get_resources_for_uri");
        var resources = new Gee.ArrayList<MediaResource>();
        string odid_item_path = null;
        try {
            KeyFile keyFile = new KeyFile();
            keyFile.load_from_file(File.new_for_uri (source_uri).get_path (),
                                   KeyFileFlags.KEEP_COMMENTS |
                                   KeyFileFlags.KEEP_TRANSLATIONS);

            odid_item_path = keyFile.get_string ("item", "odid_uri");
            message ("Get resources for %s", odid_item_path);

            var directory = File.new_for_uri(odid_item_path);
            var enumerator = directory.enumerate_children(FileAttribute.STANDARD_NAME, 0);

            FileInfo file_info;
            while ((file_info = enumerator.next_file ()) != null) {
                if (file_info.get_file_type () == FileType.DIRECTORY) {
                    message( "OdidMediaEngine:get_resources_for_uri: processing resource directory: "
                             + file_info.get_name());
                    // A directory in an item directory is a resource
                    var res = create_resource_from_resource_dir( odid_item_path
                                                                 + file_info.get_name() + "/");
                    if (res != null) {
                        resources.add(res);
                        message("get_resources_for_uri: created resource " + res.get_name());
                        message("get_resources_for_uri: resource " + res.get_name()
                                + " protocolInfo " + res.protocol_info.to_string() );
                    }
                }
            }
        } catch (Error err) {
            error("Error creating resources for source %s: %s", odid_item_path, err.message);
        }
         
        return resources;
    }

    /**
     * Construct a MediaResource from an on-disk resource
     *
     * @param res_dir_uri URI to the resource directory.
     * @return MediaResource constructed from the on-disk resource directory
     */
    internal MediaResource ? create_resource_from_resource_dir(string res_dir_uri)
         throws Error {
        message( "OdidMediaEngine:create_resource_from_resource_dir: configuring resources for "
                 + res_dir_uri);
        MediaResource res = null;

        var res_dir = File.new_for_uri(res_dir_uri);
        FileInfo res_dir_info = res_dir.query_info(GLib.FileAttribute.STANDARD_NAME, 0);

        res = new MediaResource(res_dir_info.get_name());

        string basename = null;

        res.protocol_info = new GUPnP.ProtocolInfo();
        res.protocol_info.protocol = "http-get"; // Set this temporarily to avoid an assertion error

        // Process fields set in the resource.info
        {
            File res_info_file = File.new_for_uri(res_dir_uri + "/resource.info");
            var dis = new DataInputStream(res_info_file.read());
            string line;
            while ((line = dis.read_line(null)) != null) {
                if (line[0] == '#') continue;
                var equals_pos = line.index_of("=");
                var name = line[0:equals_pos].strip();
                var value = line[equals_pos+1:line.length].strip();
                if (name == "basename") {
                    basename = value;
                    continue;
                }
                // Check if the media-engine dtcp-ip support (Rygel Wide & Media-Engine) and then if
                // protected property is set to true, then overwrite the profile name with DTCP prefix and mime-type
                if (ODIDUtil.is_rygel_dtcp_enabled()
                    && has_mediaengine_dtcp ()
                    && (name == "protected" && value == "true")) {
                    string dtcp_mime_type = ODIDUtil.handle_mime_item_protected 
                                                                  (res.protocol_info.mime_type);
                    set_resource_field(res, "profile", "DTCP_" + res.protocol_info.dlna_profile);
                    set_resource_field(res, "mime-type", dtcp_mime_type);
                    continue;
                }
                if (name.length > 0 && value.length > 0) {
                    set_resource_field(res, name, value);
                }
            }
        }

        string file_extension;
        string normal_content_filename;

        // Set the size according to the normal-rate file (speed "1/1")
        {
            normal_content_filename = ODIDMediaEngine.content_filename_for_res_speed (
                                                                res_dir_uri,
                                                                basename,
                                                                new DLNAPlaySpeed(1,1),
                                                                out file_extension );
            File content_file = File.new_for_uri(res_dir_uri + normal_content_filename);
            FileInfo content_info = content_file.query_info(GLib.FileAttribute.STANDARD_SIZE, 0);
            res.size = content_info.get_size();
            res.extension = file_extension;
            message( "OdidMediaEngine:create_resource_from_resource_dir: size for "
                     + normal_content_filename + " is " + res.size.to_string() );
        }

        res.protocol_info.dlna_flags = DLNAFlags.DLNA_V15
                                        | DLNAFlags.STREAMING_TRANSFER_MODE
                                        | DLNAFlags.BACKGROUND_TRANSFER_MODE
                                        | DLNAFlags.CONNECTION_STALL;

        // We currently support RANGE for all resources except DTCP content
        if (res.protocol_info.dlna_profile.has_prefix ("DTCP_")) {
            res.protocol_info.dlna_flags |= DLNAFlags.LINK_PROTECTED_CONTENT |
                                            DLNAFlags.CLEARTEXT_BYTESEEK_FULL;
            res.protocol_info.dlna_operation = DLNAOperation.NONE;

            res.cleartext_size = res.size;
            // TODO : Call encrypted size calculation lib after DTCP lib integration
            res.size = res.size + 1000;
        }
        else {
            res.protocol_info.dlna_operation = DLNAOperation.RANGE;
        }
        
        // Look for an index file and set fields accordingly if/when found
        {
            string index_path = res_dir_uri + normal_content_filename + ".index";
            File index_file = File.new_for_uri(index_path);
            if (index_file.query_exists()) {
                // We support TimeSeekRange for this content
                res.protocol_info.dlna_operation |= DLNAOperation.TIMESEEK; 
                // Set the duration according to the last entry in the normal-rate index file
                res.duration = duration_from_index_file(index_file);
                message( "OdidMediaEngine:create_resource_from_resource_dir: duration for "
                         + normal_content_filename + " is " + res.duration.to_string() );
            } else {
                message( "OdidMediaEngine:create_resource_from_resource_dir: No index file found for "
                         + res_dir_uri + normal_content_filename );
            }
        }

        // Look for scaled files and set fields accordingly if/when found
        {
            Gee.List<DLNAPlaySpeed> playspeeds;
            
            playspeeds = find_playspeeds_for_res(res_dir_uri, basename);

            if (playspeeds != null) {
                var speed_array = new string[playspeeds.size];
                int speed_index = 0;
                foreach (var speed in playspeeds) {
                    speed_array[speed_index++] = speed.to_string();
                }
                res.protocol_info.play_speeds = speed_array;
                message( "OdidMediaEngine:create_resource_from_resource_dir: Found %d speeds for "
                         + res_dir_uri + normal_content_filename, speed_index);
            }
        }
        return res;
    }

    /**
     * Set a MediaResource field from a resource.info name-value pair
     *
     * @param res MediaResource to modify
     * @param name The field name
     * @param value The field value
     */
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
        message ("ODIDMediaEngine.content_filename_for_res_speed: %s, %s, %s",
                 resource_dir_path,basename,playspeed.to_string() );
        string rate_string;
        if (playspeed == null) {
            rate_string = "1_1";
        } else {
            rate_string = playspeed.numerator.to_string() + "_" + playspeed.denominator.to_string();
        }

        string content_filename = null;
        extension = null;

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
                message ("ODIDMediaEngine.content_filename_for_res_speed: FOUND MATCH: %s (extension %s)",
                         content_filename, extension);
            }
        }

        return content_filename;
    }

    /**
     * Produce a list of DLNAPlaySpeed corresponding to scaled content files for the given
     * resource directory and basename.
     *
     * @return A List with one DLNAPlaySpeed per scaled-rate content file
     */
    internal static Gee.List<DLNAPlaySpeed>? find_playspeeds_for_res( string resource_dir_uri,
                                                                      string basename )
        throws Error {
        message ("ODIDMediaEngine.find_playspeeds_for_res: %s, %s",
                 resource_dir_uri,basename );
        var speeds = new Gee.ArrayList<DLNAPlaySpeed>();
        
        var directory = File.new_for_uri(resource_dir_uri);
        var enumerator = directory.enumerate_children(GLib.FileAttribute.STANDARD_NAME, 0);

        FileInfo file_info;
        while ((file_info = enumerator.next_file ()) != null) {
            var cur_filename = file_info.get_name();
            // Only look for content files (<basename>.<rate>.<extension>)
            var split_name = cur_filename.split(".");
            if ((split_name.length == 3) && (split_name[0] == basename)) {
                var speed_parts = split_name[1].split("_");
                if (speed_parts.length != 2) {
                    warning ("ODIDMediaEngine.find_playspeeds_for_res: Bad speed found in res filename %s (%s)",
                             cur_filename, split_name[1] );
                    return null;
                }
                var speed = new DLNAPlaySpeed(int.parse(speed_parts[0]),int.parse(speed_parts[1]));
                if (speed.numerator == 1 && speed.denominator == 1) {
                    continue; // Rate "1" is implied and not included in the playspeeds - skip it
                }
                speeds.add(speed);
            }
        }
        return (speeds.size > 0) ? speeds : null;
    }

    internal static long duration_from_index_file(File index_file)
            throws Error {
        message ("ODIDDataSource.duration_for_content_file: %s",
                 index_file.get_basename() );
        
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
        return this.transcoders;
    }

    public override DataSource? create_data_source_for_resource
                                (string uri, MediaResource ? resource) {
        message("create_data_source_for_resource: source uri: " + uri);

        if (!uri.has_prefix ("file://")) {
            return null;
        }

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

     /**
     * Returns if the media engine is capable of handling dtcp request
     */
    public override bool has_mediaengine_dtcp () {
        return dtcp_supported;
    }

     /**
     * Returns if dtcp libraries are initialized successfully
     */
    public static bool is_dtcp_loaded () {
        return dtcp_loaded;
    }

}

public static Rygel.MediaEngine module_get_instance() {
        message("module_get_instance");
        return new Rygel.ODIDMediaEngine();
}


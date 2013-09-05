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

            message( "OdidMediaEngine: configuring profile entry: " + row);
            config_entries.append(new ConfigProfileEntry(profile, mimetype, extension));
            // Note: This profile list won't affect what profiles are included in the 
            //       primary res block
            profiles.append(new DLNAProfile(profile,mimetype));
            // The transcoders will become secondary res blocks
//            this.transcoders.prepend(
//                    new ODIDFakeTranscoder(mimetype,profile,extension) );
        }
    }
	
    public override unowned GLib.List<DLNAProfile> get_renderable_dlna_profiles() {
        message("get_renderable_dlna_profiles");
        return this.profiles;
    }

    public override Gee.List<MediaResource>? get_resources_for_uri(string uri) {
        var resources = new Gee.ArrayList<MediaResource>();
		
		try {
			KeyFile keyFile = new KeyFile();
			keyFile.load_from_file(File.new_for_uri (uri).get_path (),
								   KeyFileFlags.KEEP_COMMENTS |
								   KeyFileFlags.KEEP_TRANSLATIONS);
		
			string[] resourceGroups = keyFile.get_string_list ("item", "resources");

			foreach (string name in resourceGroups) {
				if (keyFile.has_group (name)) {
					debug ("Creating MediaResource %s", name);

					var protocol_info = new GUPnP.ProtocolInfo();

					protocol_info.dlna_profile   = keyFile.get_string (name, "profile");
					protocol_info.protocol       = keyFile.get_string (name, "protocol");
					protocol_info.mime_type      = keyFile.get_string (name, "mime-type");
					protocol_info.dlna_operation = DLNAOperation.RANGE;
					protocol_info.dlna_flags = DLNAFlags.DLNA_V15 
					                   | DLNAFlags.STREAMING_TRANSFER_MODE 
                                       | DLNAFlags.BACKGROUND_TRANSFER_MODE 
                                       | DLNAFlags.CONNECTION_STALL;

					var res = new MediaResource(name);
					res.protocol_info   = protocol_info;
					res.duration        = keyFile.get_integer (name, "duration");
					res.size            = keyFile.get_int64   (name, "size");
					res.extension       = keyFile.get_string  (name, "extension");
					res.uri             = keyFile.get_string  (name, "uri");
					res.color_depth     = keyFile.get_integer (name, "video-color-depth");
					res.bitrate         = keyFile.get_integer (name, "bitrate");
					res.bits_per_sample = keyFile.get_integer (name, "bits-per-sample");
					res.width           = keyFile.get_integer (name, "width");
                    res.height          = keyFile.get_integer (name, "height");
                    res.audio_channels  = keyFile.get_integer (name, "audio-channels");
					res.sample_freq     = keyFile.get_integer (name, "audio-sample-frequency");
                    res.cleartext_size  = 12345; // Secret media engine sauce.

					resources.add(res);
				}
			}
		} catch (Error error) {
			warning ("Unable to read item file %s, Message: %s", uri, error.message);
		}

        return resources;
    }

    public override unowned GLib.List<Transcoder>? get_transcoders() {
        return this.transcoders;
    }

    public override DataSource? create_data_source_for_resource
                                (string uri, MediaResource ? resource) {
        if (!uri.has_prefix ("file://")) {
            return null;
        }

        message("creating data source for " + uri);

        return new ODIDDataSource(uri);
    }
}

public static Rygel.MediaEngine module_get_instance() {
        message("module_get_instance");
        return new Rygel.ODIDMediaEngine();
}


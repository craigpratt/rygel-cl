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
            this.transcoders.prepend(
                    new ODIDFakeTranscoder(mimetype,profile,extension) );
        }
    }
	
    public override unowned GLib.List<DLNAProfile> get_renderable_dlna_profiles() {
        message("get_renderable_dlna_profiles");
        return this.profiles;
    }

    public override Gee.List<MediaResource>? get_resources_for_uri(string uri) {
        message("get_resources_for_uri");
        var resources = new Gee.ArrayList<MediaResource>();

        // Note: Here's where we can get the metadata from the ODID info files.
        // For now, we'll just hobble something together from the config file
        foreach (var config in config_entries) {
            message("get_resources_for_uri: processing profile " + config.profile);
            string resource_name;
            // TODO : Must read the protected flag from config file for a resource 
            // along with the flag that states if dtcp is enabled in Rygel/MediaEngine
            bool item_protected = RygelHTTPRequestUtil.is_rygel_dtcp_enabled() &&
                                  has_mediaengine_dtcp ();

            if (item_protected) {
				resource_name = "DTCP_" + config.profile;
			} else {
				resource_name = config.profile;
			}
            var res = new MediaResource(resource_name);

            res.duration = 10;
            res.size = 12345678;
            res.extension = config.extension;

            var protocol_info = new GUPnP.ProtocolInfo();     
            protocol_info.dlna_flags = DLNAFlags.DLNA_V15 |
                                       DLNAFlags.STREAMING_TRANSFER_MODE |
                                       DLNAFlags.BACKGROUND_TRANSFER_MODE |
                                       DLNAFlags.CONNECTION_STALL;

			if (item_protected) {
				protocol_info.mime_type = RygelHTTPRequestUtil.handle_mime_item_protected
													(config.mimetype);
				debug ("The new mime type is: "+protocol_info.mime_type);
				protocol_info.dlna_profile = RygelHTTPRequestUtil.dtcp_prefix + config.profile;
				debug ("The new dlna profile is: "+protocol_info.dlna_profile);
				res.cleartext_size = 12345678;
				protocol_info.dlna_operation = DLNAOperation.RANGE;
				protocol_info.dlna_flags |= DLNAFlags.LINK_PROTECTED_CONTENT |
				                            DLNAFlags.CLEARTEXT_BYTESEEK_FULL;
			} else {

				protocol_info.dlna_profile = config.profile;
				protocol_info.mime_type = config.mimetype;
				protocol_info.dlna_operation = DLNAOperation.RANGE;
			}

            protocol_info.dlna_conversion = DLNAConversion.NONE;
            res.protocol_info = protocol_info;

            resources.add(res);
        }

        return resources;
    }

    public override unowned GLib.List<Transcoder>? get_transcoders() {
        message("get_transcoders");
        return this.transcoders;
    }

     /**
     * Returns if the media engine is capable of handling dtcp request
     */
    public override bool has_mediaengine_dtcp () {
        var config = MetaConfig.get_default();
        bool dtcp_supported = false;
        try {
            dtcp_supported = config.get_bool ("OdidMediaEngine","engine-dtcp");
        } catch (Error err) {
            error("Error reading dtcp property for media engine :" + err.message);
        }

        return dtcp_supported;
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


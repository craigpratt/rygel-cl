/*
 * Copyright (C) 2013 CableLabs
 */

/*
 * Based on Rygel SimpleMediaEngine
 * Copyright (C) 2012 Intel Corporation.
 */

using Gee;

/**
 * This media engine is intended to be the basis for the CL 
 * reference DMS.
 */
internal class Rygel.CableLabsDLNAMediaEngine : MediaEngine {
    private  GLib.List<DLNAProfile> profiles 
        = new  GLib.List<DLNAProfile>();
        
    private GLib.List<Transcoder> transcoders = null;

    public CableLabsDLNAMediaEngine() {
        message("constructing");

        var profiles_config = new Gee.ArrayList<string>();
        
        var config = MetaConfig.get_default();
        try {
            profiles_config = config.get_string_list( "CL-DLNAMediaEngine", "profiles");
        } catch (Error err) {
            error("Error reading CL-DLNAMediaEngine profiles: " + err.message);
        }

        foreach (var row in profiles_config) {
            var columns = row.split(",");
            if (columns.length < 3)
            {
                message( "CL-DLNAMediaEngine profile entry \""
                         + row + "\" is malformed: Expected 3 entries and found "
                         + columns.length.to_string() );
                break;
            }
            string profile = columns[0];
            string mimetype = columns[1];
            string extension = columns[2];

            message( "CL-DLNAMediaEngine: configuring profile entry: " + row);
            // Note: This profile list won't affect what profiles are included in the 
            //       primary res block
            profiles.append(new DLNAProfile(profile,mimetype));
            // The transcoders will become secondary res blocks
            this.transcoders.prepend(
                    new FakeTranscoder(mimetype,profile,extension) );
        }
    }
	
    public override unowned GLib.List<DLNAProfile> get_dlna_profiles() {
        message("get_dlna_profiles");
        return this.profiles;
    }

    public override unowned GLib.List<Transcoder>? get_transcoders() {
        message("get_transcoders");
        return this.transcoders;
    }

    public override DataSource? create_data_source(string uri) {
        if (!uri.has_prefix ("file://")) {
            return null;
        }

        message("creating data source for " + uri);
        return new CableLabsDLNADataSource(uri);
    }
} // END CableLabsDLNAMediaEngine

public static Rygel.MediaEngine module_get_instance() {
        message("module_get_instance");
        return new Rygel.CableLabsDLNAMediaEngine();
}

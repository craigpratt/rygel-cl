/*
 * Copyright (C) 2013 CableLabs
 */

/*
 * Based on Rygel SimpleMediaEngine
 * Copyright (C) 2012 Intel Corporation.
 */

/**
 * This media engine is intended to be the basis for the CL 
 * reference DMS.
 */
internal class Rygel.CableLabsDLNAMediaEngine : MediaEngine {
    // For now, this engine will assume all content is AVC_MP4_MP_SD
    private List<DLNAProfile> profiles 
        = new List<DLNAProfile>();
    private GLib.List<Transcoder> transcoders = null;

    public CableLabsDLNAMediaEngine() {
        message("constructing");
        profiles.append(new DLNAProfile("AVC_MP4_MP_SD","video/mp4"));
        // Note: This won't affect what profiles are included in the 
        //       primary res block
        this.transcoders.prepend(
                new FakeTranscoder("video/mp4","AVC_MP4_MP_SD","mp4") );
    }
	
    public override unowned List<DLNAProfile> get_dlna_profiles() {
        message("get_dlna_profiles");
        return this.profiles;
    }

    public override unowned List<Transcoder>? get_transcoders() {
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

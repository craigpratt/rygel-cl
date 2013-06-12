/*
 * Copyright (C) 2013 CableLabs
 */

/**
 * This media engine is intended to be the basis for the CL 
 * reference DMS.
 */
internal class Rygel.CableLabsDLNAMediaEngine : MediaEngine {
    private List<DLNAProfile> profiles = new List<DLNAProfile> ();

    public CableLabsDLNAMediaEngine () { }

    public override unowned List<DLNAProfile> get_dlna_profiles () {
        return this.profiles;
    }

    public override unowned List<Transcoder>? get_transcoders () {
        return null;
    }

    public override DataSource? create_data_source (string uri) {
        if (!uri.has_prefix ("file://")) {
            return null;
        }

        return new CableLabsDLNADataSource (uri);
    }
}

public static Rygel.MediaEngine module_get_instance () {
    return new Rygel.CableLabsDLNAMediaEngine ();
}

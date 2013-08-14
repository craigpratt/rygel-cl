/*
 * Copyright (C) 2013 CableLabs.
 */

using GUPnP;

public class Rygel.CableLabsDLNAMediaRendering : Rygel.MediaRendering {
    string uri;
    public CableLabsDLNAMediaRendering (string name, string uri, MediaResource resource) {
        base(name, uri, resource);
        this.uri = uri;
    }

    public override DataSource? create_data_source () {
        return new Rygel.CableLabsDLNADataSource(this.uri);
    }
        
}

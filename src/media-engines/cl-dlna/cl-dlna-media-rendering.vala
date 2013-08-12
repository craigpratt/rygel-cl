/*
 * Copyright (C) 2013 CableLabs.
 */

using GUPnP;

public class Rygel.CableLabsDLNAMediaRendering : Rygel.MediaRendering {
    string uri;
    public CableLabsDLNAMediaRendering (string name, MediaItem item, MediaResource resource) {
        base(name, item, resource);
        uri = item.uris.get(0);
    }

    public override DataSource? create_data_source () {
        return new Rygel.CableLabsDLNADataSource(this.uri);
    }
        
}

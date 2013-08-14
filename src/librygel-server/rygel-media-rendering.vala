/*
 * Copyright (C) 2013 CableLabs.
 */

using GUPnP;

/**
 * The base MediaRendering class.
 *
 * This class and subclasses encapsulate both the metadata and streaming
 * requirements associated with rendering of a particular content source. 
 * 
 * MediaRenderings are obtained from rygel_media_engine_get_renderings_for_uri()
 * and are only expected to support the source content types provided
 * by rygel_media_engine_get_renderable_dlna_profiles().
 *
 */
public abstract class Rygel.MediaRendering : GLib.Object {
    private string name;
    private string uri;
    private MediaResource resource;

     public MediaRendering (string name, string uri, MediaResource resource) {
        this.name = name;
        this.uri = uri;
        this.resource = resource;
    }

    public string get_name() {
        return this.name;
    }

    public string get_uri() {
         return this.uri;
    }

    public MediaResource get_resource() {
         return this.resource;
    }

    /**
     * Get a data source for rendering.
     *
     * Subclasses should return a #DataSource that will produce a data stream
     * for the associated MediaItem/MediaResource that conforms to the
     * profile/parameters associated with this MediaRendering.
     *
     * @return A data source for rendering the associated MediaItem's MediaResource
     */
    public abstract DataSource? create_data_source ();
}

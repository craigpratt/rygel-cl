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
 * MediaRenderings are obtained from rygel_media_engine_get_renderings_for_item()
 * and are only expected to support the source content types provided
 * by rygel_media_engine_get_renderable_dlna_profiles().
 *
 */
public abstract class Rygel.MediaRendering : GLib.Object {
    public string id {
         get {
             return this.id;
         }
         private set {
              this.id = value;
         }
    }
    public MediaItem item {
         get {
             return this.item;
         }
         private set {
              this.item = value;
         }
    }
    
    public MediaResource resource {
         get {
             return this.resource;
         }
         private set {
              this.resource = value;
         }
    }

     public MediaRendering (string id, MediaItem item, MediaResource resource) {
        this.id = id;
        this.item = item;
        this.resource = resource;
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

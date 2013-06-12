/*
 * Copyright (C) 2013 CableLabs
 */

using GUPnP;

/**
 * This class exists just to allow the creation of res blocks with
 * arbitrary profiles/protocolinfo.
 */
internal class Rygel.FakeTranscoder : Rygel.Transcoder
{
    public FakeTranscoder( string mime_type,
                            string dlna_profile,
                            string extension ) 
    {
        message("Creating FakeTranscoder(mime_type " + mime_type 
                + ",dlna_profile " + dlna_profile 
                + ",extension " + extension );
        GLib.Object (mime_type : mime_type,
                     dlna_profile : dlna_profile,
                     extension : extension);
    }
    
    public override void constructed () {
        base.constructed ();
    }

    /**
     * Gets a numeric value that gives an gives an estimate of how hard
     * it would be for this transcoder to trancode @item to the target profile of this transcoder.
     *
     * @param item the media item to calculate the distance for
     *
     * @return      the distance from the @item, uint.MIN if providing such a
     *              value is impossible or uint.MAX if it doesn't make any
     *              sense to use this transcoder for @item
     */
    public override uint get_distance (MediaItem item) {
        return 0;
    }
    
    /**
     * Derived classes should implement this function to fill a GUPnPDIDLLiteResource,
     * representing the transcoded content, with parameters specific to the transcoder,
     * such as bitrate or resolution. The GUPnPDIDLLiteResource should be instantiated
     * by calling this base class implementation, passing the provided didl_item, item
     * and manager parameters.
     *
     * @param didl_item The DIDLLite item for which to create the resource, by calling the base class implementation.
     * @param item The media item for which to create the DIDLiteResource, by calling the base class implementation.
     * @param manager The transcoder manager to pass to the base class implemenetation.
     * @return The new resource.
     */
    public override DIDLLiteResource? add_resource (DIDLLiteItem     didl_item,
                                                    MediaItem        item,
                                                    TranscodeManager manager)
                                                    throws Error {
        var resource = base.add_resource (didl_item, item, manager);

        return resource;
    }
    
    /**
     * Creates a transcoding source.
     *
     * @param src the media item to create the transcoding source for
     * @param src the original (non-transcoding) source
     *
     * @return      the new transcoding source
     */
    public override DataSource create_source (MediaItem  item,
                                              DataSource src) throws Error {
        message("creating fake transcode data source");
        return src;
    }
}



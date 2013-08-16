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
        operation = DLNAOperation.RANGE;
        flags = DLNAFlags.DLNA_V15 |
                DLNAFlags.STREAMING_TRANSFER_MODE |
                DLNAFlags.BACKGROUND_TRANSFER_MODE |
                DLNAFlags.CONNECTION_STALL;
    }
    
    public override void constructed () {
        base.constructed ();
    }

    /**
     * (copy of the super's docs)
     * 
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
     * (copy of the super's docs)
     * 
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
    public override DIDLLiteResource? add_resource( DIDLLiteItem     didl_item,
                                                    MediaItem        item,
                                                    TranscodeManager manager)
            throws Error {
        message("add_resource");
        DIDLLiteResource resource = base.add_resource (didl_item, item, manager);

        // Here's our opportunity to tweak the resource
        
        // We want to be able to set these in a content-specific fashion,
        // for various test scenarios. But this is probably a temporary solution anyway...
        
        // base.add_resource() will set the MIME type and DLNA profile
        //  according to what's passed in the base constructor
        /** TODO : Need to delegate to helper class to get accurate
        * value of cleartextsize if the item is protected.
        */
        resource.size64 = item.size;
        var protocol_info = resource.protocol_info;

        if (has_dtcp_enabled() && has_mediaengine_dtcp ()
                           && is_item_protected (item)) {

            protocol_info.mime_type = handle_mime_item_protected
                                                (this.mime_type);
            debug ("The new mime type is: "+protocol_info.mime_type);
            protocol_info.dlna_profile = dtcp_prefix + this.dlna_profile;
            debug ("The new dlna profile is: "+protocol_info.dlna_profile);

            resource.cleartextSize = item.size;
        } else {
                protocol_info.mime_type = this.mime_type;
                protocol_info.dlna_profile = this.dlna_profile;
        }

        //message("protocol_info:" + protocol_info.to_string());
        protocol_info.dlna_conversion = DLNAConversion.NONE;
        protocol_info.dlna_flags = this.flags;
        protocol_info.dlna_operation = this.operation;
        
        return resource;
    }

    /**
     * Check if the MediaItem is protected.
     * TODO: This can call into a helper class that will have knowledge.
     */
    public override bool is_item_protected (MediaItem item) {
        return true;
    }

    /**
     * Returns if the media engine is capable of handling dtcp request
     */
    public override bool has_mediaengine_dtcp () {
        var config = MetaConfig.get_default();
        bool dtcp_supported = false;
        try {
            dtcp_supported = config.get_bool ("CL-DLNAMediaEngine","engine-dtcp");
        } catch (Error err) {
            error("Error reading dtcp property for media engine :" + err.message);
        }

        return dtcp_supported;
    }
    
    /**
     * (copy of the super's docs)
     * 
     * Creates a transcoding source.
     *
     * @param src the media item to create the transcoding source for
     * @param src the original (non-transcoding) source
     *
     * @return      the new transcoding source
     */
    public override DataSource create_source( MediaItem  item,
                                              DataSource src)
            throws Error {
        message("creating fake transcode data source");
        // Just return the primary res data source
        return src;
    }
}



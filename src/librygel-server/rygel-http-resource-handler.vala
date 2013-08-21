/*
 * Copyright (C) 2013 CableLabs
 */

using GUPnP;

/**
 * The HTTP handler for HTTP ContentResource requests.
 */
internal class Rygel.HTTPMediaResourceHandler : HTTPGetHandler {
    private MediaItem media_item;
    private string media_resource_name;
    private MediaResource media_resource;

    public HTTPMediaResourceHandler (MediaItem media_item,
                                     string media_resource_name,
                                     Cancellable? cancellable) {
        this.media_item = media_item;
        this.cancellable = cancellable;
        this.media_resource_name = media_resource_name;

        media_resource = MediaResourceManager.get_default()
                                  .get_resource_for_uri_and_name (media_item.uris.get (0),
                                                                  media_resource_name);
    }

    public override void add_response_headers (HTTPGet request)
                                               throws HTTPRequestError {
        request.msg.response_headers.append ("Content-Type",
                                             this.media_resource.protocol_info.mime_type);
        if (request.seek != null) {
            request.seek.add_response_headers ();
        }

        // Chain-up
        base.add_response_headers (request);
    }

    public override HTTPResponse render_body (HTTPGet request)
                                              throws HTTPRequestError {
        try {
            DataSource src;

            src = (request.object as MediaItem).create_stream_source
                                        (request.http_server.context.host_ip);

            if (src == null) {
                throw new HTTPRequestError.NOT_FOUND (_("Not found"));
            }

            return new HTTPResponse (request, this, src);
        } catch (Error err) {
            throw new HTTPRequestError.NOT_FOUND (err.message);
        }
    }

    protected override DIDLLiteResource add_resource
                                        (DIDLLiteObject didl_object,
                                         HTTPGet      request)
                                        throws Error {

        DIDLLiteItem didl_item = didl_object as DIDLLiteItem;

        DIDLLiteResource didl_resource = didl_item.add_resource();
        media_resource.write_didl_lite(didl_resource);
        return didl_resource;
    }
}

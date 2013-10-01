/* 
 * Copyright (C) 2013  Cable Television Laboratories, Inc.
 * Contact: http://www.cablelabs.com/
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
 * IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL APPLE INC. OR ITS CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 *
 * Author: Craig Pratt <craig@ecaspia.com>
 *
 * This file is part of Rygel.
 */

using GUPnP;

/**
 * The HTTP handler for HTTP ContentResource requests.
 */
internal class Rygel.HTTPMediaResourceHandler : HTTPGetHandler {
    private MediaItem media_item;
    private string media_resource_name;
    public MediaResource media_resource;

    public HTTPMediaResourceHandler (MediaItem media_item,
                                     string media_resource_name,
                                     Cancellable? cancellable) {
        this.media_item = media_item;
        this.cancellable = cancellable;
        this.media_resource_name = media_resource_name;

        media_resource = MediaResourceManager.get_default()
                                  .get_resource_for_source_uri_and_name (media_item.uris.get (0),
                                                                         media_resource_name);
    }

    public override void add_response_headers (HTTPGet request)
                                               throws HTTPRequestError {
        request.msg.response_headers.append ("Content-Type",
                                             this.media_resource.protocol_info.mime_type);
        // Chain-up
        base.add_response_headers (request);
    }

    public override HTTPResponse render_body (HTTPGet request)
                                              throws HTTPRequestError {
        try {
            DataSource src;

            src = (request.object as MediaItem).create_stream_source_for_resource
                                        (request.http_server.context.host_ip,
                                        this.media_resource);

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

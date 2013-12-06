/* 
 * Copyright (C) 2013  Cable Television Laboratories, Inc.
 *
 * Author: Craig Pratt <craig@ecaspia.com>
 *
 * This file is part of Rygel.
 *
 * Rygel is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
 * IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL CABLE TELEVISION LABORATORIES
 * INC. OR ITS CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 * TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

using GUPnP;

/**
 * The HTTP handler for HTTP ContentResource requests.
 */
internal class Rygel.HTTPMediaResourceHandler : HTTPGetHandler {
    private MediaObject media_object;
    private string media_resource_name;
    public MediaResource media_resource;

    public HTTPMediaResourceHandler (MediaObject media_object,
                                     string media_resource_name,
                                     Cancellable? cancellable) throws HTTPRequestError
    {
        this.media_object = media_object;
        this.cancellable = cancellable;
        this.media_resource_name = media_resource_name;
        foreach (var resource in media_object.get_resource_list ()) {
            if (resource.get_name () == media_resource_name) {
                this.media_resource
                    = new MediaResource.from_resource (resource.get_name (),
                                                       resource);
            }
        }
        if (this.media_resource == null) {
            throw new HTTPRequestError.NOT_FOUND ("MediaResource %s not found",
                                                  media_resource_name);
        }
    }

    public override void add_response_headers (HTTPGet request)
                                               throws HTTPRequestError {
        request.http_server.set_resource_delivery_options (media_resource);

        request.msg.response_headers.append ("Content-Type",
                                             this.media_resource.mime_type);
        // Determine cache control
        if (media_resource.is_link_protection_enabled ()) {
            if (request.msg.get_http_version () == Soup.HTTPVersion.@1_1) {
                request.msg.response_headers.append ("Cache-control","no-cache");
            }
            request.msg.response_headers.append ("Pragma","no-cache");
        }

        // Add contentFeatures.dlna.org
        var protocol_info = media_resource.get_protocol_info ();
        if (protocol_info != null) {
            var pi_fields = protocol_info.to_string ().split (":", 4);
            if (pi_fields[3] != null) {
                request.msg.response_headers.append ("contentFeatures.dlna.org",
                                                     pi_fields[3]);
            }
        }

        // Chain-up
        base.add_response_headers (request);
    }
    
    public override string get_default_transfer_mode () {
        // Per DLNA 7.5.4.3.2.33.2, the assumed transfer mode is based on the content type
        // "Streaming" for AV content and "Interactive" for all others
        return media_resource.get_default_transfer_mode ();
    }

    public override bool supports_transfer_mode (string mode) {
        return media_resource.supports_transfer_mode (mode);
    }

    public override HTTPResponse render_body (HTTPGet request)
                                              throws HTTPRequestError {
        try {
            var src = request.object.create_stream_source_for_resource
                                    (request, this.media_resource);
            if (src == null) {
                throw new HTTPRequestError.NOT_FOUND
                              (_("Couldn't create data source for %s"),
                               this.media_resource.get_name ());
            }
            return new HTTPResponse (request, this, src);
        } catch (Error err) {
            throw new HTTPRequestError.NOT_FOUND (err.message);
        }
    }

    public override int64 get_resource_size () {
        return media_resource.size;
    }

    public override int64 get_resource_duration () {
        return media_resource.duration * TimeSpan.SECOND;
    }

    public override bool supports_byte_seek () {
        return media_resource.supports_arbitrary_byte_seek ();
    }

    public override bool supports_time_seek () {
        return media_resource.supports_arbitrary_time_seek ();
    }
}

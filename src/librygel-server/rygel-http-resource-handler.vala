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
 */

using GUPnP;

/**
 * The HTTP handler for HTTP ContentResource requests.
 */
internal class Rygel.HTTPMediaResourceHandler : HTTPGetHandler {

	private static int STREAMING_TRANSFER_MODE_DSCP = 0x28;
	private static int INTERACTIVE_TRANSFER_MODE_DSCP = 0x0;
	private static int BACKGROUND_TRANSFER_MODE_DSCP = 0x8;

	private static int SOL_IP = 0;
	private static int IP_TOS = 1;
	private static int SOL_SOCKET = 1;
	private static int SO_PRIORITY = 12;

    private MediaObject media_object;
    private string media_resource_name;
    public MediaResource media_resource;

    public HTTPMediaResourceHandler (MediaObject media_object,
                                     string media_resource_name,
                                     Cancellable? cancellable)
                                     throws HTTPRequestError {
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
        request.http_server.set_resource_delivery_options (this.media_resource);
        var replacements = request.http_server.get_replacements ();
        var mime_type = MediaObject.apply_replacements
                                     (replacements,
                                      this.media_resource.mime_type);
        request.msg.response_headers.append ("Content-Type", mime_type);

        // Determine cache control
        if (media_resource.is_link_protection_enabled ()) {
            if (request.msg.get_http_version () == Soup.HTTPVersion.@1_1) {
                request.msg.response_headers.append ("Cache-control","no-cache");
            }
            request.msg.response_headers.replace ("Pragma","no-cache");
        }

        // Add contentFeatures.dlna.org
        var protocol_info = media_resource.get_protocol_info (replacements);
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
			// set QoS based on transfer mode header
            string transfer_mode_header = request.msg.response_headers.get_one (TRANSFER_MODE_HEADER);

            // default to 0
            int mode_value = 0x0;

            if (transfer_mode_header == TRANSFER_MODE_STREAMING) {
                mode_value = STREAMING_TRANSFER_MODE_DSCP;
            }

            if (transfer_mode_header == TRANSFER_MODE_INTERACTIVE) {
                mode_value = INTERACTIVE_TRANSFER_MODE_DSCP;
            }

            if (transfer_mode_header == TRANSFER_MODE_BACKGROUND) {
                mode_value = BACKGROUND_TRANSFER_MODE_DSCP;
            }

            int tos_value = (mode_value << 2);
            int priority_value = (mode_value >> 3);

            int file_descriptor = request.client_context.get_socket ().get_fd ();
            Posix.socklen_t sockopt_length = (int)sizeof (Posix.socklen_t);

            Posix.setsockopt(file_descriptor, SOL_IP, IP_TOS, &tos_value, sockopt_length);
            Posix.setsockopt(file_descriptor, SOL_SOCKET, SO_PRIORITY, &priority_value, sockopt_length);

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
        return media_resource.supports_arbitrary_byte_seek ()
               || media_resource.supports_limited_byte_seek ();
    }

    public override bool supports_time_seek () {
        return media_resource.supports_arbitrary_time_seek ()
               || media_resource.supports_limited_time_seek ();
    }

    public override bool supports_playspeed () {
        return media_resource.supports_playspeed ();
    }
}

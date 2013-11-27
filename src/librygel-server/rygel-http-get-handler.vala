/*
 * Copyright (C) 2008-2010 Nokia Corporation.
 * Copyright (C) 2010 Andreas Henriksson <andreas@fatal.se>
 *
 * Author: Zeeshan Ali (Khattak) <zeeshanak@gnome.org>
 *                               <zeeshan.ali@nokia.com>
 *
 * This file is part of Rygel.
 *
 * Rygel is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * Rygel is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 */

/*
 * Modifications made by Cable Television Laboratories, Inc.
 * Copyright (C) 2013  Cable Television Laboratories, Inc.
 * Contact: http://www.cablelabs.com/
 *
 * Author: Craig Pratt <craig@ecaspia.com>
 */

using GUPnP;

/**
 * HTTP GET request handler interface.
 */
public abstract class Rygel.HTTPGetHandler: GLib.Object {
    private const string TRANSFER_MODE_HEADER = "transferMode.dlna.org";

    protected const string TRANSFER_MODE_STREAMING = "Streaming";
    protected const string TRANSFER_MODE_INTERACTIVE = "Interactive";
    protected const string TRANSFER_MODE_BACKGROUND = "Background";
    
    public Cancellable cancellable { get; set; }

    // Add response headers.
    public virtual void add_response_headers (HTTPGet request)
                                              throws HTTPRequestError {
        var mode = request.msg.request_headers.get_one (TRANSFER_MODE_HEADER);

        // Per DLNA 7.5.4.3.2.33.2, if the transferMode header is empty it
        // must be treated as Streaming mode or Interactive, depending upon the content
        if (mode == null) {
            request.msg.response_headers.append (TRANSFER_MODE_HEADER,
                                                 get_default_transfer_mode ());
        } else {
            request.msg.response_headers.append (TRANSFER_MODE_HEADER, mode);
        }

        // Handle Samsung DLNA TV proprietary subtitle headers
        if (request.msg.request_headers.get_one ("getCaptionInfo.sec") != null
            && (request.object as VideoItem).subtitles.size > 0) {
                var caption_uri = request.http_server.create_uri_for_item
                                        (request.object,
                                         (request.object as VideoItem).get_extension(),
                                         -1,
                                         0, // FIXME: offer first subtitle only?
                                         null);

                request.msg.response_headers.append ("CaptionInfo.sec",
                                                     caption_uri);
        }
    }

    public virtual string get_default_transfer_mode () {
        return TRANSFER_MODE_INTERACTIVE; // Considering this the default
    }

    public abstract bool supports_transfer_mode (string mode);

    public abstract int64 get_resource_size ();

    public virtual int64 get_resource_duration () {
        return -1;
    }

    public virtual bool supports_byte_seek () {
        return false;
    }

    public virtual bool supports_time_seek () {
        return false;
    }

    // Create an HTTPResponse object that will render the body.
    public abstract HTTPResponse render_body (HTTPGet request)
                                              throws HTTPRequestError;
}

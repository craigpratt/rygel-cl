/*
 * Copyright (C) 2009 Nokia Corporation.
 * Copyright (C) 2012 Intel Corporation.
 * Copyright (C) 2013 Cable Television Laboratories, Inc.
 *
 * Author: Zeeshan Ali (Khattak) <zeeshanak@gnome.org>
 *                               <zeeshan.ali@nokia.com>
 *         Jens Georg <jensg@openismus.com>
 *         Craig Pratt <craig@ecaspia.com>
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

using GUPnP;

public class Rygel.HTTPByteSeekRequest : Rygel.HTTPSeekRequest {
    /**
     * The start of the range in bytes 
     */
    public int64 start_byte { get; set; }

    /**
     * The end of the range in bytes (inclusive)
     */
    public int64 end_byte { get; set; }

    /**
     * The length of the range in bytes
     */
    public int64 range_length { get; private set; }

    /**
     * The length of the resource in bytes
     */
    public int64 total_size { get; set; }

    
    public HTTPByteSeekRequest (HTTPGet request) throws HTTPSeekRequestError,
                                                 HTTPRequestError {
        base ();
        Soup.Range[] ranges;
        int64 start, stop;
        unowned string range = request.msg.request_headers.get_one ("Range");
        string range_header_str = null;

        int64 total_size = request.handler.get_resource_size ();
        // TODO: Deal with resources that support Range but don't have fixed/known sizes

        // Check if Range is present in the header
        if (range == null) {
            start = 0;
            stop = total_size -1;
        } else {
            range_header_str = range;
            if (request.msg.request_headers.get_ranges (total_size,
                                                        out ranges)) {
                // TODO: Somehow deal with multipart/byterange properly
                //       (not legal in DLNA per 7.5.4.3.2.22.3)
                start = ranges[0].start;
                stop = ranges[0].end;
                // TODO: For live/in-progress sources, we need to differentiate between "x-" and
                //       "x-y" (and cases where y>total_size) (see DLNA 7.5.4.3.2.19.2)
                //       We can't tell the difference with get_ranges()...
            } else {
                throw new HTTPSeekRequestError.INVALID_RANGE (_("Invalid Range '%s'"),
                                                              range_header_str);
            }
        }

        if (start > total_size-1) {
            throw new HTTPSeekRequestError.OUT_OF_RANGE (_("Invalid Range '%s'"),
                                                         range_header_str);
        }
        
        if (stop < start) {
            throw new HTTPSeekRequestError.INVALID_RANGE (_("Invalid Range '%s'"),
                                                          range_header_str);
        }

        if ((total_size > 0) && (stop > total_size-1)) {
            // Per RFC 2616, the range end can be beyond the total length. And Soup doesn't clamp...
            stop = total_size-1;
        }
            
        this.start_byte = start;
        this.end_byte = stop;
        this.range_length = stop-start+1; // +1, since range is inclusive
        this.total_size = total_size;
    }

    public static bool supported (HTTPGet request) {
        bool force_seek = false;

        try {
            var hack = ClientHacks.create (request.msg);
            force_seek = hack.force_seek ();
        } catch (Error error) { }

        return force_seek || request.handler.supports_byte_seek();
    }

    public static bool requested (HTTPGet request) {
        return (request.msg.request_headers.get_one ("Range") != null);
    }
}

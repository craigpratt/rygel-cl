/*
 * Copyright (C) 2009 Nokia Corporation.
 * Copyright (C) 2012 Intel Corporation.
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

public class Rygel.HTTPByteSeek : Rygel.HTTPSeek {
    private static bool content_protected = false;
    public HTTPByteSeek (HTTPGet request) throws HTTPSeekError,
                                                 HTTPRequestError {
        Soup.Range[] ranges;
        int64 start = 0, total_size;
        string[] parsed_headers;
        unowned string range = request.msg.request_headers.get_one ("Range");
        unowned string range_dtcp = request.msg.request_headers.get_one ("Range.dtcp.com");
        string range_header_str = null;

        if (request.thumbnail != null) {
            total_size = request.thumbnail.size;
        } else if (request.subtitle != null) {
            total_size = request.subtitle.size;
        } else if (request.handler is HTTPMediaResourceHandler) {
            MediaResource resource = (request.handler as HTTPMediaResourceHandler)
                                              .media_resource;
            if (range_dtcp == null)
              total_size = resource.size;
            else// Get the cleartextsize for Range.dtcp.com request.
              total_size = resource.cleartext_size;

            content_protected = resource.is_link_protection_enabled();
        } else {
            total_size = (request.object as MediaItem).size;
        }
        var stop = total_size - 1;

        // Check if both Range and Range.dtcp.com is present in headers
        if (range != null && range_dtcp != null)
        {
            // The return status code must be 406(not acceptable)
            throw new HTTPRequestError.UNACCEPTABLE (_
                  ("Invalid combination of Range and Range.dtcp.com"));
        } else if (range_dtcp != null) {
            range_header_str = range_dtcp;
            if (!content_protected) {
                    throw new HTTPSeekError.INVALID_RANGE (_
                              ("Range.dtcp.com not valid for unprotected content"));
            }

            parsed_headers = parse_dtcp_range_header (range_header_str);

            if (parsed_headers.length == 2) {
                // Start byte must be present and non empty string
                if (parsed_headers[0] == null || parsed_headers[0] == "" ||
                    parsed_headers[1] == null) {
                    throw new HTTPSeekError.INVALID_RANGE (_
                              ("Invalid Range.dtcp.com '%s'"), range_header_str);
                }

               start = (int64)(double.parse (parsed_headers[0]));

               if (parsed_headers[1] == "") {
                   stop = total_size - 1;
               } else {
                   stop = (int64)(double.parse (parsed_headers[1]));
               }
            } else {
                // Range header was present but invalid
                throw new HTTPSeekError.INVALID_RANGE (_
                          ("Invalid Range.dtcp.com '%s'"), range_header_str);
            }
        } else if (range != null) {
            // Range is present, get the values from libsoup
            range_header_str = range;
            if (request.msg.request_headers.get_ranges (total_size,
                                                        out ranges)) {
                // TODO: Somehow deal with multipart/byterange properly
                start = ranges[0].start;
                stop = ranges[0].end;
            } else {
                throw new HTTPSeekError.INVALID_RANGE (_("Invalid Range '%s'"),
                                                       range_header_str);
            }
        }

        if (start > total_size-1) {
            throw new HTTPSeekError.OUT_OF_RANGE (_("Invalid Range '%s'"),
                                                       range_header_str);
        }

        if (stop < start) {
            throw new HTTPSeekError.INVALID_RANGE (_("Invalid Range '%s'"),
                                                       range_header_str);
        }

        base (request.msg);
        // A HTTP Range request is just bytes, which can live in the base
        set_byte_range(start, stop);
        // TODO: Deal with cases where length is not known (e.g. live/in-progress sources)
        this.total_size = total_size;
    }

    public static bool supported (HTTPGet request) {
        bool force_seek = false;

        try {
            var hack = ClientHacks.create (request.msg);
            force_seek = hack.force_seek ();
        } catch (Error error) { }

        bool is_byte_seek_supported = false;

        if (request.msg.request_headers.get_one ("Range.dtcp.com") != null) {
            if (!(request.handler is HTTPMediaResourceHandler)) {
                is_byte_seek_supported = false;
            } else {
                is_byte_seek_supported = (request.handler is HTTPMediaResourceHandler
                                            && (request.handler as HTTPMediaResourceHandler)
                                               .media_resource.is_cleartext_range_support_enabled());
            }
        } else if (request.msg.request_headers.get_one ("Range") != null) {
            if (!(request.handler is HTTPMediaResourceHandler)) {
                is_byte_seek_supported = true;
            } else {
                is_byte_seek_supported = request.handler is HTTPMediaResourceHandler
                                       && (request.handler as HTTPMediaResourceHandler)
                                            .media_resource.supports_arbitrary_byte_seek();
            }
        }

        return force_seek
               || (!(request.object is MediaContainer) && (request.object as MediaItem).size > 0)
               || is_byte_seek_supported
               || (request.thumbnail != null && request.thumbnail.size > 0)
               || (request.subtitle != null && request.subtitle.size > 0);
    }

    public static bool requested (HTTPGet request) {
        return (request.msg.request_headers.get_one ("Range") != null
                || request.msg.request_headers.get_one ("Range.dtcp.com") != null);
    }

    public static string[] parse_dtcp_range_header (string range_header) {
        string[] range_tokens = null;
        if (!range_header.has_prefix ("bytes=")) {
            return range_tokens;
        }

        debug ("range_header has prefix %s", range_header);
        range_tokens = range_header.substring (6).split ("-", 2);

        return range_tokens;
    }

    public override void add_response_headers () {
        // Content-Range: bytes START_BYTE-END_BYTE/TOTAL_LENGTH
        var range_str = "bytes ";
        unowned Soup.MessageHeaders headers = this.msg.response_headers;
        headers.append ("Accept-Ranges", "bytes");
        range_str += this.start_byte.to_string () + "-" +
                 this.end_byte.to_string () + "/" +
                 this.total_size.to_string ();
        if (this.msg.request_headers.get_one ("Range") != null) {
            headers.append("Content-Range", range_str);
            if (content_protected) // TODO : Call DTCP Lib to get the encrypted size 
                headers.set_content_length (this.length);
            else
                headers.set_content_length (this.length);
        } else if (this.msg.request_headers.get_one
                                           ("Range.dtcp.com") != null) {
            headers.append("Content-Range.dtcp.com", range_str);
            // TODO : Call DTCP Lib to get the encrypted size
            headers.set_content_length (this.length);
        }
    }
}

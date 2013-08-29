/*
 * Copyright (C) 2009 Nokia Corporation.
 * Copyright (C) 2012 Intel Corporation.
 *
 * Author: Zeeshan Ali (Khattak) <zeeshanak@gnome.org>
 *                               <zeeshan.ali@nokia.com>
 *         Jens Georg <jensg@openismus.com>
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

internal class Rygel.HTTPByteSeek : Rygel.HTTPSeek {
    public HTTPByteSeek (HTTPGet request) throws HTTPSeekError, HTTPRequestError {
        Soup.Range[] ranges;
        int64 start = 0, total_length;
        string[] parsed_headers;
        unowned string range = request.msg.request_headers.get_one ("Range");
        unowned string range_dtcp = request.msg.request_headers.get_one ("Range.dtcp.com");
        string range_header_str = null;

        if (request.thumbnail != null) {
            total_length = request.thumbnail.size;
        } else if (request.subtitle != null) {
            total_length = request.subtitle.size;
        } else {
            total_length = (request.object as MediaItem).size;
        }
        var stop = total_length - 1;

        // Check if both Range and Range.dtcp.com is present in headers
        if (range != null && range_dtcp != null)
        {
            // The return status code must be 406(not acceptable)
            throw new HTTPRequestError.UNACCEPTABLE (_
                  ("Invalid combination of Range and Range.dtcp.com"));
        } else if (range != null) {
			// Range is present, get the values from libsoup
            range_header_str = range;
            if (request.msg.request_headers.get_ranges (total_length,
                                                        out ranges)) {
                // TODO: Somehow deal with multipart/byterange properly
                start = ranges[0].start;
                stop = ranges[0].end;
            } else {
                // Range header was present but invalid
                throw new HTTPSeekError.INVALID_RANGE (_("Invalid Range '%s'"),
                                                       range_header_str);
            }
        } else if (range_dtcp != null) {
            range_header_str = range_dtcp;

            parsed_headers = parseDtcpRangeHeader (range_header_str);
            if (parsed_headers.length == 2) {
		        debug ("Parsed Start , Stop value :  %s , %s", parsed_headers[0], parsed_headers[1]);
                // Start byte must be present and non empty string
		        if (parsed_headers[0] == null || parsed_headers[0] == "" ||
					parsed_headers[1] == null) {
					// Range header was present but invalid
					throw new HTTPSeekError.INVALID_RANGE (_
							  ("Invalid Range.dtcp.com '%s'"), range_header_str);
				}

               // TODO : Calculate the cleartext start, end and length
               start = (int64)(double.parse (parsed_headers[0]));

               // TODO : Calculate cleartext length and assign it to stop
               if (parsed_headers[1] == "") {
				   stop = total_length - 1;
			   } else {
				   stop = (int64)(double.parse (parsed_headers[1]));
			   }
            } else {
                // Range header was present but invalid
                throw new HTTPSeekError.INVALID_RANGE (_
                          ("Invalid Range.dtcp.com '%s'"), range_header_str);
			}
        }

        if (start > stop) {
                throw new HTTPSeekError.INVALID_RANGE (_("Invalid Range '%s'"),
                                                       range_header_str);
        }

        base (request.msg, start, stop, 1, total_length);
        this.seek_type = HTTPSeekType.BYTE;
    }

    public static bool needed (HTTPGet request) {
        bool force_seek = false;

        try {
            var hack = ClientHacks.create (request.msg);
            force_seek = hack.force_seek ();
        } catch (Error error) { }

        return force_seek
               || (!(request.object is MediaContainer) && (request.object as MediaItem).size > 0)
               || (request.thumbnail != null && request.thumbnail.size > 0)
               || (request.subtitle != null && request.subtitle.size > 0);
    }

    public static bool requested (HTTPGet request) {
        return (request.msg.request_headers.get_one ("Range") != null
                || request.msg.request_headers.get_one ("Range.dtcp.com") != null);
    }

    public override void add_response_headers () {
        // Content-Range: bytes START_BYTE-STOP_BYTE/TOTAL_LENGTH
        var range_str = "bytes ";
        unowned Soup.MessageHeaders headers = this.msg.response_headers;
        headers.append ("Accept-Ranges", "bytes");
        range_str += this.start.to_string () + "-" +
                 this.stop.to_string () + "/" +
                 this.total_length.to_string ();
        if (this.msg.request_headers.get_one ("Range") != null) {
            headers.append("Content-Range", range_str);
            headers.set_content_length (this.length);
		} else if (this.msg.request_headers.get_one
		                                   ("Range.dtcp.com") != null) {
            headers.append("Content-Range.dtcp.com", range_str);
            headers.set_content_length (this.length);
        }
    }

    private static string[] parseDtcpRangeHeader (string range_header) {
        string[] range_tokens = null;
		if (!range_header.has_prefix ("bytes=")) {
			return range_tokens;
		}

        debug ("range_header has prefix %s", range_header);
        range_tokens = range_header.substring (6).split ("-", 2);

        return range_tokens;
	}
}

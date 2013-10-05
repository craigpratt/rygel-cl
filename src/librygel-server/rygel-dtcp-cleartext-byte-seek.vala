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

public static const string DTCP_CLEARTEXT_RANGE_REQUEST_HEADER = "Range.dtcp.com";

public class Rygel.DTCPCleartextByteSeekRequest : Rygel.HTTPSeekRequest {
    /**
     * The start of the cleartext range in bytes 
     */
    public int64 start_byte { get; private set; }

    /**
     * The end of the cleartext range in bytes (inclusive). May be HTTPSeekRequest.UNSPECIFIED
     */
    public int64 end_byte { get; private set; }

    /**
     * The length of the cleartext range in bytes. May be HTTPSeekRequest.UNSPECIFIED
     */
    public int64 range_length { get; private set; }

    /**
     * The length of the cleartext resource in bytes. May be HTTPSeekRequest.UNSPECIFIED
     */
    public int64 total_size { get; private set; }

    
    public DTCPCleartextByteSeekRequest (HTTPGet request) throws HTTPSeekRequestError,
                                                                 HTTPRequestError {
        base ();

        int64 start, end, total_size;
        
        // It's only possible to get the cleartext size from a MediaResource
        //  (and only if it is link protected)
        if (request.handler is HTTPMediaResourceHandler) {
            MediaResource resource = (request.handler as HTTPMediaResourceHandler)
                                     .media_resource;
            total_size = resource.cleartext_size;
            if (total_size <= 0) {
                // Even if it's a resource and the content is link-protected, it may have an
                // unknown cleartext size (e.g. if it's live/in-progress content). This doesn't
                // mean the request is invalid, it just means the total size is non-static
                total_size = UNSPECIFIED;
            }
        } else {
            total_size = UNSPECIFIED;
        }

        unowned string range = request.msg.request_headers.get_one (DTCP_CLEARTEXT_RANGE_REQUEST_HEADER);
        
        if (range == null) {
            throw new HTTPSeekRequestError.INVALID_RANGE ( "%s request header not present",
                                                           DTCP_CLEARTEXT_RANGE_REQUEST_HEADER );
        }
        
        if (!range.has_prefix ("bytes")) {
            throw new HTTPSeekRequestError.INVALID_RANGE ( "Invalid %s value (missing bytes field): '%s'",
                                                           DTCP_CLEARTEXT_RANGE_REQUEST_HEADER,
                                                           range );
        }

        var range_tokens = range.substring (6).split ("-", 2); // skip "bytes="
        if (range_tokens[0].length == 0) {
            throw new HTTPSeekRequestError.INVALID_RANGE ( "No range start specified: '%s'",
                                                           DTCP_CLEARTEXT_RANGE_REQUEST_HEADER,
                                                           range );
        }

        if (!int64.try_parse(range_tokens[0], out start) || (start < 0)) {
            throw new HTTPSeekRequestError.INVALID_RANGE ( "Invalid %s range start: '%s'",
                                                           DTCP_CLEARTEXT_RANGE_REQUEST_HEADER,
                                                           range );
        }
        // valid range start specified

        // Look for a range end...
        if (range_tokens[1].length == 0) {
            end = UNSPECIFIED;
        } else {
            if (!int64.try_parse(range_tokens[1], out end) || (end <= 0)) {
                throw new HTTPSeekRequestError.INVALID_RANGE ( "Invalid %s range end: '%s'",
                                                               DTCP_CLEARTEXT_RANGE_REQUEST_HEADER,
                                                               range );
            }
            // valid end range specified
        }

        if ((end != UNSPECIFIED) && (start > end)) {
            throw new HTTPSeekRequestError.INVALID_RANGE ( "Invalid %s range - start > end: '%s'",
                                                           DTCP_CLEARTEXT_RANGE_REQUEST_HEADER,
                                                           range );
        }

        if ((total_size != UNSPECIFIED) && (start > total_size-1)) {
            throw new HTTPSeekRequestError.INVALID_RANGE ( "Invalid %s range - start > length: '%s'",
                                                           DTCP_CLEARTEXT_RANGE_REQUEST_HEADER,
                                                           range );
        }

        if ((total_size != UNSPECIFIED) && (end > total_size-1)) {
            // It's not clear from the DLNA link protection spec if the range end can be beyond
            //  the total length. We'll assume RFC 2616 14.35.1 semantics. But note that having
            //  an end with an unspecified size will be normal for live/in-progress content 
            end = total_size-1;
        }

        this.start_byte = start;
        this.end_byte = end;
        this.range_length = (end == UNSPECIFIED) ? UNSPECIFIED
                                                : end-start+1; // +1, since range is inclusive
        this.total_size = total_size;
    }

    public static bool supported (HTTPGet request) {
        return (request.handler is HTTPMediaResourceHandler)
               && (request.handler as HTTPMediaResourceHandler)
                  .media_resource.is_cleartext_range_support_enabled();
    }

    public static bool requested (HTTPGet request) {
        return (request.msg.request_headers.get_one (DTCP_CLEARTEXT_RANGE_REQUEST_HEADER) != null);
    }
}

public static const string DTCP_CLEARTEXT_RANGE_RESPONSE_HEADER = "Content-Range.dtcp.com";

public class Rygel.DTCPCleartextByteSeekResponse : Rygel.HTTPResponseElement {
    /**
     * The start of the response range in bytes 
     */
    public int64 start_byte { get; private set; }

    /**
     * The end of the range in bytes (inclusive)
     */
    public int64 end_byte { get; private set; }

    /**
     * The length of the range in bytes
     */
    public int64 range_length { get; private set; }

    /**
     * The length of the resource in bytes. May be HTTPSeekRequest.UNSPECIFIED
     */
    public int64 total_size { get; private set; }

    /**
     * The encrypted length of the response
     */
    public int64 encrypted_length { get; public set;}
    
    public DTCPCleartextByteSeekResponse(int64 start_byte, int64 end_byte, int64 total_size) {
        this.start_byte = start_byte;
        this.end_byte = end_byte;
        this.range_length = end_byte - start_byte + 1; // +1, since range is inclusive
        this.total_size = total_size;
        this.encrypted_length = UNSPECIFIED;
    }

    public DTCPCleartextByteSeekResponse.from_request(DTCPCleartextByteSeekRequest request) {
        this.start_byte = request.start_byte;
        this.end_byte = request.end_byte;
        this.range_length = request.range_length;
        this.total_size = request.total_size;
        this.encrypted_length = UNSPECIFIED;
    }

    public override void add_response_headers (Rygel.HTTPRequest request) {
        // Content-Range.dtcp.com: bytes START_BYTE-END_BYTE/TOTAL_LENGTH (or "*")
        if (this.start_byte != UNSPECIFIED) {
            string response = "bytes " + this.start_byte.to_string()
                              + "-" + this.end_byte.to_string() + "/"
                              + ( (this.total_size == UNSPECIFIED) ? "*"
                                  : this.total_size.to_string() );

            request.msg.response_headers.append (DTCP_CLEARTEXT_RANGE_RESPONSE_HEADER, response);
        }
        if (this.encrypted_length != UNSPECIFIED) {
            request.msg.response_headers.set_content_length (this.encrypted_length);
        }
    }
}

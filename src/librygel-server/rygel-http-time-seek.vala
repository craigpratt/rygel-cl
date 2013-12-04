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

/*
 * Modifications made by Cable Television Laboratories, Inc.
 * Copyright (C) 2013  Cable Television Laboratories, Inc.
 * Contact: http://www.cablelabs.com/
 *
 * Author: Craig Pratt <craig@ecaspia.com>
 */

// Note: For TimeSeekRange, the request and response header name is the same,
//       but different forms are allowed for request and response
public static const string TIMESEEKRANGE_HEADER = "TimeSeekRange.dlna.org";

/**
 * This class represents a DLNA TimeSeekRange request and response.
 *
 * A TimeSeekRange request can only have a time range ("npt=start-end"). But a
 * TimeSeekRange response may have a time range ("npt=start-end/duration" and
 * a byte range ("bytes=") corresponding with the actual time/data range.
 *
 * Note that DLNA requires both "npt=" and "bytes=" to be set if both
 * data- and time-based seek are supported. (see DLNA 7.5.4.3.2.24.5)
 */
public class Rygel.HTTPTimeSeekRequest : Rygel.HTTPSeekRequest {
    /**
     * Requested range start time, in microseconds 
     */
    public int64 start_time;

    /**
     * Requested range end time, in microseconds 
     */
    public int64 end_time;

    /**
     * Requested range duration, in microseconds
     */
    public int64 range_duration;

    /**
     * The total duration of the resource, in microseconds
     */
    public int64 total_duration;

    /**
     * Create a HTTPTimeSeekRequest corresponding with a HTTPGet that contains a TimeSeekRange.dlna.org
     * header value.
     *
     * @param request The HTTP GET/HEAD request
     * @param positive_rate Indicates if playback is in the positive or negative direction
     */
    internal HTTPTimeSeekRequest (HTTPGet request, DLNAPlaySpeed ? speed) throws HTTPSeekRequestError {
        base ();

        bool positive_rate = (speed == null) || speed.is_positive();
        bool trick_mode = (speed != null) && speed.is_trick_rate();

        this.total_duration = request.handler.get_resource_duration();
        if (this.total_duration <= 0) {
            this.total_duration = UNSPECIFIED;
        }

        var range = request.msg.request_headers.get_one (TIMESEEKRANGE_HEADER);

        if (range == null) {
            throw new HTTPSeekRequestError.INVALID_RANGE ("%s not present", TIMESEEKRANGE_HEADER);
        }
        
        if (!range.has_prefix ("npt=")) {
            throw new HTTPSeekRequestError.INVALID_RANGE ("Invalid %s value (missing npt field): '%s'",
                                                   TIMESEEKRANGE_HEADER, range);
        }

        var parsed_range = range.substring (4);
        if (!parsed_range.contains ("-")) {
            throw new HTTPSeekRequestError.INVALID_RANGE("Invalid %s request with no '-': '%s'",
                                                  TIMESEEKRANGE_HEADER, range);
        }

        var range_tokens = parsed_range.split ("-", 2);

        int64 start = UNSPECIFIED;
        if (!parse_npt_time (range_tokens[0], ref start)) {
            throw new HTTPSeekRequestError.INVALID_RANGE("Invalid %s value (no start): '%s'",
                                                  TIMESEEKRANGE_HEADER, range);
        }

        // Check for out-of-bounds range start and clamp it in if in trick/scan mode
        if ((this.total_duration != UNSPECIFIED) && (start > this.total_duration)) {
            if (trick_mode && !positive_rate) { // Per DLNA 7.5.4.3.2.24.4
                this.start_time = this.total_duration;
            } else { // See DLNA 7.5.4.3.2.24.8
                throw new HTTPSeekRequestError.OUT_OF_RANGE( "Invalid %s start time %lldns is beyond the content duration of %lldns",
                                                      TIMESEEKRANGE_HEADER, start,
                                                      this.total_duration );
            }
        } else { // Nothing to check it against - just store it
            this.start_time = start;
        }

        // Look for an end time
        int64 end = UNSPECIFIED;
        if (parse_npt_time (range_tokens[1], ref end)) {
            // The end time was specified in the npt ("start-end")
            // Check for valid range
            if (positive_rate) {
                // Check for out-of-bounds range end or fence it in
                if ((this.total_duration != UNSPECIFIED) && (end > this.total_duration)) {
                    if (trick_mode) { // Per DLNA 7.5.4.3.2.24.4
                        this.end_time = this.total_duration;
                    } else { // Per DLNA 7.5.4.3.2.24.8
                        throw new HTTPSeekRequestError.OUT_OF_RANGE( "Invalid %s end time %lldns is beyond the content duration of %lldns",
                                                              TIMESEEKRANGE_HEADER, end,
                                                              this.total_duration );
                    }
                } else {
                    this.end_time = end;
                }
                
                this.range_duration =  this.end_time - this.start_time;
                // At positive rate, start < end
                if (this.range_duration <= 0) { // See DLNA 7.5.4.3.2.24.12
                    throw new HTTPSeekRequestError.INVALID_RANGE (
                        "Invalid %s value (start time after end time - forward scan): '%s'",
                        TIMESEEKRANGE_HEADER, range );
                }
            } else { // Negative rate
                // Note: start_time has already been checked/clamped
                this.end_time = end;
                this.range_duration = this.start_time - this.end_time;
                // At negative rate, start > end
                if (this.range_duration <= 0) { // See DLNA 7.5.4.3.2.24.12
                    throw new HTTPSeekRequestError.INVALID_RANGE (
                        "Invalid %s value (start time before end time - reverse scan): '%s'",
                        TIMESEEKRANGE_HEADER, range );
                }
            }
        } else { // End time not specified in the npt field ("start-")
            // See DLNA 7.5.4.3.2.24.4
            this.end_time = UNSPECIFIED; // Will indicate "end/beginning of binary"
            if (positive_rate) {
                this.range_duration = this.total_duration - this.start_time;
            } else { // Negative rate
                this.range_duration = this.start_time; // Going backward from start to 0
            }
        }
    }

    /**
     * Return true if time-seek is supported.
     *
     * This method utilizes elements associated with the request to determine if a
     * TimeSeekRange request is supported for the given request/resource.
     */
    public static bool supported (HTTPGet request) {
        bool force_seek = false;

        try {
            var hack = ClientHacks.create (request.msg);
            force_seek = hack.force_seek ();
        } catch (Error error) { }

        return force_seek || request.handler.supports_time_seek();
    }

    /**
     * Return true of the HTTPGet contains a TimeSeekRange request.
     */
    public static bool requested (HTTPGet request) {
        return (request.msg.request_headers.get_one (TIMESEEKRANGE_HEADER) != null);
    }

    // Parses npt times in the format of '417.33' and returns the time in microseconds
    private static bool parse_npt_seconds (string range_token,
                                           ref int64 value) {
        if (range_token[0].isdigit ()) {
            value = (int64) (double.parse (range_token) * TimeSpan.SECOND);
        } else {
            return false;
        }
        return true;
    }

    // Parses npt times in the format of '10:19:25.7' and returns the time in microseconds
    private static bool parse_npt_time (string? range_token,
                                        ref int64 value) {
        if (range_token == null) {
            return false;
        }
        
        if (range_token.index_of (":") == -1) {
            return parse_npt_seconds(range_token, ref value);
        }
        // parse_seconds has a ':' in it...
        int64 seconds_sum = 0;
        int time_factor = 0;
        string[] time_tokens;

        seconds_sum = 0;
        time_factor = 3600;

        time_tokens = range_token.split (":", 3);
        if (time_tokens[0] == null ||
            time_tokens[1] == null ||
            time_tokens[2] == null) {
            return false;
        }

        foreach (string time in time_tokens) {
            if (time[0].isdigit ()) {
                seconds_sum += (int64) ((double.parse (time) * TimeSpan.SECOND) * time_factor);
            } else {
                return false;
            }
            time_factor /= 60;
        }
        value = seconds_sum;

        return true;
    }
}

public class Rygel.HTTPTimeSeekResponse : Rygel.HTTPResponseElement {
    /**
     * Effective range start time, in microseconds 
     */
    public int64 start_time { get; private set; }

    /**
     * Effective range end time, in microseconds 
     */
    public int64 end_time { get; private set; }

    /**
     * Effective range duration, in microseconds
     */
    public int64 range_duration { get; private set; }

    /**
     * The total duration of the resource, in microseconds
     */
    public int64 total_duration { get; private set; }

    /**
     * The start of the range in bytes 
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
     * The length of the resource in bytes
     */
    public int64 total_size { get; private set; }
    
    public HTTPTimeSeekResponse(int64 start_time, int64 end_time, int64 total_duration,
                                int64 start_byte, int64 end_byte, int64 total_size ) {
        base();
        this.start_time = start_time;
        this.end_time = end_time;
        this.total_duration = total_duration;
        
        this.start_byte = start_byte;
        this.end_byte = end_byte;
        this.range_length = end_byte - start_byte + 1;
        this.total_size = total_size;
    }

    /**
     * Create a HTTPTimeSeekResponse from a HTTPTimeSeekRequest
     *
     * Note: This form is only valid when byte-seek is not supported, according to the
     * associated resource's ProtocolInfo (see DLNA 7.5.4.3.2.24.5)
     */
    public HTTPTimeSeekResponse.time_only(int64 start_time, int64 end_time, int64 total_duration) {
        base();
        this.start_time = start_time;
        this.end_time = end_time;
        this.total_duration = total_duration;
        
        this.start_byte = UNSPECIFIED;
        this.end_byte = UNSPECIFIED;
        this.range_length = UNSPECIFIED;
        this.total_size = UNSPECIFIED;
    }
    
    /**
     * Create a HTTPTimeSeekResponse from a HTTPTimeSeekRequest
     *
     * Note: This form is only valid when byte-seek is not supported, according to the
     * associated resource's ProtocolInfo (see DLNA 7.5.4.3.2.24.5)
     */
    public HTTPTimeSeekResponse.from_request( HTTPTimeSeekRequest time_seek_request,
                                              int64 total_duration ) {
        HTTPTimeSeekResponse.time_only( time_seek_request.start_time,
                                        time_seek_request.end_time,
                                        total_duration );
    }
    
    public override void add_response_headers (Rygel.HTTPRequest request) {
        var response = get_response_string ();
        if (response != null) {
            request.msg.response_headers.append (TIMESEEKRANGE_HEADER, response);
            if (this.start_byte != UNSPECIFIED) {
                // Note: Don't use set_content_range() here - we don't want a "Content-range" header
                request.msg.response_headers.set_content_length (this.range_length);
            }
        }
    }

    private string? get_response_string () {
        if (start_time == UNSPECIFIED) {
            return null;
        }
        
        // The response form of TimeSeekRange:
        //
        // TimeSeekRange.dlna.org: npt=START_TIME-END_TIME/DURATION bytes=START_BYTE-END_BYTE/LENGTH
        //
        // The "bytes=" field can be ommitted in some cases. (e.g. ORG_OP a-val==1, b-val==0)
        // The DURATION can be "*" in some cases (e.g. for limited-operation mode)
        // The LENGTH can be "*" in some cases (e.g. for limited-operation mode)
        // And the entire response header can be ommitted for HEAD requests (see DLNA 7.5.4.3.2.24.2)

        // It's not our job at this level to enforce all the semantics of the TimeSeekRange
        //  response, as we don't have enough context. Setting up the correct HTTPTimeSeekRequest
        //  object is the responsibility of the object owner. To form the response, we just
        //  use what is set.

        var response = new StringBuilder();
        response.append("npt=");
        response.append_printf("%.3f-", (double) this.start_time / TimeSpan.SECOND);
        response.append_printf("%.3f/", (double) this.end_time / TimeSpan.SECOND);
        if (this.total_duration != UNSPECIFIED) {
            response.append_printf("%.3f", (double) this.total_duration / TimeSpan.SECOND);
        } else {
            response.append("*");
        }

        if (this.start_byte != UNSPECIFIED) {
            response.append(" bytes=");
            response.append(this.start_byte.to_string());
            response.append("-");
            response.append(this.end_byte.to_string());
            response.append("/");
            if (this.total_size != UNSPECIFIED) {
                response.append(this.total_size.to_string());
            } else {
                response.append("*");
            }
        }

        return response.str;
   }

    public override string to_string () {
        return ("HTTPTimeSeekResponse(%s)".printf(get_response_string ()));
    }
}

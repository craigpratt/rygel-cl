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
    internal HTTPTimeSeekRequest (HTTPGet request, PlaySpeed ? speed)
            throws HTTPSeekRequestError {
        base ();

        bool positive_rate = (speed == null) || speed.is_positive ();
        bool trick_mode = (speed != null) && !speed.is_normal_rate ();

        this.total_duration = request.handler.get_resource_duration ();
        if (this.total_duration <= 0) {
            this.total_duration = UNSPECIFIED;
        }

        var range = request.msg.request_headers.get_one (TIMESEEKRANGE_HEADER);

        if (range == null) {
            throw new HTTPSeekRequestError.INVALID_RANGE ("%s not present",
                                                          TIMESEEKRANGE_HEADER);
        }

        if (!range.has_prefix ("npt=")) {
            throw new HTTPSeekRequestError.INVALID_RANGE
                          ("Invalid %s value (missing npt field): '%s'",
                          TIMESEEKRANGE_HEADER, range);
        }

        var parsed_range = range.substring (4);
        if (!parsed_range.contains ("-")) {
            throw new HTTPSeekRequestError.INVALID_RANGE
                          ("Invalid %s request with no '-': '%s'",
                          TIMESEEKRANGE_HEADER, range);
        }

        var range_tokens = parsed_range.split ("-", 2);

        int64 start = UNSPECIFIED;
        if (!parse_npt_time (range_tokens[0], ref start)) {
            throw new HTTPSeekRequestError.INVALID_RANGE
                          ("Invalid %s value (no start): '%s'",
                          TIMESEEKRANGE_HEADER, range);
        }

        // Check for out-of-bounds range start and clamp it in if in trick/scan mode
        if ((this.total_duration != UNSPECIFIED) && (start > this.total_duration)) {
            if (trick_mode && !positive_rate) { // Per DLNA 7.5.4.3.2.24.4
                this.start_time = this.total_duration;
            } else { // See DLNA 7.5.4.3.2.24.8
                throw new HTTPSeekRequestError.OUT_OF_RANGE
                              ("Invalid %s start time %lldns is beyond the content duration of %lldns",
                               TIMESEEKRANGE_HEADER, start, this.total_duration);
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
                        throw new HTTPSeekRequestError.OUT_OF_RANGE
                                      ("Invalid %s end time %lldns is beyond the content duration of %lldns",
                                       TIMESEEKRANGE_HEADER, end,this.total_duration);
                    }
                } else {
                    this.end_time = end;
                }

                this.range_duration =  this.end_time - this.start_time;
                // At positive rate, start < end
                if (this.range_duration <= 0) { // See DLNA 7.5.4.3.2.24.12
                    throw new HTTPSeekRequestError.INVALID_RANGE
                                  ("Invalid %s value (start time after end time - forward scan): '%s'",
                                   TIMESEEKRANGE_HEADER, range);
                }
            } else { // Negative rate
                // Note: start_time has already been checked/clamped
                this.end_time = end;
                this.range_duration = this.start_time - this.end_time;
                // At negative rate, start > end
                if (this.range_duration <= 0) { // See DLNA 7.5.4.3.2.24.12
                    throw new HTTPSeekRequestError.INVALID_RANGE
                                 ("Invalid %s value (start time before end time - reverse scan): '%s'",
                                  TIMESEEKRANGE_HEADER, range);
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

        return force_seek || request.handler.supports_time_seek ();
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
            return parse_npt_seconds (range_token, ref value);
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
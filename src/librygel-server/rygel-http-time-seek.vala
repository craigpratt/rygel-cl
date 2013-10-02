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
public class Rygel.HTTPTimeSeek : Rygel.HTTPSeek {
    public static const string TIMESEEKRANGE_HEADER = "TimeSeekRange.dlna.org";
    public static const int64 UNSPECIFIED_TIME = -1;
    
    /**
     * Requested range start time, in microseconds 
     */
    public int64 requested_start;

    /**
     * Requested range end time, in microseconds 
     */
    public int64 requested_end;

    /**
     * Requested range duration, in microseconds
     */
    public int64 requested_duration;

    /**
     * Effective range start time, in microseconds. This is the actual start time that
     * could be honored.
     */
    private int64 effective_start;

    /**
     * Effective range end time, in microseconds. This is the actual end time that
     * could be honored.
     */
    private int64 effective_end;

    /**
     * The total duration of the resource, in microseconds
     */
    private int64 total_duration;

    /**
     * Create a HTTPTimeSeek corresponding with a HTTPGet that contains a TimeSeekRange.dlna.org
     * header value.
     *
     * @param request The HTTP GET/HEAD request
     * @param positive_rate Indicates if playback is in the positive or negative direction
     */
    internal HTTPTimeSeek (HTTPGet request, DLNAPlaySpeed ? speed) throws HTTPSeekError {
        // Initialize the base first or accessing our members will fault...
        base (request.msg);

        bool positive_rate = (speed == null) || speed.is_positive();
        bool trick_mode = (speed != null) && speed.is_trick_rate();

        this.is_link_protected_flag = false;

        if (request.handler is HTTPMediaResourceHandler) {
            MediaResource resource = (request.handler as HTTPMediaResourceHandler)
                                                                  .media_resource;
            this.total_duration = resource.duration * TimeSpan.SECOND;
            this.is_link_protected_flag = resource.is_link_protection_enabled();
        } else {
            this.total_duration = (request.object as AudioItem).duration * TimeSpan.SECOND;
        }

        var range = request.msg.request_headers.get_one (TIMESEEKRANGE_HEADER);

        if (range == null) {
            throw new HTTPSeekError.INVALID_RANGE ("%s not present", TIMESEEKRANGE_HEADER);
        }
        
        if (!range.has_prefix ("npt=")) {
            throw new HTTPSeekError.INVALID_RANGE ("Invalid %s value (missing npt field): '%s'",
                                                   TIMESEEKRANGE_HEADER, range);
        }

        var range_tokens = range.substring (4).split ("-", 2);

        int64 start = UNSPECIFIED_TIME;
        if (!parse_npt_time (range_tokens[0], ref start)) {
            throw new HTTPSeekError.INVALID_RANGE("Invalid %s value (no start): '%s'",
                                                  TIMESEEKRANGE_HEADER, range);
        }

        // Check for out-of-bounds range start and clamp it in if in trick/scan mode
        if (total_duration_set() && (start > this.total_duration)) {
            if (trick_mode && !positive_rate) { // Per DLNA 7.5.4.3.2.24.4
                this.requested_start = this.total_duration;
            } else { // See DLNA 7.5.4.3.2.24.8
                throw new HTTPSeekError.OUT_OF_RANGE( "Invalid %s start time %lldns is beyond the content duration of %lldns",
                                                      TIMESEEKRANGE_HEADER, start,
                                                      this.total_duration );
            }
        } else { // Nothing to check it against - just store it
            this.requested_start = start;
        }

        // Look for an end time
        int64 end = UNSPECIFIED_TIME;
        if (parse_npt_time (range_tokens[1], ref end)) {
            // The end time was specified in the npt ("start-end")
            // Check for valid range
            if (positive_rate) {
                // Check for out-of-bounds range end or fence it in
                if (total_duration_set() && (end > this.total_duration)) {
                    if (trick_mode) { // Per DLNA 7.5.4.3.2.24.4
                        this.requested_end = this.total_duration;
                    } else { // Per DLNA 7.5.4.3.2.24.8
                        throw new HTTPSeekError.OUT_OF_RANGE( "Invalid %s end time %lldns is beyond the content duration of %lldns",
                                                              TIMESEEKRANGE_HEADER, end,
                                                              this.total_duration );
                    }
                } else {
                    this.requested_end = end;
                }
                
                this.requested_duration =  this.requested_end - this.requested_start;
                // At positive rate, start < end
                if (this.requested_duration <= 0) { // See DLNA 7.5.4.3.2.24.12
                    throw new HTTPSeekError.INVALID_RANGE (
                        "Invalid %s value (start time after end time - forward scan): '%s'",
                        TIMESEEKRANGE_HEADER, range );
                }
            } else { // Negative rate
                // Note: requested_start has already been checked/clamped
                this.requested_end = end;
                this.requested_duration = this.requested_start - this.requested_end;
                // At negative rate, start > end
                if (this.requested_duration <= 0) { // See DLNA 7.5.4.3.2.24.12
                    throw new HTTPSeekError.INVALID_RANGE (
                        "Invalid %s value (start time before end time - reverse scan): '%s'",
                        TIMESEEKRANGE_HEADER, range );
                }
            }
        } else { // End time not specified in the npt field ("start-")
            // See DLNA 7.5.4.3.2.24.4
            this.requested_end = UNSPECIFIED_TIME; // Will indicate "end/beginning of binary"
            if (positive_rate) {
                this.requested_duration = this.total_duration - this.requested_start;
            } else { // Negative rate
                this.requested_duration = this.requested_start; // Going backward from start to 0
            }
        }
        
        // The corresponding byte range and total resource length is unknown at
        // the time of construction. The effective time/byte values need to be set
        // in a media/system-specific way via set_effective_time_range() and set_byte_range(),
        // respectively. e.g. Via the MediaEngine
        unset_effective_time_range();
    }

    public bool end_time_requested() {
        return (requested_end != UNSPECIFIED_TIME);
    }

    public bool implies_negative_rate() {
        return (requested_end < requested_start);
    }

    //
    // Response-specific methods
    //

    /**
     * Set the effective time range for the seek (the seek time that is actually going to
     * be returned). This will cause a TimeSeekRange response to be generated when
     * add_response_headers() is called with the range portion "npt=" field of the
     * TimeSeekRange response populated.
     *
     * @param start_time The effective start time of the range, in microseconds
     * @param end_time The effective start time of the range, in microseconds
     */
    public void set_effective_time_range(int64 start_time, int64 end_time) {
        this.effective_start = start_time;
        this.effective_end = end_time;
    }

    /**
     * Unset the effective time. No TimeSeekRange response will be generated by
     * add_response_headers if the time range is unset.
     */
    public void unset_effective_time_range() {
        this.effective_start = UNSPECIFIED_TIME;
        this.effective_end = UNSPECIFIED_TIME;
    }

    /**
     * Return true if the effective time range is set.
     *
     * When true, a TimeSeekRange response will be generated when add_response_headers()
     * is called with the range portion of the "npt=" field of the TimeSeekRange response
     * populated.
     */
    public bool effective_time_range_set() {
        return (this.effective_start != UNSPECIFIED_TIME);
    }

    /**
     * Set the total duration for the seek response.
     *
     * When set, and the the effective time range is set, a TimeSeekRange response
     * will be generated when add_response_headers() is called with the duration portion
     * of the "npt=" field set to the total duration.
     *
     */
    public void set_total_duration(int64 duration) {
        this.total_duration = duration;
    }
    
    /**
     * Get the total duration for the seek response.
     */
    public int64 get_total_duration() {
        return this.total_duration;
    }
    
    /**
     * Unset the total duration for the seek response.
     *
     * When unset, and the the effective time range is set, a TimeSeekRange response
     * will be generated when add_response_headers() is called with the duration portion
     * of the "npt=" field unspecified (set to "*").
     */
    public void unset_total_duration() {
        this.total_duration = UNSPECIFIED_TIME;
    }

    /**
     * Return true if the total duration is set.
     *
     * When true, and the the effective time range is set, a TimeSeekRange response
     * will be generated when add_response_headers() is called with the duration portion
     * of the "npt=" field set to the total duration set.
     *
     * When false, and the the effective time range is set, a TimeSeekRange response
     * will be generated when add_response_headers() is called with the duration portion
     * of the "npt=" field unspecified (set to "*").
     */
    public bool total_duration_set() {
        return (this.total_duration != UNSPECIFIED_TIME);
    }

    /**
     * Return true if a time-seek is supported.
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

        // TODO: This needs to incorporate some delegation or maybe not even exist here.
        //       (e.g. if there's a "TimeSeekRange supported" query it should be on a
        //       ContentResource, since it owns the ProtocolInfo which indicates
        //       time-seek-ability (a-val of ORG_OP or the LOP-time indicator))
        return force_seek
               || ( request.object is AudioItem
                    && ( request.object as AudioItem).duration > 0
                         && ( request.handler is HTTPTranscodeHandler
                              || ( request.thumbnail == null
                                   && request.subtitle == null
                                   && (request.object as MediaItem).is_live_stream () ) ) )
               || ( request.handler is HTTPMediaResourceHandler
                    && (request.handler as HTTPMediaResourceHandler)
                        .media_resource.supports_arbitrary_time_seek() );
    }

    /**
     * Return true of the HTTPGet contains a TimeSeekRange request.
     */
    public static bool requested (HTTPGet request) {
        return (request.msg.request_headers.get_one (TIMESEEKRANGE_HEADER) != null);
    }

    public override void add_response_headers () {
        // The response form of TimeSeekRange:
        //
        // TimeSeekRange.dlna.org: npt=START_TIME-END_TIME/DURATION bytes=START_BYTE-END_BYTE/LENGTH
        //
        // The "bytes=" field can be ommitted in some cases. (e.g. ORG_OP a-val==1, b-val==0)
        // The DURATION can be "*" in some cases (e.g. for limited-operation mode)
        // The LENGTH can be "*" in some cases (e.g. for limited-operation mode)
        // And the entire response header can be ommitted for HEAD requests (see DLNA 7.5.4.3.2.24.2)

        // It's not our job at this level to enforce all the semantics of the TimeSeekRange
        //  response, as we don't have enough context. Setting up the correct HTTPTimeSeek
        //  object is the responsibility of the object owner. To form the response, we just
        //  use what is set.

        if (effective_time_range_set()) {
            var response_time = new StringBuilder();
            var response_bytes = new StringBuilder();
            response_time.append("npt=");
            response_time.append_printf("%.3f-", (double) this.effective_start / TimeSpan.SECOND);
            response_time.append_printf("%.3f/", (double) this.effective_end / TimeSpan.SECOND);
            if (total_duration_set()) {
                response_time.append_printf("%.3f", (double) this.total_duration / TimeSpan.SECOND);
            } else {
                response_time.append("*");
            }

            if (byte_range_set()) { // From our super, HTTPSeek
                //response.append(" bytes=");
                response_bytes.append(this.start_byte.to_string());
                response_bytes.append("-");
                response_bytes.append(this.end_byte.to_string());
                response_bytes.append("/");
                if (total_size_set()) {
                    response_bytes.append(this.total_size.to_string());
                } else {
                    response_bytes.append("*");
                }
            }

            this.msg.response_headers.append ("TimeSeekRange.dlna.org", response_time.str + " bytes=" + response_bytes.str);
            if (this.is_link_protected_flag)
                this.msg.response_headers.append ("Content-Range.dtcp.com", "bytes " + response_bytes.str);
        }
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

/*
 * Copyright (C) 2013  Cable Television Laboratories, Inc.
 * Contact: http://www.cablelabs.com/
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

    public HTTPTimeSeekResponse (int64 start_time, int64 end_time, int64 total_duration,
                                 int64 start_byte, int64 end_byte, int64 total_size) {
        base ();
        this.start_time = start_time;
        this.end_time = end_time;
        this.total_duration = total_duration;

        this.start_byte = start_byte;
        this.end_byte = end_byte;
        this.range_length = end_byte - start_byte + 1;
        this.total_size = total_size;
    }

    /**
     * Create a HTTPTimeSeekResponse only containing a time range
     *
     * Note: This form is only valid when byte-seek is not supported, according to the
     * associated resource's ProtocolInfo (see DLNA 7.5.4.3.2.24.5)
     */
    public HTTPTimeSeekResponse.time_only (int64 start_time, int64 end_time, int64 total_duration) {
        base ();
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
    public HTTPTimeSeekResponse.from_request ( HTTPTimeSeekRequest time_seek_request,
                                              int64 total_duration ) {
        HTTPTimeSeekResponse.time_only ( time_seek_request.start_time,
                                         time_seek_request.end_time,
                                         total_duration );
    }

    public override void add_response_headers (Rygel.HTTPRequest request) {
        var response = get_response_string ();
        if (response != null) {
            request.msg.response_headers.append (HTTPTimeSeekRequest.TIMESEEKRANGE_HEADER,
                                                 response);
            if (this.start_byte != UNSPECIFIED) {
                // Note: Don't use set_content_range () here - we don't want a "Content-range" header
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

        var response = new StringBuilder ();
        response.append ("npt=");
        response.append_printf ("%.3f-", (double) this.start_time / TimeSpan.SECOND);
        response.append_printf ("%.3f/", (double) this.end_time / TimeSpan.SECOND);
        if (this.total_duration != UNSPECIFIED) {
            response.append_printf ("%.3f", (double) this.total_duration / TimeSpan.SECOND);
        } else {
            response.append ("*");
        }

        if (this.start_byte != UNSPECIFIED) {
            response.append (" bytes=");
            response.append (this.start_byte.to_string ());
            response.append ("-");
            response.append (this.end_byte.to_string ());
            response.append ("/");
            if (this.total_size != UNSPECIFIED) {
                response.append (this.total_size.to_string ());
            } else {
                response.append ("*");
            }
        }

        return response.str;
   }

    public override string to_string () {
        return ("HTTPTimeSeekResponse (%s)".printf (get_response_string ()));
    }
}

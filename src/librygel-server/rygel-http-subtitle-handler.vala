/* 
 * Copyright (C) 2013  Cable Television Laboratories, Inc.
 * Contact: http://www.cablelabs.com/
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
 *
 * Author: Craig Pratt <craig@ecaspia.com>
 *
 * This file is part of Rygel.
 */

using GUPnP;

internal class Rygel.HTTPSubtitleHandler : Rygel.HTTPGetHandler {
    private MediaFileItem media_item;
    private int subtitle_index;
    public Subtitle subtitle;

    public HTTPSubtitleHandler (MediaFileItem media_item,
                                int subtitle_index,
                                Cancellable? cancellable) throws HTTPRequestError {
        this.media_item = media_item;
        this.subtitle_index = subtitle_index;
        this.cancellable = cancellable;

        if (subtitle_index >= 0 && media_item is VideoItem) {
            var video_item = media_item as VideoItem;

            if (subtitle_index < video_item.subtitles.size) {
                this.subtitle = video_item.subtitles.get (subtitle_index);
            }
        }

        if (this.subtitle == null) {
            throw new HTTPRequestError.NOT_FOUND ("Subtitle index %d not found for item '%s",
                                                  subtitle_index, media_item.id);
        }
    }

    public override bool supports_transfer_mode (string mode) {
        // Support interactive and background transfers only
        return (mode != TRANSFER_MODE_STREAMING);
    }

    public override void add_response_headers (HTTPGet request)
                                               throws HTTPRequestError {
        // Add Content-Type
        request.msg.response_headers.append ("Content-Type", subtitle.mime_type);

        // Add contentFeatures.dlna.org
        
        // This is functionally equivalent to how contentFeatures was formed via the
        //  (deprecated) HTTPIdentityHandler
        MediaResource res = this.media_item.get_resource_list ().get (0);
        string protocol_info = res.get_protocol_info ().to_string ();
        var pi_fields = protocol_info.split (":", 4);
        request.msg.response_headers.append ("contentFeatures.dlna.org", pi_fields[3]);

        // Chain-up
        base.add_response_headers (request);
    }

    public override HTTPResponse render_body (HTTPGet request)
                                              throws HTTPRequestError {
        DataSource src;
        try {
            var engine = MediaEngine.get_default ();
            src = engine.create_data_source_for_uri (this.subtitle.uri);

            return new HTTPResponse (request, this, src);
        } catch (Error err) {
            throw new HTTPRequestError.NOT_FOUND (err.message);
        }
    }

    public override int64 get_resource_size () {
        return subtitle.size;
    }
}

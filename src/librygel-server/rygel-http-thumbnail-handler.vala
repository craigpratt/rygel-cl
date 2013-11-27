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

internal class Rygel.HTTPThumbnailHandler : Rygel.HTTPGetHandler {
    private MediaFileItem media_item;
    private int thumbnail_index;
    private Thumbnail thumbnail;

    public HTTPThumbnailHandler (MediaFileItem media_item,
                                 int thumbnail_index,
                                 Cancellable? cancellable) throws HTTPRequestError 
    {
        this.media_item = media_item;
        this.thumbnail_index = thumbnail_index;
        this.cancellable = cancellable;
        
        if (media_item is MusicItem) {
            var music_item = media_item as MusicItem;
            this.thumbnail = music_item.album_art;
        } else if (media_item is VisualItem) {
            var visual_item = media_item as VisualItem;
            if (thumbnail_index < visual_item.thumbnails.size) {
                this.thumbnail = visual_item.thumbnails.get (thumbnail_index);
            }
        }
        if (this.thumbnail == null) {
            throw new HTTPRequestError.NOT_FOUND ("Thumbnail index %d not found for item '%s",
                                                  thumbnail_index, media_item.id);
        }
    }

    public override bool supports_transfer_mode (string mode) {
        // Support interactive and background transfers only
        return (mode != TRANSFER_MODE_STREAMING);
    }

    public override void add_response_headers (HTTPGet request)
                                               throws HTTPRequestError {
        // Add Content-Type
        request.msg.response_headers.append ("Content-Type", thumbnail.mime_type);

        // Add contentFeatures.dlna.org
        MediaResource res = this.thumbnail.get_resource (request.http_server.get_protocol ());
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
            src = engine.create_data_source_for_uri (this.thumbnail.uri);

            return new HTTPResponse (request, this, src);
        } catch (Error err) {
            throw new HTTPRequestError.NOT_FOUND (err.message);
        }
    }

    public override int64 get_resource_size () {
        return thumbnail.size;
    }

    public override bool supports_byte_seek () {
        return true;
    }
}

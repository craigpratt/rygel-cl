/*
 * Copyright (C) 2008-2010 Nokia Corporation.
 * Copyright (C) 2006, 2007, 2008 OpenedHand Ltd.
 * Copyright (C) 2012 Intel Corporation.
 *
 * Author: Zeeshan Ali (Khattak) <zeeshanak@gnome.org>
 *                               <zeeshan.ali@nokia.com>
 *         Jorn Baayen <jorn.baayen@gmail.com>
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

/**
 * Responsible for handling HTTP GET & HEAD client requests.
 */
public class Rygel.HTTPGet : HTTPRequest {
    private const string TRANSFER_MODE_HEADER = "transferMode.dlna.org";
    private const string SERVER_NAME = "CVP2-RI-DMS";

    public Thumbnail thumbnail;
    public Subtitle subtitle;
    public HTTPSeek seek;
    public DLNAPlaySpeed speed;

    private int thumbnail_index;
    private int subtitle_index;

    public HTTPGetHandler handler;

    internal HTTPGet (HTTPServer   http_server,
                    Soup.Server  server,
                    Soup.Message msg) {
        base (http_server, server, msg);

        this.thumbnail_index = -1;
        this.subtitle_index = -1;
    }

    protected override async void handle () throws Error {
        var header = this.msg.request_headers.get_one
                                        ("getcontentFeatures.dlna.org");

        /* We only entertain 'HEAD' and 'GET' requests */
        if ((this.msg.method != "HEAD" && this.msg.method != "GET") ||
            (header != null && header != "1")) {
            throw new HTTPRequestError.BAD_REQUEST (_("Invalid Request"));
        }

        if (uri.transcode_target != null) {
            var transcoder = this.http_server.get_transcoder
                                        (uri.transcode_target);
            this.handler = new HTTPTranscodeHandler (transcoder,
                                                     this.cancellable);
        }

        if (uri.media_resource_name != null) {
            this.handler = new HTTPMediaResourceHandler (this.object as MediaItem,
                                                         uri.media_resource_name,
                                                         this.cancellable);
        }

        if (uri.playlist_format != null &&
            HTTPPlaylistHandler.is_supported (uri.playlist_format)) {
            this.handler = new HTTPPlaylistHandler (uri.playlist_format,
                                                    this.cancellable);
        }

        if (this.handler == null) {
            this.handler = new HTTPIdentityHandler (this.cancellable);
        }

        this.ensure_correct_mode ();

        yield this.handle_item_request ();
    }

    protected override async void find_item () throws Error {
        yield base.find_item ();

        // No need to do anything here, will be done in PlaylistHandler
        if (this.object is MediaContainer) {
            return;
        }

        if (unlikely ((this.object as MediaItem).place_holder)) {
            throw new HTTPRequestError.NOT_FOUND ("Item '%s' is empty",
                                                  this.object.id);
        }

        if (this.hack != null) {
            this.hack.apply (this.object);
        }

        if (this.uri.thumbnail_index >= 0) {
            if (this.object is MusicItem) {
                var music = this.object as MusicItem;
                this.thumbnail = music.album_art;

                return;
            } else if (this.object is VisualItem) {
                var visual = this.object as VisualItem;
                if (this.uri.thumbnail_index < visual.thumbnails.size) {
                    this.thumbnail = visual.thumbnails.get
                                            (this.uri.thumbnail_index);

                    return;
                }
            }

            throw new HTTPRequestError.NOT_FOUND
                                        ("No Thumbnail available for item '%s",
                                         this.object.id);
        }

        if (this.uri.subtitle_index >= 0 && this.object is VideoItem) {
            var video = this.object as VideoItem;

            if (this.uri.subtitle_index < video.subtitles.size) {
                this.subtitle = video.subtitles.get (this.uri.subtitle_index);

                return;
            }

            throw new HTTPRequestError.NOT_FOUND
                                        ("No subtitles available for item '%s",
                                         this.object.id);
        }
    }

    private async void handle_item_request () throws Error {
        var supports_time_seek = HTTPTimeSeek.supported (this);
        var requested_time_seek = HTTPTimeSeek.requested (this);
        var supports_byte_seek = HTTPByteSeek.supported (this);
        var requested_byte_seek = HTTPByteSeek.requested (this);
        // var supports_dtcp_seek = DTCPByteSeek.supported (this);
        // var requested_dtcp_seek = DTCPByteSeek.requested (this);

        if (requested_byte_seek && !supports_byte_seek) {
            throw new HTTPRequestError.UNACCEPTABLE ("Invalid byte seek request");
        }

        if (requested_time_seek && !supports_time_seek) {
            throw new HTTPRequestError.UNACCEPTABLE ("Invalid time seek request");
        }

        bool positive_rate = true;
        // Check for DLNA PlaySpeed request only if Range or Range.dtcp.com is not
        // in the request. DLNA 7.5.4.3.3.19.2, DLNA Link Protection : 7.6.4.4.2.12
        try {
            if (!requested_byte_seek && DLNAPlaySpeed.requested(this)) {
                this.speed = new DLNAPlaySpeed.from_request(this);
                positive_rate = this.speed.is_positive();
            } else {
                this.speed = null;
            }
        } catch (DLNAPlaySpeedError error) {
            this.server.unpause_message (this.msg);
            if (error is DLNAPlaySpeedError.INVALID_SPEED_FORMAT) {
                // TODO: log something?
                this.end (Soup.KnownStatusCode.BAD_REQUEST);
                // Per DLNA 7.5.4.3.3.16.3
            } else if (error is DLNAPlaySpeedError.SPEED_NOT_PRESENT) {
                // TODO: log something?
                this.end (Soup.KnownStatusCode.NOT_ACCEPTABLE);
                 // Per DLNA 7.5.4.3.3.16.5
            } else {
                throw error;
            }
            return;
        }

        try {
            // Find if the content has link protection flag in protocolInfo
            if (this.handler is HTTPMediaResourceHandler) {
                if ((this.handler as HTTPMediaResourceHandler)
                         .media_resource.is_link_protection_enabled()) {
                    // DLNA Link protection 7.6.4.2.8 , 7.6.4.2.7
                    if (this.msg.get_http_version() == Soup.HTTPVersion.@1_1) {
                        this.msg.response_headers.append ("Cache-control","no-cache");
                    }
                    this.msg.response_headers.append ("Pragma","no-cache");
                }
            }

            // Order is intentional here. Byte-range seek takes precedence
            // TODO: Add DTCPByteSeek logic
            // if (supports_dtcp_seek && requested_dtcp_seek) {
            //     this.seek = new DTCPByteSeek (this);
            if (supports_byte_seek && requested_byte_seek) {
                this.seek = new HTTPByteSeek (this);
            } else if (supports_time_seek && requested_time_seek) {
                this.seek = new HTTPTimeSeek (this, positive_rate);
            } else {
                this.seek = null;
            }
        } catch (HTTPSeekError error) {
            warning("Caught HTTPSeekError: " + error.message);
            this.server.unpause_message (this.msg);

            if (error is HTTPSeekError.INVALID_RANGE) {
                this.end (Soup.KnownStatusCode.BAD_REQUEST);
            } else if (error is HTTPSeekError.OUT_OF_RANGE) {
                this.end (Soup.KnownStatusCode.REQUESTED_RANGE_NOT_SATISFIABLE);
            } else {
                throw error;
            }

            return;
        }

        // Add headers
        // TODO: Should we have this after preroll()?
        // TODO: How much of the logic in this method should be in the base HTTPGetHandler?
        this.handler.add_response_headers (this);

        this.msg.response_headers.append ("Server",SERVER_NAME);

        HTTPResponse response = this.handler.render_body (this);

        // Have the response process the seek/speed request
        response.preroll();
        
        //
        // All response header generation below here depends upon the seek range/speed response
        //  fields being set (preroll() will have touched our seek/speed request-related
        //  response parameters)

        int64 response_size;
        // Determine the size value and response code
        {
            if (this.seek != null) {
                // See DLNA 7.5.4.3.2.22.4
                if (this.seek.byte_range_set()) {
                    // Note: This will work with all seek subtypes (when they set the byte range)
                    response_size = this.seek.length;
                } else { // A valid seek was requested, so we won't be sending the entire binary
                    response_size = 0;
                }
            } else if (this.handler is HTTPMediaResourceHandler) {
                // If a seek isn't included, we'll be returning the entire resource binary
                response_size = (this.handler as HTTPMediaResourceHandler)
                                .media_resource.size;
            } else if (this.handler.knows_size (this)) {
                // Still supporting the concept of MediaItem size (for now)
                response_size = (this.object as MediaItem).size;
            } else {
                response_size = 0;
            }
            if (response_size > 0) {
                this.msg.response_headers.set_content_length (response_size);
            }
            // size will factor into other logic below...
        }

        // Determine the transfer mode encoding
        {
            Soup.Encoding response_body_encoding;
            // See DLNA 7.5.4.3.2.15 for requirements
            if ( (this.speed != null) && (this.msg.get_http_version() != Soup.HTTPVersion.@1_0) ) {
                // We'll want the option to insert PlaySpeed position information
                //  whether or not we know the length (see DLNA 7.5.4.3.3.17)
                response_body_encoding = Soup.Encoding.CHUNKED;
            } else if (response_size > 0) {
                // TODO: Incorporate ChunkEncodingMode.dlna.org request into this logic
                response_body_encoding = Soup.Encoding.CONTENT_LENGTH;
            } else { // Response size is 0
                if (this.msg.get_http_version() == Soup.HTTPVersion.@1_0) {
                    // Can't sent the length and can't send chunked (in HTTP 1.0)...
                    // this.msg.response_headers.append ("Connection", "close");
                    response_body_encoding = Soup.Encoding.EOF;
                } else {
                    response_body_encoding = Soup.Encoding.CHUNKED;
                }
            }
            this.msg.response_headers.set_encoding (response_body_encoding);
        }

        // Insert the seek-related response headers
        if (this.seek != null) {
            this.seek.add_response_headers();
        }

        // Insert the speed-related response headers
        if (this.speed != null) {
            this.speed.add_response_headers(this);
        }

        // Determine the status code
        {
            int response_code;
            if (this.msg.response_headers.get_one ("Content-Range") != null) {
                response_code = Soup.KnownStatusCode.PARTIAL_CONTENT;
            } else {
                response_code = Soup.KnownStatusCode.OK;
            }
            this.msg.set_status (response_code);
        }

        message ("Following HTTP headers appended to response:");
        this.msg.response_headers.foreach ((name, value) => {
            message ("%s : %s", name, value);
        });

        if (this.msg.method == "HEAD") {
            // Only headers requested, no need to send contents
            this.server.unpause_message (this.msg);

            return;
        }

        yield response.run ();

        this.end (Soup.KnownStatusCode.NONE);
    }

    private void ensure_correct_mode () throws HTTPRequestError {
        var mode = this.msg.request_headers.get_one (TRANSFER_MODE_HEADER);
        var correct = true;

        switch (mode) {
        case "Streaming":
            correct = (!(this.handler is HTTPPlaylistHandler)) && (
                      (this.handler is HTTPTranscodeHandler ||
                      ((this.object as MediaItem).streamable () &&
                       this.subtitle == null &&
                       this.thumbnail == null)));

            break;
        case "Interactive":
            correct = (this.handler is HTTPIdentityHandler &&
                      ((!(this.object as MediaItem).is_live_stream () &&
                       !(this.object as MediaItem).streamable ()) ||
                       (this.subtitle != null ||
                        this.thumbnail != null))) ||
                      this.handler is HTTPPlaylistHandler;

            break;
        }

        if (!correct) {
            throw new HTTPRequestError.UNACCEPTABLE
                                        ("%s mode not supported for '%s'",
                                         mode,
                                         this.object.id);
        }
    }
}

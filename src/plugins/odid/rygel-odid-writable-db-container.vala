/*
 * Copyright (C) 2010 Jens Georg <mail@jensge.org>.
 *
 * Author: Jens Georg <mail@jensge.org>
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
 */

using Gee;

/**
 * A DB container that is both Trackable and Writable.
 *
 * Clients can upload items to this container, causing
 * the items to be saved to the filesystem to be
 * served again subsequently.
 */
internal class Rygel.ODID.WritableDbContainer : TrackableDbContainer,
                                                       Rygel.WritableContainer {
    public ArrayList<string> create_classes { get; set; }

    public WritableDbContainer (string id, string title) {
        Object (id : id,
                title : title,
                parent : null,
                child_count : 0);
    }

    public override void constructed () {
        base.constructed ();

        this.create_classes = new ArrayList<string> ();
        bool allow_upload = false;
        var upload_options = new Gee.ArrayList<string>();
        try {
            var config = MetaConfig.get_default ();
            allow_upload = config.get_allow_upload ();
            upload_options = config.get_string_list
                                    ("general", "upload-option");
        } catch (GLib.Error error) { }

        if (allow_upload) {
             // Items
            foreach (var option in upload_options) {
                if (option == "image-upload") {
                    this.create_classes.add (Rygel.ImageItem.UPNP_CLASS);
                    this.create_classes.add (Rygel.PhotoItem.UPNP_CLASS);
                } else if (option == "av-upload") {
                    this.create_classes.add (Rygel.VideoItem.UPNP_CLASS);
                } else if (option == "audio-upload") {
                    this.create_classes.add (Rygel.AudioItem.UPNP_CLASS);
                    this.create_classes.add (Rygel.MusicItem.UPNP_CLASS);
                    this.create_classes.add (Rygel.PlaylistItem.UPNP_CLASS);
                }
            }

            // Containers
            this.create_classes.add (Rygel.MediaContainer.UPNP_CLASS);
        }
    }

    public virtual async void add_item (Rygel.MediaItem item,
                                        Cancellable? cancellable)
                                        throws Error {
        item.parent = this;
        var file = File.new_for_uri (item.uris[0]);
        // TODO: Mark as place-holder. Make this proper some time.
        if (file.is_native ()) {
            item.modified = int64.MAX;
        }
        item.id = MediaCache.get_id (file.get_uri ());
        yield this.add_child_tracked (item);
        this.media_db.make_object_guarded (item);
    }

    public virtual async string add_reference (MediaObject  object,
                                               Cancellable? cancellable)
                                               throws Error {
        return MediaCache.get_default ().create_reference (object, this);
    }

    public virtual async void add_container (MediaContainer container,
                                             Cancellable?   cancellable)
                                             throws Error {
        container.parent = this;
        switch (container.upnp_class) {
        case MediaContainer.STORAGE_FOLDER:
        case MediaContainer.UPNP_CLASS:
            var file = File.new_for_uri (container.uris[0]);
            container.id = MediaCache.get_id (file.get_uri ());
            if (file.is_native ()) {
                file.make_directory_with_parents (cancellable);
            }
            break;
        default:
            throw new WritableContainerError.NOT_IMPLEMENTED
                                        ("upnp:class %s not supported",
                                         container.upnp_class);
        }

        yield this.add_child_tracked (container);
        this.media_db.make_object_guarded (container);
    }

    public virtual async void remove_item (string id, Cancellable? cancellable)
                                           throws Error {
        var object = this.media_db.get_object (id);

        yield this.remove_child_tracked (object);
    }

    public virtual async void remove_container (string id,
                                                Cancellable? cancellable)
                                                throws Error {
        var container = this.media_db.get_object (id);

        yield this.remove_child_tracked (container);
    }

}

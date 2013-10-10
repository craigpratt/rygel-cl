/*
 * Copyright (C) 2013 Intel Corporation.
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
 * Special class for the toplevel virtual container which aggregates all
 * playlists.
 *
 * This is a special class compared to the the other virtual classes as it
 * allows the creation of subfolders to create server-side playlists.
 * It does not allow adding or removal of items, only container adding and
 * removal.
 */
internal class Rygel.ODID.PlaylistRootContainer : Rygel.WritableContainer,
                                                         DBContainer {
    internal static const string ID = "virtual-parent:" +
                                      Rygel.PlaylistItem.UPNP_CLASS;
    internal static const string URI = WritableContainer.WRITABLE_SCHEME +
                                       "playlist-root";
    public ArrayList<string> create_classes { get; set; }

    public PlaylistRootContainer () {
        Object (id : ID,
                title : _("Playlists"),
                parent : null,
                child_count : 0);
    }

    public override void constructed () {
        base.constructed ();

        // We don't support adding real folders here, just playlist container
        this.create_classes = new ArrayList<string> ();
        this.create_classes.add (Rygel.MediaContainer.UPNP_CLASS);

        // Need to add an URI otherwise core doesn't mark the container as
        // writable
        this.uris.add (PlaylistRootContainer.URI);
    }

    public async void add_item (Rygel.MediaItem item,
                                Cancellable?    cancellable)
                                throws Error {
        throw new WritableContainerError.NOT_IMPLEMENTED
                                        (_("Can't create items in %s"),
                                         this.id);
    }

    public async void remove_item (string id,
                                   Cancellable? cancellable)
                                   throws Error {
        throw new WritableContainerError.NOT_IMPLEMENTED
                                        (_("Can't remove items in %s"),
                                         this.id);
   }

    public async void add_container (Rygel.MediaContainer container,
                                     Cancellable?         cancellable)
                                     throws Error {
        if (container.upnp_class != Rygel.MediaContainer.PLAYLIST &&
            container.upnp_class != Rygel.MediaContainer.UPNP_CLASS) {
            throw new WritableContainerError.NOT_IMPLEMENTED
                                        (_("upnp:class not supported in %s"),
                                         this.id);
        }

        container.id = "playlist:" + UUID.get ();
        container.upnp_class = Rygel.MediaContainer.PLAYLIST;

        this.media_db.save_container (container);
        this.media_db.make_object_guarded (container);
    }

    public async void remove_container (string id,
                                        Cancellable?    cancellable)
                                        throws Error {
        this.media_db.remove_by_id (id);
    }
 }

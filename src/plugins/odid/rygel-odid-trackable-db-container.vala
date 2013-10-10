/*
 * Copyright (C) 2012 Intel Corporation.
 *
 * Author: Jens Georg <jensg@openismus.com>
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
 * A DB container that is trackable.
 */
public class Rygel.ODID.TrackableDbContainer : DBContainer,
                                                      TrackableContainer {
    public TrackableDbContainer (string id, string title) {
        Object (id : id,
                title : title,
                parent : null,
                child_count : 0);
    }

    public override void constructed () {
        base.constructed ();

        this.child_added.connect (on_child_added);
        this.child_removed.connect (on_child_removed);
    }

    private void on_child_added (MediaObject object) {
        try {
            var cache = this.media_db;

            if (object is MediaItem) {
                cache.save_item (object as MediaItem);
            } else if (object is MediaContainer) {
                 cache.save_container (object as MediaContainer);
            } else {
                assert_not_reached ();
            }
            cache.save_container (this);
        } catch (Error error) {
            warning ("Failed to save object: %s", error.message);
        }
    }

    private void on_child_removed (MediaObject object) {
        try {
            this.media_db.save_container (this);
        } catch (Error error) {
            warning ("Failed to save object: %s", error.message);
        }
    }

    // TrackableContainer virtual function implementations:
    protected async void add_child (MediaObject object) {
        try {
            if (object is MediaItem) {
                this.media_db.save_item (object as MediaItem);
            } else if (object is MediaContainer) {
                this.media_db.save_container (object as MediaContainer);
            } else {
                assert_not_reached ();
            }
        } catch (Error error) {
            warning ("Failed to add object: %s", error.message);
        }
    }

    protected async void remove_child (MediaObject object) {
        try {
            this.media_db.remove_object (object);
        } catch (Error error) {
            warning ("Failed to remove object: %s", error.message);
        }
    }

    // TrackableContainer overrides
    public virtual string get_service_reset_token () {
        return this.media_db.get_reset_token ();
    }

    public virtual void set_service_reset_token (string token) {
        this.media_db.save_reset_token (token);
    }

    public virtual uint32 get_system_update_id () {
        // Get the last-known System Update ID,
        // from any previous run of this service,
        // based on the max ID found in the cache database.
        var id = this.media_db.get_update_id ();
        return id;
    }
}

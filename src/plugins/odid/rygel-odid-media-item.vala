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
 * Modifications made by Cable Television Laboratories, Inc.
 * Copyright (C) 2013  Cable Television Laboratories, Inc.
 * Contact: http://www.cablelabs.com/
 *
 * Author: Doug Galligan <doug@sentosatech.com>>
 */

using GUPnP;

public class Rygel.ODID.MediaItem : Rygel.MediaItem,
                                             Rygel.UpdatableObject,
                                             Rygel.ODID.UpdatableObject,
                                             Rygel.TrackableItem {
    public MediaItem (string         id,
                      MediaContainer parent,
                      string         title,
                      string         upnp_class = Rygel.VideoItem.UPNP_CLASS) {
        Object (id : id,
                parent : parent,
                title : title,
                upnp_class : upnp_class);
    }

    public void add_uri (string uri) {
        this.uris.add (uri);
    }

    public async void commit () throws Error {
        yield this.commit_custom (true);
    }

    public async void commit_custom (bool override_guarded) throws Error {
        this.changed ();
        var cache = MediaCache.get_default ();
        cache.save_item (this, override_guarded);
    }

    internal override DIDLLiteObject? serialize (Serializer serializer,
                                                 HTTPServer http_server)
                                                 throws Error {
        var didl_item = base.serialize (serializer, http_server) as DIDLLiteItem;

        serialize_resource_list (didl_item, http_server);

        return didl_item;
    }

    public override DataSource? create_stream_source_for_resource (HTTPRequest request,
                                                                   MediaResource resource) {
        if (this.uris.size == 0) {
            return null;
        }

        return MediaEngine.get_default ().create_data_source_for_resource (this, resource);
    }
}

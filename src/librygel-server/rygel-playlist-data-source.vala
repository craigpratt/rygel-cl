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
 * Author: Craig Pratt <craig@ecaspia.com>
 */

using GUPnP;

/**
 * Implementation of RygelDataSource to serve generated playlists to a client.
 */
internal class Rygel.PlaylistDatasource : Rygel.DataSource, Object {
    private MediaContainer container;
    private uint8[] data;
    private HTTPServer server;
    private ClientHacks hacks;
    private SerializerType playlist_type;

    public PlaylistDatasource (SerializerType playlist_type,
                               MediaContainer container,
                               HTTPServer     server,
                               ClientHacks?   hacks) {
        this.playlist_type = playlist_type;
        this.container = container;
        this.server = server;
        this.hacks = hacks;
        this.generate_data.begin ();
    }

    public signal void data_ready ();

    public Gee.List<HTTPResponseElement> ? preroll ( HTTPSeekRequest? seek_request,
                                                     PlaySpeedRequest? playspeed_request)
       throws Error {
        if (seek_request != null) {
            throw new DataSourceError.SEEK_FAILED
                                        (_("Seeking not supported"));
        }

        if (playspeed_request != null) {
            throw new DataSourceError.PLAYSPEED_FAILED
                                    (_("Speed not supported"));
        }

        return null;
    }

    public void start () throws Error {
        if (this.data == null) {
            this.data_ready.connect ( () => {
                try {
                    this.start ();
                } catch (Error error) { }
            });

            return;
        }

        Idle.add ( () => {
            this.data_available (this.data);
            this.done ();

            return false;
        });
    }

    public void freeze () { }

    public void thaw () { }

    public void stop () { }

    public async void generate_data () {
        try {
            var sort_criteria = this.container.sort_criteria;
            var count = this.container.child_count;

            var children = yield this.container.get_children (0,
                                                              count,
                                                              sort_criteria,
                                                              null);

            if (children != null) {
                var serializer = new Serializer (this.playlist_type);
                children.serialize (serializer, this.server, this.hacks);

                var xml = serializer.get_string ();

                this.data = xml.data;
                this.data_ready ();
            } else {
                this.error (new DataSourceError.GENERAL
                                        (_("Failed to generate playlist")));
            }
        } catch (Error error) {
            warning ("Could not generate playlist: %s", error.message);
            this.error (error);
        }
    }
}

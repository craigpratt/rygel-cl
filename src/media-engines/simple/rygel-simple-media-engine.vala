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

/**
 * The simple media engine does not use GStreamer or any other
 * multimedia framework. Therefore its capabilities are limited.
 *
 * It does not support transcoding - get_transcoders() returns null.
 * Also, its RygelSimpleDataSource does not support time-base seeking.
 */
internal class Rygel.SimpleMediaEngine : MediaEngine {
    private List<DLNAProfile> profiles = new List<DLNAProfile> ();

    public SimpleMediaEngine () { }

    public override unowned List<DLNAProfile> get_dlna_profiles() {
        return this.profiles;
    }

    public override Gee.List<MediaResource>? get_resources_for_uri(string uri) {
        // TODO: Implement me
        return null;
    }

    public override unowned List<Transcoder>? get_transcoders () {
        return null;
    }

    public override DataSource? create_data_source_for_resource
                                (string uri, MediaResource ? resource) {
        if (!uri.has_prefix ("file://")) {
            return null;
        }
        debug("creating data source for %s", uri);
        return new SimpleDataSource (uri);
    }
}

public static Rygel.MediaEngine module_get_instance () {
    return new Rygel.SimpleMediaEngine ();
}

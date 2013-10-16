/*
 * Copyright (C) 2008 Zeeshan Ali <zeenix@gmail.com>.
 * Copyright (C) 2010 Nokia Corporation.
 * Copyright (C) 2012 Intel Corporation.
 *
 * Author: Zeeshan Ali (Khattak) <zeeshanak@gnome.org>
 *                               <zeeshan.ali@nokia.com>
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
 * Author: Craig Pratt <craig@ecaspia.com>
 */

using GUPnP;

private errordomain Rygel.MediaItemError {
    BAD_URI
}

/**
 * Represents a media item (Music, Video or Image).
 *
 * These objects correspond to items in the UPnP ContentDirectory's DIDL-Lite XML.
 */
public abstract class Rygel.MediaItem : MediaObject {
    // Resource info
    // TODO: Remove me (this will be in MediaResource)
    public string mime_type { get; set; }
    public string dlna_profile { get; set; }

    // Size in bytes
    // TODO: Remove me (this will be in MediaResource)
    private int64 _size = -1;
    public int64 size {
        get {
            return this._size;
        }

        set {
            if (value == 0) {
                this.place_holder = true;
            }

            this._size = value;
        }
    }   // Size in bytes

    public bool place_holder { get; set; default = false; }

    public string description { get; set; default = null; }

    // Note: MediaResources are ordered from most- to least-preferred
    public Gee.List<MediaResource> media_resources { get; set; default = null; }

    public override OCMFlags ocm_flags {
        get {
            var flags = OCMFlags.NONE;

            if (this.place_holder) {
                // Place-holder items are always destroyable.
                flags |= OCMFlags.DESTROYABLE;
            } else {
                var config = MetaConfig.get_default ();
                var allow_deletion = true;

                try {
                    allow_deletion = config.get_allow_deletion ();
                } catch (Error error) {}

                if (allow_deletion) {
                    flags |= OCMFlags.DESTROYABLE;
                }
            }

            if (this is UpdatableObject) {
                flags |= OCMFlags.CHANGE_METADATA;
            }

            return flags;
        }
    }

    protected static Regex address_regex;

    public MediaItem (string         id,
                      MediaContainer parent,
                      string         title,
                      string         upnp_class) {
        Object (id : id,
                parent : parent,
                title : title,
                upnp_class : upnp_class);
    }

    static construct {
        try {
            address_regex = new Regex (Regex.escape_string ("@ADDRESS@"));
        } catch (GLib.RegexError err) {
            assert_not_reached ();
        }
    }

    // Live media items need to provide a nice working implementation of this
    // method if they can/do not provide a valid URI
    public virtual DataSource? create_stream_source_for_resource (string? host_ip = null,
                                                                  MediaResource? resource = null) {
        if (this.uris.size == 0) {
            return null;
        }

        string translated_uri = this.uris.get (0);
        if (host_ip != null) {
            try {
                translated_uri = MediaItem.address_regex.replace_literal
                    (this.uris.get (0), -1, 0, host_ip);
            } catch (Error error) {
                assert_not_reached ();
            }
        }

        return MediaEngine.get_default ().create_data_source_for_resource (translated_uri, resource);
    }

    public bool is_live_stream () {
        return this.streamable () && this.size <= 0;
    }

    public abstract bool streamable ();

    public virtual void add_uri (string uri) {
        this.uris.add (uri);
    }

    internal int compare_transcoders (Transcoder transcoder1,
                                      Transcoder transcoder2) {
        return (int) transcoder1.get_distance (this) -
               (int) transcoder2.get_distance (this);
    }

    internal override DIDLLiteResource add_resource
                                        (DIDLLiteObject didl_object,
                                         string?        uri,
                                         string         protocol,
                                         MediaResource  resource,
                                         string?        import_uri = null)
                                         throws Error {
        var res = base.add_resource (didl_object,
                                     uri,
                                     protocol,
                                     resource,
                                     import_uri);

        if (uri != null && !this.place_holder) {
            res.uri = uri;
        } else {
            // Set empty string otherwise gupnp-av (libxml actually) will add
            // a self-enclosing node in the DIDL-Lite which is not very much
            // appreciated by UPnP devices using crappy XML parsers.
            res.uri = "";
        }

        if (import_uri != null && this.place_holder) {
            res.import_uri = import_uri;
        }

        if (this is TrackableItem) {
            // This is attribute is mandatory for track changes
            // implementation. We don't really support updating the resources
            // so we just set it to 0.
            res.update_count = 0;
        }

        return res;
    }

    internal override int compare_by_property (MediaObject media_object,
                                               string      property) {
        if (!(media_object is MediaItem)) {
           return 1;
        }

        var item = media_object as MediaItem;

        switch (property) {
        case "dc:creator":
            return this.compare_string_props (this.creator, item.creator);
        case "dc:date":
            return this.compare_by_date (item);
        default:
            return base.compare_by_property (item, property);
        }
    }

    internal override void apply_didl_lite (DIDLLiteObject didl_object) {
        base.apply_didl_lite (didl_object);

        this.creator = didl_object.get_creator ();
        this.date = didl_object.date;
        this.description = didl_object.description;
    }

    internal override DIDLLiteObject? serialize (Serializer serializer,
                                                 HTTPServer http_server)
                                                 throws Error {
        var didl_item = serializer.add_item ();

        didl_item.id = this.id;

        if (this.ref_id != null) {
            didl_item.ref_id = this.ref_id;
        }

        if (this.parent != null) {
            didl_item.parent_id = this.parent.id;
        } else {
            didl_item.parent_id = "0";
        }

        if (this.restricted) {
            didl_item.restricted = true;
        } else {
            didl_item.restricted = false;
            didl_item.dlna_managed = this.ocm_flags;
        }

        didl_item.title = this.title;
        didl_item.upnp_class = this.upnp_class;

        if (this.date != null) {
            didl_item.date = this.date;
        }

        if (this.creator != null && this.creator != "") {
            var creator = didl_item.add_creator ();
            creator.name = this.creator;
        }

        if (this.description != null) {
            didl_item.description = this.description;
        }

        if (this is TrackableItem) {
            didl_item.update_id = this.object_update_id;
        }

        /* We list proxy/transcoding resources first instead of original URIs
         * because some crappy MediaRenderer/ControlPoint implemenation out
         * there just choose the first one in the list instead of the one they
         * can handle.
         */
        if (!this.place_holder) {
            this.write_didl_lite_for_resources (http_server, didl_item);
            var host_ip = http_server.context.host_ip;

            // then original URIs
            bool internal_allowed;
            internal_allowed = http_server.context.interface == "lo" ||
                               host_ip == "127.0.0.1";
            this.add_resources (didl_item, internal_allowed);

            foreach (var res in didl_item.get_resources ()) {
                res.uri = MediaItem.address_regex.replace_literal (res.uri,
                                                                   -1,
                                                                   0,
                                                                   host_ip);
            }
        }

        return didl_item;
    }

    internal virtual void add_proxy_resources (HTTPServer   server,
                                               DIDLLiteItem didl_item)
                                               throws Error {
    }

    internal void write_didl_lite_for_resources(HTTPServer server, DIDLLiteItem didl_item) {
        foreach (var resource in media_resources) {
            // We create URIs here, arguably, so that the URI address can be written to
            //  incorporate the interface address the request was received on (but if a
            //  MediaItem subclass is created for each browse, perhaps it would be more
            //  appropriate to have this done at initialization instead of using lazy
            //  initialization?)
            if (resource.uri == null || resource.uri.length == 0) {
                var uri = server.create_uri_for_item (this,
                                                       -1,
                                                       -1,
                                                       this.dlna_profile,
                                                       // TODO: resource.protocol_info.dlna_profile?
                                                       null,
                                                       resource);
                resource.uri = uri;
            } else {
                // We'll be here if the MediaEngine supplied a URI. This is the temporary
                //  way to support external URIs (e.g. MPEG-DASH MPDs). Eventually external
                //  resources/URIs should be setup by the MediaServer.
                debug("Found MediaResource with pre-existing URI: " + resource.uri);
            }

            DIDLLiteResource didl_resource = didl_item.add_resource();
            resource.write_didl_lite(didl_resource);
        }
    }

    protected virtual ProtocolInfo get_protocol_info (string? uri,
                                                      string  protocol,
                                                      MediaResource resource) {
        // TODO: REMOVE ME - This should be on MediaResource
        var protocol_info = new ProtocolInfo ();

        protocol_info.mime_type = resource.protocol_info.mime_type;
        protocol_info.dlna_profile = resource.protocol_info.dlna_profile;
        protocol_info.protocol = protocol;
        // Seems like these are properties of the MediaServer
        protocol_info.dlna_flags = DLNAFlags.DLNA_V15 |
                                   DLNAFlags.CONNECTION_STALL |
                                   DLNAFlags.BACKGROUND_TRANSFER_MODE;

        if (this.size > 0) {
            protocol_info.dlna_operation = DLNAOperation.RANGE;
        }

        if (this.streamable ()) {
            protocol_info.dlna_flags |= DLNAFlags.STREAMING_TRANSFER_MODE;
        }

        return protocol_info;
    }

    internal string get_protocol_for_uri (string uri) throws Error {
        var scheme = Uri.parse_scheme (uri);
        if (scheme == null) {
            throw new MediaItemError.BAD_URI (_("Bad URI: %s"), uri);
        }

        if (scheme == "http") {
            return "http-get";
        } else if (scheme == "file") {
            return "internal";
        } else if (scheme == "rtsp") {
            // FIXME: Assuming that RTSP is always accompanied with RTP over UDP
            return "rtsp-rtp-udp";
        } else {
            // Assume the protocol to be the scheme of the URI
            warning (_("Failed to probe protocol for URI %s. Assuming '%s'"),
                     uri,
                     scheme);

            return scheme;
        }
    }

    protected virtual void add_resources (DIDLLiteItem didl_item,
                                          bool         allow_internal)
                                          throws Error {
        foreach (MediaResource resource in this.media_resources) {
            var protocol = this.get_protocol_for_uri (this.uris[0]);

            if (allow_internal || protocol != "internal") {
                this.add_resource (didl_item, this.uris[0], protocol, resource);
            }
        }
    }

    private int compare_by_date (MediaItem item) {
        if (this.date == null) {
            return -1;
        } else if (item.date == null) {
            return 1;
        } else {
            var our_date = this.date;
            var other_date = item.date;

            if (!our_date.contains ("T")) {
                our_date += "T00:00:00Z";
            }

            if (!other_date.contains ("T")) {
                other_date += "T00:00:00Z";
            }

            var tv1 = TimeVal ();
            assert (tv1.from_iso8601 (this.date));

            var tv2 = TimeVal ();
            assert (tv2.from_iso8601 (item.date));

            var ret = this.compare_long (tv1.tv_sec, tv2.tv_sec);
            if (ret == 0) {
                ret = this.compare_long (tv1.tv_usec, tv2.tv_usec);
            }

            return ret;
        }
    }

    private int compare_long (long a, long b) {
        if (a < b) {
            return -1;
        } else if (a > b) {
            return 1;
        } else {
            return 0;
        }
    }
}

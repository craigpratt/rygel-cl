/*
 * Copyright (C) 2013 CableLabs
 *
 * This file is part of Rygel.
 */

using GUPnP;

/**
 * Represents a media resource (Music, Video or Image).
 *
 * These objects correspond to items res blocks in the UPnP ContentDirectory's DIDL-Lite XML.
 */
public abstract class Rygel.MediaResource : GLib.Object {
    public MediaItem parent_item {
        get {
            return this.parent_item;
        }
        private set {
            this.parent_item = value;
        }
    }
    public string mime_type { get; set; }
    public string dlna_profile { get; set; }
    public string uri { get; set; }
    public int64 size { get; set; default = -1; }
    public int64 cleartext_size { get; set; default = -1; }
    public ProtocolInfo protcol_info { get; set; default = null; }
    public long duration { get; set; default = -1; }
    public int bitrate { get; set; default = -1; }
    public int bits_per_sample { get; set; default = -1; }
    public int color_depth { get; set; default = -1; }
    public int width { get; set; default = -1; }
    public int height { get; set; default = -1; }
    public int audio_channels { get; set; default = -1; }
    public int sample_freq { get; set; default = -1; }

    protected static Regex address_regex;

    static construct {
        try {
            address_regex = new Regex (Regex.escape_string ("@ADDRESS@"));
        } catch (GLib.RegexError err) {
            assert_not_reached ();
        }
    }

    public MediaResource (MediaItem parent) {
        this.parent_item = parent;
    }

    public void apply_didl_lite (DIDLLiteResource didl_resource) {
        //  Populate the MediaResource from the given DIDLLiteResource
        this.uri = didl_resource.uri;
        this.size = didl_resource.size64;
        // Note: No cleartext size in DIDLLiteResource currently
        this.protcol_info = didl_resource.protocol_info;
        this.duration = didl_resource.duration;
        this.bitrate = didl_resource.bitrate;
        this.bits_per_sample = didl_resource.bits_per_sample;
        this.color_depth = didl_resource.color_depth;
        this.width = didl_resource.width;
        this.height = didl_resource.height;
        this.audio_channels = didl_resource.audio_channels;
        this.sample_freq = didl_resource.sample_freq;
    }

    internal DIDLLiteResource? serialize (HTTPServer http_server)
                                                   throws Error {
        var didl_resource = new DIDLLiteResource ();

        // Note: No cleartext size in DIDLLiteResource currently

        didl_resource.size64 = this.size;
        // Note: No cleartext size in DIDLLiteResource currently
        didl_resource.protocol_info = this.protcol_info;
        didl_resource.duration = this.duration;
        didl_resource.bitrate = this.bitrate;
        didl_resource.bits_per_sample = this.bits_per_sample;
        didl_resource.color_depth = this.color_depth;
        didl_resource.width = this.width;
        didl_resource.height = this.height;
        didl_resource.audio_channels = this.audio_channels;
        didl_resource.sample_freq = this.sample_freq;
        
        var host_ip = http_server.context.host_ip;
        didl_resource.uri = address_regex.replace_literal (didl_resource.uri, -1, 0, host_ip);

        return didl_resource;
    }
}

/*
 * Copyright (C) 2013 CableLabs
 *
 * This file is part of Rygel.
 */

using GUPnP;
using Gee;

/**
 * Represents a media resource (Music, Video, Image, etc).
 */
public class Rygel.MediaResource : GLib.Object {
    
    private string name;
    public string uri { get; set; }
    public ProtocolInfo protocol_info { get; set; default = null; }
    public string extension { get; set; default = null; }
    public int64 size { get; set; default = -1; }
    public int64 cleartext_size { get; set; default = -1; }
    public long duration { get; set; default = -1; }
    public int bitrate { get; set; default = -1; }
    public int bits_per_sample { get; set; default = -1; }
    public int color_depth { get; set; default = -1; }
    public int width { get; set; default = -1; }
    public int height { get; set; default = -1; }
    public int audio_channels { get; set; default = -1; }
    public int sample_freq { get; set; default = -1; }
    
    public MediaResource(string name) {
        this.name = name;
    }

    public string get_name()
    {
        return this.name;
    }

    private HashMap<string,string> property_table = new HashMap<string,string>();

    public void set_custom_property(string ? name, string ? value) {
        property_table.set(name,value);
    }

    public string get_custom_property(string ? name) {
        return property_table.get(name);
    }

    public Set get_custom_property_names() {
        return property_table.keys;
    }

    public void apply_didl_lite (DIDLLiteResource didl_resource) {
        //  Populate the MediaResource from the given DIDLLiteResource
        // Note: For a DIDLLiteResource, a value of -1/null also signals "not set"
        this.uri = didl_resource.uri;
        this.size = didl_resource.size64;
        this.cleartext_size = didl_resource.cleartextSize;
        this.protocol_info = didl_resource.protocol_info;
        this.duration = didl_resource.duration;
        this.bitrate = didl_resource.bitrate;
        this.bits_per_sample = didl_resource.bits_per_sample;
        this.color_depth = didl_resource.color_depth;
        this.width = didl_resource.width;
        this.height = didl_resource.height;
        this.audio_channels = didl_resource.audio_channels;
        this.sample_freq = didl_resource.sample_freq;
    }
    
    public DIDLLiteResource write_didl_lite (DIDLLiteResource didl_resource) {
        // Note: For a DIDLLiteResource, a value of -1/null also signals "not set"
        didl_resource.uri = this.uri;
        didl_resource.size64 = this.size;
        didl_resource.cleartextSize = this.cleartext_size;
        didl_resource.protocol_info = this.protocol_info;
        didl_resource.duration = this.duration;
        didl_resource.bitrate = this.bitrate;
        didl_resource.bits_per_sample = this.bits_per_sample;
        didl_resource.color_depth = this.color_depth;
        didl_resource.width = this.width;
        didl_resource.height = this.height;
        didl_resource.audio_channels = this.audio_channels;
        didl_resource.sample_freq = this.sample_freq;
        
        return didl_resource;
    }

    public bool supports_arbitrary_byte_seek() {
        bool supported = ((this.protocol_info.dlna_operation & DLNAOperation.RANGE) != 0);
        return supported;
    }

    public bool supports_arbitrary_time_seek() {
        bool supported = ((this.protocol_info.dlna_operation & DLNAOperation.TIMESEEK) != 0);
        return supported;
    }
    
    public bool supports_limited_byte_seek() {
        return check_flag (this.protocol_info,DLNAFlags.BYTE_BASED_SEEK);
    }
    
    public bool supports_limited_time_seek() {
        return check_flag (this.protocol_info,DLNAFlags.TIME_BASED_SEEK);
    }

    public bool supports_limited_cleartext_byte_seek() {
        return check_flag (this.protocol_info,DLNAFlags.LOP_CLEARTEXT_BYTESEEK);
    }

    public bool supports_full_cleartext_byte_seek() {
        return check_flag (this.protocol_info,DLNAFlags.CLEARTEXT_BYTESEEK_FULL);
    }

    private bool check_flag (ProtocolInfo protocol_info, int flag) {
        long flag_value = long.parse ("%0.8d".printf (protocol_info.dlna_flags));
        return ((flag_value & flag) == flag);
    }

    public bool supports_playspeed() {
        return (this.protocol_info.play_speeds.length > 0);
    }
    
    public string to_string() {
        // TODO: incorporate all set fields
        return name + ":{" + ((protocol_info == null) ? "null" : protocol_info.to_string());
    }
}

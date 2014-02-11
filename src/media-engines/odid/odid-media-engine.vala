/*
 * Copyright (C) 2013  Cable Television Laboratories, Inc.
 * Contact: http://www.cablelabs.com/
 *
 * Author: Craig Pratt <craig@ecaspia.com>
 *         Parthiban Balasubramanian <P.Balasubramanian-contractor@cablelabs.com>
 *         Prasanna Modem <prasanna@ecaspia.com>
 *
 * This file is part of Rygel.
 *
 * Rygel is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
 * IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL CABLE TELEVISION LABORATORIES
 * INC. OR ITS CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 * TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

using Gee;
using GUPnP;
using Dtcpip;

public errordomain Rygel.ODIDMediaEngineError {
    CONFIG_ERROR,
    INDEX_FILE_ERROR
}

private static const int NANOS_PER_SEC = 1000000000;
private static const int MICROS_PER_SEC = 1000000;
private static const int MILLIS_PER_SEC = 1000;
private static const int MICROS_PER_MILLI = 1000;
public static const int64 KILOBYTES_TO_BYTES = 1024;

/**
 * This media engine is intended to be the basis for the CL
 * reference DMS. Long-term, this could be moved outside the Rygel
 * source tree and built stand-alone.
 */
internal class Rygel.ODIDMediaEngine : MediaEngine {
    private  GLib.List<DLNAProfile> profiles
        = new GLib.List<DLNAProfile> ();

    // Variable to hold chunk size for streaming
    public int64 chunk_size;

    // DTCP control variables
    private bool dtcp_initialized;
    private string dtcp_storage;
    private ushort dtcp_port; // Default DTCP port is 8999
    private string dtcp_host;

    // Control channel
    private ODIDControlChannel control_channel;

    // Live control variables
    private bool autostart_live_sims;
    private int live_sim_reset_s; // In seconds
    private HashTable <string, ODIDLiveSimulator> live_sim_table;

    public ODIDMediaEngine () {
        debug ("constructing");
        var config = MetaConfig.get_default ();

        try {
            var chunk_size_str = config.get_string ("OdidMediaEngine", "chunk-size");
            this.chunk_size = int64.parse (chunk_size_str) * KILOBYTES_TO_BYTES;
        } catch (Error err) {
            debug ("Error reading ODIDMediaEngine property: " + err.message);
            this.chunk_size = 1536 * KILOBYTES_TO_BYTES;
        }
        message ("chunk size: %lld bytes", this.chunk_size);

        try {
            this.dtcp_initialized = false;
            bool dtcp_enabled = config.get_bool ("OdidMediaEngine", "dtcp-enabled");
            if (dtcp_enabled) {
                this.dtcp_storage = config.get_string ("OdidMediaEngine", "dtcp-storage");
                this.dtcp_host = config.get_string ("OdidMediaEngine", "dtcp-host");
                this.dtcp_port = (ushort)config.get_int ("OdidMediaEngine", "dtcp-port",
                                                         6000, 8999);
                if (Dtcpip.init_dtcp_library (dtcp_storage) != 0) {
                    error ("DTCP-IP init failed for storage path: %s",dtcp_storage);
                } else {
                    debug ("DTCP-IP storage loaded successfully");
                    if (Dtcpip.server_dtcp_init (dtcp_port) != 0) {
                        error ("DTCP-IP source init failed: host %s, port %d, storage %s",
                               this.dtcp_host, this.dtcp_port, this.dtcp_storage);
                    } else {
                        this.dtcp_initialized = true;
                        message ("dtcp-ip initialized: host %s, port %d, storage %s",
                                 this.dtcp_host, this.dtcp_port, this.dtcp_storage);
                    }
                }
            } else {
                message ("dtcp-ip disabled");
            }
        } catch (Error err) {
            error ("Error initializing DTCP: " + err.message);
        }

        Gee.ArrayList<string> profiles_config;
        try {
            profiles_config = config.get_string_list ("OdidMediaEngine", "profiles");
        } catch (Error err) {
            debug ("Error reading profiles: " + err.message);
            profiles_config = new Gee.ArrayList<string> ();
        }

        foreach (var row in profiles_config) {
            var columns = row.split (",");
            if (columns.length < 2) {
                debug ("OdidMediaEngine profile entry \""
                       + row + "\" is malformed: Expected 2 entries and found "
                       + columns.length.to_string () );
                break;
            }

            message ("OdidMediaEngine: configuring profile entry: " + row);
            // Note: This profile list won't affect what profiles are included in the
            //       primary res block
            profiles.append (new DLNAProfile (columns[0],columns[1]));
        }

        uint16 control_port;
        try {
            control_port = (uint16)config.get_int ("OdidMediaEngine", "control-port",
                                                   1025, 8999);
        } catch (Error err) {
            debug ("Could not read control-port setting: " + err.message);
            control_port = 0;
        }
        if (control_port > 0) {
            // Start the control channel listener
            var cancellable = new Cancellable ();
            cancellable.connect (() => {
                message ("Control channel listener canceled");
            });
            this.control_channel = new ODIDControlChannel (control_port, process_command);
            control_channel.listen.begin (cancellable);
            message ("control channel started on port %d", control_port);
        } else {
            message ("control channel is disabled");
        }

        // Live simulation control variables
        try {
            this.autostart_live_sims = (config.get_string ("OdidMediaEngine",
                                                           "live-sim-start-mode")
                                        == "on-demand");
        } catch (Error err) {
            this.autostart_live_sims = true;
            debug ("Could not read live-sim-start-mode value (%s)", err.message);
        }
        message ("live simulator start mode: %s",
               this.autostart_live_sims ? "on-demand" : "manual");
        try {
            this.live_sim_reset_s = (uint16)config.get_int ("OdidMediaEngine",
                                                            "live-sim-autoreset-time",
                                                            0, uint16.MAX);
        } catch (Error err) {
            debug ("Could not read live-sim-autoreset-time value: " + err.message);
            this.live_sim_reset_s = 60;
        }
        message ("live simulator autoreset time: %s",
               (this.live_sim_reset_s == 0) ? "disabled" : "%d seconds".printf(live_sim_reset_s) );
        live_sim_table = new HashTable<string, ODIDLiveSimulator> (str_hash, str_equal);
    }

    public override unowned GLib.List<DLNAProfile> get_dlna_profiles () {
        debug ("get_dlna_profiles");
        return this.profiles;
    }

    public override async Gee.List<MediaResource> ? get_resources_for_item
                                                        (MediaObject object) {
        // TODO: Change this to "object is OdidMediaItem"
        if (! (object is MediaItem)) {
            warning ("Can only process odid MediaObjects (OdidMediaItems)");
            return null;
        }

        var item = object as MediaItem;

        // For MediaFileItems, uri 0 is the file URI referring directly to
        //  the content. But for us, we're presuming it refers to the ODID item file
        string item_info_uri = item.uris.get (0);

        debug ("OdidMediaEngine:get_resources: " + item_info_uri);

        Gee.List<MediaResource> resources = new Gee.ArrayList<MediaResource> ();

        try {
            string item_uri = ODIDUtil.get_item_uri (item_info_uri);
            debug ("get_resources: processing item directory: " + item_uri);
            var directory = File.new_for_uri (item_uri);
            var enumerator = directory.enumerate_children
                                           (FileAttribute.STANDARD_NAME, 0);
            FileInfo file_info;
            while ((file_info = enumerator.next_file ()) != null) {
                if (file_info.get_file_type () == FileType.DIRECTORY) {
                    debug ("get_resources:  processing resource directory: "
                           + file_info.get_name ());
                    // A directory in an item directory is a resource
                    try {
                        string resource_uri = item_uri + file_info.get_name () + "/";
                        ODIDLiveSimulator live_sim = null;
                        if (ODIDUtil.get_resource_property (resource_uri, "live") == "true") {
                            live_sim = find_live_sim_or_create (item_info_uri, resource_uri);
                        }
                        var res = create_resource (resource_uri, live_sim);
                        if (res != null) {
                            resources.add (res);
                            debug ("get_resources:   created resource: " + res.to_string ());
                            if (live_sim != null) {
                                live_sim.started_signal.connect (sim_started);
                                live_sim.stopped_signal.connect (sim_stopped);
                                live_sim.reset_signal.connect (sim_reset);
                            }
                        }
                    } catch (Error err) {
                        warning ("Error processing item resource %s: %s",
                                 item_uri + file_info.get_name (), err.message);
                        // Continue processing other resources
                    }
                }
            }
        } catch (Error err) {
            warning ("Error creating resources for source %s: %s",
                     item_info_uri, err.message);
        }

        return resources;
    }

    /**
     * Construct a MediaResource from an on-disk resource
     *
     * @param res_dir_uri URI to the resource directory.
     * @return MediaResource constructed from the on-disk resource directory
     */
    internal MediaResource ? create_resource (string res_dir_uri, ODIDLiveSimulator ? live_sim)
         throws Error {
        debug ("OdidMediaEngine:create_resource: configuring resources for "
               + res_dir_uri);

        var res_dir = File.new_for_uri (res_dir_uri);
        var short_res_path = ODIDUtil.short_resource_path (res_dir_uri);
        var res_dir_info = res_dir.query_info (GLib.FileAttribute.STANDARD_NAME, 0);
        var res = new MediaResource (res_dir_info.get_name ());
        // Assert: All res values are set to sane/unset defaults

        string basename = null;
        bool dtcp_protected = false;
        bool is_converted = false;
        bool is_live_mode = false;
        int limited_operation_mode = -1;

        // Process fields set in the resource.info
        {
            File res_info_file = File.new_for_uri (res_dir_uri + "/resource.info");
            var dis = new DataInputStream (res_info_file.read ());
            string line;
            int line_num = 0;
            while ((line = dis.read_line (null)) != null) {
                line_num++;
                line = line.strip ();
                if ((line.length == 0) || (line[0] == '#')) continue;
                var equals_pos = line.index_of ("=");
                if (equals_pos < 0)  {
                    warning ("Bad entry: %s line %d: %s",
                             res_dir_uri, line_num, line);
                    continue;
                }
                var name = line[0:equals_pos];
                var value = line[equals_pos+1:line.length];

                if ((name == null) || (value == null))  {
                    warning ("Bad entry: %s line %d: %s",
                             res_dir_uri, line_num, line);
                    continue;
                }
                name = name.strip ();
                value = value.strip ();

                if (name == "basename") {
                    basename = value;
                    continue;
                }
                if (name == "protected") {
                    dtcp_protected = (value == "true") && dtcp_initialized;
                    continue;
                }
                if (name == "converted") {
                    is_converted = (value == "true");
                    continue;
                }
                if (name == "live") {
                    is_live_mode = (value == "true");
                    continue;
                }
                if (name == "limited-operation-mode") {
                    limited_operation_mode = int.parse (value);
                    if (limited_operation_mode < 0 || limited_operation_mode > 1) {
                        throw new ODIDMediaEngineError.CONFIG_ERROR
                                      ("Invalid limited-operation-mode: " + value);
                    }
                    continue;
                }
                if (name.length > 0 && value.length > 0) {
                    set_resource_field (res, name, value);
                }
            }
        }

        // Modify the profile & mime type for DTCP, if necessary
        if (dtcp_protected) {
            res.mime_type = dtcp_mime_type_for_mime_type (res.mime_type);
            res.dlna_profile = "DTCP_" + res.dlna_profile;
        }

        if (res.uri != null) {
            // Our URI (and content) is not Rygel-hosted. So no need to look for content
            //  (there really shouldn't be any...)
            debug ("%s: Found URI in resource metadata: %s", short_res_path, res.uri);
            return res;
        }

        // Check for required properties
        if (basename == null) {
            throw new ODIDMediaEngineError.CONFIG_ERROR
                          ("No basename property set for resource");
        }

        // Common flags/settings
        res.dlna_flags = DLNAFlags.DLNA_V15
                         | DLNAFlags.STREAMING_TRANSFER_MODE
                         | DLNAFlags.BACKGROUND_TRANSFER_MODE
                         | DLNAFlags.CONNECTION_STALL;
        res.dlna_conversion = is_converted ? DLNAConversion.TRANSCODED
                                           : DLNAConversion.NONE;

        string file_extension;
        string normal_content_filename;
        normal_content_filename = ODIDUtil.content_filename_for_res_speed
                                                      (res_dir_uri, basename, null,
                                                       out file_extension);
        res.extension = file_extension;
        File normal_content_file = File.new_for_uri (res_dir_uri + normal_content_filename);
        File normal_content_index_file = File.new_for_uri (res_dir_uri
                                                           + normal_content_filename
                                                           + ".index");
        if (!normal_content_file.query_exists ()) {
            throw new ODIDMediaEngineError.CONFIG_ERROR
                          ("Content file %s not found/accessible: " + normal_content_filename);
        }

        // We won't directly set the byteseek operation mode in this block since the
        //  content protection applied will affect how byteseek operation is exposed
        int64 byte_range_start = -1;
        DLNAFlags byteseek_flags = DLNAFlags.NONE;
        DLNAOperation byteseek_operations = DLNAOperation.NONE;
        FileInfo content_info = normal_content_file.query_info
                                    (GLib.FileAttribute.STANDARD_SIZE, 0);
        if (is_live_mode) {
            if (live_sim == null) {
                throw new ODIDMediaEngineError.CONFIG_ERROR
                              ("Attempted to create live resource without live source: "
                               + res_dir_uri);
            }

            if (!normal_content_index_file.query_exists ()) {
                throw new ODIDMediaEngineError.CONFIG_ERROR
                              ("Live streaming not supported without an index file: "
                               + res_dir_uri);
            }

            switch (live_sim.get_state ()) {
                case ODIDLiveSimulator.State.UNSTARTED:
                    // We're going to make it look live, but frozen in "first position"
                case ODIDLiveSimulator.State.ACTIVE:
                    debug ("create_resource: %s (%s): no size/duration, paced SN increasing",
                           short_res_path, live_sim.get_state_string ());
                    res.dlna_flags |= DLNAFlags.SN_INCREASE
                                      | DLNAFlags.SENDER_PACED; // Content will be paced at Sn
                    switch (live_sim.get_mode ()) {
                        case ODIDLiveSimulator.Mode.S0_FIXED:
                            debug ("create_resource: %s: Enabling full seek (s0 fixed)",
                                   short_res_path);
                            byteseek_operations |= DLNAOperation.RANGE; // Full byte seek
                            res.dlna_operation |= DLNAOperation.TIMESEEK; // Full time seek
                            break;
                        case ODIDLiveSimulator.Mode.S0_INCREASING:
                            debug ("create_resource: %s: Enabling limited operation seek (S0 increasing)",
                                   short_res_path);
                            byteseek_flags |= DLNAFlags.BYTE_BASED_SEEK; // LOP byte seek
                            res.dlna_flags |= DLNAFlags.S0_INCREASE
                                              | DLNAFlags.TIME_BASED_SEEK; // LOP time seek
                            break;
                        case ODIDLiveSimulator.Mode.S0_EQUALS_SN:
                            debug ("create_resource: %s: No limited operation modes (S0==SN)",
                                   short_res_path);
                            res.dlna_flags |= DLNAFlags.S0_INCREASE;
                            break;
                        default:
                            throw new ODIDMediaEngineError.CONFIG_ERROR
                                  ("Unsupported simulator mode: %d", live_sim.get_mode ());
                    }
                    break;
                case ODIDLiveSimulator.State.STOPPED:
                    // Live mode is complete (S0/Sn are no longer increasing)
                    switch (live_sim.get_mode ()) {
                        case ODIDLiveSimulator.Mode.S0_FIXED:
                        case ODIDLiveSimulator.Mode.S0_INCREASING:
                            int64 time_range_start, time_range_end, byte_range_end;
                            live_sim.get_available_time_range (out time_range_start,
                                                               out time_range_end);
                            int64 total_duration = ODIDUtil.duration_from_index_file_ms
                                                            (normal_content_index_file);
                            ODIDUtil.offsets_within_time_range
                                       (normal_content_index_file, false, // for 1.0 rate (forward)
                                        ref time_range_start, ref time_range_end,
                                        total_duration * MICROS_PER_MILLI,
                                        out byte_range_start, out byte_range_end,
                                        content_info.get_size ());
                            // per DLNA 7.4.1.3.18.4/5
                            res.duration = (long)((time_range_end - time_range_start)
                                                  / MICROS_PER_SEC + 0.999); // Round up
                            debug ("create_resource: %s: time range from completed live source %s: %.3fs-%.3fs (%lds)",
                                   short_res_path, live_sim.name,
                                   ODIDUtil.usec_to_secs (time_range_start),
                                   ODIDUtil.usec_to_secs (time_range_end),
                                   res.duration);
                            res.size = byte_range_end - byte_range_start;
                            debug ("create_resource: %s: byte range from completed live source %s: %lld-%lld (%lld)",
                                   short_res_path, live_sim.name,
                                   byte_range_start, byte_range_end, res.size);
                            byteseek_operations |= DLNAOperation.RANGE; // Full byte seek
                            res.dlna_operation |= DLNAOperation.TIMESEEK; // Full time seek
                            // Note: Setting res@size/res@duration imply a different meaning for
                            //       npt/byte 0. The DataSource will have to offset accordingly...
                            break;
                        case ODIDLiveSimulator.Mode.S0_EQUALS_SN:
                            // There's data to access after being stopped
                            // Nothing to set and no data to serve
                            break;
                        default:
                            throw new ODIDMediaEngineError.CONFIG_ERROR
                                  ("Unsupported simulator mode: %d", live_sim.get_mode ());
                    }
                    break;
                default:
                    throw new ODIDMediaEngineError.CONFIG_ERROR
                          ("Unsupported simulator state: %d", live_sim.get_state ());
            } // END switch (live_sim.get_state ())
        } else { // Not live
            byte_range_start = 0;
            res.size = content_info.get_size ();
            debug ("create_resource: %s: size: %s", short_res_path, res.size.to_string ());
            byteseek_operations |= DLNAOperation.RANGE; // Full byte seek (full RADA)
            if (normal_content_index_file.query_exists ()) {
                res.duration = ODIDUtil.duration_from_index_file_s (normal_content_index_file);
                res.dlna_operation |= DLNAOperation.TIMESEEK; // Full time seek (full RADA)
                debug ("create_resource: %s: duration: %lds", short_res_path, res.duration);
            } else {
                debug ("create_resource: %s: duration: unknown (no index file)", short_res_path);
            }
        }
        // Assert: byte_range_start and res@size reflect the accessible byte range
        // Assert: byteseek_flags and byteseek_operations reflect capabilities
        // Assert: byte_range_start is set appropriately if res.size is set

        if (!dtcp_protected) {
            res.dlna_flags |= byteseek_flags;
            res.dlna_operation |= byteseek_operations;
        } else {
            // The flags, operation modes, and size need to reflect DTCP protection
            res.dlna_flags |= DLNAFlags.LINK_PROTECTED_CONTENT;
            if (DLNAOperation.RANGE in byteseek_operations) {
                res.dlna_flags |= DLNAFlags.CLEARTEXT_BYTESEEK_FULL;
            }
            if (DLNAFlags.BYTE_BASED_SEEK in byteseek_flags) {
                res.dlna_flags |= DLNAFlags.LOP_CLEARTEXT_BYTESEEK;
            }

            if (res.size < 0) {
                debug ("create_resource: %s: Encrypted size not calculated (live mode, etc)",
                       short_res_path);
            } else {
                res.cleartext_size = res.size; // We'll calculate a new res.size below

                string profile = res.dlna_profile;
                if ((profile.has_prefix ("DTCP_MPEG_PS"))) {
                    // Align the effective data range to VOBU boundaries (one VOBU is one PCP)
                    int64 start_offset = 0;
                    Gee.ArrayList<int64?> range_offset_list = new Gee.ArrayList<int64?> (); 
                    ODIDUtil.vobu_aligned_offsets_for_range (normal_content_index_file,
                                                             byte_range_start, res.size,
                                                             out start_offset, range_offset_list,
                                                             res.size);
                    res.size = ODIDUtil.calculate_dtcp_encrypted_length
                                            (start_offset, range_offset_list, this.chunk_size);
                } else { // We're encoding as a single PCP
                    // TODO: Think this needs to be TS-aligned...
                    res.size = (int64) Dtcpip.get_encrypted_length (res.cleartext_size, chunk_size);
                }
                debug ("create_resource: %s: encrypted size: %lld", short_res_path, res.size);
            }
        }

        // Look for scaled files and set fields accordingly if/when found
        {
            Gee.List<PlaySpeed> playspeeds;

            playspeeds = ODIDUtil.find_playspeeds_for_res (res_dir_uri, basename);

            if (playspeeds != null) {
                var speed_array = new string[playspeeds.size];
                int speed_index = 0;
                foreach (var speed in playspeeds) {
                    speed_array[speed_index++] = speed.to_string ();
                }
                res.play_speeds = speed_array;
                debug ("create_resource: %s: Found %d speeds", short_res_path, speed_index);
            }
        }

        return res;
    }

    /**
     * Return DTCP mime type string for a given mime type
     */
    public string dtcp_mime_type_for_mime_type (string mime_type) {
        return "application/x-dtcp1;DTCP1HOST=" + this.dtcp_host.to_string ()
                                + ";DTCP1PORT=" + this.dtcp_port.to_string ()
                                + ";CONTENTFORMAT=\"" + mime_type + "\"";
    }

    /**
     * Set a MediaResource field from a resource.info name-value pair
     *
     * @param res MediaResource to modify
     * @param name The field name
     * @param value The field value
     */
    void set_resource_field (MediaResource res, string name, string value) throws Error {
        switch (name) {
            case "profile":
                res.dlna_profile = value;
                break;
            case "mime-type":
                res.mime_type = value;
                break;
            case "bitrate":
                res.bitrate = int.parse (value);
                if (res.bitrate <= 0) {
                    throw new ODIDMediaEngineError.CONFIG_ERROR
                                  ("Invalid denominator: " + value);
                }
                break;
            case "audio-bits-per-sample":
                res.bits_per_sample = int.parse (value);
                if (res.bits_per_sample <= 0) {
                    throw new ODIDMediaEngineError.CONFIG_ERROR
                                  ("Bad odid resource audio-bits-per-sample value: "
                                   + value);
                }
                break;
            case "video-color-depth":
                res.color_depth = int.parse (value);
                if (res.color_depth <= 0) {
                    throw new ODIDMediaEngineError.CONFIG_ERROR
                                  ("Bad odid resource video-color-depth value: "
                                  + value);
                }
                break;
            case "video-resolution":
                var res_fields = value.split ("x");
                if (res_fields.length != 2) {
                    throw new ODIDMediaEngineError.CONFIG_ERROR
                                  ("Bad odid resource video-resolution value: "
                                   + value);
                }
                res.width = int.parse (res_fields[0]);
                if (res.width <= 0) {
                    throw new ODIDMediaEngineError.CONFIG_ERROR
                                  ("Bad odid resource video-resolution x value: "
                                   + value);
                }
                res.height = int.parse (res_fields[1]);
                if (res.height <= 0) {
                    throw new ODIDMediaEngineError.CONFIG_ERROR
                                  ("Bad odid resource video-resolution y value: "
                                   + value);
                }
                break;
            case "audio-channels":
                res.audio_channels = int.parse (value);
                if (res.audio_channels <= 0) {
                    throw new ODIDMediaEngineError.CONFIG_ERROR
                                  ("Bad odid resource audio-channels value: "
                                   + value);
                }
                break;
            case "audio-sample-frequency":
                res.sample_freq = int.parse (value);
                if (res.sample_freq <= 0) {
                    throw new ODIDMediaEngineError.CONFIG_ERROR
                                  ("Bad odid resource audio-sample-frequency value: "
                                   + value);
                }
                break;
            // Note: The entries below here are intended for remotely-hosted content (e.g. MPEG-DASH)
            case "uri":
                res.uri = value;
                break;
            case "size":
                int64 size;
                bool parsed = int64.try_parse (value, out size);
                if (parsed) {
                    res.size = size;
                } else {
                    throw new ODIDMediaEngineError.CONFIG_ERROR
                                  ("Bad odid resource size value: " + value);
                }
                break;
            case "duration":
                int64 duration;
                bool parsed = int64.try_parse (value, out duration);
                if (parsed) {
                    res.duration = (long)duration;
                } else {
                   throw new ODIDMediaEngineError.CONFIG_ERROR
                                 ("Bad odid resource duration value: " + value);
                }
                break;
        } // END switch (name)
    }

    // The ODIDControlChannel delegate
    private string process_command (string command) {
        message ("Received command: %s", command);
        string [] command_elems = command.split (" ", 3);

        // Going with a simple three-part command structure for now...

        message ("Command: %s", command_elems[0]);
        message ("Sub-command: %s", command_elems[1]);
        message ("param(s): %s", command_elems[2]);
        
        return ("Command processed: " + command_elems[0]);
    }

    public override DataSource? create_data_source_for_resource
                                    (MediaObject object, MediaResource resource)
        throws Error {
        // TODO: Change this to "object is OdidMediaItem"
        if (! (object is MediaItem)) {
            throw new ODIDMediaEngineError.CONFIG_ERROR
                          ("Only MediaItem-based data sources are supported");
        }

        var item = object as MediaItem;

        // For MediaFileItems, uri 0 is the file URI referring directly to
        //  the content. But for us, we're presuming it refers to the ODID item file
        string item_info_uri = item.uris.get (0);

        debug ("create_data_source_for_resource: source %s, resource %s",
               item_info_uri, resource.get_name ());

        debug ("create_data_source_for_resource: %s", resource.to_string ());
        string resource_uri = ODIDUtil.get_resource_uri (item_info_uri, resource);
        debug ("create_data_source_for_resource: resource_uri: %s", resource_uri);

        if (ODIDUtil.get_resource_property (resource_uri, "live") == "true") {
            debug ("create_data_source_for_resource: IS live");
            var live_sim = find_live_sim_or_create (item_info_uri, resource_uri);
            if (live_sim == null) {
                throw new ODIDMediaEngineError.CONFIG_ERROR
                              ("No live sim found/created for " + resource_uri);
            }
            if (!live_sim.started && this.autostart_live_sims) {
                // We'll start the sim now
                live_sim.start_live ();
                if (this.live_sim_reset_s > 0) {
                    debug ("Setting auto-reset time of sim %s to %d seconds",
                           live_sim.name, this.live_sim_reset_s);
                    live_sim.enable_autoreset (this.live_sim_reset_s * MILLIS_PER_SEC);
                }
            }
            debug ("Using live sim \"%s\" (effective range %0.3fs-%0.3fs)",
                   live_sim.name, live_sim.get_time_range_start ()/MILLIS_PER_SEC,
                   live_sim.get_time_range_end ()/MILLIS_PER_SEC);

            if (this.control_channel != null) {
                this.control_channel.send_message ("Creating live data source for " + item_info_uri);
            }
            return new ODIDDataSource.from_live (live_sim, resource, this.chunk_size);
        } else {
            debug ("create_data_source_for_resource: IS NOT live");
            if (this.control_channel != null) {
                this.control_channel.send_message ("Creating normal data source for " + item_info_uri);
            }

            return new ODIDDataSource (resource_uri, resource, this.chunk_size);
        }
    }

    public override DataSource? create_data_source_for_uri (string source_uri) throws Error {
        throw new ODIDMediaEngineError.CONFIG_ERROR
                      ("Only resource-based data sources are currently supported");
    }

    ODIDLiveSimulator ? find_live_sim_or_create (string item_info_uri, string resource_uri)
            throws Error {
        var short_res_path = ODIDUtil.short_resource_path (resource_uri);
        var live_sim = find_live_sim (short_res_path);
        if (live_sim != null) {
            debug ("Found pre-existing live sim for %s", short_res_path);
        } else {
            debug ("No live sim found for %s - creating one", short_res_path);
            live_sim = new ODIDLiveSimulator (short_res_path, item_info_uri, resource_uri);
            string live_time_window_val =
                       ODIDUtil.get_resource_property (resource_uri, "live-time-window");
            if (live_time_window_val != null) {
                live_sim.tsb_duration_us = int.parse (live_time_window_val) * MICROS_PER_SEC;
                debug ("Set time window of sim %s to %0.3f seconds",
                       live_sim.name, ODIDUtil.usec_to_secs (live_sim.tsb_duration_us));
            }
            string live_start_offset_val =
                       ODIDUtil.get_resource_property (resource_uri, "live-start-offset");
            if (live_start_offset_val != null) {
                live_sim.live_start_offset_us = int.parse (live_start_offset_val) * MICROS_PER_SEC;
                debug ("Set live start offset of sim %s to %0.3f seconds",
                       live_sim.name, ODIDUtil.usec_to_secs (live_sim.live_start_offset_us));
            }
            // We'll set the autostop time to the duration of the content
            live_sim.autostop_at_us = ODIDUtil.duration_for_resource_us (resource_uri);
            live_sim.report_range_when_active (1000, this.control_channel);
            debug ("Set autostop time of sim %s to %0.3f seconds",
                   live_sim.name, ODIDUtil.usec_to_secs (live_sim.autostop_at_us));
            this.live_sim_table.insert (live_sim.name, live_sim);
        }

        return live_sim;
    }

    ODIDLiveSimulator ? find_live_sim (string short_res_path) {
        return this.live_sim_table.get (short_res_path);
    }

    void sim_started (Object sim) {
        var live_sim = (ODIDLiveSimulator)sim;
        debug ("sim_started for simulator " + live_sim.name);
        // No-op (no resource change)
    }

    void sim_stopped (Object sim) {
        var live_sim = (ODIDLiveSimulator)sim;
        debug ("sim_stopped for simulator " + live_sim.name);
        ODIDUtil.touch_file_uri (live_sim.item_info_uri);
    }

    void sim_reset (Object sim) {
        var live_sim = (ODIDLiveSimulator)sim;
        debug ("sim_reset for simulator " + live_sim.name);
        debug ("  item info file: " + live_sim.item_info_uri);
        ODIDUtil.touch_file_uri (live_sim.item_info_uri);
    }
}

public static Rygel.MediaEngine module_get_instance () {
    debug ("module_get_instance");
    return new Rygel.ODIDMediaEngine ();
}


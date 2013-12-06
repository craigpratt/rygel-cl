/* 
 * Copyright (C) 2013  Cable Television Laboratories, Inc.
 * Contact: http://www.cablelabs.com/
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
 *
 * Author: Craig Pratt <craig@ecaspia.com>
 */

/*
 * Based on Rygel SimpleMediaEngine
 * Copyright (C) 2012 Intel Corporation.
 */

using Gee;
using GUPnP;
using Dtcpip;

public errordomain Rygel.ODIDMediaEngineError {
    CONFIG_ERROR,
    INDEX_FILE_ERROR
}

/**
 * This media engine is intended to be the basis for the CL 
 * reference DMS. Long-term, this could be moved outside the Rygel
 * source tree and built stand-alone.
 */
internal class Rygel.ODIDMediaEngine : MediaEngine {
    private  GLib.List<DLNAProfile> profiles 
        = new GLib.List<DLNAProfile>();

    // Entry Type (V: Video Frame)
    // | Video Frame Type (I,B,P)
    // | | Time Offset (seconds.milliseconds) (fixed decimal places, 8.3)
    // | | |           File Byte Offset (fixed decimal places, 19)
    // | | |           |                   Frame size (fixed decimal places, 10)
    // | | |           |                   |
    // v v v           v                   v
    // V F 0000000.000 0000000000000000000 0000000000<15 spaces><newline>
        
    public static const uint INDEXFILE_ROW_SIZE = 62;
    public static const uint INDEXFILE_FIELD_ENTRYTYPE_OFFSET = 0;
    public static const uint INDEXFILE_FIELD_FRAMETYPE_OFFSET = 2;
    public static const uint INDEXFILE_FIELD_TIME_OFFSET = 4;
    public static const uint INDEXFILE_FIELD_TIMESECONDS_LENGTH = 7;
    public static const uint INDEXFILE_FIELD_TIMEMS_LENGTH = 3;
    public static const uint INDEXFILE_FIELD_TIME_LENGTH = 11;
    public static const uint INDEXFILE_FIELD_BYTEOFFSET_OFFSET = 17;
    public static const uint INDEXFILE_FIELD_BYTEOFFSET_LENGTH = 19;
    public static const uint INDEXFILE_FIELD_FRAMESIZE_OFFSET = 37;
    public static const uint INDEXFILE_FIELD_FRAMESIZE_LENGTH = 10;

    // Variable to hold chunk size for streaming
    public static int64 chunk_size;

    // DTCP control variables
    private bool dtcp_initialized;
    private string dtcp_storage;
    private ushort dtcp_port; // Default DTCP port is 8999
    private string dtcp_host;

    public ODIDMediaEngine() {
        debug("constructing");
        var profiles_config = new Gee.ArrayList<string>();
        var config = MetaConfig.get_default();

        bool dtcp_enabled = false;
        string chunk_size_str;
        try {
            dtcp_enabled = config.get_bool ("OdidMediaEngine", "dtcp-enabled");
            profiles_config = config.get_string_list( "OdidMediaEngine", "profiles");
            chunk_size_str = config.get_string ("OdidMediaEngine", "chunk-size");
        } catch (Error err) {
            error("Error reading ODIDMediaEngine property: " + err.message);
        }

        chunk_size = ODIDUtil.get_chunk_size (chunk_size_str);

        dtcp_initialized = false;
        if (dtcp_enabled) {
            try {
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
                        debug ("DTCP-IP source initialized: host %s, port %d, storage %s",
                                 this.dtcp_host, this.dtcp_port, this.dtcp_storage);
                        dtcp_initialized = true;
                    }
                }
            } catch (Error err) {
                error("Error initializing DTCP: " + err.message);
            }
        } else {
            debug ("DTCP-IP is disabled");
        }

        foreach (var row in profiles_config) {
            var columns = row.split(",");
            if (columns.length < 2) {
                debug( "OdidMediaEngine profile entry \""
                         + row + "\" is malformed: Expected 2 entries and found "
                         + columns.length.to_string() );
                break;
            }

            debug("OdidMediaEngine: configuring profile entry: " + row);
            // Note: This profile list won't affect what profiles are included in the 
            //       primary res block
            profiles.append(new DLNAProfile(columns[0],columns[1]));
        }
    }

    public override unowned GLib.List<DLNAProfile> get_dlna_profiles() {
        debug("get_dlna_profiles");
        return this.profiles;
    }

    public override async Gee.List<MediaResource> ? get_resources_for_item (MediaObject object) {
        // TODO: Change this to "object is OdidMediaItem"
        if (! (object is MediaItem)) {
            warning ("Can only process odid MediaObjects (OdidMediaItems)");
            return null;
        }

        var item = object as MediaItem; 

        // For MediaFileItems, uri 0 is the file URI referring directly to the content. But for
        //  us, we're presuming it refers to the ODID base directory (this becomes less squishy
        //  when OdidMediaItem comes on the scene...)
        string source_uri = item.uris.get (0);
        
        // TODO: Consider our own uri scheme (e.g. "odid:")
        if (!source_uri.has_prefix ("file://")) {
            warning("Can't process non-file uri " + source_uri);
        }

        debug("OdidMediaEngine:get_resources: " + source_uri);
        
        Gee.List<MediaResource> resources = new Gee.ArrayList<MediaResource>();

        string odid_item_path = null;
        try {
            KeyFile keyFile = new KeyFile();
            keyFile.load_from_file(File.new_for_uri (source_uri).get_path (),
                                   KeyFileFlags.KEEP_COMMENTS |
                                   KeyFileFlags.KEEP_TRANSLATIONS);

            odid_item_path = keyFile.get_string ("item", "odid_uri");

            debug("get_resources: processing item directory: " + odid_item_path);

            var directory = File.new_for_uri(odid_item_path);
            
            var enumerator = directory.enumerate_children(FileAttribute.STANDARD_NAME, 0);

            FileInfo file_info;
            while ((file_info = enumerator.next_file ()) != null) {
                if (file_info.get_file_type () == FileType.DIRECTORY) {
                    debug( "get_resources:   processing resource directory: "
                             + file_info.get_name());
                    // A directory in an item directory is a resource
                    try {
                        var res = create_resource_from_resource_dir( odid_item_path
                                                                     + file_info.get_name() + "/");
                        if (res != null) {
                            resources.add(res);
                            debug("get_resources:     created resource: " + res.to_string());
                        }
                    } catch (Error err) {
                        warning ("Error processing item resource %s: %s",
                                 odid_item_path + file_info.get_name(), err.message);
                        // Continue processing other resources
                    }
                }
            }
        } catch (Error err) {
            error("Error creating resources for source %s: %s", odid_item_path, err.message);
        }

        return resources;
    }

    /**
     * Construct a MediaResource from an on-disk resource
     *
     * @param res_dir_uri URI to the resource directory.
     * @return MediaResource constructed from the on-disk resource directory
     */
    internal MediaResource ? create_resource_from_resource_dir(string res_dir_uri)
         throws Error {
        debug( "OdidMediaEngine:create_resource_from_resource_dir: configuring resources for "
                 + res_dir_uri);
        MediaResource res = null;

        var res_dir = File.new_for_uri(res_dir_uri);
        FileInfo res_dir_info = res_dir.query_info(GLib.FileAttribute.STANDARD_NAME, 0);

        res = new MediaResource(res_dir_info.get_name());
        // Assert: All res values are set to sane/unset defaults

        string basename = null;
        bool dtcp_protected = false;
        bool is_converted = false;

        // Process fields set in the resource.info
        {
            File res_info_file = File.new_for_uri(res_dir_uri + "/resource.info");
            var dis = new DataInputStream(res_info_file.read());
            string line;
            int line_num = 0;
            while ((line = dis.read_line(null)) != null) {
                line_num++;
                if (line[0] == '#') continue;
                var equals_pos = line.index_of("=");
                var name = line[0:equals_pos].strip();
                var value = line[equals_pos+1:line.length].strip();

                if ((name == null) || (value == null))  {
                    warning("Bad entry in %s line %d: %s", res_dir_uri, line_num, line);
                    continue;
                }
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
                if (name.length > 0 && value.length > 0) {
                    set_resource_field(res, name, value);
                }
            }
        }

        string file_extension;
        string normal_content_filename;

        // Modify the profile & mime type for DTCP, if necessary
        if (dtcp_protected) {
            res.mime_type = dtcp_mime_type_for_mime_type (res.mime_type);
            res.dlna_profile = "DTCP_" + res.dlna_profile;
        }

        if (res.uri != null) {
            // Our URI (and content) is not Rygel-hosted. So no need to look for content
            //  (there really shouldn't be any...)
            debug("Found URI in resource metadata for %s: %s", res_dir_uri, res.uri);
            return res;
        }

        // Check for required properties
        if (basename == null) {
            throw new ODIDMediaEngineError.CONFIG_ERROR("No basename property set for resource");
        }

        // Set the size according to the normal-rate file (speed "1/1")
        {
            normal_content_filename = ODIDMediaEngine.content_filename_for_res_speed (
                                                                res_dir_uri, basename, null,
                                                                out file_extension );
            File content_file = File.new_for_uri(res_dir_uri + normal_content_filename);
            FileInfo content_info = content_file.query_info(GLib.FileAttribute.STANDARD_SIZE, 0);
            res.size = content_info.get_size();
            res.extension = file_extension;
            debug( "create_resource_from_resource_dir: size for "
                     + normal_content_filename + " is " + res.size.to_string() );
        }

        res.dlna_flags = DLNAFlags.DLNA_V15
                         | DLNAFlags.STREAMING_TRANSFER_MODE
                         | DLNAFlags.BACKGROUND_TRANSFER_MODE
                         | DLNAFlags.CONNECTION_STALL;

        res.dlna_conversion = is_converted ? DLNAConversion.TRANSCODED : DLNAConversion.NONE;

        // We currently support RANGE for all resources except DTCP content
        if (dtcp_protected) {
            res.dlna_flags |= DLNAFlags.LINK_PROTECTED_CONTENT | DLNAFlags.CLEARTEXT_BYTESEEK_FULL;
            res.dlna_operation = DLNAOperation.NONE;
            // We'll OR in TIMESEEK if we have an index file...
            res.cleartext_size = res.size;
            res.size = (int64)Dtcpip.get_encrypted_length (res.cleartext_size, chunk_size);
            debug ("Encrypted size from DTCP library: %lld",res.size);
        } else {
            res.dlna_operation = DLNAOperation.RANGE;
            // We'll OR in TIMESEEK if we have an index file...
        }
        
        // Look for an index file and set fields accordingly if/when found
        {
            string index_path = res_dir_uri + normal_content_filename + ".index";
            File index_file = File.new_for_uri(index_path);
            if (index_file.query_exists()) {
                // We support TimeSeekRange for this content
                res.dlna_operation |= DLNAOperation.TIMESEEK; 
                // Set the duration according to the last entry in the normal-rate index file
                res.duration = duration_from_index_file (index_file);
                debug( "create_resource_from_resource_dir: duration for "
                       + normal_content_filename + " is " + res.duration.to_string() );
            } else {
                debug( "create_resource_from_resource_dir: No index file found for "
                       + res_dir_uri + normal_content_filename );
            }
        }

        // Look for scaled files and set fields accordingly if/when found
        {
            Gee.List<PlaySpeed> playspeeds;
            
            playspeeds = find_playspeeds_for_res(res_dir_uri, basename);

            if (playspeeds != null) {
                var speed_array = new string[playspeeds.size];
                int speed_index = 0;
                foreach (var speed in playspeeds) {
                    speed_array[speed_index++] = speed.to_string();
                }
                res.play_speeds = speed_array;
                debug( "create_resource_from_resource_dir: Found %d speeds for "
                       + res_dir_uri + normal_content_filename, speed_index);
            }
        }
        return res;
    }

    /**
     * Return DTCP mime type string for a given mime type
     */
    public string dtcp_mime_type_for_mime_type (string mime_type) {
        return "application/x-dtcp1;DTCP1HOST=" + this.dtcp_host.to_string()
                                + ";DTCP1PORT=" + this.dtcp_port.to_string()
                                + ";CONTENTFORMAT=\"" + mime_type + "\"";
    }

    /**
     * Set a MediaResource field from a resource.info name-value pair
     *
     * @param res MediaResource to modify
     * @param name The field name
     * @param value The field value
     */
    void set_resource_field(MediaResource res, string name, string value) throws Error {
        switch (name) {
            case "profile": 
                res.dlna_profile = value;
                break;
            case "mime-type":
                res.mime_type = value;
                break;
            case "bitrate":
                res.bitrate = int.parse(value);
                if (res.bitrate <= 0) {
                    throw new ODIDMediaEngineError.CONFIG_ERROR(
                                "Invalid denominator: " + value);
                }
                break;
            case "audio-bits-per-sample":
                res.bits_per_sample = int.parse(value);
                if (res.bits_per_sample <= 0) {
                    throw new ODIDMediaEngineError.CONFIG_ERROR(
                                "Bad odid resource audio-bits-per-sample value: " + value);
                }
                break;
            case "video-color-depth":
                res.color_depth = int.parse(value);
                if (res.color_depth <= 0) {
                    throw new ODIDMediaEngineError.CONFIG_ERROR(
                                "Bad odid resource video-color-depth value: " + value);
                }
                break;
            case "video-resolution":
                var res_fields = value.split("x");
                if (res_fields.length != 2) {
                    throw new ODIDMediaEngineError.CONFIG_ERROR(
                                "Bad odid resource video-resolution value: " + value);
                }
                res.width = int.parse(res_fields[0]);
                if (res.width <= 0) {
                    throw new ODIDMediaEngineError.CONFIG_ERROR(
                                "Bad odid resource video-resolution x value: " + value);
                }
                res.height = int.parse(res_fields[1]);
                if (res.height <= 0) {
                    throw new ODIDMediaEngineError.CONFIG_ERROR(
                                "Bad odid resource video-resolution y value: " + value);
                }
                break;
            case "audio-channels":
                res.audio_channels = int.parse(value);
                if (res.audio_channels <= 0) {
                    throw new ODIDMediaEngineError.CONFIG_ERROR(
                                "Bad odid resource audio-channels value: " + value);
                }
                break;
            case "audio-sample-frequency":
                res.sample_freq = int.parse(value);
                if (res.sample_freq <= 0) {
                    throw new ODIDMediaEngineError.CONFIG_ERROR(
                                "Bad odid resource audio-sample-frequency value: " + value);
                }
                break;
            // Note: The entries below here are intended for remotely-hosted content (e.g. MPEG-DASH)
            case "uri":
                res.uri = value;
                break;
            case "size":
                int64 size;
                bool parsed = int64.try_parse(value, out size);
                if (parsed) {
                    res.size = size;
                } else {
                    throw new ODIDMediaEngineError.CONFIG_ERROR("Bad odid resource size value: "
                                                                + value);
                }
                break;
            case "duration":
                int64 duration;
                bool parsed = int64.try_parse(value, out duration);
                if (parsed) {
                    res.duration = (long)duration;
                } else {
                   throw new ODIDMediaEngineError.CONFIG_ERROR("Bad odid resource duration value: "
                                                               + value);
                }
                break;
            default:
                throw new ODIDMediaEngineError.CONFIG_ERROR("Unknown odid configuration entry: "
                                                            + name);

        } // END switch (name)
    }

    internal static string? content_filename_for_res_speed( string resource_dir_path,
                                                            string basename,
                                                            PlaySpeed? playspeed,
                                                            out string extension )
            throws Error {
        debug ("content_filename_for_res_speed: %s, %s, %s",
                 resource_dir_path,basename,
                 (playspeed != null) ? playspeed.to_string() : "null" );
        string rate_string;
        if (playspeed == null) {
            rate_string = "1_1";
        } else {
            rate_string = playspeed.numerator.to_string()
                          + "_" + playspeed.denominator.to_string();
        }

        string content_filename = null;
        extension = null;

        var directory = File.new_for_uri(resource_dir_path);
        var enumerator = directory.enumerate_children(GLib.FileAttribute.STANDARD_NAME, 0);

        FileInfo file_info;
        while ((file_info = enumerator.next_file ()) != null) {
            var cur_filename = file_info.get_name();
            // Check for content file for the requested rate (<basename>.<rate>.<extension>)
            var split_name = cur_filename.split(".");
            if ( (split_name.length == 3)
                 && (split_name[0] == basename) && (split_name[1] == rate_string) ) {
                content_filename = cur_filename;
                extension = split_name[2];
                debug ("content_filename_for_res_speed: FOUND MATCH: %s (extension %s)",
                         content_filename, extension);
            }
        }

        return content_filename;
    }

    /**
     * Produce a list of PlaySpeeds corresponding to scaled content files for the given
     * resource directory and basename.
     *
     * @return A List with one PlaySpeed per scaled-rate content file
     */
    internal static Gee.List<PlaySpeed>? find_playspeeds_for_res( string resource_dir_uri,
                                                                      string basename )
        throws Error {
        debug ("ODIDMediaEngine.find_playspeeds_for_res: %s, %s",
                 resource_dir_uri,basename );
        var speeds = new Gee.ArrayList<PlaySpeed>();
        
        var directory = File.new_for_uri(resource_dir_uri);
        var enumerator = directory.enumerate_children(GLib.FileAttribute.STANDARD_NAME, 0);

        FileInfo file_info;
        while ((file_info = enumerator.next_file ()) != null) {
            var cur_filename = file_info.get_name();
            // Only look for content files (<basename>.<rate>.<extension>)
            var split_name = cur_filename.split(".");
            if ((split_name.length == 3) && (split_name[0] == basename)) {
                var speed_parts = split_name[1].split("_");
                if (speed_parts.length != 2) {
                    throw new ODIDMediaEngineError.CONFIG_ERROR(
                                "Bad  speed found in res filename %s (%s)",
                                cur_filename, split_name[1]);
                }
                var speed = new PlaySpeed(int.parse(speed_parts[0]),int.parse(speed_parts[1]));
                if (speed.numerator == 1 && speed.denominator == 1) {
                    continue; // Rate "1" is implied and not included in the playspeeds - skip it
                }
                speeds.add(speed);
            }
        }
        return (speeds.size > 0) ? speeds : null;
    }

    internal static long duration_from_index_file(File index_file)
            throws Error {
        debug ("ODIDDataSource.duration_for_content_file: %s",
                 index_file.get_basename() );
        
        FileInfo index_info = index_file.query_info(GLib.FileAttribute.STANDARD_SIZE, 0);
        var dis = new DataInputStream(index_file.read());

        // We don't need to parse the whole file.
        // The last index entry will be INDEXFILE_ROW_SIZE bytes from the end of the file...

        size_t last_entry_offset = (size_t)(index_info.get_size()-INDEXFILE_ROW_SIZE);
        dis.skip(last_entry_offset);
        string line = dis.read_line(null);
        
        if (line.length != ODIDMediaEngine.INDEXFILE_ROW_SIZE-1) {
            throw new ODIDMediaEngineError.INDEX_FILE_ERROR(
                          "Bad index file entry size (entry at offset %s of %s is %d bytes - should be %d bytes): '%s'",
                          last_entry_offset.to_string (), index_file.get_basename (),
                          line.length, ODIDMediaEngine.INDEXFILE_ROW_SIZE, line);
        }
        uint time_field_start = INDEXFILE_FIELD_TIME_OFFSET;
        uint time_field_end = INDEXFILE_FIELD_TIME_OFFSET+INDEXFILE_FIELD_TIME_LENGTH;
        string seconds_field = line[time_field_start:time_field_end];
        double duration_val;
        if (double.try_parse(seconds_field, out duration_val))
        {
            return (long)(duration_val+0.99); // For rounding
        } else {
            throw new ODIDMediaEngineError.INDEX_FILE_ERROR(
                        "Ill-formed duration field ('%s') in last index file entry of %s: '%s'",
                        seconds_field, index_file.get_basename (), line);
        }
    }

    internal static string strip_leading_zeros(string number_string) {
        int i=0;
        while ((number_string[i] == '0') && (i < number_string.length)) {
            i++;
        }
        if (i == 0) {
            return number_string;
        } else {
            return number_string[i:number_string.length];
        }
    }

    public override DataSource? create_data_source_for_resource ( MediaObject object,
                                                                  MediaResource resource) {
        // TODO: Change this to "object is OdidMediaItem"
        if (! (object is MediaItem)) {
            warning ("Can only process odid MediaObjects (OdidMediaItems)");
            return null;
        }

        var item = object as MediaItem; 

        // For MediaItems, uri 0 is the file URI referring directly to the content. But for
        //  us, we're presuming it refers to the ODID base directory (this becomes less squishy
        //  when OdidMediaItem comes on the scene...)
        string source_uri = item.uris.get (0);
        
        debug("create_data_source_for_resource: source %s, resource %s",
              source_uri, resource.get_name());

        // TODO: Consider our own uri scheme (e.g. "odid:")
        if (!source_uri.has_prefix ("file://")) {
            warning("create_data_source_for_resource: can't process non-file uri " + source_uri);
            return null;
        }

        debug("create_data_source_for_resource: %s", resource.to_string ());
        
        return new ODIDDataSource(source_uri, resource);
    }
    
    public override DataSource? create_data_source_for_uri (string source_uri) {
        warning("create_data_source_for_uri not supported");
        return null;
    }
}

public static Rygel.MediaEngine module_get_instance() {
    debug("module_get_instance");
    return new Rygel.ODIDMediaEngine();
}


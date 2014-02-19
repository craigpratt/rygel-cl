/*
 * Copyright (C) 2013  Cable Television Laboratories, Inc.
 *
 * Author: Parthiban Balasubramanian <P.Balasubramanian-contractor@cablelabs.com>
 *         Craig Pratt <craig@ecaspia.com>
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

public class Rygel.ODIDUtil : Object {
    public static const int64 PACKET_SIZE_188 = 188;
    public static const int64 PACKET_SIZE_192 = 192;
    public static const int NANOS_PER_SEC = 1000000000;
    public static const int MICROS_PER_SEC = 1000000;
    public static const int MILLIS_PER_SEC = 1000;
    public static const int MICROS_PER_MILLI = 1000;

    private ODIDUtil () {
    }

    internal static string? content_filename_for_res_speed
                                (string resource_dir_path,
                                 string basename,
                                 PlaySpeed? playspeed,
                                 out string extension)
            throws Error {
        debug ("content_filename_for_res_speed: %s, %s, %s",
               resource_dir_path,basename,
               (playspeed != null) ? playspeed.to_string () : "null" );
        string rate_string;
        if (playspeed == null) {
            rate_string = "1_1";
        } else {
            rate_string = playspeed.numerator.to_string ()
                          + "_" + playspeed.denominator.to_string ();
        }

        string content_filename = null;
        extension = null;

        var directory = File.new_for_uri (resource_dir_path);
        var enumerator = directory.enumerate_children
                                       (GLib.FileAttribute.STANDARD_NAME, 0);

        FileInfo file_info;
        while ((file_info = enumerator.next_file ()) != null) {
            var cur_filename = file_info.get_name ();
            // Check for content file for the requested rate (<basename>.<rate>.<extension>)
            var split_name = cur_filename.split (".");
            if ( (split_name.length == 3)
                 && (split_name[0] == basename)
                 && (split_name[1] == rate_string) ) {
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
    internal static Gee.List<PlaySpeed>? find_playspeeds_for_res ( string resource_dir_uri,
                                                                      string basename )
        throws Error {
        debug ("ODIDMediaEngine.find_playspeeds_for_res: %s, %s",
               resource_dir_uri,basename );
        var speeds = new Gee.ArrayList<PlaySpeed> ();

        var directory = File.new_for_uri (resource_dir_uri);
        var enumerator = directory.enumerate_children (GLib.FileAttribute.STANDARD_NAME, 0);

        FileInfo file_info;
        while ((file_info = enumerator.next_file ()) != null) {
            var cur_filename = file_info.get_name ();
            // Only look for content files (<basename>.<rate>.<extension>)
            var split_name = cur_filename.split (".");
            if ((split_name.length == 3) && (split_name[0] == basename)) {
                var speed_parts = split_name[1].split ("_");
                if (speed_parts.length != 2) {
                    throw new ODIDMediaEngineError.CONFIG_ERROR
                                  ("Bad  speed found in res filename %s (%s)",
                                   cur_filename, split_name[1]);
                }
                var speed = new PlaySpeed (int.parse (speed_parts[0]),int.parse (speed_parts[1]));
                if (speed.numerator == 1 && speed.denominator == 1) {
                    continue; // Rate "1" is implied and not included in the playspeeds - skip it
                }
                speeds.add (speed);
            }
        }
        return (speeds.size > 0) ? speeds : null;
    }

    internal static string last_line_from_index_file (File index_file) throws Error {
        FileInfo index_info = index_file.query_info
                                             (GLib.FileAttribute.STANDARD_SIZE, 0);
        var dis = new DataInputStream (index_file.read ());

        // We don't need to parse the whole file.
        // The last index entry will be INDEXFILE_ROW_SIZE bytes from the end of the file...

        size_t last_entry_offset = (size_t)(index_info.get_size ()-ODIDIndexEntry.ROW_SIZE);
        dis.skip (last_entry_offset);
        string line = dis.read_line (null);

        if (!ODIDIndexEntry.size_ok (line)) {
            throw new ODIDMediaEngineError.INDEX_FILE_ERROR (
                           "Bad index file entry size (entry at offset %s of %s is %d bytes - should be %u bytes): '%s'",
                           last_entry_offset.to_string (), index_file.get_basename (),
                           line.length+1, ODIDIndexEntry.ROW_SIZE, line);
        }

        return line;
    }

    /**
     * Return the duration of the content according to the given index file (in milliseconds)
     */
    internal static int64 duration_from_index_file_ms (File index_file)
            throws Error {
        var line = last_line_from_index_file (index_file);
        var time_ms = ODIDIndexEntry.time_ms (line);
        message ("Duration from %s: %sms", index_file.get_basename (), time_ms.to_string());
        return time_ms;
    }

    /**
     * Return the duration of the content according to the given index file (in seconds)
     */
    internal static long duration_from_index_file_s (File index_file)
            throws Error {
        var line = last_line_from_index_file (index_file);
        var time_s = ODIDIndexEntry.time_s (line);
        message ("Duration from %s: %ss", index_file.get_basename (), time_s.to_string());
        return time_s;
    }

    /**
     * Find time/data keyframe offsets in the associated index file that cover the provided
     * time range (start_time to end_time, in microseconds).
     *
     * start_time will be modified to be <= the passed start_time.
     * end_time will be modified to be >= the passed end_time.
     *
     * Note: This method will clamp the end time/offset to the duration/total_size if not
     *       present in the index file.
     */
    internal static void offsets_covering_time_range (File index_file, bool is_reverse,
                                                      ref int64 start_time, ref int64 end_time,
                                                      int64 total_duration,
                                                      out int64 start_offset, out int64 end_offset,
                                                      int64 total_size)
         throws Error {
        debug ("offsets_covering_time_range: %s, %lld-%s",
               index_file.get_basename(), start_time,
               ((end_time != int64.MAX) ? end_time.to_string () : "*") );

        if (start_time > total_duration) {
            throw new DataSourceError.SEEK_FAILED ("Start time %lld is larger than the duration",
                                                  start_time);
        }

        bool start_offset_found = false;
        bool end_offset_found = false;

        var dis = new DataInputStream (index_file.read ());
        string line;
        int64 cur_time_offset = 0;
        string cur_data_offset = null;
        int64 last_time_offset = is_reverse ? total_duration : 0; // Time can go backward
        string last_data_offset = "0"; // but data offsets always go forward...
        start_offset = int64.MAX;
        end_offset = 0;
        int line_count = 0;
        // Read lines until end of file (null) is reached
        while ((line = dis.read_line (null)) != null) {
            line_count++;
            if (!ODIDIndexEntry.size_ok (line)) {
                throw new ODIDMediaEngineError.INDEX_FILE_ERROR (
                              "Bad index file entry size (line %d of %s is %d bytes - should be %u bytes): '%s'",
                              line_count, index_file.get_basename (), line.length+1,
                              ODIDIndexEntry.ROW_SIZE, line);
            }
            if ( (ODIDIndexEntry.type (line) == 'V')
                 && (ODIDIndexEntry.subtype (line) == 'I')) {
                cur_time_offset = ODIDIndexEntry.time_us (line);
                cur_data_offset = ODIDIndexEntry.offset_field (line); // Convert only when needed
                // debug ("offsets_covering_time_range: keyframe at %s (%s) has offset %s",
                //        ODIDIndexEntry.time_field(line), cur_time_offset.to_string(),
                //        cur_data_offset);
                if (!start_offset_found
                    && ( (is_reverse && (cur_time_offset < start_time))
                         || (!is_reverse && (cur_time_offset > start_time)) ) ) {
                        start_time = last_time_offset;
                        start_offset = int64.parse (strip_leading_zeros (last_data_offset));
                        start_offset_found = true;
                        debug ("offsets_covering_time_range: found start of range (%s): time %lld, offset %lld",
                               (is_reverse ? "reverse" : "forward"),
                               start_time, start_offset);
                } else { // start offset found (note that start and end can't be the same)
                    if ((is_reverse && (cur_time_offset < end_time))
                        || (!is_reverse && (cur_time_offset > end_time)) ) {
                        end_time = cur_time_offset;
                        end_offset = int64.parse (strip_leading_zeros (cur_data_offset));
                        end_offset_found = true;
                        debug ("offsets_covering_time_range: found end of range (%s): time %lld, offset %lld",
                               (is_reverse ? "reverse" : "forward"),
                               end_time, end_offset);
                        break; // We're done
                    }
                }
                last_time_offset = cur_time_offset;
                last_data_offset = cur_data_offset;
            }
        }

        if (!start_offset_found) {
            start_time = cur_time_offset;
            start_offset = int64.parse (strip_leading_zeros (cur_data_offset));
            debug ("offsets_covering_time_range: start of range beyond last keyframe (%s): time %lld, offset %lld",
                   (is_reverse ? "reverse" : "forward"), start_time, start_offset);
        }
        if (!end_offset_found) {
            // Modify the end byte value to align to start/end of the file, if necessary
            //  (see DLNA 7.5.4.3.2.24.4)
            end_offset = total_size;
            if (is_reverse) {
                end_time = 0;
            } else {
                end_time = total_duration;
            }
            debug ("offsets_covering_time_range: end of range beyond last keyframe (%s): time %lld, offset %lld",
                   (is_reverse ? "reverse" : "forward"), end_time, end_offset);
        }
    }

    /**
     * Find time/data frame offsets in the associated index file with an end time within the
     * provided time range (start_time to end_time, in microseconds).
     *
     * start_time will be modified to be <= the passed start_time.
     * end_time will be modified to be <= the passed end_time.
     *
     * Note: This method will clamp the end time/offset to the duration/total_size if not
     *       present in the index file.
     * Note: If the requested range is between two keyframes, start_time/start_offset
     *       and end_time/end_offset will be equal. 
     */
    internal static void offsets_within_time_range (File index_file, bool is_reverse,
                                                      ref int64 start_time, ref int64 end_time,
                                                      int64 total_duration,
                                                      out int64 start_offset, out int64 end_offset,
                                                      int64 total_size)
         throws Error {
        debug ("offsets_within_time_range: %s, %lld-%s",
               index_file.get_basename(), start_time,
               ((end_time != int64.MAX) ? end_time.to_string () : "*") );

        if (start_time > total_duration) {
            throw new DataSourceError.SEEK_FAILED ("Start time %lld is larger than the duration",
                                                  start_time);
        }
               
        bool start_offset_found = false;
        bool end_offset_found = false;

        var dis = new DataInputStream (index_file.read ());
        string line;
        int64 cur_time_offset = 0;
        string cur_data_offset = null;
        int64 last_time_offset = is_reverse ? total_duration : 0; // Time can go backward
        string last_data_offset = "0"; // but data offsets always go forward...
        start_offset = int64.MAX;
        end_offset = 0;
        int line_count = 0;
        if (start_time == 0) { // 0-time is always a valid random access point
            start_time = start_offset = 0;
            start_offset_found = true;
            debug ("offsets_within_time_range: Using 0 time/offset as start of range");
        }
        // Read lines until end of file (null) is reached
        while ((line = dis.read_line (null)) != null) {
            line_count++;
            if (!ODIDIndexEntry.size_ok (line)) {
                throw new ODIDMediaEngineError.INDEX_FILE_ERROR (
                              "Bad index file entry size (line %d of %s is %d bytes - should be %u bytes): '%s'",
                              line_count, index_file.get_basename (), line.length+1,
                              ODIDIndexEntry.ROW_SIZE, line);
            }
            if (ODIDIndexEntry.type (line) == 'V') { // Any video frame type
                cur_time_offset = ODIDIndexEntry.time_us (line);
                cur_data_offset = ODIDIndexEntry.offset_field (line); // Convert only when needed
                // debug ("offsets_within_time_range: frame at %s (%s) has offset %s",
                //       extended_time_string, cur_time_offset.to_string(), cur_data_offset);
                if (!start_offset_found
                    && (ODIDIndexEntry.subtype (line) == 'I') // Only consider keyframes for start
                    && ((is_reverse && (cur_time_offset <= start_time))
                         || (!is_reverse && (cur_time_offset >= start_time)) ) ) {
                        start_time = cur_time_offset;
                        start_offset = int64.parse (strip_leading_zeros (cur_data_offset));
                        start_offset_found = true;
                        debug ("offsets_within_time_range: found start of range (%s): time %lld, offset %lld",
                               (is_reverse ? "reverse" : "forward"),
                               start_time, start_offset);
                }
                if (start_offset_found // Consider any video frame type for end
                    && ( (is_reverse && (cur_time_offset < end_time))
                         || (!is_reverse && (cur_time_offset > end_time)) ) ) {
                    end_time = last_time_offset;
                    end_offset = int64.parse (strip_leading_zeros (last_data_offset));
                    end_offset_found = true;
                    debug ("offsets_within_time_range: found end of range (%s): time %lld, offset %lld",
                           (is_reverse ? "reverse" : "forward"),
                           end_time, end_offset);
                    break; // We're done
                    // Note: One entry can be larger than the requested start or end time. 
                }
                last_time_offset = cur_time_offset;
                last_data_offset = cur_data_offset;
            }
        }

        if (!start_offset_found) {
            start_offset = total_size;
            if (is_reverse) {
                start_time = 0;
            } else {
                start_time = total_duration;
            }
            debug ("offsets_within_time_range: start of range beyond last frame (%s): time %lld, offset %lld",
                   (is_reverse ? "reverse" : "forward"), start_time, start_offset);
        }
        if (!end_offset_found) {
            // Modify the end byte value to align to start/end of the file, if necessary
            //  (see DLNA 7.5.4.3.2.24.4)
            end_offset = total_size;
            if (is_reverse) {
                end_time = 0;
            } else {
                end_time = total_duration;
            }
            debug ("offsets_within_time_range: end of range beyond last frame (%s): time %lld, offset %lld",
                   (is_reverse ? "reverse" : "forward"), end_time, end_offset);
        }
    }
    
    /**
     * Moves the index_stream forward to the index entry with an offset >= the
     * data_offset and returns the time offset of the entry (in milliseconds).
     *
     * If data_offset is 0, 0 is returned. If the offset is larger than the last
     * index entry, int64.MAX is returned.
     */
    internal static int64 advance_index_to_offset (DataInputStream index_stream,
                                                   ref int64 data_offset)
            throws Error {
        // debug ("advance_index_to_offset: %lld", data_offset);

        if (data_offset == 0) { // 0-time is always a valid random access point
            // debug ("advance_index_to_offset: Using 0 time/offset");
            return 0;
        }

        string line;
        int line_count = 0;
        // Read lines until end of file (null) is reached
        while ((line = index_stream.read_line (null)) != null) {
            line_count++;
            if (!ODIDIndexEntry.size_ok (line)) {
                throw new ODIDMediaEngineError.INDEX_FILE_ERROR (
                              "Bad index file entry size (entry is %d bytes, should be %u bytes): '%s'",
                              line.length+1, ODIDIndexEntry.ROW_SIZE, line);
            }
            // Any entry type is ok (not checking the type)
            // debug ("advance_to_offset: entry at %s (%s) has offset %s",
            //        extended_time_string, cur_time_offset.to_string(), cur_data_offset);
            int64 cur_data_offset = ODIDIndexEntry.offset_bytes (line);
            if (cur_data_offset >= data_offset) {
                data_offset = cur_data_offset;
                int64 time_offset_ms = ODIDIndexEntry.time_ms (line);
                // debug ("advance_index_to_offset: found offset %lld with time %0.3f",
                //        data_offset, msec_to_secs (time_offset_ms));
                return (time_offset_ms);
            }
        }
        return int64.MAX;
    }

    /**
     * Find the vobu data offsets that cover the provided time range start_time to end_time.
     */
    internal static void vobu_aligned_offsets_for_range (File index_file, 
                                                         int64 start, int64 end,
                                                         out int64 start_offset,
                                                         Gee.ArrayList<int64?> aligned_range_list,
                                                         int64 total_size)
         throws Error {
        debug ("vobu_offsets_for_range: %s\n", index_file.get_basename () );
        bool start_offset_found = false;
        bool end_offset_found = false;

        var dis = new DataInputStream (index_file.read ());
        string line;
        int64  aligned_offset;
        int64  end_offset;
        start_offset = int64.MAX;
        int line_count = 0;
        // Clear the list
        aligned_range_list.clear ();
        // Read lines until end of file (null) is reached
        while ((line = dis.read_line (null)) != null) {
            line_count++;
            if (!ODIDIndexEntry.size_ok (line)) {
                throw new ODIDMediaEngineError.INDEX_FILE_ERROR (
                              "Bad index file entry size (line %d of %s is %d bytes - should be %u bytes): '%s'",
                              line_count, index_file.get_basename (), line.length+1,
                              ODIDIndexEntry.ROW_SIZE, line);
            }
            if ( (ODIDIndexEntry.type (line) == 'S')
                 && (ODIDIndexEntry.subtype (line) == 'S')) {
                aligned_offset = ODIDIndexEntry.offset_bytes (line);
                if (!start_offset_found) {
                    if( aligned_offset <= start ) {
                        debug ("vobu_offsets_for_range: found start of range req_start %lld, aligned_start %lld",
                               start, aligned_offset);
                                
                        start_offset = aligned_offset;
                        start_offset_found = true;
                        continue;
                    }
                }
                // If a byte range spans multiple vobus, each vobu boundary
                // needs to be added to a list so that the vobus can be
                // streamed one at a time.
                // From DLNA_Link_Protection_Part_3_2011-12-01.pdf
                // 8.9.5.3.2 (For content using MPEG-2 Program Stream (PS) transferred with the HTTP
                // transport protocol, the size of each PCP shall be one VOBU)
                if (!end_offset_found) {
                    if (aligned_offset >= end && end != 0) {
                         debug ("vobu_offsets_for_range: found end of range req_end %lld, aligned_end %lld",
                                   end, aligned_offset);
                         end_offset = aligned_offset;
                         aligned_range_list.add (aligned_offset);
                         end_offset_found = true;
                     }
                     else {
                         aligned_range_list.add (aligned_offset);
                     } 
                 }
             }
        }

        if (!start_offset_found) {
            throw new DataSourceError.SEEK_FAILED ("Start offset %lld is out of index file range",
                                                  start);
        }

        if (!end_offset_found) {
            // Modify the end byte value to align to start/end of the file, if necessary
            //  (see DLNA 7.5.4.3.2.24.4)
            //end_offset = total_size;
            aligned_range_list.add (total_size);
            debug ("vobu_offsets_for_range: end of range beyond index range offset %lld", total_size);
        }
    }

    internal static string strip_leading_zeros (string number_string) {
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

    public static float usec_to_secs (uint64 time_us) {
        return ((float)time_us)/MICROS_PER_SEC;
    }

    public static float msec_to_secs (uint64 time_ms) {
        return ((float)time_ms)/MILLIS_PER_SEC;
    }

    internal static int64 calculate_dtcp_encrypted_length
                                (int64 range_start, Gee.ArrayList<int64?> range_offset_list,
                                int64 chunk_size)
            throws Error {
        int64 encrypted_total = 0;
        foreach (int64 range_end in range_offset_list) {
            int64 encrypted_length = (int64) Dtcpip.get_encrypted_length
                                              (range_end-range_start, chunk_size);
            encrypted_total += encrypted_length;
            // debug ("Encrypted size of range %lld-%lld (%lld bytes) is %lld. Total: %lld",
            //        range_start, range_end, range_end-range_start,
            //        encrypted_length, encrypted_total);
            range_start = range_end;
        }

        return encrypted_total;
    }

    /**
     * Note: range_end and aligned_end are non-inclusive
     */
    internal static void get_dtcp_aligned_range (MediaResource res, File index_file,
                                                 int64 range_start, int64 req_end_val,
                                                 int64 total_size,
                                                 out int64 aligned_start,
                                                 Gee.ArrayList<int64?> aligned_range_list) 
       throws Error {
        //Get the transport stream packet size for the profile
        string profile = res.dlna_profile;
        aligned_start = range_start;
        // Transport streams
        if ((profile.has_prefix ("DTCP_MPEG_TS") ||
             profile.has_prefix ("DTCP_AVC_TS")) ) {
            // Align the bytes to transport packet boundaries
            int64 packet_size = ODIDUtil.get_profile_packet_size (profile);
            // TODO: Align beginning of the packet also??
            if (packet_size > 0) {
                // DLNA Link Protection : 8.9.5.4.2
                int64 aligned_end = ODIDUtil.get_dtcp_aligned_end (range_start, req_end_val,
                                                                   packet_size);
                aligned_end = int64.min (aligned_end, total_size);
                aligned_range_list[0] = aligned_end;
            }
            else {
                aligned_range_list[0] = req_end_val;
            }
        } 
        // Program streams
        else if ((profile.has_prefix ("DTCP_MPEG_PS"))) {
            // Align the 'end' to VOBU boundary
            // This can be a list of vobu offsets
            ODIDUtil.vobu_aligned_offsets_for_range (index_file,
                           range_start, req_end_val,
                           out aligned_start, aligned_range_list,
                           total_size );
        } 
        else {
            warning ("Attemped to DTCP-align unsupported protocol: "
                     + profile);
        }
    }

    // DTCP content has to be aligned to a packet boundary.  188 or 192
    // Note: end_byte is not inclusive
    internal static int64 get_dtcp_aligned_end (int64 start_byte, int64 end_byte,
                                                int64 packet_size) {
        int64 temp_end;
        if (end_byte > 0) {
            // Check if the total length falls between the packet size.
            // Else add bytes to complete packet size.
            int64 req_length = end_byte - start_byte;
            int64 add_bytes = (packet_size - (req_length % packet_size)) % packet_size;
            temp_end = end_byte + add_bytes;
        } else {
            temp_end = end_byte;
        }
        return temp_end;
    }

    // Identify the packet size from the profile
    internal static int64 get_profile_packet_size (string profile) {
        // TODO : Need to consider mime types other than MPEG.
        if ((profile.has_prefix ("DTCP_MPEG_TS") ||
             profile.has_prefix ("DTCP_AVC_TS")) &&
             profile.has_suffix ("_ISO")) {
            return PACKET_SIZE_188;
        }
        // For Timestamped 192 byte packets for non ISO profiles
        if ((profile.has_prefix ("DTCP_MPEG_TS") ||
             profile.has_prefix ("DTCP_AVC_TS")) &&
             !profile.has_suffix ("_ISO")){
            return PACKET_SIZE_192;
        }
        // For MPEG_PS content alignment.(DLNA Link Protection 8.9.5.2.2)
        // The Decoder Friendly Alignment Position for bitstreams using MPEG-2 
        // Program Stream (PS) to these profiles shall be the VOBU boundary.
        // It is handled in odid data source by reading VOBU boundaries
        // from the index file.  
        return 0;
    }

    /**
     * Return a string representation of the given system time (in microseconds) as
     *
     * YYYY-MM-DDTHH:MM:SS+TZ +0.SSSSSSs
     */
    internal static string system_time_to_string (int64 time_us) {
		var datetime = new GLib.DateTime.from_unix_local (time_us/1000000);
        return "%s +0.%06llds".printf (datetime.to_string (),
                                        time_us % 1000000);
    }

    /**
     * Get the URI to a resource (dir) given the uri to the item info file and the
     *  MediaResource.
     */
    internal static string get_resource_uri (string odid_item_info_uri, MediaResource res)
         throws Error {
        // The resources are published by this engine with the resource name == subdir name
        return (get_item_uri (odid_item_info_uri) + res.get_name () + "/");
    }

    /**
     * Get the URI to a item (dir) given the uri to the item info file
     */
    internal static string get_item_uri (string odid_item_info_uri)
         throws Error {
        // TODO: Consider our own uri scheme (e.g. "odid:")
        if (!odid_item_info_uri.has_prefix ("file://")) {
            throw new ODIDMediaEngineError.CONFIG_ERROR
                          ("Only file/odid URIs are supported");
        }

        File item_info_file = File.new_for_uri (odid_item_info_uri);
        KeyFile item_info_keyfile = new KeyFile ();
        item_info_keyfile.load_from_file (item_info_file.get_path(),
                                          KeyFileFlags.KEEP_COMMENTS
                                          | KeyFileFlags.KEEP_TRANSLATIONS);
        string item_dir_uri;
        if (item_info_keyfile.has_key ("item", "odid_uri")) {
            item_dir_uri = item_info_keyfile.get_string ("item", "odid_uri");
        } else {
            // If the odid_uri property is not available, assume the info file is in the
            //  item's base directory (and the resources are in the same directory)
            var parent_dir = item_info_file.get_parent ();
            if (parent_dir == null) {
                throw new DataSourceError.GENERAL ("Root level odid items not supported");
            }
            item_dir_uri = parent_dir.get_uri () + "/";
        }

        return item_dir_uri;
    }

    internal static string ? get_resource_property (string odid_resource_uri,
                                                  string property_name)
         throws Error {
        return get_property_from_file (odid_resource_uri + "resource.info",
                                       property_name);
    }

    internal static string ? get_content_property (string odid_content_uri,
                                                   string property_name)
         throws Error {
        string content_info_filename = odid_content_uri + ".info";
        try {
            return get_property_from_file (content_info_filename, property_name);
        } catch (Error error) {
            debug ("Content info file %s not found (non-fatal)", content_info_filename);
            return null;
        }
    }

    internal static string ? get_property_from_file (string uri, string property_name)
         throws Error {
        var file = File.new_for_uri (uri);
        var dis = new DataInputStream (file.read ());
        string line;
        // Read lines until end of file (null) is reached
        while ((line = dis.read_line (null)) != null) {
            if (line.length == 0) continue;
            if (line[0] == '#') continue;
            var equals_pos = line.index_of ("=");
            var name = line[0:equals_pos].strip ();
            if (name == property_name) {
                var value = line[equals_pos+1:line.length].strip ();
                return ((value.length == 0) ? null : value);
            }
        }

        return null;
    }

    public static string short_resource_path (string odid_resource_uri) {
        // Return a string with the last two path elements of a resource URI
        var segments = odid_resource_uri.split ("/");
        return segments[segments.length-3] + "/" + segments[segments.length-2];
    }

    public static string short_content_path (string odid_content_uri) {
        // Return a string with the last three path elements of a content URI
        var segments = odid_content_uri.split ("/");
        return segments[segments.length-3] + "/" + segments[segments.length-2]
                                           + "/" + segments[segments.length-1];
    }

    /**
     * Returns the duration of the normal-rate resource (in microseconds)
     */
    public static int64 duration_for_resource_us (string resource_uri) throws Error {
        var basename = get_resource_property (resource_uri, "basename");
        string file_extension;
        var content_filename = content_filename_for_res_speed (
                                                      resource_uri,
                                                      basename,
                                                      null, // Looking for 1.0-rate content
                                                      out file_extension );
        var index_file = File.new_for_uri (resource_uri + content_filename + ".index");
        if (!index_file.query_exists ()) {
            throw new ODIDMediaEngineError.CONFIG_ERROR
                          ("Index file not found/accessible: " + index_file.get_uri ());
        }
        return duration_from_index_file_ms (index_file) * MICROS_PER_MILLI;
    }

    public static void touch_file_and_parentdir (string file_uri) {
        try {
            File file = File.new_for_uri (file_uri);
            touch_file (file);
            touch_file (file.get_parent ());
        } catch (Error e) {
            warning ("touch_file: Error touching file: %s\n", e.message);
        }
    }

    public static void touch_file_uri (string file_uri) {
        try {
            File file = File.new_for_uri (file_uri);
            touch_file (file);
        } catch (Error e) {
            warning ("touch_file_uri: Error touching file: %s\n", e.message);
        }
    }

    public static void touch_file (File file) throws Error {
        FileInfo file_info = file.query_info (FileAttribute.TIME_MODIFIED, 0);
        TimeVal timeval_now = TimeVal ();
        debug ("touch_file: Changing modification time of %s from %s to %s", file.get_path (),
               file_info.get_modification_time ().to_iso8601 (), timeval_now.to_iso8601 ());
        file_info.set_modification_time (timeval_now);
        file.set_attributes_from_info (file_info, 0);
    }
}

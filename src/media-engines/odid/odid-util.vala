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
    private static ODIDUtil util = null;
    public const int64 PACKET_SIZE_188 = 188;
    public const int64 PACKET_SIZE_192 = 192;
    public const int64 KILOBYTES_TO_BYTES = 1024;

    private ODIDUtil () {
    }

    public static ODIDUtil get_default () {
        if (util == null) {
            util = new ODIDUtil ();
        }

        return util;
    }

    /**
     * Find the vobu data offsets that cover the provided time range start_time to end_time.
     *
     */
    public static void vobu_aligned_offsets_for_range (string index_path, 
                                          int64 start, int64 end,
                                          out int64 start_offset, Gee.ArrayList<int64?> aligned_range_list,
                                          int64 total_size)
         throws Error {
        debug ("vobu_offsets_for_range: %s\n", index_path );
        bool start_offset_found = false;
        bool end_offset_found = false;

        var file = File.new_for_uri (index_path);
        var dis = new DataInputStream (file.read ());
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
            // Entry Type (S: System)
            // | Type (S: System header (identifies vobu (video object unit) boundaries in program streams))
            // | | Time Offset (seconds.milliseconds) (fixed decimal places, 8.3)
            // | | |            File Byte Offset (fixed decimal places, 19)
            // | | |            |                   Vobu size (fixed decimal places, 10)
            // | | |            |                   |
            // v v v            v                   v
            // S S 00000000.000 0000000000000000000 0000000000<16 spaces><newline>
            if (line.length != ODIDMediaEngine.INDEXFILE_ROW_SIZE-1) {
                throw new ODIDMediaEngineError.INDEX_FILE_ERROR (
                              "Bad index file entry size (line %lld of %s is %d bytes - should be %d bytes): '%s'",
                              line_count, index_path, line.length,
                              ODIDMediaEngine.INDEXFILE_ROW_SIZE, line);
            }
            var index_fields = line.split (" "); // Could use fixed field positions here...
            if ((index_fields[0][0] == 'S') && (index_fields[1][0] == 'S')) {
                aligned_offset = int64.parse (strip_leading_zeros (index_fields[3]));
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
        return ODIDMediaEngine.strip_leading_zeros (number_string);
    }

    // DTCP content has to be aligned to a packet boundary.  188 or 192
    // Note: end_byte is not inclusive
    public static int64 get_dtcp_aligned_end (int64 start_byte, int64 end_byte, int64 packet_size) {
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
    public static int64 get_profile_packet_size (string profile) {
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
     * Returns if the content is protected
     */
    public bool is_item_protected (MediaItem item){
        return false;
    }

    /**
     * Returns the chunk size in bytes to be used while streaming.
     * rygel.conf will provide value in KiloBytes
     */
    public static int64 get_chunk_size (string chunk_size_str) {
        var chunk_size = int64.parse (chunk_size_str) * KILOBYTES_TO_BYTES;
        debug ("Streaming chunk size : %"+int64.FORMAT, chunk_size);
        return chunk_size;
    }

}

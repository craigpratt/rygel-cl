/*
 * Copyright (C) 2013  Cable Television Laboratories, Inc.
 * Contact: http://www.cablelabs.com/
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
 * IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL APPLE INC. OR ITS CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 *
 * Author: Parthiban Balasubramanian <P.Balasubramanian-contractor@cablelabs.com>
 */

using Dtcpip;

public class Rygel.ODIDUtil : Object {
    private static ODIDUtil util = null;
    public const int64 PACKET_SIZE_188 = 188;
    public const int64 PACKET_SIZE_192 = 192;

    private ODIDUtil() {

    }

    public static ODIDUtil get_default() {
        if (util == null) {
            util = new ODIDUtil();
        }

        return util;
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
        //TODO : Handle MPEG_PS content alignment.(DLNA Link Protection 8.9.5.1.1)
        return 0;
    }
    
    /**
     * Returns if the content is protected
     */
    public bool is_item_protected (MediaItem item){
        return false;
    }

}

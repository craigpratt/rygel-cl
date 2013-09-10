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
 */

public class Rygel.RygelHTTPRequestUtil : Object {
    private static RygelHTTPRequestUtil util = null;
    public const int64 PACKET_SIZE_188 = 188;
    public const int64 PACKET_SIZE_192 = 192;
    public const string dtcp_mime_prefix = "application/x-dtcp1";
    public const string dtcp_host_str = "DTCP1HOST=";
    public const string dtcp_port_str = "DTCP1PORT=";
    public const string content_format_str = "CONTENTFORMAT=";
    public const string dtcp_prefix = "DTCP_";

    private RygelHTTPRequestUtil() {

    }

    public static RygelHTTPRequestUtil get_default() {
        if (util == null) {
			util = new RygelHTTPRequestUtil();
		}

		return util;
	}

    // DTCP content has to be aligned to a packet boundary.  188 or 192
	public static int64 get_dtcp_algined_end (int64 start_byte, int64 end_byte, int64 packet_size) {
        int64 temp_end;
        if (end_byte > 0) {
			// Check if the total length falls between the packet size.
			// Else add bytes to complete packet size.
			int64 req_length = end_byte - start_byte +1;
			int64 add_bytes = packet_size - (req_length % packet_size);
			temp_end = end_byte + add_bytes;
		} else {
			temp_end = end_byte;
		}
		return temp_end;
	}

	// TODO : Identify the packet size from the profile
    public static int64 get_profile_packet_size (string profile) {
        // TODO : Need to consider mime types other than MPEG.
        if (profile.has_prefix ("DTCP_MPEG_TS") && profile.has_suffix ("_ISO")) {
			return PACKET_SIZE_188;
	    }
        // For Timestamped 192 byte packets
        if (profile.has_prefix ("DTCP_MPEG_TS") && !profile.has_suffix ("_ISO")){
			return PACKET_SIZE_192;
	    }
	    //TODO : Handle MPEG_PS content alignment.(DLna Link Protection 8.9.5.1.1)
		return 0;
	}

	 /**
      * Modify mime type if the item is protected.
      * This can call into a custom class that will have knowledge.
      */
    public static string handle_mime_item_protected (string mime_type) {
        string dtcp_host;
        string dtcp_port;

        var config = MetaConfig.get_default();
        try {
            dtcp_host = config.get_string ("general","dtcp-host");
            dtcp_port = config.get_string ("general", "dtcp-port");

            if (dtcp_host != "" && dtcp_port != "") {
                return dtcp_mime_prefix + ";" + dtcp_host_str + dtcp_host + ";" +
                       dtcp_port_str + dtcp_port + ";" + content_format_str + "\"" +
                       mime_type +"\"";
		    }
        } catch (Error err) {
            error ("Error reading dtcp host/port :" + err.message);
        }

        return mime_type;
    }

    /**
     * Returns if dtcp is enabled Rygel wide,
     * with DTCP (keys, host, port) values.
     */
    public static bool is_rygel_dtcp_enabled () {
        var config = MetaConfig.get_default();
	    bool dtcp_enabled = false;

        try {
            dtcp_enabled = config.get_bool ("general","dtcp-enabled");
        } catch (Error err) {
            error("Error reading dtcp enabled property :"+ err.message);
        }
        return dtcp_enabled;
    }

    /**
     * Returns if the content is protected
     */
    public bool is_item_protected (MediaItem item){
		return false;
	}

    public static string[] parse_dtcp_range_header (string range_header) {
        string[] range_tokens = null;
		if (!range_header.has_prefix ("bytes=")) {
			return range_tokens;
		}

        debug ("range_header has prefix %s", range_header);
        range_tokens = range_header.substring (6).split ("-", 2);

        return range_tokens;
	}

}

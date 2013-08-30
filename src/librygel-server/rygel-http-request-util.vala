/*
 * Copyright (C) 2013 CableLabs
 */

public class Rygel.RygelHTTPRequestUtil : Object {
    private static RygelHTTPRequestUtil util = null;
    private static long PACKET_SIZE_188 = 188;
    private static long PACKET_SIZE_192 = 192;

    private RygelHTTPRequestUtil() {

    }

    public static RygelHTTPRequestUtil get_default() {
        if (util == null) {
			util = new RygelHTTPRequestUtil();
		}

		return util;
	}

    // DTCP content has to be aligned to a packet boundary.  188 or 192
	public static long get_dtcp_algined_end (long start_byte, long end_byte, long packet_size) {
        long temp_end;
        if (end_byte > 0) {
			// Check if the total length falls between the packet size.
			// Else add bytes to complete packet size.
			long req_length = end_byte - start_byte +1;
			long add_bytes = packet_size - (req_length % packet_size);
			temp_end = end_byte + add_bytes;
		} else {
			temp_end = end_byte;
		}
		return temp_end;
	}

	// TODO : Identify the packet size from the profile
	// Write a method in mediaengine to give this information
    public static long get_profile_packet_size (string profile) {
        // TODO : Need to consider mime types other than MPEG.
        if (profile.has_prefix ("DTCP_MPEG") || profile.has_prefix("MPEG")) {
            if (!profile.has_suffix ("_ISO")) {
			    return PACKET_SIZE_188;
		    } else {
			    return PACKET_SIZE_192;
		    }
	    }
	    //TODO : Handle more mime types properly.
	    // Returning packet size as 188 if other than above conditions.
		return PACKET_SIZE_188;
	}

}

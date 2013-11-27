/*
 * Copyright (C) 2008 Zeeshan Ali <zeenix@gmail.com>.
 *
 * Author: Zeeshan Ali <zeenix@gmail.com>
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
 * Author: Craig Pratt <craig@ecaspia.com>
 */

using GUPnP;

/**
 * Represents a picture or video thumbnail.
 */
public class Rygel.Thumbnail : Rygel.IconInfo {
    public string dlna_profile;

    public Thumbnail (string mime_type = "image/jpeg",
                      string dlna_profile = "JPEG_TN",
                      string file_extension = "jpg") {
        base (mime_type, file_extension);

        this.dlna_profile = dlna_profile;
    }

    internal virtual MediaResource get_resource (string protocol) {
        MediaResource res = new MediaResource (protocol + "_thumbnail");

        res.size = this.size;
        res.width = this.width;
        res.height = this.height;
        res.color_depth = this.depth;
        res.mime_type = this.mime_type;
        res.dlna_profile = this.dlna_profile;
        res.protocol = protocol;
        // Note: These represent best-case. The MediaServer/HTTPServer can dial these back
        res.dlna_flags |= DLNAFlags.INTERACTIVE_TRANSFER_MODE |
                          DLNAFlags.BACKGROUND_TRANSFER_MODE |
                          DLNAFlags.CONNECTION_STALL |
                          DLNAFlags.DLNA_V15;
        res.dlna_operation = DLNAOperation.RANGE;
        res.dlna_conversion = DLNAConversion.TRANSCODED;

        return res;
    }
}

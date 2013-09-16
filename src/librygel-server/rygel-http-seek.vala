/*
 * Copyright (C) 2008-2009 Nokia Corporation.
 * Copyright (C) 2012 Intel Corporation.
 *
 * Author: Zeeshan Ali (Khattak) <zeeshanak@gnome.org>
 *                               <zeeshan.ali@nokia.com>
 *         Jens Georg <jensg@openismus.com>
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

public errordomain Rygel.HTTPSeekError {
    INVALID_RANGE = Soup.KnownStatusCode.BAD_REQUEST,
    OUT_OF_RANGE = Soup.KnownStatusCode.REQUESTED_RANGE_NOT_SATISFIABLE,
}

public enum Rygel.HTTPSeekType {
    BYTE,
    TIME
}

/**
 * HTTPSeek is an abstract representation of a ranged HTTP request.
 *
 * It can be one of:
 *
 *  - The classic Range request (seek_type == HTTPSeekType.BYTE), with start and stop in bytes.
 *  - The DLNA-Specific "TimeSeekRange.dlna.org" request (seek_type == HTTPSeekType.TIME) with start and stop in microseconds.
 */
public abstract class Rygel.HTTPSeek : GLib.Object {

    /**
     * Identifies whether this is a class Range request or a DLNA-specific
     * "TimeSeekRange.dlna.org" request.
     */
    public HTTPSeekType seek_type { get; protected set; }
    public Soup.Message msg { get; private set; }

    /**
     * The start of the range as a number of bytes (classic) or as microseconds 
     * (DLNA-specific). See seek_type.
     */
    public int64 start { get; private set; }

    /**
     * The end of the range as a number of bytes (classic) or as microseconds 
     * (DLNA-specific). See seek_type.
     */
    public int64 stop { get; private set; }

    /**
     * Either 1 byte (classic) or as 1000 G_TIME_SPAN_MILLISECOND microseconds 
     * (DLNA-specific). See seek_type.
     */
    public int64 step { get; private set; }

    /**
     * The length of the range as a number of bytes (classic) or as microseconds 
     * (DLNA-specific). See seek_type.
     */
    public int64 length { get; private set; }

    /**
     * The length of the media file as a number of bytes (classic) or as microseconds 
     * (DLNA-specific). See seek_type.
     */
    public int64 total_length { get; private set; }

    /**
     * The resource name which has been requested as string.
     */
    public string resource_name { get; protected set;}

    /**
     * If the request includes a protected content.
     */
    public bool content_protected { get; protected set;}

    public HTTPSeek (Soup.Message msg,
                     int64        start,
                     int64        stop,
                     int64        step,
                     int64        total_length,
                     bool         is_protected) throws HTTPSeekError {
        this.msg = msg;
        this.start = start;
        this.stop = stop;
        this.length = length;
        this.total_length = total_length;
        this.content_protected = is_protected;
        // TODO: Had to disable this for now since these fields are properties
        //       of resources and not items and the unset values trigger these
        //       range checks
        // if (start < 0 || start >= total_length) {
        //     throw new HTTPSeekError.OUT_OF_RANGE (_("Out Of Range Start '%ld'"),
        //                                          start);
        // }
        // if (stop < 0 || stop >= total_length) {
        //     throw new HTTPSeekError.OUT_OF_RANGE (_("Out Of Range Stop '%ld'"),
        //                                           stop);
        // }

        if (length > 0) {
            this.stop = stop.clamp (start + 1, length - 1);
        }

        this.length = stop + step - start;
    }

    public abstract void add_response_headers ();
}

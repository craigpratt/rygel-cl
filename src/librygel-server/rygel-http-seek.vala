/*
 * Copyright (C) 2008-2009 Nokia Corporation.
 * Copyright (C) 2012 Intel Corporation.
 *
 * Author: Zeeshan Ali (Khattak) <zeeshanak@gnome.org>
 *                               <zeeshan.ali@nokia.com>
 *         Jens Georg <jensg@openismus.com>
 *         Craig Pratt <craig@ecaspia.com>
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

/**
 * HTTPSeek is an abstract representation of a ranged HTTP request.
 *
 * Note that subclasses can represent different types of intra-resource requests
 * (e.g. HTTP Range, DLNA TimeSeekRange request). The base class represents the
 * byte-level request/response and the common interface for the request processing
 * and response generation. 
 */
public abstract class Rygel.HTTPSeek : GLib.Object {
    public static const int64 UNSPECIFIED_RANGE_VAL = -1;
    
    public Soup.Message msg { get; private set; }

    /**
     * The start of the range in bytes 
     */
    public int64 start_byte { get; set; }

    /**
     * The end of the range in bytes (inclusive)
     */
    public int64 end_byte { get; set; }

    /**
     * The length of the range in bytes
     */
    public int64 length { get; private set; }

    /**
     * The length of the resource in bytes
     */
    public int64 total_length { get; set; }

    public HTTPSeek (Soup.Message msg) {
        this.msg = msg;
        unset_byte_range();
        unset_total_length();
    }

    /**
     * Set the byte range that corresponds with the seek and the total size of the resource
     *
     * @param start The start byte offset of the byte range
     * @param stop The stop byte offset of the off set (inclusive)
     * @param total_length The total length of the resource
     */
    public void set_byte_range (int64   start,
                                int64   stop) throws HTTPSeekError {
        this.start_byte = start;
        this.end_byte = stop;

        // Byte ranges only go upward (at least DLNA 7.5.4.3.2.24.4 doesn't say otherwise)
        if (start > stop) {
            throw new HTTPSeekError.OUT_OF_RANGE (_("Range stop byte before start: Start '%ld', Stop '%ld'"),
                                                  start, stop);
        }

        this.length = stop - start + 1; // Range is inclusive, so add 1 to capture byte at stop
    }

    public void unset_byte_range() {
        this.start_byte = UNSPECIFIED_RANGE_VAL;
        this.end_byte = UNSPECIFIED_RANGE_VAL;
    }

    /**
     * Return true of the byte range is set.
     */
    public bool byte_range_set() {
        return (this.start_byte != UNSPECIFIED_RANGE_VAL);
    }    

    public void unset_total_length() {
        this.total_length = UNSPECIFIED_RANGE_VAL;
    }
    
    /**
     * Return true of the length is set.
     */
    public bool total_length_set() {
        return (this.total_length != UNSPECIFIED_RANGE_VAL);
    }

    /**
     * Set the reponse headers on the associated HTTP Message corresponding to the seek request 
     */
    public abstract void add_response_headers ();
}

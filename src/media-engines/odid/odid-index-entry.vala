/*
 * Copyright (C) 2014  Cable Television Laboratories, Inc.
 *
 * Author: Craig Pratt <craig@ecaspia.com>
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

public errordomain Rygel.ODIDIndexEntryError {
    INVALID_ENTRY_FORMAT,
    TIME_FORMAT_ERROR,
    OFFSET_FORMAT_ERROR,
}

/**
 * This class operates on an entry in an ODID content index file
 *
 * Note: Everything is static here for speed/memory. We don't want to be allocating an object
 *       just to parse some values...
 */
public class Rygel.ODIDIndexEntry : Object {
    // Index File Entry Syntax (62 bytes per row)
    // 
    // Type (V: Video Frame, S: System Info, ...)
    // | Subtype (Video Frame: Frame Type (I,B,P), System: System Header (S=PS System Header)
    // | | Time Offset (seconds.milliseconds) (fixed decimal places, 7.3)
    // | | |           File Byte Offset (fixed decimal places, 19)
    // | | |           |                   Type-specific data (25 bytes)
    // | | |           |                   | Video Frame: Frame size (10 decimals) + 15 spaces
    // | | |           |                   | System Info: VOBU size (10 decimals) + 15 spaces
    // v v v           v                   v
    // T S 0000000.000 0000000000000000000 *************************<newline>

    public static const uint ROW_SIZE = 62;
    public static const uint ENTRYTYPE_OFFSET = 0;
    public static const uint FRAMETYPE_OFFSET = 2;
    public static const uint TIME_OFFSET = 4;
    public static const uint TIMESECONDS_LENGTH = 7;
    public static const uint TIMEMS_LENGTH = 3;
    public static const uint TIME_LENGTH = 11;
    public static const uint BYTEOFFSET_OFFSET = 16;
    public static const uint BYTEOFFSET_LENGTH = 19;
    public static const uint FRAMESIZE_OFFSET = 36;
    public static const uint FRAMESIZE_LENGTH = 10;

    public string index_line;

    public static bool size_ok (string index_line) {
        return (index_line.length+1 == ROW_SIZE);
    }

    public static uchar type (string index_line) {
        return index_line[0];
    }

    public static uchar subtype (string index_line) {
        return index_line[2];
    }

    public static string time_field (string index_line) throws Error {
        return index_line[TIME_OFFSET : TIME_OFFSET+TIME_LENGTH];
    }

    public static string time_ms_string (string index_line) throws Error {
        var ext_time = new StringBuilder.sized (TIME_LENGTH);
        var offset = TIME_OFFSET;
        ext_time.append (index_line[offset:offset+TIMESECONDS_LENGTH]);
        offset += TIMESECONDS_LENGTH + 1; // Skip the dot
        ext_time.append (index_line[offset:offset+TIMEMS_LENGTH]);
        return ext_time.str;
    }

    public static int64 time_ms (string index_line) throws Error {
        var ext_time = time_ms_string (index_line);

        int64 entry_time_ms;
        // Leading "0"s cause try_parse() to assume the value is octal (see Vala bug 656691)
        if (!int64.try_parse (strip_leading_zeros (ext_time), out entry_time_ms)) {
            throw new ODIDIndexEntryError.TIME_FORMAT_ERROR ("Bad time value in index entry: '%s'",
                                                             index_line);
        }
        return entry_time_ms;
    }

    public static int64 time_field_to_time_ms (string time_field) throws Error {
        var ext_time = new StringBuilder.sized (TIME_LENGTH);
        ext_time.append (time_field[0:TIMESECONDS_LENGTH]);
        uint offset = TIMESECONDS_LENGTH + 1; // Skip the dot
        ext_time.append (time_field[offset:offset+TIMEMS_LENGTH]);

        int64 entry_time_ms;
        // Leading "0"s cause try_parse() to assume the value is octal (see Vala bug 656691)
        if (!int64.try_parse (strip_leading_zeros (ext_time.str), out entry_time_ms)) {
            throw new ODIDIndexEntryError.TIME_FORMAT_ERROR ("Bad time value in index entry: '%s'",
                                                             index_line);
        }
        return entry_time_ms * MICROS_PER_MILLI;
    }

    /**
     * Returns time as seconds (rounded up)
     */
    public static long time_s (string index_line) throws Error {
        var time_field = time_field (index_line);

        double time_s;
        if (!double.try_parse (time_field, out time_s)) {
            throw new ODIDIndexEntryError.TIME_FORMAT_ERROR ("Bad time value in index entry: '%s'",
                                                             index_line);
        }
        return (long)(time_s+0.999); // Round up to the next integer
    }

    public static int64 time_us (string index_line) throws Error {
        return (time_ms (index_line) * 1000); // 1000 microseconds per millisecond
    }

    public static string offset_field (string index_line) throws Error {
        return index_line[BYTEOFFSET_OFFSET : BYTEOFFSET_OFFSET+BYTEOFFSET_LENGTH];
    }

    public static int64 offset_bytes (string index_line) throws Error {
        string offset_string = strip_leading_zeros (offset_field (index_line));
        int64 offset_bytes;
        if (!int64.try_parse (offset_string, out offset_bytes)) {
            throw new ODIDIndexEntryError.OFFSET_FORMAT_ERROR ("Bad offset value \"%s\" in index entry: '%s'",
                                                               offset_string, index_line);
        }
        return offset_bytes;
    }

    private static string strip_leading_zeros (string number_string) {
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
}

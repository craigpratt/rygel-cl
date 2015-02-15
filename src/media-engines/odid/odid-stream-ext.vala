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

using Gee;

public class Rygel.Bits {
    public static uint64 getbits_64 (uint64 target, uint offset, uint width) 
            throws Error {
        if (offset+width > 64) {
            throw new IOError.FAILED ("Attempt to access bit %u in 64-bit field"
                                      .printf (offset+width)); 
        }
        uint64 bitmask;
        if ((offset+width) == 64) {
            bitmask = (0xFFFFFFFFFFFFFFFF << offset);
        } else {
            bitmask = (0xFFFFFFFFFFFFFFFF << offset) 
                      ^ (0xFFFFFFFFFFFFFFFF << (offset+width));  
        }
        return  (target & bitmask) >> offset;
    }

    public static uint64 readbits_64 (Rygel.ExtDataInputStream instream, 
                                     uint offset, uint width) 
            throws Error {
        return getbits_64 (instream.read_uint64 (), offset, width);
    }

    public static bool getbit_64 (uint64 target, uint offset) throws Error {
        if (offset >= 64) {
            throw new IOError.FAILED ("Attempt to access bit %u in 64-bit field"
                                      .printf (offset)); 
        }
        uint64 bitmask = 1 << offset;
        return (target & bitmask) == bitmask;
    }

    public static bool readbit_64 (Rygel.ExtDataInputStream instream, 
                                     uint offset) 
            throws Error {
        return getbit_64 (instream.read_uint64 (), offset);
    }

    public static uint32 getbits_32 (uint32 target, uint offset, uint width) 
            throws Error {
        if (offset+width > 32) {
            throw new IOError.FAILED ("Attempt to access bit %u in 32-bit field"
                                      .printf (offset+width)); 
        }
        uint32 bitmask;
        if ((offset+width) == 32) {
            bitmask = ((uint32)0xFFFFFFFF << offset);
        } else {
            bitmask = ((uint32)0xFFFFFFFF << offset) ^ ((uint32)0xFFFFFFFF << (offset+width));  
        }
        return  (target & bitmask) >> offset;
    }

    public static uint32 readbits_32 (Rygel.ExtDataInputStream instream, 
                                     uint offset, uint width) 
            throws Error {
        return getbits_32 (instream.read_uint32 (), offset, width);
    }

    public static bool getbit_32 (uint32 target, uint offset) throws Error {
        if (offset >= 32) {
            throw new IOError.FAILED ("Attempt to access bit %u in 32-bit field"
                                      .printf (offset)); 
        }
        uint64 bitmask = 1 << offset;
        return (target & bitmask) == bitmask;
    }

    public static bool readbit_32 (Rygel.ExtDataInputStream instream, 
                                     uint offset) 
            throws Error {
        return getbit_32 (instream.read_uint32 (), offset);
    }

    public static uint16 getbits_16 (uint16 target, uint offset, uint width) 
            throws Error {
        if (offset+width > 16) {
            throw new IOError.FAILED ("Attempt to access bit %u in 16-bit field"
                                      .printf (offset+width)); 
        }
        uint32 bitmask;
        if ((offset+width) == 16) {
            bitmask = ((uint32)0xFFFF << offset);
        } else {
            bitmask = ((uint32)0xFFFF << offset) ^ ((uint32)0xFFFFFFFF << (offset+width));  
        }
        return  (uint16)((target & bitmask) >> offset);
    }

    public static uint16 readbits_16 (Rygel.ExtDataInputStream instream, 
                                      uint offset, uint width) 
            throws Error {
        return getbits_16 (instream.read_uint16 (), offset, width);
    }

    public static bool getbit_16 (uint16 target, uint offset) throws Error {
        if (offset >= 16) {
            throw new IOError.FAILED ("Attempt to access bit %u in 16-bit field"
                                      .printf (offset)); 
        }
        uint64 bitmask = 1 << offset;
        return (target & bitmask) == bitmask;
    }

    public static bool readbit_16 (Rygel.ExtDataInputStream instream, 
                                      uint offset) 
            throws Error {
        return getbit_16 (instream.read_uint16 (), offset);
    }

    public static uint8 getbits_8 (uint8 target, uint offset, uint width) 
            throws Error {
        if (offset+width > 8) {
            throw new IOError.FAILED ("Attempt to access bit %u in 8-bit field"
                                      .printf (offset+width)); 
        }
        uint32 bitmask;
        if ((offset+width) == 16) {
            bitmask = ((uint32)0xFFFF << offset);
        } else {
            bitmask = ((uint32)0xFFFF << offset) ^ ((uint32)0xFFFFFFFF << (offset+width));  
        }
        return  (uint8)((target & bitmask) >> offset);
    }

    public static uint8 readbits_8 (Rygel.ExtDataInputStream instream, 
                                     uint offset, uint width) 
            throws Error {
        return getbits_8 (instream.read_byte (), offset, width);
    }

    public static bool getbit_8 (uint8 target, uint offset) throws Error {
        if (offset >= 8) {
            throw new IOError.FAILED ("Attempt to access bit %u in 8-bit field"
                                      .printf (offset)); 
        }
        uint64 bitmask = 1 << offset;
        return (target & bitmask) == bitmask;
    }

    public static bool readbit_8 (Rygel.ExtDataInputStream instream, 
                                    uint offset) 
            throws Error {
        return getbit_8 (instream.read_byte (), offset);
    }
}

public class Rygel.ExtDataInputStream : GLib.DataInputStream {
    public ExtDataInputStream (GLib.FileInputStream base_stream) {
        // Can't use: base (base_stream);
        // See https://mail.gnome.org/archives/vala-list/2009-October/msg00000.html
        Object (base_stream: base_stream);
        this.set_byte_order (DataStreamByteOrder.BIG_ENDIAN); // We want network byte order
    }

    public uint8[] read_buf (uint8[] byte_buffer) throws Error {
        if (read (byte_buffer) != byte_buffer.length) {
            throw new IOError.FAILED
                          ("Could not read %d bytes from the stream".printf (byte_buffer.length));
        }
        return byte_buffer;
    }

    public uint64[] read_uint64_array (uint64[] array) throws Error {
        for (int i=0; i<array.length; i++) {
            array[i] = read_uint64 ();
        }
        return array;
    }

    public int64[] read_int64_array (int64[] array) throws Error {
        for (int i=0; i<array.length; i++) {
            array[i] = read_int64 ();
        }
        return array;
    }

    public uint32[] read_uint32_array (uint32[] array) throws Error {
        for (int i=0; i<array.length; i++) {
            array[i] = read_uint32 ();
        }
        return array;
    }

    public int32[] read_int32_array (int32[] array) throws Error {
        for (int i=0; i<array.length; i++) {
            array[i] = read_int32 ();
        }
        return array;
    }

    public uint16[] read_uint16_array (uint16[] array) throws Error {
        for (int i=0; i<array.length; i++) {
            array[i] = read_uint16 ();
        }
        return array;
    }

    public int16[] read_int16_array (int16[] array) throws Error {
        for (int i=0; i<array.length; i++) {
            array[i] = read_int16 ();
        }
        return array;
    }

    public string read_4cc () throws Error {
        uint8 byte_buf[4];
        read_buf (byte_buf);
        return "%c%c%c%c".printf(byte_buf[0], byte_buf[1], byte_buf[2], byte_buf[3]);
    }

    public string[] read_4cc_array (string[] array) throws Error {
        for (int i=0; i<array.length; i++) {
            array[i] = read_4cc ();
        }
        return array;
    }

    public double read_fixed_point_16_16 () throws Error {
        return (((double)read_uint32()) / 65536);
    }

    public float read_fixed_point_8_8 () throws Error {
        return (((float)read_uint16()) / 256);
    }

    public string read_packed_language_code () throws Error {
        uint16 packed_code = read_uint16 ();
        return "%c%c%c".printf ((uint8)(((packed_code >> 10) & 0x1f) + 0x60),
                                (uint8)(((packed_code >> 5) & 0x1f) + 0x60),
                                (uint8)(((packed_code) & 0x1f) + 0x60));
    }

    public string read_null_terminated_string (out size_t bytes_read) throws Error {
        size_t string_len;
        var read_string = read_upto ("\0", 1, out string_len);
        read_byte (); // Read the null
        bytes_read = string_len + 1;
        return read_string;
    }
    
    public uint64 read_bytes_uint64 (uint count) throws Error {
        if (count > 8) {
            throw new IOError.FAILED ("Cannot read %u bytes into a uint64".printf(count));
        }
        uint64 result = 0;
        for (int i=0; i<count; i++) {
            result = result << 8;
            result |= read_byte();
        }
        return result;
    }

    public uint32 read_bytes_uint32 (uint count) throws Error {
        if (count > 4) {
            throw new IOError.FAILED ("Cannot read %u bytes into a uint64".printf(count));
        }
        uint32 result = 0;
        for (int i=0; i<count; i++) {
            result = result << 8;
            result |= read_byte();
        }
        return result;
    }

    public void seek_to_offset (uint64 offset) throws Error {
        // debug ("ExtDataInputStream: seek_to_offset: Seeking to " + offset.to_string ());
        if (!can_seek ()) {
            throw new IOError.FAILED ("Stream doesn't support seeking");
        }
        if (!seek ((int64)offset, GLib.SeekType.SET)) {
            throw new IOError.FAILED ("Failed to seek to byte " + offset.to_string ());
        }
    }

    public void skip_bytes (uint64 bytes) throws Error {
        skip ((size_t)bytes);
    }
}

public class Rygel.ExtDataOutputStream : DataOutputStream {
    public ExtDataOutputStream (GLib.OutputStream base_stream) {
        // Can't use: base (base_stream);
        // See https://mail.gnome.org/archives/vala-list/2009-October/msg00000.html
        Object (base_stream: base_stream);
        this.byte_order = DataStreamByteOrder.BIG_ENDIAN; // We want network byte order
    }

    public void put_uint64_array (uint64[] array) throws Error {
        foreach (var val in array) {
            put_uint64 (val);
        }
    }

    public void put_int64_array (int64[] array) throws Error {
        foreach (var val in array) {
            put_int64 (val);
        }
    }

    public void put_uint32_array (uint32[] array) throws Error {
        foreach (var val in array) {
            put_uint32 (val);
        }
    }

    public void put_int32_array (int32[] array) throws Error {
        foreach (var val in array) {
            put_int32 (val);
        }
    }

    public void put_uint16_array (uint16[] array) throws Error {
        foreach (var val in array) {
            put_uint16 (val);
        }
    }

    public void put_int16_array (int16[] array) throws Error {
        foreach (var val in array) {
            put_int16 (val);
        }
    }

    public void put_4cc (string code) throws Error {
        write (code.data);
    }

    public void put_4cc_array (string[] array) throws Error {
        foreach (var val in array) {
            write (val.data);
        }
    }

    public void put_fixed_point_16_16 (double val) throws Error {
        put_uint32 ((uint32)(val * 65536));
    }

    public void put_fixed_point_8_8 (float val) throws Error {
        put_uint16 ((uint16)(val * 256));
    }

    public void put_bytes_uint64 (uint64 val, uint count) throws Error {
        if (count > 8) {
            throw new IOError.FAILED ("Cannot write %u bytes from a uint64".printf(count));
        }
        for (int8 i=(int8)count-1; count >= 0; i--) {
            uint8 byte = (uint8)(val >> i*8);
            put_byte (byte);
        }
    }

    public void put_bytes_uint32 (uint32 val, uint count) throws Error {
        if (count > 4) {
            throw new IOError.FAILED ("Cannot write %u bytes from a uint32".printf(count));
        }
        for (int8 i=(int8)count-1; count >= 0; i--) {
            uint8 byte = (uint8)(val >> i*8);
            put_byte (byte);
        }
    }

    public void put_packed_language_code (string language) throws Error {
        uint16 packed_language = 0;
        packed_language |= (language.data[2] - 0x60);
        packed_language |= (language.data[1] - 0x60) << 5;
        packed_language |= (language.data[0] - 0x60) << 10;
        put_uint16 (packed_language);
    }

    public void put_null_terminated_string (string outstring) throws Error {
        put_string (outstring);
        put_byte (0);
    }

    public void put_zero_bytes (uint64 num_bytes) throws Error {
        for (uint64 i=0; i<num_bytes; i++) {
            put_byte (0);
        }
    }
}

/**
 * This is a simple OutputStream that generates fixed-size buffers and hands off ownership
 * via a delegate.
 */
public class BufferGeneratingOutputStream : OutputStream {
    /**
     * BufferReady delegate will be called when there's a buffer available.
     * last_buffer will be true when the last buffer is sent. Note that the last
     * buffer can be indicated when the stream is closed prematurely. In this case,
     * new_buffer may be null.
     */
    public delegate void BufferReady (Bytes ? new_buffer, bool last_buffer);

    protected unowned BufferReady buffer_sink;
    protected uint32 buffer_target_size;
    protected ByteArray current_buffer;
    private Mutex state_mutex = Mutex ();
    private bool paused;
    private Cond unpaused = Cond ();
    private bool stopped;
    private bool flush_partial_buffer;

    public BufferGeneratingOutputStream (uint64 buffer_size, BufferReady buffer_sink, bool paused)
            throws Error {
        // debug ("BufferGeneratingOutputStream constructor(size %u)", buffer_size);
        if (buffer_size > uint32.MAX) {
            throw new IOError.NOT_SUPPORTED ("Only 32-bit sizes are currently supported");
        }
        this.buffer_target_size = (uint32)buffer_size;
        this.buffer_sink = buffer_sink;
        this.current_buffer = null;
        this.paused = paused;
        this.stopped = false;
        this.flush_partial_buffer = true;
    }

    public override ssize_t write (uint8[] buffer, Cancellable? cancellable = null)
            throws IOError {
        // debug ("BufferGeneratingOutputStream.write (buffer %02x%02x%02x%02x%02x%02x..., buffer.length %u, cancellable %s)",
        //        buffer[0], buffer[1], buffer[2], buffer[3], buffer[4], buffer[5],
        //        buffer.length, ((cancellable==null) ? "null" : "non-null"));
        uint32 bytes_copied = 0;
        while (bytes_copied < buffer.length) {
            Bytes buffer_to_pass = null;
            try {
                this.state_mutex.lock ();
                if (this.stopped) {
                    throw new IOError.NO_SPACE ("The BufferGeneratingOutputStream is stopped (pre-wait)");
                }
                if (this.current_buffer == null) {
                    this.current_buffer = new ByteArray.sized ((uint32)buffer_target_size);
                }
                var bytes_remaining = buffer.length - bytes_copied;
                var space_in_buffer = this.buffer_target_size - this.current_buffer.len;
                var bytes_to_copy = uint32.min (bytes_remaining, space_in_buffer);
                // debug ("bytes_remaining %u, space_in_buffer %u", bytes_remaining, space_in_buffer);
                this.current_buffer.append (buffer[bytes_copied:bytes_copied+bytes_to_copy]);
                bytes_copied += bytes_to_copy;
                space_in_buffer -= bytes_to_copy;
                if (space_in_buffer == 0) {
                    if (this.paused) {
                        // debug ("BufferGeneratingOutputStream.write: waiting for unpaused");
                        this.unpaused.wait (state_mutex);
                        // debug ("BufferGeneratingOutputStream.write: done waiting");
                        if (this.stopped) {
                            throw new IOError.NO_SPACE ("The BufferGeneratingOutputStream is stopped (post-wait)");
                        }
                        if (this.current_buffer == null) {
                            // Buffer was handled out from under us (e.g. flushed)
                            continue;
                        }
                    }
                    buffer_to_pass = ByteArray.free_to_bytes (this.current_buffer);
                    this.current_buffer = null;
                }
            } finally {
                this.state_mutex.unlock ();
            }
            if (buffer_to_pass != null) {
                // Call the delegate without holding the lock
                this.buffer_sink (buffer_to_pass, false);
            }
        }
        return buffer.length;
    }

    public override bool flush (Cancellable? cancellable = null)
            throws Error {
        debug ("BufferGeneratingOutputStream.flush()");
        Bytes buffer_to_pass = null;
        try {
            this.state_mutex.lock ();
            if (this.stopped) {
                return false;
            }
            // Bit of a policy conflict here. We want to generate fixed-sized buffers. But
            //  we were asked to flush...
            if (this.flush_partial_buffer
                 && (this.current_buffer != null)
                 && this.paused) {
                this.unpaused.wait (state_mutex);
            }

            // Re-check, since the mutex isn't held in wait
            if (this.stopped) {
                return false;
            }
            if (this.flush_partial_buffer && (this.current_buffer != null)) {
                buffer_to_pass = ByteArray.free_to_bytes (this.current_buffer);
                this.current_buffer = null;
            }
        } finally {
            this.state_mutex.unlock ();
        }
        if (buffer_to_pass != null) {
            // Call the delegate without holding the lock
            this.buffer_sink (buffer_to_pass, false);
        }
        return true;
    }

    public override bool close (Cancellable? cancellable = null)
            throws IOError {
        debug ("BufferGeneratingOutputStream.close()");

        try {
            this.state_mutex.lock ();
            if (this.stopped) {
                return false;
            }
            if (this.current_buffer != null) {
                this.current_buffer = null;
            }
            this.stopped = true;
            this.unpaused.broadcast ();
            // No one should be waiting now
        } finally {
            this.state_mutex.unlock ();
        }
        return true;
    }

    /**
     * Resume/start issuing buffers on the BufferReady delegate.
     */
    public void resume () {
        debug ("BufferGeneratingOutputStream.resume()");
        try {
            this.state_mutex.lock ();
            this.paused = false;
            this.unpaused.broadcast ();
        } finally {
            this.state_mutex.unlock ();
        }
    }

    /**
     * Stop issuing buffers on the BufferReady delegate and block writes until resume() or
     *  stop() is called.
     */
    public void pause () {
        debug ("BufferGeneratingOutputStream.pause()");
        try {
            this.state_mutex.lock ();
            this.paused = true;
        } finally {
            this.state_mutex.unlock ();
        }
    }

    /**
     * Stop issuing buffers on the BufferReady delegate and fail/disallow IO operations
     *  (write(), flush(), etc). The BufferReady delegate will not be called once stop()
     *  returns.
     */
    public void stop () {
        debug ("BufferGeneratingOutputStream.stop()");
        if (this.stopped) { // We never unset stopped - so this is a safe check
            return;
        }
        try {
            this.state_mutex.lock ();
            if (this.current_buffer != null) {
                this.current_buffer = null;
            }
            this.stopped = true;
            this.unpaused.broadcast ();
            // No one should be waiting now
        } finally {
            this.state_mutex.unlock ();
        }
    }
}


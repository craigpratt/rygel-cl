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

public errordomain Rygel.IsoBoxError {
    PARSE_ERROR,
    INVALID_BOX_TYPE,
    INVALID_BOX_STATE,
    FRAGMENTED_BOX,
    UNSUPPORTED_VERSION,
    ENTRY_NOT_FOUND,
    BOX_NOT_FOUND,
    VALUE_TOO_LARGE,
    NOT_LOADED
}

public class Rygel.IsoInputStream : GLib.DataInputStream {
    public IsoInputStream (GLib.FileInputStream base_stream) {
        // Can't use: base (base_stream);
        // See https://mail.gnome.org/archives/vala-list/2009-October/msg00000.html
        Object (base_stream: base_stream);
        this.set_byte_order (DataStreamByteOrder.BIG_ENDIAN); // We want network byte order
    }

    public uint8[] read_buf (uint8[] byte_buffer) throws Error {
        if (read (byte_buffer) != byte_buffer.length) {
            throw new IsoBoxError.PARSE_ERROR
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

    public void seek_to_offset (uint64 offset) throws Error {
        debug ("IsoInputStream: seek_to_offset: Seeking to " + offset.to_string ());
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

public class Rygel.IsoOutputStream : DataOutputStream {
    public IsoOutputStream (GLib.OutputStream base_stream) {
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
            throw new Rygel.IsoBoxError.VALUE_TOO_LARGE ("Only 32-bit sizes are currently supported");
        }
        this.buffer_target_size = (uint32)buffer_size;
        this.buffer_sink = buffer_sink;
        this.current_buffer = null;
        this.paused = paused;
        this.stopped = false;
        this.flush_partial_buffer = false;
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
                    throw new IOError.NO_SPACE ("The BufferGeneratingOutputStream is stopped");
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
                            throw new IOError.NO_SPACE ("The BufferGeneratingOutputStream is stopped");
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
                return true;
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
                return true;
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
        Bytes buffer_to_pass = null;
        try {
            this.state_mutex.lock ();
            if (this.stopped) {
                return true;
            }
            if ((this.current_buffer != null) && this.paused) {
                this.unpaused.wait (state_mutex);
            }

            // Re-check, since the mutex isn't held in wait
            if (this.stopped) {
                return true;
            }
            if (this.current_buffer != null) {
                buffer_to_pass = ByteArray.free_to_bytes (this.current_buffer);
                this.current_buffer = null;
            }
        } finally {
            this.state_mutex.unlock ();
        }

        // Call the delegate without holding the lock
        this.buffer_sink (buffer_to_pass, true);
        return true;
    }

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

    public void pause () {
        debug ("BufferGeneratingOutputStream.pause()");
        try {
            this.state_mutex.lock ();
            this.paused = true;
        } finally {
            this.state_mutex.unlock ();
        }
    }

    public void stop () {
        debug ("BufferGeneratingOutputStream.stop()");
        Bytes buffer_to_pass = null;
        if (this.stopped) { // We never unset stopped - so this is a safe check
            return;
        }
        try {
            this.state_mutex.lock ();
            if (this.current_buffer != null) {
                buffer_to_pass = ByteArray.free_to_bytes (this.current_buffer);
                this.current_buffer = null;
            }
            this.stopped = true;
            this.unpaused.broadcast ();
            // No one should be waiting now
        } finally {
            this.state_mutex.unlock ();
        }
        // Notify outside the lock
        this.buffer_sink (buffer_to_pass, true);
    }
}

public abstract class Rygel.IsoBox : Object {
    public IsoContainerBox parent_box;
    public string type_code;
    public uint64 size; // Needs to be set/updated by subclasses prior to write
    public bool force_large_size; // Write largesize even when the box length doesn't require it

    protected bool loaded; // Indicates the box fields/children are populated/parsed

    // These fields are for IsoBox instances contained in a input stream
    public unowned IsoInputStream source_stream;
    public uint64 source_offset;
    public uint32 source_size;
    public uint64 source_largesize; // If source_size==1
    public bool source_verbatim;

    public IsoBox (IsoContainerBox ? parent, string type_code, bool force_large_size=false) {
        base ();
        this.parent_box = parent;
        this.type_code = type_code;
        this.source_stream = null;
        this.source_offset = 0;
        this.source_size = 0;
        this.source_largesize = 0;
        this.force_large_size = force_large_size;
        this.size = 0;
        this.source_verbatim = false;
        this.loaded = true;
    }

    public IsoBox.from_stream (IsoContainerBox ? parent, string type_code,
                               IsoInputStream stream, uint64 offset,
                               uint32 size, uint64 largesize)
            throws Error {
        base ();
        this.parent_box = parent;
        this.type_code = type_code;
        this.source_stream = stream;
        this.source_offset = offset;
        this.source_size = size;
        this.source_largesize = largesize;
        this.force_large_size = (size == 1);
        this.size = (size == 1) ? largesize : size;
        this.source_verbatim = true;
        this.loaded = false;
    }

    /**
     * Tell the box to load/parse the box fields from the source
     */
    public virtual void load () throws Error {
        if (this.source_verbatim) {
            parse_from_stream ();
            this.source_verbatim = false;
            this.loaded = true;
            debug ("IsoBox(%s): parse: parsed %s", this.type_code, this.to_string ());
        }
    }

    /**
     * Tell the box to parse the fields from the source and load children to the designated
     * level (0 indicating all levels)
     *
     * Note: Container boxes should override this method
     */
    public virtual void load_children (uint levels = 0) throws Error {
        // The base box doesn't have children
        load ();
    }

    /**
     * Tell the box to parse the fields from the stream source and return the number of bytes
     * consumed.
     */
    protected virtual uint64 parse_from_stream () throws Error {
        debug ("IsoBox(%s).parse_from_stream()", this.type_code);
        uint64 header_size = ((this.source_size == 1) ? 16 : 8); // 32-bit or 64-bit size
        // No-op - all fields are passed to from_stream() constructor - and we skipped past the
        //  header above
        uint64 seek_pos = this.source_offset + header_size;
        this.source_stream.seek_to_offset (seek_pos);
        return header_size;
    }

    /**
     * Tell the box (and parent boxes) to update themselves to accommodate field changes
     * to the box. e.g. To update the size, version, or flags fields to reflect the field
     * changes.
     */
    public virtual void update () throws Error {
        debug ("IsoBox(%s): update()", this.type_code);
        if (this.source_verbatim) {
            throw new IsoBoxError.INVALID_BOX_STATE ("Cannot update a verbatim (unparsed) box");
        }
        update_box_fields ();
        if (this.parent_box != null) {
            this.parent_box.update ();
        }
    }

    /**
     * Update box fields for dependent changes. 
     *
     * The contained payload size is passed to allow for size-dependent fields to be
     * adjusted. The adjusted size must then be passed to the base for the IsoBox to be
     * properly sized for the payload.
     */
    protected virtual void update_box_fields (uint64 payload_size = 0) throws Error {
        if ((payload_size+8 > uint32.MAX) || this.force_large_size) {
            this.size = payload_size + 16; // Need to account for largesize field
        } else {
            this.size = payload_size + 8;
        }
        debug ("IsoBox(%s): update_box_fields(): size %llu", this.type_code, this.size);
    }

    /**
     * Write the box to the given output stream.
     *
     * Note that if any fields are changed, update() must be called prior to write_to_stream().
     *
     * The base implementation will write from the source when source_verbatim is true or
     * call write_fields_to_stream() when it's false.
     */
    public virtual void write_to_stream (IsoOutputStream outstream) throws Error {
        if (this.source_verbatim) {
            debug ("write_to_stream(%s): Writing %s from the source stream",
                   this.type_code, this.to_string ());
            this.write_box_from_source (outstream);
        } else {
            debug ("write_to_stream(%s): Writing %s from fields",
                   this.type_code, this.to_string ());
            write_fields_to_stream (outstream);
        }
    }

    /**
     * Write the box's fields to the given output stream.
     *
     * Subclasses must over-ride this method to write their fields (after calling
     * base.write_fields_to_stream()). And it's presumed that update() is called
     * prior to write if/when/after fields are modified.
     */
    protected virtual void write_fields_to_stream (IsoOutputStream outstream) throws Error {
        if (this.source_verbatim) {
            throw new IsoBoxError.INVALID_BOX_STATE ("Cannot update a verbatim (unparsed) box");
        }
        if ((this.size > uint32.MAX) || this.force_large_size) {
            outstream.put_uint32 (1); // Indicates this is a large-size box
            outstream.put_4cc (this.type_code);
            outstream.put_uint64 (this.size);
        } else {
            outstream.put_uint32 ((uint32)this.size);
            outstream.put_4cc (this.type_code);
        }
    }

    /**
     * This helper function will write out a box from a box with a
     * source_stream. In other words, this function will copy a box from an
     * input stream to an output stream without reading the box into memory
     * or parsing it.
     * 
     * Note: This will change the box source_stream file position.
     *
     * TODO: Consider restoring the file position post-write.
     */
    protected void write_box_from_source (IsoOutputStream outstream) throws Error {
        write_from_source (outstream, this.source_offset, this.source_size);
    }

    /**
     * This helper function will write out length bytes of data from the box's source_stream
     * starting at source_offset to the given outstream.
     * 
     * Note: This will change the box source_stream file position.
     *
     * TODO: Consider restoring the file position post-write.
     */
    protected void write_from_source (IsoOutputStream outstream,
                                      uint64 source_offset, uint64 length)
            throws Error {
        this.source_stream.seek_to_offset (source_offset);
        var copy_buf = new uint8 [1024*500];
        uint64 total_to_copy = length;
        while (total_to_copy > 0) {
            var bytes_to_copy = uint64.min (copy_buf.length, total_to_copy);
            unowned uint8[] target_slice = copy_buf [0:bytes_to_copy];
            var read_bytes = this.source_stream.read (target_slice);
            if (read_bytes != bytes_to_copy) {
                throw new IOError.FAILED ("Failed to read " + bytes_to_copy.to_string ()
                                          + " bytes");
            }
            var written_bytes = outstream.write (target_slice);
            if (written_bytes != bytes_to_copy) {
                throw new IOError.FAILED ("Failed to write " + bytes_to_copy.to_string ()
                                          + " bytes");
            }
            total_to_copy -= bytes_to_copy;
        }
    }

    /**
     * Get a box's nth-level ancestor. The ancestor will be checked against the
     * expected_box_class and INVALID_BOX_TYPE will be thrown if there's a mismatch.
     */
    public IsoBox get_ancestor_by_level (uint level, Type expected_box_class) throws Error {
        IsoBox cur_box = this;
        for (; level>0; level--) {
            if (cur_box.parent_box == null) {
                throw new IsoBoxError.BOX_NOT_FOUND
                                      (cur_box.to_string() + " does not have a parent");
            }
            cur_box = cur_box.parent_box;
        }
        if (cur_box.get_type () != expected_box_class) {
            throw new IsoBoxError.INVALID_BOX_TYPE
                                  (cur_box.to_string() + " is not the expected type "
                                   + expected_box_class.to_string ());
        }

        return cur_box;
    }

    /**
     * Walk the box's ancestor's until a box of type box_class is found.
     *
     * If no box of box_class is found, BOX_NOT_FOUND is thrown.
     */
    public IsoBox get_ancestor_by_class (Type box_class) throws Error {
        IsoBox cur_box = this.parent_box;
        while (cur_box != null) {
            if (cur_box.get_type () == box_class) {
                return cur_box;
            }
            cur_box = cur_box.parent_box;
        }
        throw new IsoBoxError.BOX_NOT_FOUND
                              (this.to_string() + " does not have an ancestor of type "
                              + box_class.to_string ());
    }

    /**
     * Walk the box's ancestor's until a box with 4-letter type_code is found.
     *
     * If no box of box_class is found, BOX_NOT_FOUND is thrown.
     */
    public IsoBox get_ancestor_by_type_code (string type_code) throws Error {
        IsoBox cur_box = this.parent_box;
        while (cur_box != null) {
            if (cur_box.type_code == type_code) {
                return cur_box;
            }
            cur_box = cur_box.parent_box;
        }
        throw new IsoBoxError.BOX_NOT_FOUND
                              (this.to_string() + " does not have an ancestor with type code "
                              + type_code);
    }

    /**
     * Output the box's parameters as comma-separated name-value pairs.
     */
    public virtual string to_string () {
        return "type %s,src_offset %lld,size %lld"
               .printf (this.type_code, this.source_offset, this.size);
    }

    public delegate void LinePrinter (string line);

    /**
     * Output the box's parameters to the given LinePrinter.
     *
     * A box with array entries should output each entry on a separate line with curly
     * braces ("{" and "}") before and after groups of entries.
     */
    public virtual void to_printer (LinePrinter printer, string prefix) {
        printer ("%s%s".printf (prefix,this.to_string ()));
    }
} // END class IsoBox

/**
 * full box
 */
public abstract class Rygel.IsoFullBox : IsoBox {
    public uint8 version;
    public uint32 flags;

    public IsoFullBox (IsoContainerBox parent, string type_code, uint8 version, uint32 flags) {
        base (parent, type_code);
        this.version = version;
        this.flags = flags;
    }

    public IsoFullBox.from_stream (IsoContainerBox parent, string type_code,
                                   IsoInputStream stream, uint64 offset,
                                   uint32 size, uint64 largesize)
            throws Error {
        base.from_stream (parent, type_code, stream, offset, size, largesize);
    }

    public override uint64 parse_from_stream () throws Error {
        debug ("IsoFullBox(%s).parse_from_stream()", this.type_code);
        var bytes_consumed = base.parse_from_stream ();
        var dword = this.source_stream.read_uint32 ();
        this.version = (uint8)(dword >> 24);
        this.flags = dword & 0xFFFFFF;
        return (bytes_consumed + 4);
    }

    protected override void update_box_fields (uint64 payload_size = 0) throws Error {
        base.update_box_fields (payload_size + 4); // 1 version byte + 3 flag bytes
    }

    public override void write_fields_to_stream (IsoOutputStream outstream) throws Error {
        base.write_fields_to_stream (outstream);
        uint32 dword = (this.version << 24) | (this.flags & 0xFFFFFF);
        outstream.put_uint32 (dword);
    }

    public override string to_string () {
        var builder = new StringBuilder (base.to_string ());
            builder.append_printf (",version %d,flags 0x%04x",this.version,this.flags);
        return builder.str;
    }

    public override void to_printer (IsoBox.LinePrinter printer, string prefix) {
        printer ("%s%s".printf (prefix,this.to_string ()));
    }
} // END class IsoFullBox

/**
 * Abstract class for implementing containers.
 *
 * This class is intended for use by boxes that may or may not have headers before
 * any contained boxes.
 */
public abstract class Rygel.IsoContainerBox : IsoBox {
    public Gee.List<IsoBox> children = new Gee.ArrayList<IsoBox> ();

    public IsoContainerBox (IsoContainerBox ? parent, string type_code) {
        base (parent, type_code);
    }

    public IsoContainerBox.with_child (IsoContainerBox parent, IsoBox first_child) {
        base (parent, type_code);
        children.add (first_child);
    }

    public Gee.List<IsoBox> get_boxes_by_type (string type_code) {
        var box_list = new Gee.ArrayList<IsoBox> ();
        foreach (var box in this.children) {
            if (box.type_code == type_code) {
                box_list.add (box);
            }
        }
        return box_list;
    }

    public Gee.List<IsoBox> get_boxes_by_class (Type box_class) {
        var box_list = new Gee.ArrayList<IsoBox> ();
        foreach (var box in this.children) {
            if (box.get_type () == box_class) {
                box_list.add (box);
            }
        }
        return box_list;
    }

    public IsoBox ? first_box_of_type (string type_code) throws Error {
        foreach (var box in this.children) {
            if (box.type_code == type_code) {
                return box;
            }
        }
        throw new IsoBoxError.BOX_NOT_FOUND
                              (this.to_string() + " does not contain a " + type_code + " box");
    }

    public IsoBox first_box_of_class (Type box_class) throws Error {
        foreach (var box in this.children) {
            if (box.get_type () == box_class) {
                return box;
            }
        }
        throw new IsoBoxError.BOX_NOT_FOUND
                              (this.to_string() + " does not contain a " + box_class.to_string ());
    }

    public bool has_box_of_type (string type_code) {
        foreach (var box in this.children) {
            if (box.type_code == type_code) {
                return true;
            }
        }
        return false;
    }

    public bool has_box_of_class (Type box_class) {
        foreach (var box in this.children) {
            if (box.get_type () == box_class) {
                return true;
            }
        }
        return false;
    }

    public IsoBox get_descendant_by_class_list (Type [] box_class_array) throws Error {
        IsoBox cur_box = this;
        foreach (var box_class in box_class_array) {
            if (!(cur_box is IsoContainerBox)) {
                throw new IsoBoxError.BOX_NOT_FOUND
                                      (cur_box.to_string() + " cannot contain "
                                       + box_class.to_string ());
            }
            cur_box = (cur_box as IsoContainerBox).first_box_of_class (box_class);
        }
        return cur_box;
    }

    public IsoBox get_descendant_by_type_list (string [] box_type_array) throws Error {
        IsoBox cur_box = this;
        foreach (var box_type in box_type_array) {
            if (!(cur_box is IsoContainerBox)) {
                throw new IsoBoxError.BOX_NOT_FOUND
                                      (cur_box.to_string() + " cannot contain "
                                       + box_type + " boxes");
            }
            cur_box = (cur_box as IsoContainerBox).first_box_of_type (box_type);
        }
        return cur_box;
    }

    public uint remove_boxes_by_class (Type box_class, uint num_to_remove = 0) {
        uint remove_count = 0;
        for (var box_it = this.children.iterator (); box_it.next ();) {
            var box = box_it.get ();
            if (box.get_type () == box_class) {
                box_it.remove ();
                remove_count++;
                if ((num_to_remove != 0) && (remove_count == num_to_remove)) {
                    break;
                }
            }
        }
        return remove_count;
    }

    /**
     * Read list of boxes from the input stream, not reading more than bytes_to_read bytes.
     */
    protected Gee.List<IsoBox> read_boxes (uint64 stream_offset, uint64 bytes_to_read) throws Error {
        debug ("read_boxes(%s): stream_offset %lld, bytes_to_read %lld",
               this.type_code, stream_offset, bytes_to_read);
        var box_list = new Gee.ArrayList<IsoBox> ();
        uint64 pos = 0;
        do {
            var box = read_box (stream_offset + pos);
            if (box.size > bytes_to_read) {
                throw new IsoBoxError.FRAGMENTED_BOX
                              ("Found box size of %lld with only %lld bytes remaining",
                               box.size, bytes_to_read);
            }
            box_list.add (box);
            // debug ("Offset %lld: Found box type %s with size %lld",
            //          source_offset+pos, box.type_code, box.size);
            pos += box.size;
            bytes_to_read -= box.size;
        } while (bytes_to_read > 0);
        return box_list;
    }

    /**
     * Read and construct one box from the input stream.
     */
    protected IsoBox read_box (uint64 stream_offset) throws Error {
        debug ("IsoContainerBox(%s): read_box offset %lld", this.type_code, stream_offset);
        var box_size = this.source_stream.read_uint32 ();
        var type_code = this.source_stream.read_4cc ();
        uint64 box_largesize = 0;
        if (box_size == 1) {
            box_largesize = this.source_stream.read_uint64 ();
            this.source_stream.skip_bytes (box_largesize - 16);
        } else {
            this.source_stream.skip_bytes (box_size - 8);
        }
        return make_box_for_type (type_code, stream_offset, box_size, box_largesize);
    }

    /**
     * Make a typed box
     */
    protected IsoBox make_box_for_type (string type_code, uint64 stream_offset, 
                                        uint32 box_size, uint64 box_largesize)
            throws Error {
        debug ("IsoContainerBox(%s).make_box_for_type(type_code %s,stream_offset %lld,box_size %u,largesize %llu)",
               this.type_code, type_code, stream_offset, box_size, box_largesize);
        switch (type_code) {
            case "ftyp":
                return new IsoFileTypeBox.from_stream (this, type_code, this.source_stream,
                                                       stream_offset, box_size, box_largesize);
            case "moov":
                return new IsoMovieBox.from_stream (this, type_code, this.source_stream,
                                                    stream_offset, box_size, box_largesize);
            case "mvhd":
                return new IsoMovieHeaderBox.from_stream (this, type_code, this.source_stream,
                                                          stream_offset, box_size, box_largesize);
            case "trak":
                return new IsoTrackBox.from_stream (this, type_code, this.source_stream,
                                                    stream_offset, box_size, box_largesize);
            case "tkhd":
                return new IsoTrackHeaderBox.from_stream (this, type_code, this.source_stream,
                                                          stream_offset, box_size, box_largesize);
            case "mdia":
                return new IsoMediaBox.from_stream (this, type_code, this.source_stream,
                                                    stream_offset, box_size, box_largesize);
            case "mdhd":
                return new IsoMediaHeaderBox.from_stream (this, type_code, this.source_stream,
                                                          stream_offset, box_size, box_largesize);
            case "hdlr":
                return new IsoHandlerBox.from_stream (this, type_code, this.source_stream,
                                                      stream_offset, box_size, box_largesize);
            case "minf":
                return new IsoMediaInformationBox.from_stream (this, type_code, this.source_stream,
                                                               stream_offset, box_size,
                                                               box_largesize);
            case "vmhd":
                return new IsoVideoMediaHeaderBox.from_stream (this, type_code, this.source_stream,
                                                               stream_offset, box_size,
                                                               box_largesize);
            case "smhd":
                return new IsoSoundMediaHeaderBox.from_stream (this, type_code, this.source_stream,
                                                               stream_offset, box_size,
                                                               box_largesize);
            case "stbl":
                return new IsoSampleTableBox.from_stream (this, type_code, this.source_stream,
                                                          stream_offset, box_size,
                                                          box_largesize);
            case "stts":
                return new IsoTimeToSampleBox.from_stream (this, type_code, this.source_stream,
                                                           stream_offset, box_size, box_largesize);
            case "stss":
                return new IsoSyncSampleBox.from_stream (this, type_code, this.source_stream,
                                                          stream_offset, box_size, box_largesize);
            case "stsc":
                return new IsoSampleToChunkBox.from_stream (this, type_code, this.source_stream,
                                                            stream_offset, box_size, box_largesize);
            case "stsz":
                return new IsoSampleSizeBox.from_stream (this, type_code, this.source_stream,
                                                         stream_offset, box_size, box_largesize);
            case "stco":
            case "co64":
                return new IsoChunkOffsetBox.from_stream (this, type_code, this.source_stream,
                                                          stream_offset, box_size, box_largesize);
            case "edts":
                return new IsoEditBox.from_stream (this, type_code, this.source_stream,
                                                   stream_offset, box_size, box_largesize);
            case "elst":
                return new IsoEditListBox.from_stream (this, type_code, this.source_stream,
                                                       stream_offset, box_size, box_largesize);
            case "dinf":
                return new IsoDataInformationBox.from_stream (this, type_code, this.source_stream,
                                                              stream_offset, box_size,
                                                              box_largesize);
            default:
                return new IsoGenericBox.from_stream (this, type_code, this.source_stream,
                                                      stream_offset, box_size, box_largesize);
        }
    }

    /**
     * Tell the box to parse the fields from the source and load children to the designated
     * level (0 indicating all levels)
     */
    public override void load_children (uint levels = 0) throws Error {
        load ();
        debug ("IsoContainerBox(%s).load_children(%u)", this.type_code, levels);
        if (levels != 1) {
            if (levels != 0) {
                levels--;
            }
            foreach (var box in this.children) {
                box.load_children (levels);
            }
        }
    }

    /**
     * Update children/ancestors according to the designated level (0 indicating all levels)
     * and then update the parent.
     */
    public void update_children (uint levels = 0) throws Error {
        debug ("IsoContainerBox(%s).update_children(%u)", this.type_code, levels);
        // First go down
        if (levels != 1) {
            if (levels != 0) {
                levels--;
            }
            foreach (var box in this.children) {
                if (box is IsoContainerBox) {
                    (box as IsoContainerBox).update_children (levels);
                }
                box.update_box_fields ();
            }
        }
    }

    protected override void update_box_fields (uint64 payload_size = 0) throws Error {
        payload_size += sum_children_sizes ();

        base.update_box_fields (payload_size);
    }

    protected uint64 sum_children_sizes () {
        uint64 total = 0;
        foreach (var box in this.children) {
            total += box.size;
        }
        return total;
    }

    protected string children_to_string () {
        var builder = new StringBuilder ();
        if (this.loaded) {
            if (this.children.size > 0) {
                foreach (var box in this.children) {
                    builder.append (box.to_string ());
                    builder.append_c (',');
                }
                builder.truncate (builder.len-1);
            }
        } else {
            builder.append ("[unloaded children]");
        }
        return builder.str;
    }

    protected void children_to_printer (IsoBox.LinePrinter printer, string prefix) {
        if (this.loaded) {
            foreach (var box in this.children) {
                box.to_printer (printer, prefix);
            }
        } else {
            printer (prefix + "[unloaded children]");
        }
    }
} // END class IsoContainerBox

/**
 * The file container box is the top-level box for a MP4/ISO BMFF file.
 * It can only contain boxes (no fields)
 */
public class Rygel.IsoFileContainerBox : IsoContainerBox {
    public GLib.File iso_file;
    public IsoInputStream file_stream;
    public static const int MICROS_PER_SEC = 1000000;

    public IsoFileContainerBox.from_stream (FileInputStream file_stream, uint64 largesize)
               throws Error {
        var input_stream = new IsoInputStream (file_stream);
        base.from_stream (null, "FILE", input_stream, 0, 1, largesize);
        this.file_stream = input_stream;
    }

    public IsoFileContainerBox (GLib.File iso_file) throws Error {
        var file_info = iso_file.query_info (GLib.FileAttribute.STANDARD_SIZE, 0);
        this.from_stream (iso_file.read (), file_info.get_size ());
        this.iso_file = iso_file;
        this.type_code = iso_file.get_basename (); // OK - since we won't be serializing...
    }

    public override uint64 parse_from_stream () throws Error {
        debug ("IsoFileContainerBox(%s).parse_from_stream()", this.type_code);
        // The FileContainerBox doesn't have a base header
        this.source_stream.seek_to_offset (this.source_offset);
        this.children = base.read_boxes (0, this.size);
        return this.size;
    }

    protected override void update_box_fields (uint64 payload_size = 0) throws Error {
        // The FileContainerBox doesn't have a base header
        payload_size += base.sum_children_sizes ();
        this.size = payload_size;
    }

    public override void write_fields_to_stream (IsoOutputStream outstream) throws Error {
        // The FileContainerBox doesn't have a base header
        foreach (var box in this.children) {
            box.write_to_stream (outstream);
        }
    }

    public IsoFileTypeBox get_file_type_box () throws Error {
        return first_box_of_class (typeof (IsoFileTypeBox)) as IsoFileTypeBox;
    }

    public IsoMovieBox get_movie_box () throws Error {
        return first_box_of_class (typeof (IsoMovieBox)) as IsoMovieBox;
    }

    public IsoGenericBox get_first_media_data_box () throws Error {
        foreach (var cur_box in this.children) {
            if (cur_box.type_code == "mdat") {
                return cur_box as IsoGenericBox;
            }
        }
        throw new IsoBoxError.BOX_NOT_FOUND (this.to_string() + " does not have a mdat box");
    }

    public IsoGenericBox get_mdat_for_offset (uint64 file_offset) throws Error {
        foreach (var cur_box in this.children) {
            if (cur_box.type_code == "mdat") {
                if ((file_offset >= cur_box.source_offset)
                    && (file_offset < cur_box.source_offset+cur_box.size)) {
                    return cur_box as IsoGenericBox;
                }
            }
        }
        throw new IsoBoxError.BOX_NOT_FOUND (this.to_string()
                                             + " does not have a mdat box for offset "
                                             + file_offset.to_string ());
    }

    public void trim_to_time_range (ref int64 start_time_us, ref int64 end_time_us,
                                    out IsoSampleTableBox.AccessPoint start_point,
                                    out IsoSampleTableBox.AccessPoint end_point,
                                    bool insert_empty_edit = false)
                throws Error {
        message ("IsoFileContainerBox.trim_to_time_range(start %lluus, end %lluus)",
                 start_time_us, end_time_us);
        var movie_box = this.get_movie_box ();
        var master_track = movie_box.get_first_track_of_type (Rygel.IsoMediaBox.MediaType.VIDEO);
        var master_track_id = master_track.get_header_box ().track_id;
        message ("  Using video track %u", master_track_id);

        //
        // Establish the time range
        //
        start_point = {0,0,0};
        end_point = {0,0,0};
        var master_track_timescale = master_track.get_media_timescale ();
        start_point.time_offset = start_time_us * master_track_timescale / MICROS_PER_SEC;
        end_point.time_offset = end_time_us * master_track_timescale / MICROS_PER_SEC;
        message ("  Finding video access points for time range %0.3f to %0.3f:",
                       (float)start_point.time_offset/master_track_timescale,
                       (float)end_point.time_offset/master_track_timescale);
        var sample_table_box = master_track.get_sample_table_box ();
        // Note: This will resolve all the start_point/end_point fields to align
        //       to appropriate samples points
        sample_table_box.get_access_points_for_range (ref start_point, ref end_point);

        start_time_us = start_point.time_offset * MICROS_PER_SEC / master_track_timescale;
        message ("   Range start: time %llu (%0.3f), sample %u, byte_offset %llu",
                 start_point.time_offset, (float)start_point.time_offset/master_track_timescale,
                 start_point.sample, start_point.byte_offset);

        end_time_us = end_point.time_offset * MICROS_PER_SEC / master_track_timescale;
        if (end_point.sample != 0) {
            message ("   Range end: time %llu (%0.3f), sample %u, byte_offset %llu",
                     end_point.time_offset, (float)end_point.time_offset/master_track_timescale,
                     end_point.sample, end_point.byte_offset);
        } else {
            message ("   Range end not provided (end time %llu)", end_point.time_offset);
        }

        var range_duration = end_point.time_offset - start_point.time_offset;

        var movie_box_header = movie_box.get_header_box ();
        // Master track duration needs to account for an empty edit
        var master_track_duration = insert_empty_edit ? end_point.time_offset : range_duration;

        movie_box_header.set_duration (master_track_duration, master_track_timescale);
        message ("   Range duration: %llu (%0.2fs)", range_duration,
                 (float)range_duration/master_track_timescale);

        //
        // Adjusting chunk/sample offsets
        //
        {
            var mdat_with_offset = this.get_mdat_for_offset (start_point.byte_offset);
            uint64 mdat_start_bytes_to_cut = start_point.byte_offset
                                             - mdat_with_offset.source_payload_offset
                                             - mdat_with_offset.source_offset;
            uint64 mdat_end_bytes_to_cut;
            if (end_point.sample == 0) {
                mdat_end_bytes_to_cut = 0;
            } else {
                mdat_end_bytes_to_cut = mdat_with_offset.source_offset + mdat_with_offset.size 
                                        - end_point.byte_offset;
            }
            var old_header_size = this.get_file_type_box ().size + movie_box.size;
            var track_list = movie_box.get_tracks ();
            message ("  Removing samples outside byte range %llu-%llu for %d tracks",
                     start_point.byte_offset, end_point.byte_offset, track_list.size);
            // var track_duration = end_point.time_offset - start_point.time_offset;
            for (var track_it = track_list.iterator (); track_it.next ();) {
                var track = track_it.get ();
                var track_header = track.get_header_box ();
                message ("  Trimming track %u", track_header.track_id);
                Rygel.IsoSampleTableBox.AccessPoint start_cut_point, end_cut_point;
                if (track_header.track_id == master_track_id) {
                    start_cut_point = start_point;
                    end_cut_point = end_point;
                    message ("    Removing samples on sync track before sample %u and after sample %u",
                             start_cut_point.sample, end_cut_point.sample);
                } else {
                    start_cut_point = {0, start_point.byte_offset, 0, 0, 0};
                    end_cut_point = {0, end_point.byte_offset, 0, 0, 0};
                    message ("    Removing samples on non-sync track before byte %llu and after byte %llu",
                             start_cut_point.byte_offset, end_cut_point.byte_offset);
                }
                // Remove the end first (cutting the end doesn't change the sample/index numbers)
                sample_table_box = track.get_sample_table_box ();
                if (end_point.sample != 0) {
                    sample_table_box.remove_sample_refs_after_point (ref end_cut_point);
                }
                sample_table_box.remove_sample_refs_before_point (ref start_cut_point);

                if (!sample_table_box.has_samples ()) {
                    // There aren't any samples left in the track - delete it
                    message ("    Track %u doesn't have samples - deleting it",
                             track_header.track_id);
                    track_it.remove ();
                    continue;
                }
                // Adjust track time metadata
                var media_header_box = track.get_media_box ().get_header_box ();
                media_header_box.set_duration (range_duration, master_track_timescale);
                message ("    set track media duration to %llu (%0.2fs)",
                         media_header_box.duration, media_header_box.get_duration_seconds ());
                track_header.set_duration (master_track_duration, master_track_timescale);
                // Note: This is assuming the EditListBox is 1-for-1 with the track media
                message ("    set track movie duration to %llu (%0.2fs)",
                         track_header.duration, track_header.get_duration_seconds ());

                // Create/replace the EditListBox
                var edit_list_box = track.create_edit_box ().get_edit_list_box ();
                if (insert_empty_edit) {
                    edit_list_box.edit_array = new IsoEditListBox.EditEntry[2];
                    edit_list_box.set_edit_list_entry (0, start_point.time_offset,
                                                       master_track_timescale,
                                                       -1, 0,
                                                       1, 0);
                    message ("    Created empty edit: " + edit_list_box.string_for_entry (0));
                    edit_list_box.set_edit_list_entry (1,
                                                       end_point.time_offset
                                                        - start_point.time_offset,
                                                       master_track_timescale,
                                                       0, master_track_timescale,
                                                       1, 0);
                    message ("    Created offset edit: " + edit_list_box.string_for_entry (1));
                } else {
                    edit_list_box.edit_array = new IsoEditListBox.EditEntry[1];
                    edit_list_box.set_edit_list_entry (0, master_track_duration,
                                                       master_track_timescale,
                                                       0,
                                                       master_track_timescale,
                                                       1, 0);
                    message ("    Created simple edit: " + edit_list_box.string_for_entry (0));
                }
                edit_list_box.update ();
            }
            
            message ("Updating movie box fields...");
            movie_box.update_children (100); // Recurse all the way down
            movie_box.update ();

            var new_header_size = this.get_file_type_box ().size + movie_box.size;
            message ("  Old header size: %llu bytes", old_header_size);
            message ("  New header size: %llu bytes", new_header_size);

            // Adjust the mdat's offset to not include the cut data
            message ("mdat bytes to cut from start: %llu", mdat_start_bytes_to_cut);
            message ("mdat bytes to cut from end: %llu", mdat_end_bytes_to_cut);
            message ("  mdat before: %s", mdat_with_offset.to_string ());
            mdat_with_offset.source_payload_offset += mdat_start_bytes_to_cut;
            mdat_with_offset.source_payload_size -= mdat_start_bytes_to_cut + mdat_end_bytes_to_cut;
            mdat_with_offset.update ();
            // TODO: Remove all mdats before the target and adjust any other mdats offsets
            message ("  mdat after: %s", mdat_with_offset.to_string ());

            // Fixup all chunk offset tables now that the header size has been established
            int64 chunk_offset_fixup = (int64)mdat_start_bytes_to_cut
                                       + ((int64)old_header_size - (int64)new_header_size);
            message ("Chunk offset fixup: %s", chunk_offset_fixup.to_string ());
            foreach (var track in track_list) {
                message ("  Adjusting track %u offsets by %llu",
                               track.get_header_box ().track_id, chunk_offset_fixup);
                var chunk_offset_box = track.get_sample_table_box ().get_chunk_offset_box ();
                // chunk_offset_box.to_printer ( (l) => {debug (l);}, "  PRE-ADJUST: ");
                chunk_offset_box.adjust_offsets (-chunk_offset_fixup);
                chunk_offset_box.update ();
                // chunk_offset_box.to_printer ( (l) => {debug (l);}, "  ADJUSTED: ");
            }
        }
    }

    public override string to_string () {
        var builder = new StringBuilder ("IsoFileContainerBox[");
        builder.append (base.to_string ());
        builder.append (base.children_to_string ());
        builder.append_c (']');
        return builder.str;
    }
    
    public override void to_printer (IsoBox.LinePrinter printer, string prefix) {
        printer (prefix + "ISO Media File: source "
                 + (this.iso_file != null ? this.iso_file.get_basename () : "stream")
                 + " {");
        base.children_to_printer (printer, prefix + "  ");
        printer (prefix + "}");
    }
} // END class IsoFileContainerBox

/**
 * Can be used to represent opaque boxes where there's no need to access fields or
 * contained boxes. Can accommodate adjustments to the size/location of the source data.
 */
public class Rygel.IsoGenericBox : IsoBox {
    public uint64 source_payload_offset; // How far from the source_offset should the
                                         //  payload be taken from
    public uint64 source_payload_size; // How much payload should be taken from the source

    public IsoGenericBox (IsoContainerBox parent, string type_code, bool large_box) {
        base (parent, type_code, large_box);
        this.source_payload_offset = large_box ? 16 : 8;;
        this.source_payload_size = 0;
    }

    public IsoGenericBox.from_stream (IsoContainerBox parent, string type_code,
                                      IsoInputStream stream, uint64 offset,
                                      uint32 size, uint64 largesize)
            throws Error {
        base.from_stream (parent, type_code, stream, offset, size, largesize);
        this.source_payload_offset = (size == 1) ? 16 : 8; // account for large boxes
        this.source_payload_size = this.size - this.source_payload_offset; 
    }

    /**
     * Parse the box data from the input stream and set any fields.
     */
    public override uint64 parse_from_stream () throws Error {
        debug ("IsoGenericBox(%s).parse_from_stream()", this.type_code);
        var bytes_skipped = base.parse_from_stream ();
        // For the generic box, treat the box as an opaque blob of bytes that we can
        //  reference from the source file if/when needed.
        this.source_stream.skip_bytes (this.size - bytes_skipped);
        return this.size;
    }

    protected override void update_box_fields (uint64 payload_size = 0) throws Error {
        base.update_box_fields (payload_size + this.source_payload_size);
    }

    public override void write_fields_to_stream (IsoOutputStream outstream) throws Error {
        base.write_fields_to_stream (outstream);
        base.write_from_source (outstream,
                                this.source_offset + this.source_payload_offset,
                                this.source_payload_size);
    }

    public override string to_string () {
        return "IsoGenericBox[%s,payload_offset %llu,payload_size %llu]"
               .printf (base.to_string (), source_payload_offset, source_payload_size);
    }
    
    public override void to_printer (IsoBox.LinePrinter printer, string prefix) {
        printer (prefix + this.to_string ());
    }
} // END class IsoGenericBox

/**
 * ftyp box
 */
public class Rygel.IsoFileTypeBox : IsoBox {
    public string major_brand;
    public uint32 minor_version;
    public string[] compatible_brands;

    public IsoFileTypeBox (string major_brand, uint32 minor_version, string[] compatible_brands) {
        base (null, "ftyp");
        this.major_brand = major_brand;
        this.minor_version = minor_version;
        this.compatible_brands = compatible_brands;
    }

    public IsoFileTypeBox.from_stream (IsoContainerBox parent, string type_code,
                                       IsoInputStream stream, uint64 offset,
                                       uint32 size, uint64 largesize)
            throws Error {
        base.from_stream (parent, type_code, stream, offset, size, largesize);
    }

    /**
     * Parse the box data from the input stream and set any fields.
     */
    public override uint64 parse_from_stream () throws Error {
        debug ("IsoFileTypeBox(%s).parse_from_stream()", this.type_code);
        var instream = this.source_stream;
        
        var bytes_consumed = base.parse_from_stream () + 8;
        this.major_brand = instream.read_4cc ();
        this.minor_version = instream.read_uint32 ();
        // Remaining box data is a list of compatible_brands
        uint64 num_brands = (this.source_size - bytes_consumed) / 4;
        this.compatible_brands = instream.read_4cc_array (new string[num_brands]);
        return this.source_size; // Everything in the box was consumed
    }

    protected override void update_box_fields (uint64 payload_size = 0) throws Error {
        base.update_box_fields (payload_size + 8 + (this.compatible_brands.length * 4));
    }

    public override void write_fields_to_stream (IsoOutputStream outstream) throws Error {
        base.write_fields_to_stream (outstream);
        outstream.put_4cc (this.major_brand);
        outstream.put_uint32 (this.minor_version);
        foreach (var brand in this.compatible_brands) {
            outstream.put_4cc (brand);
        }
    }

    public override string to_string () {
        var builder = new StringBuilder ("IsoFileTypeBox[");
        builder.append (base.to_string ());
        if (this.loaded) {
            builder.append_printf (",brand %s,version %u",this.major_brand,this.minor_version);
            if (compatible_brands.length > 0) {
                builder.append (",comp brands[");                
                foreach (var brand in compatible_brands) {
                    builder.append (brand);
                    builder.append_c (',');
                }
                builder.truncate (builder.len-1);
                builder.append_c (']');
            }
        } else {
            builder.append (",[unloaded fields]");
        }
        builder.append_c (']');
        return builder.str;
    }

    public override void to_printer (IsoBox.LinePrinter printer, string prefix) {
        printer (prefix + to_string ());
    }
} // END class IsoFileTypeBox

/**
 * moov box
 * 
 * The Movie Box is just a container for other boxes
 */
public class Rygel.IsoMovieBox : IsoContainerBox {
    public IsoMovieBox.from_stream (IsoContainerBox parent, string type_code,
                                    IsoInputStream stream, uint64 offset,
                                    uint32 size, uint64 largesize)
            throws Error {
        base.from_stream (parent, type_code, stream, offset, size, largesize);
    }

    public IsoMovieBox (IsoContainerBox parent) {
        base (parent, "moov");
    }

    public override uint64 parse_from_stream () throws Error {
        debug ("IsoMovieBox(%s).parse_from_stream()", this.type_code);
        var bytes_consumed = base.parse_from_stream (); // IsoContainer/IsoBox
        this.children = base.read_boxes (this.source_offset + bytes_consumed,
                                         this.size - bytes_consumed);
        return this.source_size; // Everything in the box was consumed
    }

    protected override void update_box_fields (uint64 payload_size = 0) throws Error {
        base.update_box_fields (payload_size);
    }

    public override void write_fields_to_stream (IsoOutputStream outstream) throws Error {
        base.write_fields_to_stream (outstream);
        foreach (var box in this.children) {
            box.write_to_stream (outstream);
        }
    }

    public IsoMovieHeaderBox get_header_box () throws Error {
        return first_box_of_class (typeof (IsoMovieHeaderBox)) as IsoMovieHeaderBox;
    }

    public Gee.List<IsoTrackBox> get_tracks ()
            throws Error {
        var box_list = new Gee.ArrayList<IsoBox> ();
        foreach (var cur_box in this.children) {
            if (cur_box is IsoTrackBox) {
                box_list.add (cur_box as IsoTrackBox);
            }
        }
        return box_list;
    }

    public IsoTrackBox get_first_track_of_type (IsoMediaBox.MediaType media_type) throws Error {
        foreach (var cur_box in this.children) {
            if (cur_box is IsoTrackBox) {
                var track_box = cur_box as IsoTrackBox;
                if (track_box.is_media_type (media_type)) {
                    return track_box;
                }
            }
        }
        throw new IsoBoxError.BOX_NOT_FOUND
                              (this.to_string() + " does not have a track of type %d");
    }

    public Gee.List<IsoTrackBox> get_tracks_of_type (IsoMediaBox.MediaType media_type)
            throws Error {
        var box_list = new Gee.ArrayList<IsoBox> ();
        foreach (var cur_box in this.children) {
            if ((cur_box is IsoTrackBox)
                && ((cur_box as IsoTrackBox).is_media_type (media_type))) {
                box_list.add (cur_box);
            }
        }
        return box_list;
    }

    public IsoTrackBox get_first_sync_track () throws Error {
        foreach (var cur_box in this.children) {
            if (cur_box is IsoTrackBox) {
                var track_box = cur_box as IsoTrackBox;
                if (track_box.has_sync_sample_box ()) {
                    return track_box;
                }
            }
        }
        throw new IsoBoxError.BOX_NOT_FOUND
                              (this.to_string() + " does not have a SyncSampleBox");
    }

    public Gee.List<IsoTrackBox> get_sync_tracks () throws Error {
        var box_list = new Gee.ArrayList<IsoBox> ();
        foreach (var cur_box in this.children) {
            if ((cur_box is IsoTrackBox)
                && ((cur_box as IsoTrackBox).has_sync_sample_box ())) {
                box_list.add (cur_box);
            }
        }
        return box_list;
    }

    public override string to_string () {
        return "IsoMovieBox[" + base.to_string () + "," + base.children_to_string () + "]";
    }
    
    public override void to_printer (IsoBox.LinePrinter printer, string prefix) {
        printer (prefix + "IsoMovieBox[" + base.to_string () + "] {");
        base.children_to_printer (printer, prefix + "  ");
        printer (prefix + "}");
    }
} // END class IsoMovieBox

/**
 * mvhd box
 * 
 * The Movie Header Box
 */
public class Rygel.IsoMovieHeaderBox : IsoFullBox {
    public uint64 creation_time;
    public uint64 modification_time;
    public uint32 timescale;
    public uint64 duration;
    public double rate;
    public float volume;
    public uint32[] matrix;
    public uint32 next_track_id;
    public bool force_large_header;

    public IsoMovieHeaderBox (IsoContainerBox parent, uint64 creation_time,
                              uint64 modification_time, uint32 timescale, uint64 duration,
                              double rate, float volume, uint32[] matrix, uint32 next_track_id,
                              bool force_large_header) {
        base (parent, "mvhd", 0, 0); // Version and flags are 0
        this.creation_time = creation_time;
        this.modification_time = modification_time;
        this.timescale = timescale;
        this.duration = duration;
        this.rate = rate;
        this.volume = volume;
        this.matrix = matrix;
        this.next_track_id = next_track_id;
        this.force_large_header = force_large_header;
    }

    public IsoMovieHeaderBox.from_stream (IsoContainerBox parent, string type_code,
                                   IsoInputStream stream, uint64 offset,
                                   uint32 size, uint64 largesize)
            throws Error {
        base.from_stream (parent, type_code, stream, offset, size, largesize);
    }

    public override uint64 parse_from_stream () throws Error {
        debug ("IsoMovieHeaderBox(%s).parse_from_stream()", this.type_code);

        var bytes_consumed = base.parse_from_stream ();
        var instream = this.source_stream;
        switch (this.version) {
            case 0:
                this.creation_time = instream.read_uint32 ();
                this.modification_time = instream.read_uint32 ();
                this.timescale = instream.read_uint32 ();
                this.duration = instream.read_uint32 ();
                bytes_consumed += 16;
                this.force_large_header = false;
            break;
            case 1:
                this.creation_time = instream.read_uint64 ();
                this.modification_time = instream.read_uint64 ();
                this.timescale = instream.read_uint32 ();
                this.duration = instream.read_uint64 ();
                bytes_consumed += 28;
                this.force_large_header = true;
            break;
            default:
                throw new IsoBoxError.UNSUPPORTED_VERSION
                              ("moov box version unsupported: " + this.version.to_string ());
        }
        this.rate = instream.read_fixed_point_16_16 ();
        this.volume = instream.read_fixed_point_8_8 ();
        instream.skip_bytes (10); // reserved
        this.matrix = instream.read_uint32_array (new uint32[9]); // 36 bytes
        instream.skip_bytes (24); // pre-defined
        this.next_track_id = instream.read_uint32 ();
        bytes_consumed += 4 + 2 + 2 + 8 + 36 + 24 + 4;

        if (bytes_consumed != this.size) {
            throw new IsoBoxError.PARSE_ERROR
                          ("box size mismatch (parsed %lld, box size %lld)"
                           .printf(bytes_consumed, this.size));
        }
        return this.size;
    }

    private bool fields_require_large_header () {
        return (this.creation_time > uint32.MAX
                || this.modification_time > uint32.MAX
                || this.duration > uint32.MAX);
    }

    public override void update () throws Error {
        if (this.force_large_header || fields_require_large_header ()) {
            this.version = 1;
        } else {
            this.version = 0;
        }

        base.update ();
    }

    protected override void update_box_fields (uint64 payload_size = 0) throws Error {
        if (this.force_large_header || fields_require_large_header ()) {
            this.version = 1;
            payload_size += 28;
        } else {
            this.version = 0;
            payload_size += 16;
        }

        payload_size += 4 + 2 + 10 + 36 + 24 + 4;
        base.update_box_fields (payload_size);
    }

    /**
     * This will set the duration, accounting for the source timescale
     */
    public void set_duration (uint64 duration, uint32 timescale) throws Error {
        if (this.timescale == timescale) {
            this.duration = duration;
        } else { // Convert
            if (duration > uint32.MAX) {
                this.force_large_header = true;
            }
            if (this.force_large_header) {
                this.duration = (uint64)((double)this.timescale/timescale) * duration;
            } else { // Can use integer math
                this.duration = (duration * this.timescale) / timescale;
            }
        }
    }

    /**
     * This will get the duration, in seconds (accounting for the timescale)
     *
     * Note: This doesn't account for EditList boxes
     */
    public float get_duration_seconds () throws Error {
        if (!loaded) {
            throw new IsoBoxError.NOT_LOADED
                          ("IsoMovieHeaderBox.get_duration_seconds(): dependent fields aren't loaded");
        }
        return (float)this.duration / this.timescale;
    }

    public override void write_fields_to_stream (IsoOutputStream outstream) throws Error {
        base.write_fields_to_stream (outstream);
        switch (this.version) {
            case 0:
                outstream.put_uint32 ((uint32)this.creation_time);
                outstream.put_uint32 ((uint32)this.modification_time);
                outstream.put_uint32 (this.timescale);
                outstream.put_uint32 ((uint32)this.duration);
            break;
            case 1:
                outstream.put_uint64 (this.creation_time);
                outstream.put_uint64 (this.modification_time);
                outstream.put_uint32 (this.timescale);
                outstream.put_uint64 (this.duration);
            break;
            default:
                throw new IsoBoxError.UNSUPPORTED_VERSION
                              ("moov box version unsupported: " + this.version.to_string ());
        }
        outstream.put_fixed_point_16_16 (this.rate);
        outstream.put_fixed_point_8_8 (this.volume);
        outstream.put_zero_bytes (10); // reserved
        outstream.put_uint32_array (this.matrix);
        outstream.put_zero_bytes (24); // pre-defined
        outstream.put_uint32 (this.next_track_id);
    }

    public override string to_string () {
        var builder = new StringBuilder ("IsoMovieHeaderBox[");
        builder.append (base.to_string ());
        if (this.loaded) {
            try {
                builder.append_printf (",ctime %llu,mtime %llu,tscale %u,duration %llu (%0.2fs),rate %0.2f,vol %0.2f",
                                       this.creation_time, this.modification_time, this.timescale,
                                       this.duration, get_duration_seconds (), this.rate, this.volume);
                builder.append (",matrix[");
                foreach (var dword in this.matrix) {
                    builder.append (dword.to_string ());
                    builder.append_c (',');
                }
                builder.truncate (builder.len-1);
                builder.append_printf ("],next_track %u", this.next_track_id);
            } catch (Error e) {
                builder.append ("error: ");
                builder.append (e.message);
            }
        } else {
            builder.append (",[unloaded fields]");
        }
        builder.append_c (']');
        return builder.str;
    }

    public override void to_printer (IsoBox.LinePrinter printer, string prefix) {
        printer (prefix + this.to_string ());
    }
} // END class IsoMovieHeaderBox

/**
 * trak box
 * 
 * The Track Box is just a container for other track-related boxes
 */
public class Rygel.IsoTrackBox : IsoContainerBox {
    // Box cache references (MAKE SURE these are nulled out in update())
    protected IsoMovieBox movie_box = null;
    protected IsoTrackHeaderBox track_header_box = null;
    protected IsoMediaBox media_box = null;
    protected IsoEditBox edit_box = null;
    
    public IsoTrackBox (IsoContainerBox parent) {
        base (parent, "trak");
    }

    public IsoTrackBox.from_stream (IsoContainerBox parent, string type_code,
                                    IsoInputStream stream, uint64 offset,
                                    uint32 size, uint64 largesize)
            throws Error {
        base.from_stream (parent, type_code, stream, offset, size, largesize);
    }

    public override uint64 parse_from_stream () throws Error {
        debug ("IsoTrackBox(%s).parse_from_stream()", this.type_code);
        var bytes_consumed = base.parse_from_stream (); // IsoContainer/IsoBox
        this.children = base.read_boxes (this.source_offset + bytes_consumed,
                                         this.size - bytes_consumed);
        return this.source_size; // Everything in the box was consumed
    }

    protected override void update () throws Error {
        movie_box = null;
        track_header_box = null;
        media_box = null;
        edit_box = null;
        base.update ();
    }

    protected override void update_box_fields (uint64 payload_size = 0) throws Error {
        base.update_box_fields (payload_size);
    }

    public override void write_fields_to_stream (IsoOutputStream outstream) throws Error {
        base.write_fields_to_stream (outstream);
        foreach (var box in this.children) {
            box.write_to_stream (outstream);
        }
    }

    public uint32 get_movie_timescale () throws Error {
        return get_movie_box ().get_header_box ().timescale;
    }

    public uint32 get_media_timescale () throws Error {
        return get_media_box ().get_header_box ().timescale;
    }

    /**
     * Return the IsoMovieBox containing this IsoTrackBox
     *
     * Note that this will cache the box reference until update() is called.
     */
    public IsoMovieBox get_movie_box () throws Error {
        if (this.movie_box == null) {
            this.movie_box = get_ancestor_by_level (1, typeof (IsoMovieBox)) as IsoMovieBox;
        }
        return this.movie_box;
    }

    /**
     * Return the IsoTrackHeaderBox within the IsoTrackBox
     *
     * Note that this will cache the box reference until update() is called.
     */
    public IsoTrackHeaderBox get_header_box () throws Error {
        if (this.track_header_box == null) {
            this.track_header_box
                    = first_box_of_class (typeof (IsoTrackHeaderBox)) as IsoTrackHeaderBox;
        }
        return this.track_header_box;
    }

    /**
     * Return the IsoMediaBox within the IsoTrackBox
     *
     * Note that this will cache the box reference until update() is called.
     */
    public IsoMediaBox get_media_box () throws Error {
        if (this.media_box == null) {
            this.media_box
                    = first_box_of_class (typeof (IsoMediaBox)) as IsoMediaBox;
        }
        return this.media_box;
    }

    /**
     * Return the IsoEditBox within the IsoTrackBox
     *
     * Note that this will cache the box reference until update() is called.
     */
    public IsoEditBox get_edit_box () throws Error {
        if (this.edit_box == null) {
            this.edit_box
                    = first_box_of_class (typeof (IsoEditBox)) as IsoEditBox;
        }
        return this.edit_box;
    }

    /**
     * Create an IsoEditBox with an empty IsoEditListBox and add it to the TrackBox,
     * replacing any exiting IsoEditBox.
     *
     * Note that this will cache the box reference until update() is called.
     */
    public IsoEditBox create_edit_box () throws Error {
        remove_boxes_by_class (typeof (IsoEditBox));
        this.edit_box = new IsoEditBox (this);
        this.edit_box.create_edit_list_box ();
        this.children.insert (0, this.edit_box);
        return this.edit_box;
    }

    public bool is_media_type (IsoMediaBox.MediaType media_type) throws Error {
        return get_media_box ().is_media_type (media_type);
    }

    public IsoSampleTableBox get_sample_table_box () throws Error {
        return (get_media_box ().get_media_information_box ().get_sample_table_box ());
    }

    public bool has_sync_sample_box () throws Error {
        return (get_media_box ().get_media_information_box ().get_sample_table_box ()
                                   .has_box_of_class (typeof (IsoSyncSampleBox)));
    }

    public override string to_string () {
        return "IsoTrackBox[" + base.to_string () + "," + base.children_to_string () + "]";
    }
    
    public override void to_printer (IsoBox.LinePrinter printer, string prefix) {
        printer (prefix + "IsoTrackBox[" + base.to_string () + "] {");
        base.children_to_printer (printer, prefix + "  ");
        printer (prefix + "}");
    }
} // END class IsoTrackBox

/**
 * tkhd box
 *
 * Track Header box
 */
public class Rygel.IsoTrackHeaderBox : IsoFullBox {
    public uint64 creation_time;
    public uint64 modification_time;
    public uint32 track_id;
    public uint64 duration;
    public int16 layer;
    public int16 alternate_group;
    public float volume;
    public uint32[] matrix;
    public double width;
    public double height;
    public bool force_large_header;

    public IsoTrackHeaderBox (IsoTrackBox parent, uint64 creation_time,
                              uint64 modification_time, uint32 track_id, uint64 duration,
                              int16 layer, int16 alternate_group, float volume, uint32[] matrix,
                              double width, double height, bool force_large_header) {
        base (parent, "tkhd", 0, 0); // Version and flags are 0
        this.creation_time = creation_time;
        this.modification_time = modification_time;
        this.track_id = track_id;
        this.duration = duration;
        this.layer = layer;
        this.alternate_group = alternate_group;
        this.volume = volume;
        this.matrix = matrix;
        this.width = width;
        this.height = height;
        this.force_large_header = force_large_header;
    }

    public IsoTrackHeaderBox.from_stream (IsoContainerBox parent, string type_code,
                                   IsoInputStream stream, uint64 offset,
                                   uint32 size, uint64 largesize)
            throws Error {
        base.from_stream (parent, type_code, stream, offset, size, largesize);
    }

    public override uint64 parse_from_stream () throws Error {
        debug ("IsoMovieHeaderBox(%s).parse_from_stream()", this.type_code);

        var bytes_consumed = base.parse_from_stream ();
        var instream = this.source_stream;
        switch (this.version) { // set via IsoFullBox.from_stream
            case 0:
                this.creation_time = instream.read_uint32 ();
                this.modification_time = instream.read_uint32 ();
                this.track_id = instream.read_uint32 ();
                instream.skip_bytes (4); // reserved
                this.duration = instream.read_uint32 ();
                bytes_consumed += 20;
                this.force_large_header = false;
            break;
            case 1:
                this.creation_time = instream.read_uint64 ();
                this.modification_time = instream.read_uint64 ();
                this.track_id = instream.read_uint32 ();
                instream.skip_bytes (4); // reserved
                this.duration = instream.read_uint64 ();
                bytes_consumed += 32;
                this.force_large_header = true;
            break;
            default:
                throw new IsoBoxError.UNSUPPORTED_VERSION
                              ("tkhd box version unsupported: " + this.version.to_string ());
        }

        instream.skip_bytes (8); // reserved
        this.layer = instream.read_int16 ();
        this.alternate_group = instream.read_int16 ();
        this.volume = instream.read_fixed_point_8_8 ();
        instream.skip_bytes (2); // reserved
        this.matrix = instream.read_uint32_array (new uint32[9]); // 36 bytes
        this.width = instream.read_fixed_point_16_16 ();
        this.height = instream.read_fixed_point_16_16 ();

        bytes_consumed += 8 + 2 + 2 + 2 + 2 + 36 + 4 + 4;

        if (bytes_consumed != this.size) {
            throw new IsoBoxError.PARSE_ERROR
                          ("box size mismatch (parsed %lld, box size %lld)"
                           .printf(bytes_consumed, this.size));
        }
        return this.size;
    }

    private bool fields_require_large_header () {
        return (this.creation_time > uint32.MAX
                || this.modification_time > uint32.MAX
                || this.duration > uint32.MAX);
    }

    public override void update () throws Error {
        if (this.force_large_header || fields_require_large_header ()) {
            this.version = 1;
        } else {
            this.version = 0;
        }

        base.update ();
    }

    protected override void update_box_fields (uint64 payload_size = 0) throws Error {
        if (this.force_large_header || fields_require_large_header ()) {
            this.version = 1;
            payload_size += 32;
        } else {
            this.version = 0;
            payload_size += 20;
        }

        payload_size += 8 + 2 + 2 + 2 + 2 + 36 + 4 + 4;
        base.update_box_fields (payload_size);
    }

    /**
     * This will set the duration, accounting for the source timescale
     */
    public void set_duration (uint64 duration, uint32 timescale) throws Error {
        // The TrackBoxHeader duration timescale is the MovieBox's timescale
        var movie_timescale = (this.parent_box as IsoTrackBox).get_movie_timescale ();
        if (movie_timescale == timescale) {
            this.duration = duration;
        } else { // Convert
            if (duration > uint32.MAX) {
                this.force_large_header = true;
            }
            if (this.force_large_header) {
                this.duration = (uint64)((double)movie_timescale/timescale) * duration;
            } else { // Can use integer math
                this.duration = (duration * movie_timescale) / timescale;
            }
        }
    }

    /**
     * This will get the track's movie duration, in seconds (accounting for the timescale)
     */
    public float get_duration_seconds () throws Error {
        if (!loaded) {
            throw new IsoBoxError.NOT_LOADED
                          ("IsoTrackHeaderBox.get_duration_seconds(): dependent fields aren't loaded");
        }
        // The TrackBoxHeader duration timescale is the MovieBox's timescale
        var movie_timescale = (this.parent_box as IsoTrackBox).get_movie_timescale ();
        return (float)this.duration / movie_timescale;
    }

    public override void write_fields_to_stream (IsoOutputStream outstream) throws Error {
        base.write_fields_to_stream (outstream);
        switch (this.version) {
            case 0:
                outstream.put_uint32 ((uint32)this.creation_time);
                outstream.put_uint32 ((uint32)this.modification_time);
                outstream.put_uint32 (this.track_id);
                outstream.put_uint32 (0);
                outstream.put_uint32 ((uint32)this.duration);
            break;
            case 1:
                outstream.put_uint64 (this.creation_time);
                outstream.put_uint64 (this.modification_time);
                outstream.put_uint32 (this.track_id);
                outstream.put_uint32 (0);
                outstream.put_uint64 (this.duration);
            break;
            default:
                throw new IsoBoxError.UNSUPPORTED_VERSION
                              ("moov box version unsupported: " + this.version.to_string ());
        }

        outstream.put_uint64 (0);
        outstream.put_int16 (this.layer);
        outstream.put_int16 (this.alternate_group);
        outstream.put_fixed_point_8_8 (this.volume);
        outstream.put_uint16 (0);
        outstream.put_uint32_array (this.matrix);
        outstream.put_fixed_point_16_16 (this.width);
        outstream.put_fixed_point_16_16 (this.height);
    }

    public override string to_string () {
        var builder = new StringBuilder ("IsoTrackHeaderBox[");
        builder.append (base.to_string ());
        if (this.loaded) {
            try {
                builder.append_printf (",ctime %lld,mtime %lld,track_id %d,duration %lld (%0.2fs),layer %d,alt_group %d,vol %0.2f",
                                       this.creation_time, this.modification_time, this.track_id,
                                       this.duration, this.get_duration_seconds (),
                                       this.layer, this.alternate_group, this.volume,
                                       this.width, this.height);
                builder.append (",matrix[");
                foreach (var dword in this.matrix) {
                    builder.append (dword.to_string ());
                    builder.append_c (',');
                }
                builder.truncate (builder.len-1);
                builder.append_printf ("],width %0.2f,height %0.2f", this.width, this.height);
            } catch (Error e) {
                builder.append ("error: ");
                builder.append (e.message);
            }
        } else {
            builder.append (",[unloaded fields]");
        }
        builder.append_c (']');
        return builder.str;
    }

    public override void to_printer (IsoBox.LinePrinter printer, string prefix) {
        printer (prefix + this.to_string ());
    }
} // END class IsoTrackHeaderBox

/**
 * mdia box
 * 
 * The Media Box contains all the objects that declare information about the media data
 * within a track.
 */
public class Rygel.IsoMediaBox : IsoContainerBox {
    // Box cache references (MAKE SURE these are nulled out in update())
    protected IsoMediaHeaderBox media_header_box = null;
    protected IsoMediaInformationBox media_information_box = null;

    public enum MediaType {UNDEFINED, AUDIO, VIDEO}

    public IsoMediaBox (IsoContainerBox parent) {
        base (parent, "mdia");
    }

    public IsoMediaBox.from_stream (IsoContainerBox parent, string type_code,
                                    IsoInputStream stream, uint64 offset,
                                    uint32 size, uint64 largesize)
            throws Error {
        base.from_stream (parent, type_code, stream, offset, size, largesize);
    }

    public override uint64 parse_from_stream () throws Error {
        debug ("IsoMediaBox(%s).parse_from_stream()", this.type_code);
        var bytes_consumed = base.parse_from_stream (); // IsoContainer/IsoBox
        this.children = base.read_boxes (this.source_offset + bytes_consumed,
                                         this.size - bytes_consumed);
        return this.source_size; // Everything in the box was consumed
    }

    protected override void update () throws Error {
        media_header_box = null;
        media_information_box = null;
        base.update ();
    }

    protected override void update_box_fields (uint64 payload_size = 0) throws Error {
        base.update_box_fields (payload_size);
    }

    public override void write_fields_to_stream (IsoOutputStream outstream) throws Error {
        base.write_fields_to_stream (outstream);
        foreach (var box in this.children) {
            box.write_to_stream (outstream);
        }
    }

    /**
     * Return the IsoMediaHeaderBox within the IsoMediaBox
     *
     * Note that this will cache the box reference until update() is called.
     */
    public IsoMediaHeaderBox get_header_box () throws Error {
        if (this.media_header_box == null) {
            this.media_header_box
                    = first_box_of_class (typeof (IsoMediaHeaderBox)) as IsoMediaHeaderBox;
        }
        return this.media_header_box;
    }

    /**
     * Return the IsoMediaInformationBox within the IsoMediaBox
     *
     * Note that this will cache the box reference until update() is called.
     */
    public IsoMediaInformationBox get_media_information_box () throws Error {
        if (this.media_information_box == null) {
            this.media_information_box
                    = first_box_of_class (typeof (IsoMediaInformationBox)) as IsoMediaInformationBox;
        }
        return this.media_information_box;
    }

    public bool is_media_type (MediaType media_type) throws Error {
        var media_information_box = get_media_information_box ();
        switch (media_type) {
            case MediaType.VIDEO:
                return media_information_box.has_box_of_class (typeof (IsoVideoMediaHeaderBox));
            case MediaType.AUDIO:
                return media_information_box.has_box_of_class (typeof (IsoSoundMediaHeaderBox));
            default:
                throw new IsoBoxError.BOX_NOT_FOUND
                              (this.to_string () + " does not contain a IsoSyncSampleBox");
                
        }
    }

    public override string to_string () {
        return "IsoMediaBox[" + base.to_string () + "," + base.children_to_string () + "]";
    }
    
    public override void to_printer (IsoBox.LinePrinter printer, string prefix) {
        printer (prefix + "IsoMediaBox[" + base.to_string () + "] {");
        base.children_to_printer (printer, prefix + "  ");
        printer (prefix + "}");
    }
} // END class IsoMediaBox

/**
 * mdhd box
 *
 * The Media box declares overall information that is media-independent, and relevant to
 * characteristics of the media in a track.
 */
public class Rygel.IsoMediaHeaderBox : IsoFullBox {
    public uint64 creation_time;
    public uint64 modification_time;
    public uint32 timescale;
    public uint64 duration;
    public string language;
    public bool force_large_header;

    public IsoMediaHeaderBox (IsoContainerBox parent, uint64 creation_time,
                              uint64 modification_time, uint32 timescale, uint64 duration,
                              string language, bool force_large_header) {
        base (parent, "mdhd", force_large_header ? 1 : 0, 0); // Version is 1 for large headers
        this.creation_time = creation_time;
        this.modification_time = modification_time;
        this.timescale = timescale;
        this.duration = duration;
        this.language = language;
        this.force_large_header = force_large_header;
    }

    public IsoMediaHeaderBox.from_stream (IsoContainerBox parent, string type_code,
                                   IsoInputStream stream, uint64 offset,
                                   uint32 size, uint64 largesize)
            throws Error {
        base.from_stream (parent, type_code, stream, offset, size, largesize);
    }

    public override uint64 parse_from_stream () throws Error {
        debug ("IsoMediaHeaderBox(%s).parse_from_stream()", this.type_code);

        var bytes_consumed = base.parse_from_stream ();
        var instream = this.source_stream;
        switch (this.version) {
            case 0:
                this.creation_time = instream.read_uint32 ();
                this.modification_time = instream.read_uint32 ();
                this.timescale = instream.read_uint32 ();
                this.duration = instream.read_uint32 ();
                bytes_consumed += 16;
                this.force_large_header = false;
            break;
            case 1:
                this.creation_time = instream.read_uint64 ();
                this.modification_time = instream.read_uint64 ();
                this.timescale = instream.read_uint32 ();
                this.duration = instream.read_uint64 ();
                bytes_consumed += 28;
                this.force_large_header = true;
            break;
            default:
                throw new IsoBoxError.UNSUPPORTED_VERSION
                              ("mdhd box version unsupported: " + this.version.to_string ());
        }
        this.language = instream.read_packed_language_code ();
        instream.skip_bytes (2); // pre defined
        bytes_consumed += 2 + 2;

        if (bytes_consumed != this.size) {
            throw new IsoBoxError.PARSE_ERROR
                          ("box size mismatch (parsed %lld, box size %lld)"
                           .printf(bytes_consumed, this.size));
        }
        return this.size;
    }

    private bool fields_require_large_header () {
        return (this.creation_time > uint32.MAX
                || this.modification_time > uint32.MAX
                || this.duration > uint32.MAX);
    }

    /**
     * This will set the duration, accounting for the source timescale
     */
    public void set_duration (uint64 duration, uint32 timescale) throws Error {
        if (this.timescale == timescale) {
            this.duration = duration;
        } else { // Convert
            if (duration > uint32.MAX) {
                this.force_large_header = true;
            }
            if (this.force_large_header) {
                this.duration = (uint64)((double)this.timescale/timescale) * duration;
            } else { // Can use integer math
                this.duration = (duration * this.timescale) / timescale;
            }
        }
    }

    /**
     * This will get the duration, in seconds (accounting for the timescale)
     */
    public float get_duration_seconds () throws Error {
        if (!loaded) {
            throw new IsoBoxError.NOT_LOADED
                          ("IsoMediaHeaderBox.get_duration_seconds(): dependent fields aren't loaded");
        }
        return (float)this.duration / this.timescale;
    }

    public override void update () throws Error {
        if (this.force_large_header || fields_require_large_header ()) {
            this.version = 1;
        } else {
            this.version = 0;
        }

        base.update ();
    }

    protected override void update_box_fields (uint64 payload_size = 0) throws Error {
        if (this.force_large_header || fields_require_large_header ()) {
            this.version = 1;
            payload_size += 28;
        } else {
            this.version = 0;
            payload_size += 16;
        }

        payload_size += 2 + 2;
        base.update_box_fields (payload_size);
    }

    public override void write_fields_to_stream (IsoOutputStream outstream) throws Error {
        base.write_fields_to_stream (outstream);
        switch (this.version) {
            case 0:
                outstream.put_uint32 ((uint32)this.creation_time);
                outstream.put_uint32 ((uint32)this.modification_time);
                outstream.put_uint32 (this.timescale);
                outstream.put_uint32 ((uint32)this.duration);
            break;
            case 1:
                outstream.put_uint64 (this.creation_time);
                outstream.put_uint64 (this.modification_time);
                outstream.put_uint32 (this.timescale);
                outstream.put_uint64 (this.duration);
            break;
            default:
                throw new IsoBoxError.UNSUPPORTED_VERSION
                              ("mdhd box version unsupported: " + this.version.to_string ());
        }
        outstream.put_packed_language_code (this.language);
        outstream.put_zero_bytes (2); // pre defined
    }

    public override string to_string () {
        var builder = new StringBuilder ("IsoMediaHeaderBox[");
        builder.append (base.to_string ());
        if (this.loaded) {
            try {
                builder.append_printf (",ctime %lld,mtime %lld,duration %lld (%0.2fs),language %s",
                                       this.creation_time, this.modification_time, this.duration,
                                       get_duration_seconds (), this.language);
            } catch (Error e) {
                builder.append ("error: ");
                builder.append (e.message);
            }
        } else {
            builder.append (",[unloaded fields]");
        }
        builder.append_c (']');
        return builder.str;
    }

    public override void to_printer (IsoBox.LinePrinter printer, string prefix) {
        printer (prefix + this.to_string ());
    }
} // END class IsoMediaHeaderBox

/**
 * hdlr box
 *
 * The Handler Reference Box declares the process by which the media-data in the track is
 * presented, and thus, the nature of the media in a track. For example, a video track would
 * be handled by a video handler.
 */
public class Rygel.IsoHandlerBox : IsoFullBox {
    public string handler_type;
    public string name;

    public IsoHandlerBox (IsoContainerBox parent, string handler_type, string name) {
        base (parent, "hdlr", 0, 0); // Version/flags 0
        this.handler_type = handler_type;
        this.name = name;
    }

    public IsoHandlerBox.from_stream (IsoContainerBox parent, string type_code,
                                      IsoInputStream stream, uint64 offset,
                                      uint32 size, uint64 largesize)
            throws Error {
        base.from_stream (parent, type_code, stream, offset, size, largesize);
    }

    public override uint64 parse_from_stream () throws Error {
        debug ("IsoHandlerBox(%s).parse_from_stream()", this.type_code);

        var bytes_consumed = base.parse_from_stream ();
        var instream = this.source_stream;

        instream.skip_bytes (4); // reserved
        this.handler_type = instream.read_4cc ();
        instream.skip_bytes (12); // reserved
        size_t bytes_read;
        this.name = instream.read_null_terminated_string (out bytes_read);
        bytes_consumed += 4 + 4 + 12 + bytes_read;

        if (bytes_consumed != this.size) {
            throw new IsoBoxError.PARSE_ERROR
                          ("box size mismatch (parsed %lld, box size %lld)"
                           .printf(bytes_consumed, this.size));
        }
        return this.size;
    }

    protected override void update_box_fields (uint64 payload_size = 0) throws Error {
        payload_size += 4 + 4 + 12 + this.name.length + 1;
        base.update_box_fields (payload_size);
    }

    public override void write_fields_to_stream (IsoOutputStream outstream) throws Error {
        base.write_fields_to_stream (outstream);
        outstream.put_zero_bytes (4); // reserved
        outstream.put_4cc (this.handler_type);
        outstream.put_zero_bytes (12); // reserved
        outstream.put_null_terminated_string (this.name);
    }

    public override string to_string () {
        var builder = new StringBuilder ("IsoHandlerBox[");
        builder.append (base.to_string ());
        if (this.loaded) {
            builder.append_printf (",htype %s,name %s",this.handler_type, this.name);
        } else {
            builder.append (",[unloaded fields]");
        }
        builder.append_c (']');
        return builder.str;
    }

    public override void to_printer (IsoBox.LinePrinter printer, string prefix) {
        printer (prefix + this.to_string ());
    }
} // END class IsoHandlerBox

/**
 * minf box
 * 
 * The Media Information Box contains all the objects that declare characteristic information
 * of the media in the track.
 */
public class Rygel.IsoMediaInformationBox : IsoContainerBox {
    public IsoMediaInformationBox (IsoContainerBox parent) {
        base (parent, "minf");
    }

    public IsoMediaInformationBox.from_stream (IsoContainerBox parent, string type_code,
                                    IsoInputStream stream, uint64 offset,
                                    uint32 size, uint64 largesize)
            throws Error {
        base.from_stream (parent, type_code, stream, offset, size, largesize);
    }

    public override uint64 parse_from_stream () throws Error {
        debug ("IsoMediaInformationBox(%s).parse_from_stream()", this.type_code);
        var bytes_consumed = base.parse_from_stream (); // IsoContainer/IsoBox
        this.children = base.read_boxes (this.source_offset + bytes_consumed,
                                         this.size - bytes_consumed);
        return this.source_size; // Everything in the box was consumed
    }

    protected override void update_box_fields (uint64 payload_size = 0) throws Error {
        base.update_box_fields (payload_size);
    }

    public override void write_fields_to_stream (IsoOutputStream outstream) throws Error {
        base.write_fields_to_stream (outstream);
        foreach (var box in this.children) {
            box.write_to_stream (outstream);
        }
    }

    public IsoSampleTableBox get_sample_table_box () throws Error {
        return first_box_of_class (typeof (IsoSampleTableBox)) as IsoSampleTableBox;
    }

    public override string to_string () {
        return "IsoMediaInformationBox[" + base.to_string () + "," + base.children_to_string () + "]";
    }
    
    public override void to_printer (IsoBox.LinePrinter printer, string prefix) {
        printer (prefix + "IsoMediaInformationBox[" + base.to_string () + "] {");
        base.children_to_printer (printer, prefix + "  ");
        printer (prefix + "}");
    }
} // END class IsoMediaInformationBox

/**
 * vmhd box
 *
 * The Video Media Header Box contains general presentation information, independent of the coding,
 * for video media. Note that the flags field has the value 1.
 */
public class Rygel.IsoVideoMediaHeaderBox : IsoFullBox {
    public uint16 graphicsmode;
    public uint16[] opcolor; // 3 16-bit values: RGB

    public IsoVideoMediaHeaderBox (IsoContainerBox parent, uint16 graphicsmode, uint16[] opcolor) {
        base (parent, "vmhd", 0, 0); // Version/flags 0
        this.graphicsmode = graphicsmode;
        this.opcolor = opcolor;
    }

    public IsoVideoMediaHeaderBox.from_stream (IsoContainerBox parent, string type_code,
                                      IsoInputStream stream, uint64 offset,
                                      uint32 size, uint64 largesize)
            throws Error {
        base.from_stream (parent, type_code, stream, offset, size, largesize);
    }

    public override uint64 parse_from_stream () throws Error {
        debug ("IsoVideoMediaHeaderBox(%s).parse_from_stream()", this.type_code);

        var bytes_consumed = base.parse_from_stream ();
        var instream = this.source_stream;

        this.graphicsmode = instream.read_uint16 ();
        this.opcolor = instream.read_uint16_array (new uint16[3]); // 6 bytes
        bytes_consumed += 2 + 6;

        if (bytes_consumed != this.size) {
            throw new IsoBoxError.PARSE_ERROR
                          ("box size mismatch (parsed %lld, box size %lld)"
                           .printf(bytes_consumed, this.size));
        }
        return this.size;
    }

    protected override void update_box_fields (uint64 payload_size = 0) throws Error {
        payload_size += 2 + 6;
        base.update_box_fields (payload_size);
    }

    public override void write_fields_to_stream (IsoOutputStream outstream) throws Error {
        base.write_fields_to_stream (outstream);
        outstream.put_uint16 (this.graphicsmode);
        outstream.put_uint16_array (this.opcolor);
    }

    public override string to_string () {
        var builder = new StringBuilder ("IsoVideoMediaHeaderBox[");
        builder.append (base.to_string ());
        if (this.loaded) {
            builder.append_printf (",gmode %ld,opcolor %d:%d:%d", this.graphicsmode,
                                   this.opcolor[0], this.opcolor[1], this.opcolor[2]);
        } else {
            builder.append (",[unloaded fields]");
        }
        builder.append_c (']');
        return builder.str;
    }

    public override void to_printer (IsoBox.LinePrinter printer, string prefix) {
        printer (prefix + this.to_string ());
    }
} // END class IsoVideoMediaHeaderBox

/**
 * smhd box
 *
 * The sound media header contains general presentation information, independent of the coding,
 * for audio media. This header is used for all tracks containing audio.
 */
public class Rygel.IsoSoundMediaHeaderBox : IsoFullBox {
    public int16 balance;

    public IsoSoundMediaHeaderBox (IsoContainerBox parent, int16 balance) {
        base (parent, "smhd", 0, 0); // Version/flags 0
        this.balance = balance;
    }

    public IsoSoundMediaHeaderBox.from_stream (IsoContainerBox parent, string type_code,
                                      IsoInputStream stream, uint64 offset,
                                      uint32 size, uint64 largesize)
            throws Error {
        base.from_stream (parent, type_code, stream, offset, size, largesize);
    }

    public override uint64 parse_from_stream () throws Error {
        debug ("IsoSoundMediaHeaderBox(%s).parse_from_stream()", this.type_code);

        var bytes_consumed = base.parse_from_stream ();
        var instream = this.source_stream;

        this.balance = instream.read_int16 ();
        instream.skip_bytes (2); // reserved
        bytes_consumed += 2 + 2;

        if (bytes_consumed != this.size) {
            throw new IsoBoxError.PARSE_ERROR
                          ("box size mismatch (parsed %lld, box size %lld)"
                           .printf(bytes_consumed, this.size));
        }
        return this.size;
    }

    protected override void update_box_fields (uint64 payload_size = 0) throws Error {
        payload_size += 2 + 2;
        base.update_box_fields (payload_size);
    }

    public override void write_fields_to_stream (IsoOutputStream outstream) throws Error {
        base.write_fields_to_stream (outstream);
        outstream.put_int16 (this.balance);
        outstream.put_zero_bytes (2); // reserved
    }

    public override string to_string () {
        var builder = new StringBuilder ("IsoSoundMediaHeaderBox[");
        builder.append (base.to_string ());
        if (this.loaded) {
            builder.append_printf (",balance %d", this.balance);
        } else {
            builder.append (",[unloaded fields]");
        }
        builder.append_c (']');
        return builder.str;
    }

    public override void to_printer (IsoBox.LinePrinter printer, string prefix) {
        printer (prefix + this.to_string ());
    }
} // END class IsoSoundMediaHeaderBox

/**
 * stbl box
 *
 * The Sample Table Box contains all the time and data indexing of the media samples in a track.
 * Using the tables here, it is possible to locate samples in time, determine their type
 * (e.g. I-frame or not), and determine their size, container, and offset into that container.
 */
public class Rygel.IsoSampleTableBox : IsoContainerBox {
    // Box cache references (MAKE SURE these are nulled out in update())
    IsoMovieBox movie_box = null;
    IsoTrackBox track_box = null;
    IsoMediaBox media_box = null;
    IsoTimeToSampleBox sample_time_box = null;
    IsoSyncSampleBox sample_sync_box = null;
    IsoSampleToChunkBox sample_chunk_box = null;
    IsoSampleSizeBox sample_size_box = null;
    IsoChunkOffsetBox chunk_offset_box = null;

    public IsoSampleTableBox (IsoContainerBox parent) {
        base (parent, "stbl");
    }

    public IsoSampleTableBox.from_stream (IsoContainerBox parent, string type_code,
                                    IsoInputStream stream, uint64 offset,
                                    uint32 size, uint64 largesize)
            throws Error {
        base.from_stream (parent, type_code, stream, offset, size, largesize);
    }

    public override uint64 parse_from_stream () throws Error {
        debug ("IsoSampleTableBox(%s).parse_from_stream()", this.type_code);
        var bytes_consumed = base.parse_from_stream (); // IsoContainer/IsoBox
        this.children = base.read_boxes (this.source_offset + bytes_consumed,
                                         this.size - bytes_consumed);
        return this.source_size; // Everything in the box was consumed
    }

    protected override void update () throws Error {
        movie_box = null;
        track_box = null;
        media_box = null;
        sample_time_box = null;
        sample_sync_box = null;
        sample_chunk_box = null;
        sample_size_box = null;
        chunk_offset_box = null;
        base.update ();
    }

    protected override void update_box_fields (uint64 payload_size = 0) throws Error {
        base.update_box_fields (payload_size);
    }

    public override void write_fields_to_stream (IsoOutputStream outstream) throws Error {
        base.write_fields_to_stream (outstream);
        foreach (var box in this.children) {
            box.write_to_stream (outstream);
        }
    }

    /**
     * Return the IsoMovieBox containing this IsoSampleTableBox
     *
     * Note that this will cache the box reference until update() is called.
     */
    public IsoMovieBox get_movie_box () throws Error {
        if (this.movie_box == null) {
            this.movie_box = get_ancestor_by_level (4, typeof (IsoMovieBox)) as IsoMovieBox;
        }
        return this.movie_box;
    }

    /**
     * Return the IsoTrackBox containing this IsoSampleTableBox
     *
     * Note that this will cache the box reference until update() is called.
     */
    public IsoTrackBox get_track_box () throws Error {
        if (this.track_box == null) {
            this.track_box = get_ancestor_by_level (3, typeof (IsoTrackBox)) as IsoTrackBox;
        }
        return this.track_box;
    }

    /**
     * Return the IsoMediaBox containing this IsoSampleTableBox
     *
     * Note that this will cache the box reference until update() is called.
     */
    public IsoMediaBox get_media_box () throws Error {
        if (this.media_box == null) {
            this.media_box = get_ancestor_by_level (2, typeof (IsoMediaBox)) as IsoMediaBox;
        }
        return this.media_box;
    }

    /**
     * Return the IsoTimeToSampleBox within the IsoSampleTableBox
     *
     * Note that this will cache the box reference until update() is called.
     */
    public IsoTimeToSampleBox get_sample_time_box () throws Error {
        if (this.sample_time_box == null) {
            this.sample_time_box
                    = first_box_of_class (typeof (IsoTimeToSampleBox)) as IsoTimeToSampleBox;
        }
        return this.sample_time_box;
    }

    /**
     * Return the IsoSyncSampleBox within the IsoSampleTableBox
     *
     * Note that this will cache the box reference until update() is called.
     */
    public IsoSyncSampleBox get_sample_sync_box () throws Error {
        if (this.sample_sync_box == null) {
            this.sample_sync_box
                    = first_box_of_class (typeof (IsoSyncSampleBox)) as IsoSyncSampleBox;
        }
        return this.sample_sync_box;
    }

    /**
     * Return the IsoSampleToChunkBox within the IsoSampleTableBox
     *
     * Note that this will cache the box reference until update() is called.
     */
    public IsoSampleToChunkBox get_sample_chunk_box () throws Error {
        if (this.sample_chunk_box == null) {
            this.sample_chunk_box
                    = first_box_of_class (typeof (IsoSampleToChunkBox)) as IsoSampleToChunkBox;
        }
        return this.sample_chunk_box;
    }

    /**
     * Return the IsoSampleSizeBox within the IsoSampleTableBox
     *
     * Note that this will cache the box reference until update() is called.
     */
    public IsoSampleSizeBox get_sample_size_box () throws Error {
        if (this.sample_size_box == null) {
            this.sample_size_box
                    = first_box_of_class (typeof (IsoSampleSizeBox)) as IsoSampleSizeBox;
        }
        return this.sample_size_box;
    }

    /**
     * Return the IsoChunkOffsetBox within the IsoSampleTableBox
     *
     * Note that this will cache the box reference until update() is called.
     */
    public IsoChunkOffsetBox get_chunk_offset_box () throws Error {
        if (this.chunk_offset_box == null) {
            this.chunk_offset_box
                    = first_box_of_class (typeof (IsoChunkOffsetBox)) as IsoChunkOffsetBox;
        }
        return this.chunk_offset_box;
    }

    public struct AccessPoint {
        int64 time_offset; /** in the timescale of the track */
        uint64 byte_offset;
        uint32 sample;
        uint32 chunk;
        uint32 samples_into_chunk;
        uint64 bytes_into_chunk;
        bool is_at_extent; /** indicates the AccessPoint is an very start or end of the range */
    }

    public enum Proximity {UNDEFINED, BEFORE, AFTER, WITHIN}

    /**
     * Currently this assumes start/end.time_offset is set, aligns the start to the nearest
     * (preceding) sync point, and aligns the end to the nearest sample containing the end
     * time offset.
     */
    public void get_access_points_for_range (ref AccessPoint start, ref AccessPoint end)
            throws Error {
        debug ("get_access_points_for_range: start time %llu (%0.3fs), end time %llu (%0.3fs)",
               start.time_offset, (float)start.time_offset/get_media_box ().get_header_box ().timescale,
               end.time_offset, (float)end.time_offset/get_media_box ().get_header_box ().timescale);

        var time_to_sample_box = get_sample_time_box ();

        { // Start time calculation
            start.sample = time_to_sample_box.sample_for_time (start.time_offset);
            try {
                var sync_sample_box = first_box_of_class (typeof (IsoSyncSampleBox))
                                      as IsoSyncSampleBox;
                // Adjust the start sample to the nearest sync sample
                start.sample = sync_sample_box.sync_sample_before_sample (start.sample);
            } catch (Rygel.IsoBoxError.BOX_NOT_FOUND error) {
                debug ("   no sync sample box - not aligning the start time");
            }
            start.is_at_extent = (start.sample == 1);
            debug ("   start sample for time: %u (%sat start)",
                   start.sample, (start.is_at_extent ? "" : "not "));
            // Sample-align the start time
            start.time_offset = time_to_sample_box.time_for_sample (start.sample);
            debug ("   effective start time: %llu (%0.3fs)", start.time_offset,
                   (float)start.time_offset/get_media_box ().get_header_box ().timescale);
            access_point_offsets_for_sample (ref start); // Calculate the chunk/byte offsets
        }
        { // End time calculation
            var last_sample_number = sample_size_box.last_sample_number ();
            try { // The time offset may be beyond the duration
                end.sample = time_to_sample_box.sample_for_time (end.time_offset);
            } catch (Rygel.IsoBoxError.ENTRY_NOT_FOUND error) {
                end.sample = last_sample_number + 1;
            }
            end.is_at_extent = (end.sample == last_sample_number+1);
            debug ("   end sample for time: %u (%sat end)",
                   end.sample, (end.is_at_extent ? "" : "not "));
            end.time_offset = time_to_sample_box.time_for_sample (end.sample);
            debug ("   effective end time: %llu (%0.3fs)", end.time_offset,
                   (float)end.time_offset/get_media_box ().get_header_box ().timescale);
            access_point_offsets_for_sample (ref end); // Calculate the chunk/byte offsets
        }
    }

    /**
     * Calculate the AccessPoint byte_offset, chunk, samples_into_chunk, and bytes_into_chunk
     * using the access_point sample and the SampleToChunkBox, ChunkOffsetBox, and SampleSizeBox.
     *
     * Note: This will also fence in access_point.sample if it's beyond the sample range.
     *       It will be set the the last sample referenced in the SampleToChunkBox.
     */
    void access_point_offsets_for_sample (ref AccessPoint access_point) throws Error {
        debug ("access_point_offsets_for_sample(sample %u)",access_point.sample);
        var sample_to_chunk_box = get_sample_chunk_box ();
        var chunk_offset_box = get_chunk_offset_box ();
        var sample_size_box = get_sample_size_box ();

        uint32 samples_into_chunk;
        uint32 target_sample;
        try {
            access_point.chunk = sample_to_chunk_box.chunk_for_sample (access_point.sample,
                                                                       out samples_into_chunk);
            target_sample = access_point.sample;
        } catch (Rygel.IsoBoxError.ENTRY_NOT_FOUND error) {
            // debug ("   ENTRY_NOT_FOUND for sample %u - using sample %u",
            //        access_point.sample, access_point.sample);
            target_sample = access_point.sample - 1;
            access_point.chunk = sample_to_chunk_box.chunk_for_sample (target_sample,
                                                                       out samples_into_chunk);
        }
        access_point.samples_into_chunk = samples_into_chunk;
        access_point.bytes_into_chunk = sample_size_box.sum_samples
                                            (target_sample - samples_into_chunk,
                                             samples_into_chunk);
        access_point.byte_offset = chunk_offset_box.offset_for_chunk (access_point.chunk)
                                   + access_point.bytes_into_chunk;
        debug ("   sample %u,chunk %u,samples_into_chunk %u,bytes_into_chunk %llu,byte_offset %llu",
               access_point.sample, access_point.chunk, access_point.samples_into_chunk,
               access_point.bytes_into_chunk, access_point.byte_offset);
    }

    /**
     * Return the last byte offset referenced
     */
    public uint64 last_byte_offset () throws Error {
        var sample_to_chunk_box = get_sample_chunk_box ();
        var chunk_offset_box = get_chunk_offset_box ();
        var sample_size_box = get_sample_size_box ();

        var last_chunk = chunk_offset_box.last_chunk_number ();
        var chunk_byte_offset = chunk_offset_box.offset_for_chunk (last_chunk);
        uint32 samples_in_chunk;
        var sample_for_chunk = sample_to_chunk_box.sample_for_chunk (last_chunk,
                                                                     out samples_in_chunk);
        var bytes_into_chunk = sample_size_box.sum_samples
                                            (sample_for_chunk - samples_in_chunk,
                                             samples_in_chunk);
        
        return chunk_byte_offset + bytes_into_chunk;
    }

    /**
     * Calculate the access_point sample, chunk, and bytes_into_chunk values using byte_offset.
     * This will not set the access point time value.
     *
     * If no sample contains the access_point byte_offset, this will set the access_point
     * sample/chunk/bytes_into_chunk for the next sample after the byte offset. Otherwise
     * the sample/chunk/bytes_into_chunk will be set to the sample preceding the byte offset.
     */
    void access_point_sample_for_byte_offset (ref AccessPoint access_point,
                                              Proximity sample_proximity) throws Error {
        debug ("IsoSampleTableBox.access_point_sample_for_byte_offset(access_point.byte_offset %llu, proximity %d)",
               access_point.byte_offset, sample_proximity);
        var chunk_offset_box = get_chunk_offset_box ();
        var sample_to_chunk_box = get_sample_chunk_box ();
        var sample_size_box = get_sample_size_box ();
        try {
            uint64 chunk_byte_offset;
            access_point.chunk = chunk_offset_box.chunk_for_offset
                                           (access_point.byte_offset, out chunk_byte_offset);
            access_point.bytes_into_chunk = access_point.byte_offset - chunk_byte_offset;
            debug ("   calculated preceding chunk index %u, bytes_into_chunk %llu",
                   access_point.chunk, access_point.bytes_into_chunk);
            
            uint32 samples_in_chunk;
            var sample_for_chunk = sample_to_chunk_box.sample_for_chunk (access_point.chunk,
                                                                         out samples_in_chunk);
            debug ("   sample/offset for preceding chunk (%u): %u/%llu",
                   access_point.chunk, sample_for_chunk,
                   chunk_offset_box.offset_for_chunk (access_point.chunk));
            try {
                // See if the sample is in the chunk
                var samples_into_chunk = sample_size_box.count_samples_for_bytes
                                            (access_point.chunk, samples_in_chunk,
                                             access_point.bytes_into_chunk);
                debug ("   target byte %llu is %llu bytes/%u samples into chunk %u",
                       access_point.bytes_into_chunk, access_point.bytes_into_chunk,
                       samples_into_chunk, access_point.chunk );
                access_point.sample = sample_for_chunk + samples_into_chunk;
            } catch (Rygel.IsoBoxError.ENTRY_NOT_FOUND error) {
                // The byte offset isn't in the chunk
                access_point.sample = sample_for_chunk + samples_in_chunk;
                debug ("   byte offset %llu isn't in chunk %u (next chunk/sample %u/%u is at offset %llu)",
                       access_point.byte_offset, access_point.chunk, access_point.chunk+1,
                       access_point.sample, chunk_offset_box.offset_for_chunk (access_point.chunk+1));
                switch (sample_proximity) {
                    case Proximity.BEFORE: // Use the last sample in the chunk
                        // The byte offset isn't within the chunk
                        access_point.sample--; // Just use the last sample of the preceding chunk
                        access_point.bytes_into_chunk = sample_size_box.sum_samples
                                                            (sample_for_chunk, samples_in_chunk-1);
                        debug ("   Proximity.BEFORE: using last sample in chunk %u: sample %u",
                               access_point.chunk, access_point.sample);
                        break;
                    case Proximity.AFTER: // Use the first sample of the next chunk
                        access_point.bytes_into_chunk = 0;
                        access_point.chunk++;
                        debug ("   Proximity.AFTER: using next chunk %u, sample: %u",
                               access_point.chunk, access_point.sample);
                        break;
                    case Proximity.WITHIN:
                        throw new IsoBoxError.ENTRY_NOT_FOUND ("IsoSampleTableBox.access_point_sample_for_byte_offset: byte offset %lld isn't within any chunk of %s (proximity WITHIN)"
                                                               .printf (access_point.byte_offset,
                                                                        this.to_string ()));
                    default:
                        throw new IsoBoxError.ENTRY_NOT_FOUND ("IsoSampleTableBox.access_point_sample_for_byte_offset: Invalid proximity value %d"
                                                               .printf (sample_proximity));
                }
            }
        } catch (Rygel.IsoBoxError.ENTRY_NOT_FOUND error) {
            // The offset must precede the first chunk
            access_point.chunk = 1;
            access_point.sample = 1;
            access_point.bytes_into_chunk = 0;
            debug ("   byte offset %llu precedes the first chunk - using chunk %u sample %u",
                   access_point.byte_offset, access_point.chunk-1, access_point.chunk,
                   access_point.sample);
        }
        debug ("   calculated sample %u for byte offset %llu",
               access_point.sample, access_point.byte_offset);
    }

    /**
     * Calculate the access_point chunk and bytes_into_chunk values using the sample.
     * This will not set the access point time value.
     */
    void access_point_chunk_for_sample (ref AccessPoint access_point) throws Error {
        debug ("IsoSampleTableBox.access_point_chunk_for_sample(access_point.sample %u)",
               access_point.sample);
        var sample_to_chunk_box = get_sample_chunk_box ();
        uint32 samples_into_chunk;
        access_point.chunk = sample_to_chunk_box.chunk_for_sample (access_point.sample,
                                                                   out samples_into_chunk);
        access_point.bytes_into_chunk = sample_size_box.sum_samples
                                            (access_point.sample - samples_into_chunk,
                                             samples_into_chunk);
    }

    /**
     * Get the random access point times and associated offsets
     */
    public AccessPoint[] get_random_access_points () throws Error {
        IsoSyncSampleBox sync_sample_box;
        try {
            sync_sample_box = first_box_of_class (typeof (IsoSyncSampleBox)) as IsoSyncSampleBox;
        } catch (Rygel.IsoBoxError.BOX_NOT_FOUND error) {
            sync_sample_box = null; // If SyncSampleBox is not present, all samples are sync points
        }
        // TODO: Support sample boxes without SyncSampleBox (where every sample is a sync point)

        var time_to_sample_box = get_sample_time_box ();

        AccessPoint [] access_points;
        if (sync_sample_box == null) {
            // debug ("get_random_access_points: no SyncSampleBox - using TimeToSampleBox entries");
            access_points = new AccessPoint[time_to_sample_box.get_total_samples ()];
            for (uint i=0; i<access_points.length; i++) {
                access_points[i].sample = i+1;
                access_points[i].time_offset = time_to_sample_box.time_for_sample (i+1);
                access_point_offsets_for_sample (ref access_points[i]);
                // debug ("get_random_access_points: sample %u: time %0.3f, offset %llu",
                //        i+1, access_points[i].time_offset, access_points[i].byte_offset);
            }
        } else {
            // debug ("get_random_access_points: using SyncSampleBox");
            access_points = new AccessPoint[sync_sample_box.sample_number_array.length];
            uint32 i=0;
            foreach (var sample in sync_sample_box.sample_number_array) {
                access_points[i].sample = sample;
                access_points[i].time_offset = time_to_sample_box.time_for_sample (sample);
                access_point_offsets_for_sample (ref access_points[i]);
                // debug ("get_random_access_points: sample %u: time %0.3f, offset %llu",
                //        sample, access_points[i].time_offset, access_points[i].byte_offset);
                i++;
            }
        }

        return access_points;
    }

    /**
     * This will remove all sample references that precede the given byte offset.
     *
     * The sample and/or time_offset may not be provided (and will be 0 when omitted) 
     */
    public void remove_sample_refs_before_point (ref AccessPoint new_start) throws Error {
        debug ("IsoSampleTableBox.remove_sample_refs_before_point(new_start.byte_offset %llu, .sample %u, .time_offset %llu)",
               new_start.byte_offset, new_start.sample, new_start.time_offset);
        var chunk_offset_box = get_chunk_offset_box ();
        var sample_to_chunk_box = get_sample_chunk_box ();
        var sample_size_box = get_sample_size_box ();
        IsoSyncSampleBox sample_sync_box;
        try {
            sample_sync_box = get_sample_sync_box ();
        } catch (Rygel.IsoBoxError.BOX_NOT_FOUND error) {
            sample_sync_box = null;
        }

        if (new_start.sample == 0) { // Need to look it up using the byte offset
            debug ("   no target sample provided - looking up sample for byte offset %llu",
                   new_start.byte_offset);
            // Get the sample containing the given byte or the nearest-following sample
            access_point_sample_for_byte_offset (ref new_start, Proximity.AFTER);
        } else { // Sample was provided
            access_point_chunk_for_sample (ref new_start);
            debug ("   target sample provided. chunk for sample %u: %u (sample %u, bytes into chunk %llu)",
                   new_start.sample, new_start.chunk, new_start.samples_into_chunk,
                   new_start.bytes_into_chunk);
        }

        try {
            // This may throw since the sample can be beyond the last sample
            //  (when all refs are removed)
            access_point_offsets_for_sample (ref new_start);
            debug ("   cut point for sample %u: %llu", new_start.sample, new_start.byte_offset);
        } catch (Error e) { }
        debug ("   removing samples before #%u from TimeToSampleBox",
               new_start.sample);
        var sample_time_box = get_sample_time_box ();
        sample_time_box.remove_sample_refs_before (new_start.sample);

        debug ("   removing samples before #%u from SampleSizeBox",
               new_start.sample);
        sample_size_box.remove_sample_refs_before (new_start.sample);

        debug ("   removing samples before #%u from SampleToChunkBox",
               new_start.sample);
        sample_to_chunk_box.remove_sample_refs_before (new_start.sample);

        debug ("   removing chunks before #%u from ChunkOffsetBox",
               new_start.chunk);
        chunk_offset_box.remove_chunk_refs_before (new_start.chunk);

        if (sample_sync_box != null) {
            debug ("   removing sync points before #%u from SyncSampleBox",
                   new_start.sample);
            sample_sync_box.remove_sample_refs_before (new_start.sample);
        }
        // Note: Chunk references will be updated after we know the size of the preceding boxes
        //       (e.g. MovieBox, EditListBox, etc)
        debug ("   sample %u is %llu bytes into chunk",
               new_start.sample, new_start.bytes_into_chunk);
        if (new_start.bytes_into_chunk > 0) {
            chunk_offset_box.chunk_offset_array[0] += new_start.bytes_into_chunk;
            debug ("   adjusting new first chunk offset from %llu to %llu",
                   chunk_offset_box.chunk_offset_array[0] - new_start.bytes_into_chunk,
                   chunk_offset_box.chunk_offset_array[0]);
        }
    }

    /**
     * This will remove all sample references that follow the given byte offset.
     *
     * The sample and/or time_offset may not be provided (and will be 0 when omitted) 
     */
    public void remove_sample_refs_after_point (ref AccessPoint new_end) throws Error {
        debug ("remove_sample_refs_after_point(new_end.byte_offset %llu,sample %u,time_offset %llu)",
               new_end.byte_offset, new_end.sample, new_end.time_offset);
        var chunk_offset_box = get_chunk_offset_box ();
        var sample_to_chunk_box = get_sample_chunk_box ();
        var sample_size_box = get_sample_size_box ();
        IsoSyncSampleBox sample_sync_box;
        try {
            sample_sync_box = get_sample_sync_box ();
        } catch (Rygel.IsoBoxError.BOX_NOT_FOUND error) {
            sample_sync_box = null;
        }

        if (new_end.sample == 0) { // Need to look it up using the byte offset
            debug ("   no target sample provided - looking up sample for byte offset %llu",
                   new_end.byte_offset);
            // Get the sample containing the given byte or the nearest-preceding sample
            access_point_sample_for_byte_offset (ref new_end, Proximity.BEFORE);
        } else { // Sample was provided
            access_point_chunk_for_sample (ref new_end);
            debug ("   target sample provided. chunk for sample %u: %u (%u/%llu samples/bytes into chunk)",
                   new_end.sample, new_end.chunk, new_end.samples_into_chunk,
                   new_end.bytes_into_chunk);
        }

        try {
            // This may throw since the sample can be beyond the last sample
            //  (when all refs are removed)
            access_point_offsets_for_sample (ref new_end);
            debug ("   cut point for sample %u: %llu", new_end.sample, new_end.byte_offset);
        } catch (Error e) { }
        debug ("   removing samples after #%u from TimeToSampleBox",
               new_end.sample);
        var sample_time_box = get_sample_time_box ();
        sample_time_box.remove_sample_refs_after (new_end.sample);

        debug ("   removing samples after #%u from SampleSizeBox",
               new_end.sample);
        sample_size_box.remove_sample_refs_after (new_end.sample);

        debug ("   removing samples after #%u from SampleToChunkBox",
               new_end.sample);
        sample_to_chunk_box.remove_sample_refs_after (new_end.sample);

        debug ("   removing chunks after #%u from ChunkOffsetBox",
               new_end.chunk);
        chunk_offset_box.remove_chunk_refs_after (new_end.chunk);

        if (sample_sync_box != null) {
            debug ("   removing sync points after #%u from SyncSampleBox",
                   new_end.sample);
            sample_sync_box.remove_sample_refs_after (new_end.sample);
        }
        // Note: Chunk references will be updated after we know the size of the preceding boxes
        //       (e.g. MovieBox, EditListBox, etc)
    }

    /**
     * Return true of the SampleTableBox has any valid samples
     */
    public bool has_samples () throws Error {
        var chunk_offset_box = get_chunk_offset_box ();
        var sample_to_chunk_box = get_sample_chunk_box ();
        var sample_size_box = get_sample_size_box ();
        var sample_time_box = get_sample_time_box ();

        return ( chunk_offset_box.has_samples ()
                 && sample_to_chunk_box.has_samples ()
                 && sample_size_box.has_samples ()
                 && sample_time_box.has_samples ());
    }

    public override string to_string () {
        return "IsoSampleTableBox[" + base.to_string () + "," + base.children_to_string () + "]";
    }
    
    public override void to_printer (IsoBox.LinePrinter printer, string prefix) {
        printer (prefix + "IsoSampleTableBox[" + base.to_string () + "] {");
        base.children_to_printer (printer, prefix + "  ");
        printer (prefix + "}");
    }
} // END class IsoSampleTableBox

/**
 * stts box
 *
 * The Time To Sample Box contains a compact version of a table that allows indexing from decoding
 * time to sample number. Other tables give sample sizes and pointers, from the sample number. Each
 * entry in the table gives the number of consecutive samples with the same time delta, and
 * the delta of those samples. By adding the deltas a complete time-to-sample map may be built.
 */
public class Rygel.IsoTimeToSampleBox : IsoFullBox {
    public struct SampleEntry {
        uint32 sample_count;
        uint32 sample_delta;
    }
    public SampleEntry[] sample_array;

    public IsoTimeToSampleBox (IsoContainerBox parent, uint64 creation_time,
                               uint64 modification_time, uint32 timescale, uint64 duration,
                               string language, bool force_large_header) {
        base (parent, "stts", 0, 0); // Version / flags 0
        this.sample_array = new SampleEntry[0];
    }

    public IsoTimeToSampleBox.from_stream (IsoContainerBox parent, string type_code,
                                           IsoInputStream stream, uint64 offset,
                                           uint32 size, uint64 largesize)
            throws Error {
        base.from_stream (parent, type_code, stream, offset, size, largesize);
    }

    public override uint64 parse_from_stream () throws Error {
        debug ("IsoTimeToSampleBox(%s).parse_from_stream()", this.type_code);

        var bytes_consumed = base.parse_from_stream ();
        var instream = this.source_stream;

        var entry_count = instream.read_uint32 ();
        this.sample_array = new SampleEntry[entry_count];
        for (uint32 i=0; i<entry_count; i++) {
            this.sample_array[i].sample_count = instream.read_uint32 ();
            this.sample_array[i].sample_delta = instream.read_uint32 ();
        }
        bytes_consumed += 4 + (entry_count * 8);

        if (bytes_consumed != this.size) {
            throw new IsoBoxError.PARSE_ERROR
                          ("box size mismatch (parsed %lld, box size %lld)"
                           .printf(bytes_consumed, this.size));
        }
        return this.size;
    }

    protected override void update_box_fields (uint64 payload_size = 0) throws Error {
        payload_size += 4 + (sample_array.length * 8);
        base.update_box_fields (payload_size);
    }

    public override void write_fields_to_stream (IsoOutputStream outstream) throws Error {
        base.write_fields_to_stream (outstream);
        var entry_count = this.sample_array.length;
        outstream.put_uint32 (entry_count);
        for (uint32 i=0; i<entry_count; i++) {
            outstream.put_uint32 (this.sample_array[i].sample_count);
            outstream.put_uint32 (this.sample_array[i].sample_delta);
        }
    }

    public uint32 get_total_samples () throws Error {
        // debug ("get_total_samples(%llu)", time_val);
        uint32 total_samples = 0;
        foreach (var cur_entry in this.sample_array) {
            total_samples += cur_entry.sample_count;
        }
        return total_samples;
    }

    public uint32 sample_for_time (uint64 time_val) throws Error {
        // debug ("sample_for_time(%llu)", time_val);
        uint64 base_time = 0;
        uint32 base_sample = 1;
        foreach (var cur_entry in this.sample_array) {
            uint64 entry_duration = cur_entry.sample_count * cur_entry.sample_delta;
            // debug ("   sample entry: count %u, delta %u, duration %llu",
            //        time_val, cur_entry.sample_count, cur_entry.sample_delta, entry_duration);
            // debug ("   base_time %llu, base_sample %llu, base_time+dur %llu",
            //        time_val, base_time, base_sample, base_time + entry_duration);
            if (base_time + entry_duration >= time_val) {
                // Entry covers the target time - calculate the sample number offset
                return (uint32)(((time_val-base_time) / cur_entry.sample_delta) + base_sample);
            }
            base_time += entry_duration;
            base_sample += cur_entry.sample_count;
        }
        throw new IsoBoxError.ENTRY_NOT_FOUND ("IsoTimeToSampleBox.sample_for_time: no sample for time %llu found in %s (max time %llu)"
                                               .printf (time_val, this.to_string (), base_time));
    }

    public int64 time_for_sample (uint32 sample_number) throws Error {
        uint32 base_sample = 1;
        int64 base_time = 0;
        // debug ("time_for_sample(%u)", sample_number);
        foreach (var cur_entry in this.sample_array) {
            var offset_in_entry = sample_number - base_sample;
            // debug ("time_for_sample: Entry: sample_count %u, sample_delta %u",
            //        cur_entry.sample_count, cur_entry.sample_delta);
            if (offset_in_entry <= cur_entry.sample_count) { // This entry is for our sample
                return (base_time + (offset_in_entry * cur_entry.sample_delta));
            }
            base_sample += cur_entry.sample_count;
            base_time += cur_entry.sample_count * cur_entry.sample_delta;
            // debug ("time_for_sample: base_sample %u, base_time %llu",
            //        base_sample, base_time);
        }

        throw new IsoBoxError.ENTRY_NOT_FOUND ("IsoTimeToSampleBox.time_for_sample: sample %u not found in %s (total samples %u)"
                                               .printf (sample_number, this.to_string (),
                                                        base_sample));
    }

    public uint64 total_sample_duration () throws Error {
        uint64 base_time = 0;
        foreach (var cur_entry in this.sample_array) {
            base_time += cur_entry.sample_count * cur_entry.sample_delta;
        }
        return base_time;
    }

    /**
     * Update the sample array to remove references to samples before sample_number.
     */
    public void remove_sample_refs_before (uint32 sample_number) throws Error {
        uint32 base_sample = 1;
        // debug ("remove_sample_refs_before(%u)", sample_number);
        for (int i=0; i < this.sample_array.length; i++) {
            var cur_entry = this.sample_array[i];
            var offset_in_entry = sample_number - base_sample;
            // debug ("  Entry: sample_count %u, sample_delta %u",
            //         cur_entry.sample_count, cur_entry.sample_delta);
            if (offset_in_entry < cur_entry.sample_count) { // This entry is for our sample
                var new_sample_array = this.sample_array [i : this.sample_array.length];
                var samples_remaining = cur_entry.sample_count - offset_in_entry; // never 0
                new_sample_array[0].sample_count = samples_remaining;
                this.sample_array = new_sample_array;
                return;
            }
            base_sample += cur_entry.sample_count;
            // debug ("  base_sample %u", base_sample);
        }
        debug ("  sample_number %u is beyond the last sample (%u) - removing all sample refs",
               sample_number, base_sample-1);
        this.sample_array = new SampleEntry[0];
    }

    /**
     * Update the sample array to remove references to samples after sample_number.
     */
    public void remove_sample_refs_after (uint32 sample_number) throws Error {
        if (sample_number == 0) { // Everything is removed
            this.sample_array = new SampleEntry[0];
        }
        uint32 base_sample = 1;
        // debug ("remove_sample_refs_after(%u)", sample_number);
        for (int i=0; i < this.sample_array.length; i++) {
            var cur_entry = this.sample_array[i];
            var offset_in_entry = sample_number - base_sample;
            // debug ("  Entry: sample_count %u, sample_delta %u",
            //         cur_entry.sample_count, cur_entry.sample_delta);
            if (offset_in_entry < cur_entry.sample_count) { // This entry is for our sample
                var new_sample_array = this.sample_array [0 : i+1];
                // Adjust the sample count on the last entry 
                new_sample_array[i].sample_count = offset_in_entry + 1; // never 0;
                this.sample_array = new_sample_array;
                return;
            }
            base_sample += cur_entry.sample_count;
            // debug ("  base_sample %u", base_sample);
        }
        debug ("  sample_number %u is beyond the last sample (%u) - nothing to remove",
               sample_number, base_sample-1);
    }

    public bool has_samples () {
        return (sample_array.length > 0);
    }

    public override string to_string () {
        var builder = new StringBuilder ("IsoTimeToSampleBox[");
        builder.append (base.to_string ());
        if (this.loaded) {
            builder.append_printf (",entry_count %d", this.sample_array.length);
        } else {
            builder.append (",[unloaded fields]");
        }
        builder.append_c (']');
        return builder.str;
    }

    public override void to_printer (IsoBox.LinePrinter printer, string prefix) {
        printer ("%s%s {".printf (prefix,this.to_string ()));
        for (uint32 i=0; i<sample_array.length; i++) {
            printer ("%s   entry %u: %u samples with delta %u"
                     .printf (prefix, i+1, sample_array[i].sample_count,
                              sample_array[i].sample_delta));
        }
        printer ("%s}".printf (prefix));
    }
} // END class IsoTimeToSampleBox

/**
 * stss box
 *
 * The Sync Sample Box provides a compact marking of the sync samples within the stream.
 * The table is arranged in strictly increasing order of sample number.
 */
public class Rygel.IsoSyncSampleBox : IsoFullBox {
    public uint32[] sample_number_array;

    public IsoSyncSampleBox (IsoContainerBox parent) {
        base (parent, "stss", 0, 0); // Version/flags 0
        this.sample_number_array = new uint32[0];
    }

    public IsoSyncSampleBox.from_stream (IsoContainerBox parent, string type_code,
                                           IsoInputStream stream, uint64 offset,
                                           uint32 size, uint64 largesize)
            throws Error {
        base.from_stream (parent, type_code, stream, offset, size, largesize);
    }

    public override uint64 parse_from_stream () throws Error {
        debug ("IsoSyncSampleBox(%s).parse_from_stream()", this.type_code);

        var bytes_consumed = base.parse_from_stream ();
        var instream = this.source_stream;

        var entry_count = instream.read_uint32 ();
        this.sample_number_array = new uint32[entry_count];
        for (uint32 i=0; i<entry_count; i++) {
            this.sample_number_array[i] = instream.read_uint32 ();
        }
        bytes_consumed += 4 + (entry_count * 4);

        if (bytes_consumed != this.size) {
            throw new IsoBoxError.PARSE_ERROR
                          ("box size mismatch (parsed %lld, box size %lld)"
                           .printf(bytes_consumed, this.size));
        }
        return this.size;
    }

    protected override void update_box_fields (uint64 payload_size = 0) throws Error {
        payload_size += 4 + (sample_number_array.length * 4);
        base.update_box_fields (payload_size);
    }

    public override void write_fields_to_stream (IsoOutputStream outstream) throws Error {
        base.write_fields_to_stream (outstream);
        outstream.put_uint32 (this.sample_number_array.length);
        outstream.put_uint32_array (this.sample_number_array);
    }

    public uint32 sync_sample_before_sample (uint32 sample) {
        // debug ("sync_sample_before_sample(%u)", sample);
        uint32 last_sync_sample = 1;
        for (uint32 i=0; i<sample_number_array.length; i++) {
            if (sample_number_array[i] > sample) {
                break;
            }
            last_sync_sample = sample_number_array[i];
        }
        return last_sync_sample;
    }

    public uint32 sync_sample_after_sample (uint32 sample) {
        // debug ("sync_sample_after_sample(%u)", sample);
        for (uint32 i=0; i<sample_number_array.length; i++) {
            if (sample_number_array[i] >= sample) {
                return sample_number_array[i];
            }
        }
        return sample; // There isn't a sync sample after - just use the sample passed
    }

    /**
     * Update the sample array to remove references to samples before sample_number.
     */
    public void remove_sample_refs_before (uint32 sample_number) throws Error {
        // debug ("IsoSyncSampleBox(%s).remove_sample_refs_before(%u)",
        //        this.type_code, sample_number);
        uint32 reference_offset = sample_number-1; // the given sample number becomes sample 1
        
        for (uint32 i=0; i<sample_number_array.length; i++) {
            if (this.sample_number_array[i] >= sample_number) {
                var new_sample_number_array = new uint32[sample_number_array.length-i];
                // debug ("   new sync sample length: %u", new_sample_number_array.length);
                for (uint32 j=0; i<sample_number_array.length; i++, j++) {
                    new_sample_number_array[j] = this.sample_number_array[i] - reference_offset;
                //     debug ("   entry %u added: %u",
                //            sample_number, j+1, new_sample_number_array[j]);
                }
                this.sample_number_array = new_sample_number_array;
                return;
            }
        }
        // If we got all the way through, it means all sync points were before the target sample
        this.sample_number_array = new uint32[0];
    }

    /**
     * Update the sample array to remove references to samples after sample_number.
     */
    public void remove_sample_refs_after (uint32 sample_number) throws Error {
        // debug ("IsoSyncSampleBox(%s).remove_sample_refs_before(%u)",
        //        this.type_code, sample_number);
        if (sample_number == 0) { // everything is removed
            this.sample_number_array = new uint32[0];
        }

        for (uint32 i=0; i<sample_number_array.length; i++) {
            if (this.sample_number_array[i] >= sample_number) {
                // We want to exclude the current entry
                var new_sample_number_array = this.sample_number_array[0:i];
                // debug ("   new sync sample length: %u", new_sample_number_array.length);
                this.sample_number_array = new_sample_number_array;
                return;
            }
        }
    }

    public override string to_string () {
        var builder = new StringBuilder ("IsoSyncSampleBox[");
        builder.append (base.to_string ());
        if (this.loaded) {
            builder.append_printf (",entry_count %d", this.sample_number_array.length);
        } else {
            builder.append (",[unloaded fields]");
        }
        builder.append_c (']');
        return builder.str;
    }

    public override void to_printer (IsoBox.LinePrinter printer, string prefix) {
        printer ("%s%s {".printf (prefix,this.to_string ()));
        for (uint32 i=0; i<sample_number_array.length; i++) {
            printer ("%s   entry %u: sync sample_number %u"
                     .printf (prefix, i+1, sample_number_array[i]));
        }
        printer ("%s}".printf (prefix));
    }
} // END class IsoSyncSampleBox

/**
 * stsc box
 *
 * The Sample To Chunk Box provides a mapping of samples to chunks.
 *
 * Samples within the media data are grouped into chunks. Chunks can be of different sizes,
 * and the samples within a chunk can have different sizes. This table can be used to find the
 * chunk that contains a sample, its position, and the associated sample description.
 * 
 * The table is compactly coded. Each entry gives the index of the first chunk of a run of
 * chunks with the same characteristics. By subtracting one entry here from the previous one,
 * you can compute how many chunks are in this run. You can convert this to a sample count by
 * multiplying by the appropriate samples-per-chunk.
 */
public class Rygel.IsoSampleToChunkBox : IsoFullBox {
    // A ChunkRunEntry describes a series of chunks for this track that share the same
    //  samples per chunk and description. 
    public struct ChunkRunEntry {
        uint32 first_chunk;
        uint32 samples_per_chunk;
        uint32 sample_description_index;
    }
    public ChunkRunEntry[] chunk_run_array;

    public IsoSampleToChunkBox (IsoContainerBox parent) {
        base (parent, "stsc", 0, 0); // Version/flags 0
        this.chunk_run_array = new ChunkRunEntry[0];
    }

    public IsoSampleToChunkBox.from_stream (IsoContainerBox parent, string type_code,
                                           IsoInputStream stream, uint64 offset,
                                           uint32 size, uint64 largesize)
            throws Error {
        base.from_stream (parent, type_code, stream, offset, size, largesize);
    }

    public override uint64 parse_from_stream () throws Error {
        debug ("IsoSampleToChunkBox(%s).parse_from_stream()", this.type_code);

        var bytes_consumed = base.parse_from_stream ();
        var instream = this.source_stream;

        var entry_count = instream.read_uint32 ();
        this.chunk_run_array = new ChunkRunEntry[entry_count];
        for (uint32 i=0; i<entry_count; i++) {
            this.chunk_run_array[i].first_chunk = instream.read_uint32 ();
            this.chunk_run_array[i].samples_per_chunk = instream.read_uint32 ();
            this.chunk_run_array[i].sample_description_index = instream.read_uint32 ();
        }
        bytes_consumed += 4 + (entry_count * 12);

        if (bytes_consumed != this.size) {
            throw new IsoBoxError.PARSE_ERROR
                          ("box size mismatch (parsed %lld, box size %lld)"
                           .printf(bytes_consumed, this.size));
        }
        return this.size;
    }

    protected override void update_box_fields (uint64 payload_size = 0) throws Error {
        payload_size += 4 + (chunk_run_array.length * 12);
        base.update_box_fields (payload_size);
    }

    public override void write_fields_to_stream (IsoOutputStream outstream) throws Error {
        base.write_fields_to_stream (outstream);
        var entry_count = this.chunk_run_array.length;
        outstream.put_uint32 (entry_count);
        for (uint32 i=0; i<entry_count; i++) {
            outstream.put_uint32 (this.chunk_run_array[i].first_chunk);
            outstream.put_uint32 (this.chunk_run_array[i].samples_per_chunk);
            outstream.put_uint32 (this.chunk_run_array[i].sample_description_index);
        }
    }

    public uint32 chunk_for_sample (uint32 sample_number, out uint32 samples_into_chunk)
            throws Error {
        // debug ("IsoSampleToChunkBox.chunk_for_sample(sample_number %u)",sample_number);
        uint32 base_sample = 1;
        uint32 base_chunk = 1;
        uint32 last_entry_index = this.chunk_run_array.length;
        for (uint32 i=0; i < last_entry_index; i++) {
            var cur_entry = this.chunk_run_array[i];
            uint32 chunk_run_length;
            if (i == last_entry_index - 1) {
                chunk_run_length = 1;
            } else {
                chunk_run_length = this.chunk_run_array[i+1].first_chunk - cur_entry.first_chunk;
            }
            var chunk_run_samples = chunk_run_length * cur_entry.samples_per_chunk;
            if ((base_sample + chunk_run_samples) > sample_number) { // This is our entry
                var samples_into_run = sample_number-base_sample;
                base_chunk += samples_into_run / cur_entry.samples_per_chunk;
                samples_into_chunk = samples_into_run % cur_entry.samples_per_chunk;
                // debug ("   base_chunk %u, samples_into_run %u, samples_into_chunk %u",
                //        base_chunk, samples_into_run, samples_into_chunk);
                return base_chunk;
            }
            base_chunk += chunk_run_length;
            base_sample += chunk_run_samples;
        }
        throw new IsoBoxError.ENTRY_NOT_FOUND ("IsoSampleToChunkBox.chunk_for_sample: sample index %u not found in %s (total samples %u)"
                                               .printf (sample_number, this.to_string (),
                                                        base_sample));
    }

    /**
     * Return the sample number of the first sample of the given chunk and the number of samples
     * in the given chunk in samples_in_chunk.
     */
    public uint32 sample_for_chunk (uint32 chunk_index, out uint32 samples_in_chunk) throws Error {
        // debug ("IsoSampleToChunkBox.sample_for_chunk(chunk_index %u)",chunk_index);
        uint32 base_sample = 1;
        uint32 base_chunk = 1;
        uint32 last_entry_index = this.chunk_run_array.length;
        for (uint32 i=0; i < last_entry_index; i++) {
            var cur_entry = this.chunk_run_array[i];
            uint32 chunk_run_length;
            if (i == last_entry_index - 1) {
                chunk_run_length = 1;
            } else {
                chunk_run_length = this.chunk_run_array[i+1].first_chunk - cur_entry.first_chunk;
            }
            uint32 chunk_run_samples = chunk_run_length * cur_entry.samples_per_chunk;
            // debug ("   base_chunk %u, chunk_run_length %u, base_sample %u, chunk_run_samples %u",
            //        base_chunk, chunk_run_length, base_sample, chunk_run_samples);
            if (chunk_index < cur_entry.first_chunk + chunk_run_length) {
                // This entry covers this chunk
                var chunks_into_entry = chunk_index - base_chunk;
                var samples_into_entry = chunks_into_entry * cur_entry.samples_per_chunk;
                // debug ("   chunks_into_entry %u, samples_into_entry %u, total %u",
                //        chunks_into_entry, samples_into_entry, base_sample + samples_into_entry);
                samples_in_chunk = cur_entry.samples_per_chunk;
                return base_sample + samples_into_entry;
            }
            base_chunk += chunk_run_length;
            base_sample += chunk_run_samples;
        }
        throw new IsoBoxError.ENTRY_NOT_FOUND ("IsoSampleToChunkBox.sample_for_chunk: chunk index %u not found in %s (total chunks %u)"
                                               .printf (chunk_index, this.to_string (),
                                                        base_chunk));
    }

    /**
     * Update the chunk run array to remove references to samples before sample_number.
     */
    public void remove_sample_refs_before (uint32 sample_number) throws Error {
        // debug ("IsoSampleToChunkBox.remove_samples_before(sample_number %u)",sample_number);
        // This is a nasty bit of logic. And I haven't figured out a good way to comment it
        //  without making it even more confusing. Probably providing examples of the
        //  various scenarios would help - if there was time...
        if (sample_number == 1) {
            return; // Nothing can be before sample 1
        }
        uint32 base_sample = 1;
        uint32 base_chunk = 1;
        uint32 last_entry_index = this.chunk_run_array.length;
        uint32 copy_index = 0;
        uint32 first_chunk_offset = 0;
        ChunkRunEntry [] new_chunk_run_array = null;
        for (uint32 i=0; i < last_entry_index; i++) {
            var cur_entry = this.chunk_run_array[i];
            // debug ("   Looking at entry %u: first_chunk %u, samples_per_chunk %u, sample_desc_index %u",
            //          i, cur_entry.first_chunk, cur_entry.samples_per_chunk,
            //          cur_entry.sample_description_index);
            uint32 chunk_run_length;
            if (i == last_entry_index - 1) {
                chunk_run_length = 1;
            } else {
                chunk_run_length = this.chunk_run_array[i+1].first_chunk - cur_entry.first_chunk;
            }
            var chunk_run_samples = chunk_run_length * cur_entry.samples_per_chunk;
            if (new_chunk_run_array != null) {
                new_chunk_run_array[copy_index] = cur_entry;
                new_chunk_run_array[copy_index].first_chunk -= first_chunk_offset;
                copy_index++;
            } else if (sample_number < (base_sample + chunk_run_samples)) { // This is our entry
                var samples_into_run = sample_number - base_sample;
                var rem_entry_samples = chunk_run_samples - samples_into_run; // > 0
                var rem_chunks = rem_entry_samples / cur_entry.samples_per_chunk;
                var rem_samples = rem_entry_samples % cur_entry.samples_per_chunk;
                // debug ("   base_chunk %u, samples_into_run %u, rem_chunks %u, rem_samples %u",
                //        base_chunk, samples_into_run, rem_chunks, rem_samples);
                // If the sample aligned with the start of a entry, this entry will disappear
                //  and not be replaced. But we may need to add 1 or 2 entries, dep on alignment
                var new_entry_count = (last_entry_index - i - 1)
                                      + ((rem_samples > 0) ? 1 : 0)
                                      + ((rem_chunks > 0) ? 1 : 0);
                new_chunk_run_array = new ChunkRunEntry [new_entry_count];
                first_chunk_offset = cur_entry.first_chunk + chunk_run_length - 1;
                if (rem_samples > 0) {
                    // Entry for samples remaining in the split chunk
                    new_chunk_run_array[copy_index]
                            = {1, rem_samples, cur_entry.sample_description_index};
                    // debug ("   chunk split required: first_chunk %u, samples_per_chunk %u, description %u",
                    //        new_chunk_run_array[copy_index].first_chunk,
                    //        new_chunk_run_array[copy_index].samples_per_chunk,
                    //        new_chunk_run_array[copy_index].sample_description_index);
                    copy_index++;
                    first_chunk_offset--;
                }

                if (rem_chunks > 0) {
                    // Entry for chunks left in the split entry
                    new_chunk_run_array[copy_index]
                            = {copy_index+1, /* 1 or 2 */
                               cur_entry.samples_per_chunk, cur_entry.sample_description_index};
                    // debug ("   partial chunk run added: first_chunk %u, samples_per_chunk %u, description %u",
                    //        new_chunk_run_array[copy_index].first_chunk,
                    //        new_chunk_run_array[copy_index].samples_per_chunk,
                    //        new_chunk_run_array[copy_index].sample_description_index);
                    copy_index++;
                    first_chunk_offset -= rem_chunks;
                }
                // We've dealt with cur_entry. We just need to move everything else down
                // debug ("   shifting remaining entries down %u", first_chunk_offset);
            }
            base_chunk += chunk_run_length;
            base_sample += chunk_run_samples;
        }

        if (new_chunk_run_array == null) {
            if (sample_number >= base_sample) {
                debug ("  sample_number %u is beyond the last sample (%u) - removing all sample refs",
                       sample_number, base_sample-1);
                new_chunk_run_array = new ChunkRunEntry [0];
            } else {
                throw new IsoBoxError.ENTRY_NOT_FOUND ("IsoSampleToChunkBox.remove_sample_refs_before: sample %u not found in %s (total samples %u)"
                                                       .printf (sample_number, this.to_string (),
                                                                base_sample));
            }
        }

        this.chunk_run_array = new_chunk_run_array;
    }

    /**
     * Update the chunk run array to remove references to samples after sample_number.
     */
    public void remove_sample_refs_after (uint32 sample_number) throws Error {
        // debug ("IsoSampleToChunkBox.remove_samples_after(sample_number %u)",sample_number);
        if (sample_number == 0) {
            // debug ("  sample_number %u is before the first sample - removing all sample refs",
            //        sample_number);
            this.chunk_run_array = new ChunkRunEntry [0];
            return;
        }
        uint32 base_sample = 0;
        uint32 base_chunk = 1;
        uint32 last_entry_index = this.chunk_run_array.length;
        ChunkRunEntry [] new_chunk_run_array = null;
        for (uint32 i=0; i < last_entry_index; i++) {
            var cur_entry = this.chunk_run_array[i];
            // debug ("   Looking at entry %u: first_chunk %u,samples_per_chunk %u,sample_desc_index %u",
            //        i, cur_entry.first_chunk, cur_entry.samples_per_chunk,
            //        cur_entry.sample_description_index);
            uint32 chunk_run_length;
            bool last_entry = (i == last_entry_index - 1);
            if (last_entry) {
                chunk_run_length = 1;
            } else {
                chunk_run_length = this.chunk_run_array[i+1].first_chunk - cur_entry.first_chunk;
            }
            var chunk_run_samples = chunk_run_length * cur_entry.samples_per_chunk;
            if (sample_number < (base_sample + chunk_run_samples)) { // This is our entry
                // debug ("   entry %u for sample %u: first_chunk %u,samples_per_chunk %u,sample_desc_index %u",
                //        i, sample_number, cur_entry.first_chunk, cur_entry.samples_per_chunk,
                //        cur_entry.sample_description_index);
                var samples_into_run = sample_number - base_sample;
                var chunks_into_run = samples_into_run / cur_entry.samples_per_chunk;  // >0
                var samples_into_chunk = samples_into_run % cur_entry.samples_per_chunk;
                uint32 fixup_index = (chunk_run_length == 1) ? i : i+1;
                // debug ("   base_chunk %u,samples_into_run %u,chunks_into_run %u,samples_into_chunk %u",
                //        base_chunk, samples_into_run, chunks_into_run, samples_into_chunk);
                new_chunk_run_array = this.chunk_run_array [0:fixup_index+1];
                // This will define chunks_into_run chunks with this.chunk_run_array[x].samples_per_chunk
                //  samples and 1 chunk with samples_into_chunk
                new_chunk_run_array [fixup_index].first_chunk = base_chunk + chunks_into_run;
                new_chunk_run_array [fixup_index].samples_per_chunk = samples_into_chunk;
                new_chunk_run_array [fixup_index].sample_description_index
                                          = cur_entry.sample_description_index;
                // debug ("   set entry %u: first_chunk %u,samples_per_chunk %u,sample_description_index %u",
                //        fixup_index, new_chunk_run_array [fixup_index].first_chunk,
                //        new_chunk_run_array [fixup_index].samples_per_chunk,
                //        new_chunk_run_array [fixup_index].sample_description_index);
                this.chunk_run_array = new_chunk_run_array;
                return;
            }
            base_chunk += chunk_run_length;
            base_sample += chunk_run_samples;
        }
        // debug ("  sample_number %u is after the last sample - nothing to do", sample_number+1);
    }

    public bool has_samples () {
        return (chunk_run_array.length > 0);
    }

    public override string to_string () {
        var builder = new StringBuilder ("IsoSampleToChunkBox[");
        builder.append (base.to_string ());
        if (this.loaded) {
            builder.append_printf (",entry_count %d", this.chunk_run_array.length);
        } else {
            builder.append (",[unloaded fields]");
        }
        builder.append_c (']');
        return builder.str;
    }

    public override void to_printer (IsoBox.LinePrinter printer, string prefix) {
        printer ("%s%s {".printf (prefix,this.to_string ()));
        for (uint32 i=0; i<chunk_run_array.length; i++) {
            printer ("%s   entry %u: first_chunk %u, sample_description %u, samples_per_chunk %u"
                     .printf (prefix, i+1, this.chunk_run_array[i].first_chunk,
                              this.chunk_run_array[i].sample_description_index,
                              this.chunk_run_array[i].samples_per_chunk));
        }
        printer ("%s}".printf (prefix));
    }
} // END class IsoSampleToChunkBox

/**
 * stsz box
 *
 * The Sample Size Box contains the sample count and a table giving the size in bytes of each
 * sample. This allows the media data itself to be unframed. The total number of samples in
 * the media is always indicated in the sample count.
 *
 * There are two variants of the sample size box. The first variant has a fixed size 32-bit
 * field for representing the sample sizes; it permits defining a constant size for all samples
 * in a track. The second variant permits smaller size fields, to save space when the sizes are
 * varying but small. 
 */
public class Rygel.IsoSampleSizeBox : IsoFullBox {
    public uint32 sample_size;
    public uint32 sample_count;
    public uint32[] entry_size_array;

    public IsoSampleSizeBox (IsoContainerBox parent) {
        base (parent, "stsz", 0, 0); // Version/flags 0
        this.sample_size = 0;
        this.entry_size_array = new uint32[0];
    }

    public IsoSampleSizeBox.from_stream (IsoContainerBox parent, string type_code,
                                           IsoInputStream stream, uint64 offset,
                                           uint32 size, uint64 largesize)
            throws Error {
        base.from_stream (parent, type_code, stream, offset, size, largesize);
    }

    public override uint64 parse_from_stream () throws Error {
        debug ("IsoSampleSizeBox(%s).parse_from_stream()", this.type_code);

        var bytes_consumed = base.parse_from_stream ();
        var instream = this.source_stream;

        this.sample_size = instream.read_uint32 ();
        this.sample_count = instream.read_uint32 ();
        bytes_consumed += 8;
        if (this.sample_size == 0) {
            var entry_count = this.sample_count;
            this.entry_size_array = new uint32[entry_count];
            for (uint32 i=0; i<entry_count; i++) {
                this.entry_size_array[i] = instream.read_uint32 ();
            }
            bytes_consumed += entry_count * 4;
        }

        if (bytes_consumed != this.size) {
            throw new IsoBoxError.PARSE_ERROR
                          ("box size mismatch (parsed %lld, box size %lld)"
                           .printf(bytes_consumed, this.size));
        }
        return this.size;
    }

    protected override void update_box_fields (uint64 payload_size = 0) throws Error {
        payload_size += 8;
        if (this.entry_size_array != null) {
            this.sample_size = 0;
            this.sample_count = this.entry_size_array.length;
            payload_size += this.sample_count * 4;
        }
        base.update_box_fields (payload_size);
    }

    public override void write_fields_to_stream (IsoOutputStream outstream) throws Error {
        base.write_fields_to_stream (outstream);
        outstream.put_uint32 (this.sample_size);
        outstream.put_uint32 (this.sample_count);
        if (this.entry_size_array != null) {
            assert (this.sample_size == 0);
            var entry_count = this.entry_size_array.length;
            for (uint32 i=0; i<entry_count; i++) {
                outstream.put_uint32 (this.entry_size_array[i]);
            }
        }
    }

    public uint64 sum_samples (uint32 start_sample, uint32 sample_count) throws Error {
        if (this.sample_size != 0) { // All samples are the same size
            return (sample_count * this.sample_size);
        }

        if ((start_sample + sample_count - 1) > entry_size_array.length) {
            throw new IsoBoxError.ENTRY_NOT_FOUND
                          ("IsoSampleSizeBox.sum_samples: sample range end %u is larger than the number of entries in %s"
                           .printf (start_sample + sample_count,this.to_string ()));
        }
        uint64 sum = 0;
        uint32 last_entry = start_sample+sample_count-1;
        for (uint32 i=start_sample-1; i < last_entry; i++) {
            sum += this.entry_size_array[i];
        }
        return sum;
    }

    public uint32 count_samples_for_bytes (uint32 start_sample, uint32 samples_in_chunk,
                                           uint64 byte_count)
            throws Error {
        if (this.sample_size != 0) { // All samples are the same size
            var samples_for_bytes = (uint32)(byte_count / this.sample_size);
            if ((start_sample + samples_for_bytes) > this.sample_count) {
                throw new IsoBoxError.ENTRY_NOT_FOUND
                              ("IsoSampleSizeBox.count_samples_for_bytes: could not find samples adding to %llu from sample %u to %u in %s"
                               .printf (byte_count, start_sample, start_sample+this.sample_count,
                                        this.to_string ()));
            } 
            return samples_for_bytes;
        }

        uint32 start_index = start_sample-1; // sample #s are 1-based, array is 0-based
        uint32 end_index = start_index + samples_in_chunk;
        if (end_index >= this.entry_size_array.length) {
            throw new IsoBoxError.ENTRY_NOT_FOUND
                          ("IsoSampleSizeBox.count_samples_for_bytes: start_sample %u + samples_in_chunk %u > num entries %u in %s"
                           .printf (start_sample, samples_in_chunk, this.entry_size_array.length,
                                    this.to_string ()));
        }
        for (uint32 i=start_index; i < end_index; i++) {
            var entry_size = this.entry_size_array[i];
            if (byte_count < entry_size) {
                return i-start_index;
            }
            byte_count -= entry_size;
        }
        throw new IsoBoxError.ENTRY_NOT_FOUND
                      ("IsoSampleSizeBox.count_samples_for_bytes: could not find samples adding to %llu from sample %u to %u in %s"
                       .printf (byte_count, start_sample, start_sample+samples_in_chunk-1, this.to_string ()));
    }

    /**
     * Update the sample size array to remove references to samples before sample_number.
     */
    public void remove_sample_refs_before (uint32 sample_number) throws Error {
        assert (sample_number > 0);
        if (this.sample_size != 0) { // All samples are the same size
            assert (this.entry_size_array==null);
            if (sample_number > this.sample_count) {
                this.sample_count = 0;
            } else {
                this.sample_count -= sample_number;
            }
        } else if (sample_number > this.entry_size_array.length) {
            // All samples precede sample_number
            this.entry_size_array = new uint32[0];
            this.sample_count = 0;
        } else {
            // sample_numbers are 1-based. And Vala slices are start-inclusive
            //  (and end-exclusive). e.g. chunk_offset_array[0] is "chunk 1"
            this.entry_size_array = this.entry_size_array
                                        [sample_number-1 : this.entry_size_array.length];
            this.sample_count = this.entry_size_array.length;
        }
    }

    /**
     * Update the sample size array to remove references to samples after sample_number.
     */
    public void remove_sample_refs_after (uint32 sample_number) throws Error {
        if (this.sample_size != 0) { // All samples are the same size
            assert (this.entry_size_array==null);
            this.sample_count = sample_number;
        } else if (sample_number == 0) {
            // All samples follow the sample_number
            this.entry_size_array = new uint32[0];
            this.sample_count = 0;
        } else if (sample_number <= this.entry_size_array.length) {
            // sample_numbers are 1-based. And Vala slices are start-inclusive
            //  (and end-exclusive). So this will include sample_number in the new array
            this.entry_size_array = this.entry_size_array [0:sample_number];
            this.sample_count = this.entry_size_array.length;
        }
    }

    public uint32 last_sample_number () {
        return ((this.sample_size == 0) ? this.entry_size_array.length+1 : this.sample_count);
    }

    public bool has_samples () {
        return ((this.sample_count > 0) || (entry_size_array.length > 0));
    }

    public override string to_string () {
        var builder = new StringBuilder ("IsoSampleSizeBox[");
        builder.append (base.to_string ());
        if (this.loaded) {
            builder.append_printf (",sample_size %u,sample_count %u",
                                   this.sample_size, this.sample_count);
        } else {
            builder.append (",[unloaded fields]");
        }
        builder.append_c (']');
        return builder.str;
    }

    public override void to_printer (IsoBox.LinePrinter printer, string prefix) {
        if (entry_size_array == null) {
            printer (prefix + this.to_string ());
        } else {
            printer ("%s%s {".printf (prefix,this.to_string ()));
            for (uint32 i=0; i<entry_size_array.length; i++) {
                printer ("%s   entry %u: entry_size %u".printf (prefix, i+1, entry_size_array[i]));
            }
            printer ("%s}".printf (prefix));
        }
    }
} // END class IsoSampleSizeBox

/**
 * stco/co64 box
 *
 * The Chunk Offset Box provides the index of each chunk into the containing file (under 4GB). 
 *
 * Offsets are file offsets, not the offset into any box within the file (e.g. Media Data Box).
 * This permits referring to media data in files without any box structure. It does also mean
 * that care must be taken when constructing a self-contained ISO file with its metadata
 * (Movie Box) at the front, as the size of the Movie Box will affect the chunk offsets to the
 * media data.
 *
 * Note: This version works as both a ChunkOffsetBox and ChunkLargeOffsetBox (with 64-bit offsets).
 */
public class Rygel.IsoChunkOffsetBox : IsoFullBox {
    public uint64[] chunk_offset_array = null; // In-memory model is 64-bit
    public bool use_large_offsets = false;

    public IsoChunkOffsetBox (IsoContainerBox parent, bool use_large_offsets) {
        base (parent, use_large_offsets ? "co64" : "stco",  0, 0); // Version/flags 0
        this.use_large_offsets = use_large_offsets;
        this.chunk_offset_array = new uint64[0];
    }

    public IsoChunkOffsetBox.from_stream (IsoContainerBox parent, string type_code,
                                          IsoInputStream stream, uint64 offset,
                                          uint32 size, uint64 largesize)
            throws Error {
        base.from_stream (parent, type_code, stream, offset, size, largesize);
        use_large_offsets = (this.type_code == "co64");
    }

    public override uint64 parse_from_stream () throws Error {
        debug ("IsoChunkOffsetBox(%s).parse_from_stream()", this.type_code);

        var bytes_consumed = base.parse_from_stream ();
        var instream = this.source_stream;

        var entry_count = instream.read_uint32 ();
        bytes_consumed += 4;
        this.chunk_offset_array = new uint64[entry_count];
        if (use_large_offsets) {
            instream.read_uint64_array (this.chunk_offset_array);
            bytes_consumed += entry_count * 8;
        } else {
            for (uint32 i=0; i<entry_count; i++) {
                this.chunk_offset_array[i] = instream.read_uint32 ();
            }
            bytes_consumed += entry_count * 4;
        }

        if (bytes_consumed != this.size) {
            throw new IsoBoxError.PARSE_ERROR
                          ("IsoChunkOffsetBox.parse_from_stream: box size mismatch (parsed %lld, box size %lld)"
                           .printf(bytes_consumed, this.size));
        }
        return this.size;
    }

    protected override void update_box_fields (uint64 payload_size = 0) throws Error {
        if (use_large_offsets) {
            this.type_code = "co64";
            payload_size += 4 + (chunk_offset_array.length * 8);
        } else {
            this.type_code = "stco";
            payload_size += 4 + (chunk_offset_array.length * 4);
        }
        base.update_box_fields (payload_size);
    }

    public override void write_fields_to_stream (IsoOutputStream outstream) throws Error {
        base.write_fields_to_stream (outstream);
        outstream.put_uint32 (this.chunk_offset_array.length);
        if (use_large_offsets) {
            outstream.put_uint64_array (this.chunk_offset_array);
        } else {
            for (uint32 i=0; i<this.chunk_offset_array.length; i++) {
                if (this.chunk_offset_array[i] > uint32.MAX) {
                    throw new IsoBoxError.VALUE_TOO_LARGE ("IsoChunkOffsetBox.write_fields_to_stream: offset %llu (entry %u) is too large for stco box"
                                                           .printf (this.chunk_offset_array[i], i));
                }
                outstream.put_uint32 ((uint32)this.chunk_offset_array[i]);
            }
        }
    }

    public uint32 last_chunk_number () throws Error {
        return (this.chunk_offset_array.length);
    }

    public uint64 offset_for_chunk (uint32 chunk_number) throws Error {
        if (chunk_number > this.chunk_offset_array.length) {
            throw new IsoBoxError.ENTRY_NOT_FOUND ("IsoChunkOffsetBox.offset_for_chunk: %s does not have an entry for sample %u"
                                                   .printf (this.to_string (), chunk_number));
        }
        return (this.chunk_offset_array[chunk_number-1]);
    }

    /**
     * Remove the chunk references before the given chunk_number
     */
    public void remove_chunk_refs_before (uint32 chunk_number) throws Error {
        if (chunk_number > this.chunk_offset_array.length) {
            this.chunk_offset_array = new uint64[0];
        } else {
            // Note that chunk_numbers are 1-based. And Vala slices are start-inclusive
            //  (and end-exclusive). e.g. chunk_offset_array[0] is "chunk 1"
            this.chunk_offset_array = this.chunk_offset_array
                                        [chunk_number-1 : this.chunk_offset_array.length];
        }
    }

    /**
     * Remove the chunk references after the given chunk_number
     */
    public void remove_chunk_refs_after (uint32 chunk_number) throws Error {
        if (chunk_number == 0) {
            this.chunk_offset_array = new uint64[0];
        } else if (chunk_number <= this.chunk_offset_array.length) {
            // Note that chunk_numbers are 1-based. And Vala slices are start-inclusive
            //  (and end-exclusive). So this won't remove chunk_number entry
            this.chunk_offset_array = this.chunk_offset_array [0 : chunk_number];
        }
    }

    /**
     * Adjust all chunk offset references by byte_adjustment
     */
    public void adjust_offsets (int64 byte_adjustment) throws Error {
        for (uint32 i=0; i<this.chunk_offset_array.length; i++) {
            this.chunk_offset_array[i] += byte_adjustment;
        }
    }

    /**
     * Return the chunk number that most immediately precedes the given byte offset and
     * the byte offset of the chunk in chunk_byte_offset.
     *
     * Note that the content at byte_offset may or may not be in the chunk.
     */
    public uint32 chunk_for_offset (uint64 byte_offset, out uint64 chunk_byte_offset)
            throws Error {
        uint32 i;
        if (byte_offset < chunk_offset_array[0]) {
            throw new IsoBoxError.ENTRY_NOT_FOUND
                          ("IsoChunkOffsetBox.chunk_for_offset: the first entry offset for %s is %llu"
                           .printf (this.to_string (), chunk_offset_array[0]));
        }
        for (i=1; i<chunk_offset_array.length; i++) {
            if (byte_offset < chunk_offset_array[i]) {
                break;
            }
        }
        chunk_byte_offset = chunk_offset_array[i-1];
        return i; // Entries are 1-based
    }

    public bool has_samples () {
        return (chunk_offset_array.length > 0);
    }

    public override string to_string () {
        var builder = new StringBuilder ("IsoChunkOffsetBox[");
        builder.append (base.to_string ());
        if (this.loaded) {
            builder.append_printf (",entry_count %d", this.chunk_offset_array.length);
        } else {
            builder.append (",[unloaded fields]");
        }
        builder.append_c (']');
        return builder.str;
    }

    public override void to_printer (IsoBox.LinePrinter printer, string prefix) {
        printer ("%s%s {".printf (prefix,this.to_string ()));
        for (uint32 i=0; i<this.chunk_offset_array.length; i++) {
            printer ("%s   entry %u: chunk_offset %llu"
                     .printf (prefix, i+1, this.chunk_offset_array[i]));
        }
        printer ("%s}".printf (prefix));
    }
} // END class IsoChunkOffsetBox

/**
 * edts box
 *
 * An Edit Box maps the presentation time-line to the media time-line as it is stored in the
 * file. The Edit Box is a container for the edit lists.
 *
 * The Edit Box is optional. In the absence of this box, there is an implicit one-to-one
 * mapping of these time-lines, and the presentation of a track starts at the beginning
 * of the presentation. An empty edit is used to offset the start time of a track.
 */
public class Rygel.IsoEditBox : IsoContainerBox {
    // Box cache references (MAKE SURE these are nulled out in update())
    protected IsoEditListBox edit_list_box = null;

    public IsoEditBox (IsoContainerBox parent) {
        base (parent, "edts");
    }

    public IsoEditBox.from_stream (IsoContainerBox parent, string type_code,
                                   IsoInputStream stream, uint64 offset,
                                   uint32 size, uint64 largesize)
            throws Error {
        base.from_stream (parent, type_code, stream, offset, size, largesize);
    }

    public override uint64 parse_from_stream () throws Error {
        debug ("IsoEditBox(%s).parse_from_stream()", this.type_code);
        var bytes_consumed = base.parse_from_stream (); // IsoContainer/IsoBox
        this.children = base.read_boxes (this.source_offset + bytes_consumed,
                                         this.size - bytes_consumed);
        return this.source_size; // Everything in the box was consumed
    }

    protected override void update () throws Error {
        edit_list_box = null;
        base.update ();
    }

    protected override void update_box_fields (uint64 payload_size = 0) throws Error {
        base.update_box_fields (payload_size);
    }

    /**
     * Return the IsoEditBox within the IsoTrackBox
     *
     * Note that this will cache the box reference until update() is called.
     */
    public IsoEditListBox get_edit_list_box () throws Error {
        if (this.edit_list_box == null) {
            this.edit_list_box
                    = first_box_of_class (typeof (IsoEditListBox)) as IsoEditListBox;
        }
        return this.edit_list_box;
    }

    /**
     * Create an empty IsoEditListBox within the IsoEditBox, replacing any exiting
     * EditListBox.
     *
     * Note that this will cache the box reference until update() is called.
     */
    public IsoEditListBox create_edit_list_box (bool use_large_times=false) throws Error {
        remove_boxes_by_class (typeof (IsoEditListBox));
        this.edit_list_box = new IsoEditListBox (this, use_large_times);
        this.children.insert (0, this.edit_list_box);
        return this.edit_list_box;
    }

    public override void write_fields_to_stream (IsoOutputStream outstream) throws Error {
        base.write_fields_to_stream (outstream);
        foreach (var box in this.children) {
            box.write_to_stream (outstream);
        }
    }

    public override string to_string () {
        return "IsoEditBox[" + base.to_string () + "," + base.children_to_string () + "]";
    }
    
    public override void to_printer (IsoBox.LinePrinter printer, string prefix) {
        printer (prefix + "IsoEditBox[" + base.to_string () + "] {");
        base.children_to_printer (printer, prefix + "  ");
        printer (prefix + "}");
    }
} // END class IsoEditBox

/**
 * elst box
 *
 * The Edit List Box provides an explicit timeline map. Each entry defines part of the
 * track time-line: by mapping part of the media time-line, or by indicating ‘empty’ time,
 * or by defining a ‘dwell’, where a single time-point in the media is held for a period.
 *
 * 
 */
public class Rygel.IsoEditListBox : IsoFullBox {
    // Box cache references (MAKE SURE these are nulled out in update())
    protected IsoMovieHeaderBox movie_header_box = null;
    protected IsoTrackBox track_box = null;
    protected IsoMediaHeaderBox media_header_box = null;

    public bool use_large_times;
    public struct EditEntry {
        uint64 segment_duration;
        int64 media_time;
        int16 media_rate_integer;
        int16 media_rate_fraction;
    }
    public EditEntry[] edit_array;

    public IsoEditListBox (IsoEditBox parent, bool use_large_times) {
        base (parent, "elst", use_large_times ? 1 : 0, 0);
        this.use_large_times = use_large_times;
        this.edit_array = new EditEntry[0];
    }

    public IsoEditListBox.from_stream (IsoContainerBox parent, string type_code,
                                           IsoInputStream stream, uint64 offset,
                                           uint32 size, uint64 largesize)
            throws Error {
        base.from_stream (parent, type_code, stream, offset, size, largesize);
    }

    public override uint64 parse_from_stream () throws Error {
        debug ("IsoEditListBox(%s).parse_from_stream()", this.type_code);

        var bytes_consumed = base.parse_from_stream ();
        var instream = this.source_stream;

        var entry_count = instream.read_uint32 ();
        this.edit_array = new EditEntry[entry_count];
        bytes_consumed += 4;

        switch (this.version) {
            case 0:
                for (uint32 i=0; i<entry_count; i++) {
                    this.edit_array[i].segment_duration = instream.read_uint32 ();
                    this.edit_array[i].media_time = instream.read_int32 ();
                    this.edit_array[i].media_rate_integer = instream.read_int16 ();
                    this.edit_array[i].media_rate_fraction = instream.read_int16 ();
                }
                bytes_consumed += entry_count * 12;
                this.use_large_times = false;
            break;
            case 1:
                for (uint32 i=0; i<entry_count; i++) {
                    this.edit_array[i].segment_duration = instream.read_uint64 ();
                    this.edit_array[i].media_time = instream.read_int64 ();
                    this.edit_array[i].media_rate_integer = instream.read_int16 ();
                    this.edit_array[i].media_rate_fraction = instream.read_int16 ();
                }
                bytes_consumed += entry_count * 20;
                this.use_large_times = true;
            break;
            default:
                throw new IsoBoxError.UNSUPPORTED_VERSION
                              ("moov box version unsupported: " + this.version.to_string ());
        }

        if (bytes_consumed != this.size) {
            throw new IsoBoxError.PARSE_ERROR
                          ("box size mismatch (parsed %lld, box size %lld)"
                           .printf(bytes_consumed, this.size));
        }
        return this.size;
    }

    protected override void update () throws Error {
        this.movie_header_box = null;
        this.track_box = null;
        this.media_header_box = null;
        base.update ();
    }

    protected override void update_box_fields (uint64 payload_size = 0) throws Error {
        if (this.use_large_times) {
            this.version = 1;
            payload_size += 4 + (edit_array.length * 20);
        } else {
            this.version = 0;
            payload_size += 4 + (edit_array.length * 12);
        }
        base.update_box_fields (payload_size);
    }

    /**
     * Return the IsoTrackBox containing this IsoEditListBox
     *
     * Note that this will cache the box reference until update() is called.
     */
    public IsoTrackBox get_track_box () throws Error {
        if (this.track_box == null) {
            this.track_box = get_ancestor_by_level (2, typeof (IsoTrackBox)) as IsoTrackBox;
        }
        return this.track_box;
    }

    /**
     * Return the IsoMovieHeaderBox for the the IsoMovieBox containing this IsoEditListBox
     *
     * Note that this will cache the box reference until update() is called.
     */
    public IsoMovieHeaderBox get_movie_header_box () throws Error {
        if (this.movie_header_box == null) {
            this.movie_header_box = this.get_track_box ().get_movie_box ().get_header_box ();
        }
        return this.movie_header_box;
    }

    /**
     * Return the IsoMediaHeaderBox for the the IsoTrackBox containing this IsoEditListBox
     *
     * Note that this will cache the box reference until update() is called.
     */
    public IsoMediaHeaderBox get_media_header_box () throws Error {
        if (this.media_header_box == null) {
            this.media_header_box = this.get_track_box ().get_media_box ().get_header_box ();
        }
        return this.media_header_box;
    }

    /**
     * Sets a EditListBox entry, adjusting the media_time for the MovieHeaderBox timescale and
     * adjusting the duration value for the MediaHeaderBox timescale. 
     */
    public void set_edit_list_entry (uint32 index,
                                     uint64 duration, uint32 duration_timescale, 
                                     int64 media_time, uint32 media_timescale,
                                     int16 rate_integer, int16 rate_fraction) throws Error {
        var movie_timescale = get_movie_header_box ().timescale;
        var track_timescale = get_media_header_box ().timescale;
        if (duration_timescale == movie_timescale) {
            this.edit_array[index].segment_duration = duration; 
        } else if (duration < uint32.MAX) { // Can do integer math without overflow
            this.edit_array[index].segment_duration
                           = (duration * movie_timescale) / duration_timescale; 
        } else {
            this.edit_array[index].segment_duration
                           = (uint64)(duration * ((float)movie_timescale / duration_timescale)); 
        }
        if (media_time == -1) {
            this.edit_array[index].media_time = -1;
        } else if (media_timescale == track_timescale) {
            this.edit_array[index].media_time = media_time;
        } else if (media_time < uint32.MAX) { // Can do integer math without overflow
            this.edit_array[index].media_time
                           = (media_time * track_timescale) / media_timescale; 
        } else {
            this.edit_array[index].media_time
                           = (int64)(duration * ((float)track_timescale / media_timescale)); 
        }
        this.edit_array[index].media_rate_integer = rate_integer;
        this.edit_array[index].media_rate_fraction = rate_fraction;
    }

    public string string_for_entry (uint32 index) throws Error {
        var movie_header_box = this.get_movie_header_box ();
        var media_header_box = this.get_media_header_box ();
        var duration = this.edit_array[index].segment_duration;
        var media_time = this.edit_array[index].media_time;
        return ("segment_dur %llu (%0.2fs), media_time %lld (%0.2fs), rate %u/%u"
                     .printf (duration, (float)duration/movie_header_box.timescale,
                              media_time, (float)media_time/media_header_box.timescale,
                              this.edit_array[index].media_rate_integer,
                              this.edit_array[index].media_rate_fraction));
    }

    public override void write_fields_to_stream (IsoOutputStream outstream) throws Error {
        base.write_fields_to_stream (outstream);
        var entry_count = this.edit_array.length;
        outstream.put_uint32 (entry_count);
        if (this.use_large_times) {
            assert (this.version == 1);
            for (uint32 i=0; i<entry_count; i++) {
                outstream.put_uint64 (this.edit_array[i].segment_duration);
                outstream.put_int64 (this.edit_array[i].media_time);
                outstream.put_int16 (this.edit_array[i].media_rate_integer);
                outstream.put_int16 (this.edit_array[i].media_rate_fraction);
            }
        } else {
            assert (this.version == 0);
            for (uint32 i=0; i<entry_count; i++) {
                outstream.put_uint32 ((uint32) this.edit_array[i].segment_duration);
                outstream.put_int32 ((int32) this.edit_array[i].media_time);
                outstream.put_int16 (this.edit_array[i].media_rate_integer);
                outstream.put_int16 (this.edit_array[i].media_rate_fraction);
            }
        }
    }

    public override string to_string () {
        var builder = new StringBuilder ("IsoEditListBox[");
        builder.append (base.to_string ());
        if (this.loaded) {
            builder.append_printf (",entry_count %d", this.edit_array.length);
        } else {
            builder.append (",[unloaded fields]");
        }
        builder.append_c (']');
        return builder.str;
    }

    public override void to_printer (IsoBox.LinePrinter printer, string prefix) {
        printer ("%s%s {".printf (prefix,this.to_string ()));
        for (uint32 i=0; i<edit_array.length; i++) {
            try {
                printer ("%s   Entry %u: %s".printf(prefix,i,this.string_for_entry (i)));
            } catch (Error e) {
                printer ("%s   Entry %u: Error: %s".printf(prefix,i,e.message));
            }
        }
        printer ("%s}".printf (prefix));
    }
} // END class IsoEditListBox

/**
 * dinf box
 *
 * The Data Information Box contains objects that declare the location of the media
 * information in a track.
 */
public class Rygel.IsoDataInformationBox : IsoContainerBox {
    public IsoDataInformationBox (IsoContainerBox parent) {
        base (parent, "dinf");
    }

    public IsoDataInformationBox.from_stream (IsoContainerBox parent, string type_code,
                                              IsoInputStream stream, uint64 offset,
                                              uint32 size, uint64 largesize)
            throws Error {
        base.from_stream (parent, type_code, stream, offset, size, largesize);
    }

    public override uint64 parse_from_stream () throws Error {
        debug ("IsoDataInformationBox(%s).parse_from_stream()", this.type_code);
        var bytes_consumed = base.parse_from_stream (); // IsoContainer/IsoBox
        this.children = base.read_boxes (this.source_offset + bytes_consumed,
                                         this.size - bytes_consumed);
        return this.source_size; // Everything in the box was consumed
    }

    protected override void update_box_fields (uint64 payload_size = 0) throws Error {
        base.update_box_fields (payload_size);
    }

    public override void write_fields_to_stream (IsoOutputStream outstream) throws Error {
        base.write_fields_to_stream (outstream);
        foreach (var box in this.children) {
            box.write_to_stream (outstream);
        }
    }

    public override string to_string () {
        return "IsoDataInformationBox[" + base.to_string () + "," + base.children_to_string () + "]";
    }
    
    public override void to_printer (IsoBox.LinePrinter printer, string prefix) {
        printer (prefix + "IsoDataInformationBox[" + base.to_string () + "] {");
        base.children_to_printer (printer, prefix + "  ");
        printer (prefix + "}");
    }
} // END class IsoEditBox

// For testing
public static int main (string[] args) {
    int MICROS_PER_SEC = 1000000;
	try {
        bool trim_file = false;
        bool with_empty_edit = false;
        bool print_infile = false;
        uint64 print_infile_levels = 0;
        bool print_outfile = false;
        bool print_access_points = false;
        bool print_movie_duration = false;
        bool print_track_durations = false;
        string adhoc_test_name = null;
        int64 time_range_start_us = 0, time_range_end_us = 0;
        File in_file = null;
        File out_file = null;
        bool buf_out_stream_test = false;
        uint64 buf_out_stream_buf_size = 0;

        try {
            for (uint i=1; i<args.length; i++) {
                var option = args[i];
                switch (option) {
                    case "-infile":
                        if (in_file != null) {
                            throw new OptionError.BAD_VALUE ("Only one %s option may be specified",
                                                             option);
                        }
                        if (i+1 == args.length) {
                            throw new OptionError.BAD_VALUE (option + " requires a parameter");
                        }
                        in_file = File.new_for_path (args[++i]);
                        break;
                    case "-outfile":
                        if (out_file != null) {
                            throw new OptionError.BAD_VALUE ("Only one %s option may be specified",
                                                             option);
                        }
                        if (i+1 == args.length) {
                            throw new OptionError.BAD_VALUE (option + " requires a parameter");
                        }
                        out_file = File.new_for_path (args[++i]);
                        break;
                    case "-bufoutstream":
                        if (buf_out_stream_test) {
                            throw new OptionError.BAD_VALUE ("Only one %s option may be specified",
                                                             option);
                        }
                        if ((i+1 < args.length)
                             && uint64.try_parse (args[i+1], out buf_out_stream_buf_size)) {
                            i++;
                        } else { // Use a default buffer size
                            buf_out_stream_buf_size = 1572864;
                        }
                        buf_out_stream_test = true;
                        break;
                    case "-timerange":
                        if (trim_file) {
                            throw new OptionError.BAD_VALUE ("Only one %s option may be specified",
                                                             option);
                        }
                        if (i+1 == args.length) {
                            throw new OptionError.BAD_VALUE (option + " requires a parameter");
                        }
                        var range_param = args[++i];
                        if (range_param[0] == '^') {
                            with_empty_edit = true;
                            range_param = range_param.substring (1);
                        } else {
                            with_empty_edit = false;
                        }
                        var range_elems = range_param.split ("-");
                        if (range_elems.length != 2) {
                            throw new OptionError.BAD_VALUE ("Bad range value: " + range_param);
                        }
                        double time_val;
                        if (!double.try_parse (range_elems[0], out time_val)) {
                            throw new OptionError.BAD_VALUE ("Bad range start: " + range_elems[0]);
                        }
                        time_range_start_us = (int64)(time_val * MICROS_PER_SEC);
                        if (!double.try_parse (range_elems[1], out time_val)) {
                            throw new OptionError.BAD_VALUE ("Bad range end: " + range_elems[1]);
                        }
                        time_range_end_us = (int64)(time_val * MICROS_PER_SEC);
                        trim_file = true;
                        break;
                    case "-print":
                        if (i+1 == args.length) {
                            throw new OptionError.BAD_VALUE (option + " requires a parameter");
                        }
                        var print_param = args[++i];
                        switch (print_param) {
                            case "infile":
                                print_infile = true;
                                if ((i+1 < args.length)
                                     && uint64.try_parse (args[i+1], out print_infile_levels)) {
                                    i++;
                                } else { // Default to loading/printing all levels
                                    print_infile_levels = 0;
                                }
                                break;
                            case "outfile":
                                print_outfile = true;
                                break;
                            case "access-points":
                                print_access_points = true;
                                break;
                            case "movie-duration":
                                print_movie_duration = true;
                                break;
                            case "track-durations":
                                print_track_durations = true;
                                break;
                            default:
                                throw new OptionError.BAD_VALUE ("bad print parameter: " + print_param);
                        }
                        break;
                    case "-adhoc":
                        if (i+1 == args.length) {
                            throw new OptionError.BAD_VALUE (option + " requires a parameter");
                        }
                        if (adhoc_test_name != null) {
                            throw new OptionError.BAD_VALUE ("Only one %s option may be specified",
                                                             option);
                        }
                        adhoc_test_name = args[++i];
                        break;
                    default:
                        throw new OptionError.UNKNOWN_OPTION ("Unknown option: " + option);
                }
            }

            if (in_file == null) {
                throw new OptionError.BAD_VALUE ("Input file is required (use -infile)");
            }
        } catch (Error e) {
            stderr.printf ("Error: %s\n\n", e.message);
            stderr.printf ("Usage: %s -infile <filename>\n", args[0]);
            stderr.printf ("\t[-timerange [^]x-y]: Reduce the samples in the MP4 to those falling between time range x-y (decimal seconds)\n");
            stderr.printf ("\t                     (The caret (^) will cause an empty edit to be inserted into the generated stream)\n");
            stderr.printf ("\t[-print (infile [levels]|outfile|access-points|movie-duration|track-duration)]: Print various details to the standard output\n");
            stderr.printf ("\t[-outfile <filename>]: Write the resulting MP4 to the given filename\n");
            stderr.printf ("\t[-bufoutstream [buffer_size]]: Test running the resulting MP4 through the BufferGeneratingOutputStream\n");
            return 1;
        }

        stdout.printf ("\nINPUT FILE: %s\n", in_file.get_path ());
        stdout.flush ();

        var file_container_box = new Rygel.IsoFileContainerBox (in_file);

        if (print_infile) {
            uint levels = (uint)print_infile_levels;
            // Fully load/parse the input file (0 indicates full depth)
            file_container_box.load_children (levels);
            stdout.printf ("\nPARSED INPUT FILE (%s levels):\n",
                           ((levels == 0) ? "all" : levels.to_string ()));
            file_container_box.to_printer ( (l) => {stdout.puts (l); stdout.putc ('\n');}, "  ");
            stdout.flush ();
        }

        // debug ("updating box...");
        // file_container_box.update ();

        if (print_access_points) {
            //
            // Enumerating track sync points
            //
            // Fully load/parse the input file (0 indicates full depth)
            file_container_box.load_children (0);
            var movie_box = file_container_box.get_movie_box ();
            var video_track = movie_box.get_first_track_of_type (Rygel.IsoMediaBox.MediaType.VIDEO);
            var timescale = video_track.get_media_timescale ();
            var video_track_id = video_track.get_header_box ().track_id;
            stdout.printf ("\nRANDOM ACCESS POINTS FOR TRACK %u {\n", video_track_id);

            var sample_table_box = video_track.get_sample_table_box ();
            var sync_times = sample_table_box.get_random_access_points ();
            foreach (var sync_point in sync_times) {
                stdout.printf ("  time val %9llu:%9.2f seconds, sample %7u, byte offset %12llu\n",
                               sync_point.time_offset, sync_point.time_offset/(float)timescale,
                               sync_point.sample, sync_point.byte_offset);
            }
            stdout.printf ("}\n");
            stdout.flush ();
        }

        if (adhoc_test_name != null) {
            stdout.printf ("\nRUNNING ADHOC TEST %s {\n", adhoc_test_name);
            
            switch (adhoc_test_name) {
                case "after":
                    break;
                default:
                    stderr.printf ("Unknown adhoc test: %s\n\n", adhoc_test_name);
                    return 2;
            }
            
            stdout.printf ("}\n");
            stdout.flush ();
        }

        if (trim_file) {
            // Fully load/parse the input file (0 indicates full depth)
            file_container_box.load_children (0);
            //
            // Trim the MP4 to the designated time range
            //
            stdout.printf  ("\nTRIMMING INPUT FILE: (%s empty edit)\n",
                            (with_empty_edit ? "with" : "no"));
            stdout.printf  ("  Requested time range: %0.3fs-%0.3fs\n", (float)time_range_start_us/MICROS_PER_SEC,
                                                             (float)time_range_end_us/MICROS_PER_SEC);
            Rygel.IsoSampleTableBox.AccessPoint start_point, end_point;
            file_container_box.trim_to_time_range (ref time_range_start_us, ref time_range_end_us,
                                                   out start_point, out end_point, with_empty_edit);
            stdout.printf  ("  Effective time range: %0.3fs-%0.3fs\n", (float)time_range_start_us/MICROS_PER_SEC,
                                                           (float)time_range_end_us/MICROS_PER_SEC);
            stdout.printf  ("  Effective byte range: %llu-%llu (0x%llx-0x%llx) (%llu bytes)\n",
                     start_point.byte_offset, end_point.byte_offset,
                     start_point.byte_offset, end_point.byte_offset,
                     end_point.byte_offset-start_point.byte_offset);
            stdout.printf  ("  Generated mp4 is %llu bytes\n", file_container_box.size);
        }

        if (print_movie_duration) {
            file_container_box.load_children (3); // file_container->MovieBox->MovieHeaderBox
            var movie_box = file_container_box.get_movie_box ();
            stdout.printf ("\nMOVIE DURATION: %0.3f seconds\n",
                           movie_box.get_header_box ().get_duration_seconds ());
        }

        if (print_track_durations) {
            stdout.printf ("\nTRACK DURATIONS {\n");
            file_container_box.load_children (5); // file_container->MovieBox->TrackBox->TrackHeaderBox
            var movie_box = file_container_box.get_movie_box ();
            var track_list = movie_box.get_tracks ();
            for (var track_it = track_list.iterator (); track_it.next ();) {
                var track = track_it.get ();
                var track_header = track.get_header_box ();
                var media_header_box = track.get_media_box ().get_header_box ();
                stdout.printf ("  track %u: movie duration %0.2f seconds, media duration %0.2f seconds\n",
                               track_header.track_id, track_header.get_duration_seconds (),
                               media_header_box.get_duration_seconds ());
            }
            stdout.printf ("}\n");
        }

        if (print_outfile) {
            stdout.printf ("\nPARSED OUTPUT CONTAINER:\n");
            file_container_box.to_printer ( (l) => {stdout.puts (l); stdout.putc ('\n');}, "  ");
            stdout.flush ();
        }

        if (out_file != null) {
            //
            // Write new mp4
            //
            stdout.printf ("\nWRITING TO OUTPUT FILE: %s\n", out_file.get_path ());
            if (out_file.query_exists ()) {
                out_file.delete ();
            }
            var out_stream = new Rygel.IsoOutputStream (out_file.create (
                                                        FileCreateFlags.REPLACE_DESTINATION ) );
            file_container_box.write_to_stream (out_stream);
            out_stream.close ();
            FileInfo out_file_info = out_file.query_info (GLib.FileAttribute.STANDARD_SIZE, 0);
            stdout.printf ("  Wrote %llu bytes to file.\n", out_file_info.get_size ());
        }

        if (buf_out_stream_test) {
            //
            // Test writing to BufferGeneratingOutputStream
            //
            uint64 byte_count = 0;
            uint32 buffer_size = (uint32)buf_out_stream_buf_size;
            stdout.printf ("  Using buffer size %u (0x%x)\n", buffer_size, buffer_size);
            var my_buf_gen_stream = new BufferGeneratingOutputStream (buffer_size,
                                                                      (bytes, last_buffer) =>
                {
                    if (bytes != null) {
                        var buffer = bytes.get_data ();
                        stdout.printf ("    Received %u bytes (%02x %02x %02x %02x %02x %02x) - offset %llu (0x%llx)\n",
                                       buffer.length, buffer[0], buffer[1], buffer[2],
                                       buffer[3], buffer[4], buffer[5], byte_count, byte_count);
                        byte_count += bytes.length;
                    }
                    if (last_buffer) {
                        stdout.printf ("  Last buffer received. Total bytes received: %llu\n",
                                       byte_count);
                    }
                }, true /* paused */ );
            var gen_thread = new Thread<void*> ( "mp4 time-seek generator", () => {
                stderr.printf ("  Generator started\n");
                Rygel.IsoOutputStream out_stream;
                try {
                    stderr.printf ("  Generator writing...\n");
                    out_stream = new Rygel.IsoOutputStream (my_buf_gen_stream);
                    file_container_box.write_to_stream (out_stream);
                    stderr.printf ("  Generator done writing.\n");
                } catch (Error err) {
                    error ("Error opening/writing to socket: %s", err.message);
                }
                if (out_stream != null) {
                    try {
                        out_stream.close ();
                    } catch (Error err) {
                        error ("Error closing stream: %s", err.message);
                    }
                }
                stderr.printf ("  Generator done\n");
                return null;
            } );
            Thread.usleep (1000000);
            stdout.printf ("\nStarting BufferGeneratingOutputStream\n");
            my_buf_gen_stream.resume ();
            Thread.usleep (5000);
            my_buf_gen_stream.pause ();
            stdout.printf (" Paused BufferGeneratingOutputStream\n");
            Thread.usleep (500000);
            stdout.printf (" Resuming BufferGeneratingOutputStream\n");
            my_buf_gen_stream.resume ();
            Thread.usleep (3000);
            my_buf_gen_stream.pause ();
            stdout.printf (" Paused BufferGeneratingOutputStream\n");
            Thread.usleep (700000);
            stdout.printf (" Resuming BufferGeneratingOutputStream\n");
            my_buf_gen_stream.resume ();
            gen_thread.join ();
            stdout.printf ("}\nCompleted mp4 time-seek generation (%llu bytes)\n", byte_count);
        }

        // new MainLoop ().run ();
    } catch (Error err) {
        error ("Error: %s", err.message);
    }
    return 0;
}


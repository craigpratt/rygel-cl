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
    NOT_LOADED,
    NOT_SUPPORTED
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
        // debug ("IsoInputStream: seek_to_offset: Seeking to " + offset.to_string ());
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

/**
 * The IsoBox is the top-level class for all ISO/MP4 Box classes defined here
 *
 * An IsoBox may or may not have a parent.
 *
 * The semantics for modifying box created from a stream:
 *
 *   1) An IsoBox is created via load_children on the box's IsoContainerBox
 *      (e.g. IsoFileContainerBox)
 *   2) The box's fields are loaded from the stream (either recursively via load_children()
 *      or explicitly via load()s)
 *   3) Modifications are performed on the box's fields/collections
 *   4) update() is called when modifications are complete to propagate field dependencies.
 *      (e.g. the box size, version, upstream container sizes, etc)
 *   5) The box is reserialized to an output stream via write_to_stream() (usually by the
 *      box's parent IsoContainerBox)
 * 
 * The semantics for creating a box and inserting it into a representation:
 *
 *   1) An IsoBox is created using a field-initializing constructor, modified as desired,
 *      and given a parent
 *   2) update() is called when modifications are complete to propagate field dependencies.
 *      (e.g. the box size, version, upstream container sizes, etc)
 *   5) The box is reserialized to an output stream via write_to_stream() (usually by the
 *      box's parent IsoContainerBox)
 */
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
            // debug ("IsoBox(%s): parse: parsed %s", this.type_code, this.to_string ());
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
        // debug ("IsoBox(%s).parse_from_stream()", this.type_code);
        uint64 header_size = ((this.source_size == 1) ? 16 : 8); // 32-bit or 64-bit size
        // No-op - all fields are passed to from_stream() constructor - and we skipped past the
        //  header above
        uint64 seek_pos = this.source_offset + header_size;
        this.source_stream.seek_to_offset (seek_pos);
        return header_size;
    }

    /**
     * Check to see if the box is loaded and throw IsoBoxError.NOT_LOADED if not,
     * with the corresponding context and parameter strings added to the message
     */
    public void check_loaded (string context, string ? param=null) throws IsoBoxError {
        if (!this.loaded) {
            throw new IsoBoxError.NOT_LOADED
                          ("%s(%s): fields aren't loaded for %s"
                           .printf (context, (param ?? ""), this.to_string ()));
        }
    }

    /**
     * Tell the box (and parent boxes) to update themselves to accommodate field changes
     * to the box. e.g. To update the size, version, or flags fields to reflect the field
     * changes.
     */
    public virtual void update () throws IsoBoxError {
        // debug ("IsoBox(%s): update()", this.type_code);
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
    protected virtual void update_box_fields (uint64 payload_size = 0) throws IsoBoxError {
        if ((payload_size+8 > uint32.MAX) || this.force_large_size) {
            this.size = payload_size + 16; // Need to account for largesize field
        } else {
            this.size = payload_size + 8;
        }
        // debug ("IsoBox(%s): update_box_fields(): size %llu", this.type_code, this.size);
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
            // debug ("write_to_stream(%s): Writing from source stream: %s",
            //        this.type_code, this.to_string ());
            this.write_box_from_source (outstream);
        } else {
            // debug ("write_to_stream(%s): Writing from fields: %s",
            //        this.type_code, this.to_string ());
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
        var copy_buf = new uint8 [1024*8]; // 8K
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
     * Get the root container (the box's ancestor that doesn't have a parent)
     */
    public IsoContainerBox get_root_container (uint max_levels = -1) throws IsoBoxError {
        IsoBox cur_box = this;
        uint level = max_levels;
        while (true) {
            if ((cur_box.parent_box == null)
                || (cur_box.parent_box == cur_box)) {
                if (!(cur_box is IsoContainerBox)) {
                    throw new IsoBoxError.BOX_NOT_FOUND
                                          ("IsoBox.get_root_container(): root of %s is not a IsoContainerBox: %s",
                                           this.to_string (), cur_box.to_string ());
                }
                return cur_box as IsoContainerBox;
            }
            if (level > 0) {
                level--;
                if (level == 0) {
                    throw new IsoBoxError.BOX_NOT_FOUND
                                          ("IsoBox.get_root_container(): no root found for %s within %u levels",
                                           cur_box.to_string(), max_levels);
                }
            }
            cur_box = cur_box.parent_box;
        }
    }

    /**
     * Get a box's nth-level ancestor. The ancestor will be checked against the
     * expected_box_class and INVALID_BOX_TYPE will be thrown if there's a mismatch.
     */
    public IsoBox get_ancestor_by_level (uint level, Type expected_box_class)
            throws IsoBoxError {
        IsoBox cur_box = this;
        for (; level>0; level--) {
            if (cur_box.parent_box == null) {
                throw new IsoBoxError.BOX_NOT_FOUND
                                      (cur_box.to_string() + " does not have a parent");
            }
            cur_box = cur_box.parent_box;
        }
        if (!cur_box.get_type ().is_a (expected_box_class)) {
            throw new IsoBoxError.INVALID_BOX_TYPE
                                  (cur_box.to_string() + " is not the expected type "
                                   + expected_box_class.name ());
        }

        return cur_box;
    }

    /**
     * Get a box's parent and check it against the expected_parent_class.
     * 
     * IsoBoxError.INVALID_BOX_TYPE will be thrown if the parent isn't of the expected type.
     * IsoBoxError.BOX_NOT_FOUND will be thrown if the parent is null or the same value
     * as the box itself.
     */
    public IsoBox get_parent_box (Type expected_parent_class) throws IsoBoxError {
        if ((this.parent_box == null) || (this.parent_box == this)) {
            throw new IsoBoxError.BOX_NOT_FOUND
                                  (this.to_string() + " does not have a parent");
        }
        if (!this.parent_box.get_type ().is_a (expected_parent_class)) {
            throw new IsoBoxError.INVALID_BOX_TYPE
                                  ("parent of %s is not of the expected type %s (found %s)"
                                   .printf (this.to_string (),
                                            expected_parent_class.name (),
                                            this.parent_box.to_string ()));
        }
        return this.parent_box;
    }

    /**
     * Walk the box's ancestor's until a box of type box_class is found.
     *
     * If no box of box_class is found, BOX_NOT_FOUND is thrown.
     */
    public IsoBox get_ancestor_by_class (Type box_class) throws IsoBoxError {
        IsoBox cur_box = this.parent_box;
        while (cur_box != null) {
            if (cur_box.get_type ().is_a (box_class)) {
                return cur_box;
            }
            cur_box = cur_box.parent_box;
        }
        throw new IsoBoxError.BOX_NOT_FOUND
                              (this.to_string() + " does not have an ancestor of type "
                              + box_class.name ());
    }

    /**
     * Walk the box's ancestor's until a box with 4-letter type_code is found.
     *
     * If no box of box_class is found, BOX_NOT_FOUND is thrown.
     */
    public IsoBox get_ancestor_by_type_code (string type_code) throws IsoBoxError {
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
     * Return true if other_box precedes this box in the box's parent container
     *
     * Throws IsoBoxError.BOX_NOT_FOUND if other_box is not in the same container as this box
     */
    public bool precedes (IsoBox other_box) throws IsoBoxError {
        var parent_container = get_parent_box (typeof (IsoContainerBox)) as IsoContainerBox;
        return parent_container.is_box_before_box (this, other_box);
    }

    /**
     * Return true if other_box follows this box in the box's parent container
     *
     * Throws IsoBoxError.BOX_NOT_FOUND if other_box is not in the same container as this box
     */
    public bool follows (IsoBox other_box) throws IsoBoxError {
        var parent_container = get_parent_box (typeof (IsoContainerBox)) as IsoContainerBox;
        return parent_container.is_box_before_box (other_box, this);
    }

    /**
     * Return true if other_box immediately precedes this box in the box's parent container
     *
     * Throws IsoBoxError.BOX_NOT_FOUND if other_box is not in the same container as this box
     */
    public bool immediately_precedes (IsoBox other_box) throws IsoBoxError  {
        var parent_container = get_parent_box (typeof (IsoContainerBox)) as IsoContainerBox;
        return parent_container.is_box_immediately_before_box (this, other_box);
    }

    /**
     * Return true if other_box precedes this box in the box's parent container
     *
     * Throws IsoBoxError.BOX_NOT_FOUND if other_box is not in the same container as this box
     */
    public bool immediately_follows (IsoBox other_box) throws IsoBoxError {
        var parent_container = get_parent_box (typeof (IsoContainerBox)) as IsoContainerBox;
        return parent_container.is_box_immediately_before_box (other_box, this);
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
        // debug ("IsoFullBox(%s).parse_from_stream()", this.type_code);
        var bytes_consumed = base.parse_from_stream ();
        var dword = this.source_stream.read_uint32 ();
        this.version = (uint8)(dword >> 24);
        this.flags = dword & 0xFFFFFF;
        return (bytes_consumed + 4);
    }

    protected override void update_box_fields (uint64 payload_size = 0) throws IsoBoxError {
        base.update_box_fields (payload_size + 4); // 1 version byte + 3 flag bytes
    }

    public override void write_fields_to_stream (IsoOutputStream outstream) throws Error {
        base.write_fields_to_stream (outstream);
        uint32 dword = (this.version << 24) | (this.flags & 0xFFFFFF);
        outstream.put_uint32 (dword);
    }

    public bool flag_set (uint32 flag) throws IsoBoxError {
        check_loaded ("IsoFullBox.flag_set", flag.to_string ("%x"));
        return ((this.flags & flag) != 0);
    }

    public bool flag_set_loaded (uint32 flag) {
        return ((this.flags & flag) != 0);
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

    public Gee.List<IsoBox> get_boxes_by_type (string type_code) throws IsoBoxError {
        check_loaded ("IsoContainerBox.get_boxes_by_type",type_code);
        var box_list = new Gee.ArrayList<IsoBox> ();
        foreach (var box in this.children) {
            if (box.type_code == type_code) {
                box_list.add (box);
            }
        }
        return box_list;
    }

    public Gee.List<IsoBox> get_boxes_by_class (Type box_class) throws IsoBoxError {
        check_loaded ("IsoContainerBox.get_boxes_by_class", box_class.name ());
        var box_list = new Gee.ArrayList<IsoBox> ();
        foreach (var box in this.children) {
            if (box.get_type ().is_a (box_class)) {
                box_list.add (box);
            }
        }
        return box_list;
    }

    public IsoBox ? first_box_of_type (string type_code) throws IsoBoxError {
        check_loaded ("IsoContainerBox.first_box_of_type",type_code);
        foreach (var box in this.children) {
            if (box.type_code == type_code) {
                return box;
            }
        }
        throw new IsoBoxError.BOX_NOT_FOUND
                              (this.to_string() + " does not contain a " + type_code + " box");
    }

    public IsoBox first_box_of_class (Type box_class) throws IsoBoxError {
        check_loaded ("IsoContainerBox.first_box_of_class", box_class.name ());
        foreach (var box in this.children) {
            if (box.get_type ().is_a (box_class)) {
                return box;
            }
        }
        throw new IsoBoxError.BOX_NOT_FOUND
                              (this.to_string() + " does not contain a " + box_class.name ());
    }

    public bool has_box_of_type (string type_code) throws Rygel.IsoBoxError {
        check_loaded ("IsoContainerBox.has_box_of_type",type_code);
        foreach (var box in this.children) {
            if (box.type_code == type_code) {
                return true;
            }
        }
        return false;
    }

    public bool has_box_of_class (Type box_class) throws Rygel.IsoBoxError {
        check_loaded ("IsoContainerBox.has_box_of_class", box_class.name ());
        foreach (var box in this.children) {
            if (box.get_type ().is_a (box_class)) {
                return true;
            }
        }
        return false;
    }

    public bool is_box_before_box (IsoBox box_a, IsoBox box_b) throws Rygel.IsoBoxError {
        check_loaded ("IsoContainerBox.is_box_before_box");
        bool found_a = false;
        foreach (var box in this.children) {
            if (box == box_a) {
                found_a = true;
            } else if (box == box_b) {
                return found_a;
            }
        }
        if (found_a) {
            throw new IsoBoxError.BOX_NOT_FOUND
                                  ("IsoContainerBox.is_box_before_box(): "
                                   + this.to_string() + " does not contain "
                                   + box_b.to_string ());
        } else {
            throw new IsoBoxError.BOX_NOT_FOUND
                                  ("IsoContainerBox.is_box_before_box(): "
                                   + this.to_string() + " does not contain "
                                   + box_a.to_string () + " or " + box_b.to_string ());
        }
    }

    public bool is_box_immediately_before_box (IsoBox box_a, IsoBox box_b) throws Rygel.IsoBoxError {
        check_loaded ("IsoContainerBox.is_box_immediately_before_box");
        bool found_a = false;
        foreach (var box in this.children) {
            if (box == box_b) {
                return found_a;
            }
            found_a = (box == box_a);
        }
        throw new IsoBoxError.BOX_NOT_FOUND
                              ("IsoContainerBox.is_box_immediately_before_box(): "
                               + this.to_string() + " does not contain "
                               + box_b.to_string ());
    }

    public IsoBox get_descendant_by_class_list (Type [] box_class_array) throws Rygel.IsoBoxError {
        check_loaded ("IsoContainerBox.get_descendant_by_class_list",
                      box_class_array.length.to_string ());
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

    public IsoBox get_descendant_by_type_list (string [] box_type_array) throws IsoBoxError {
        check_loaded ("IsoContainerBox.get_descendant_by_class_list",
                      box_type_array.length.to_string ());
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

    public uint remove_boxes_by_class (Type box_class, uint num_to_remove = 0) throws IsoBoxError {
        check_loaded ("IsoContainerBox.remove_boxes_by_class", box_class.name ());
        uint remove_count = 0;
        for (var box_it = this.children.iterator (); box_it.next ();) {
            var box = box_it.get ();
            if (box.get_type ().is_a (box_class)) {
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
    protected Gee.List<IsoBox> read_boxes (uint64 stream_offset, uint64 bytes_to_read)
            throws IsoBoxError {
        // debug ("read_boxes(%s): stream_offset %lld, bytes_to_read %lld",
        //        this.type_code, stream_offset, bytes_to_read);
        var box_list = new Gee.ArrayList<IsoBox> ();
        uint64 pos = 0;
        do {
            var box = read_box (stream_offset + pos);
            if (box.size > bytes_to_read) {
                throw new IsoBoxError.FRAGMENTED_BOX
                              ("Found box size of %lld with only %lld bytes remaining at offset %llu",
                               box.size, bytes_to_read, stream_offset);
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
    protected IsoBox read_box (uint64 stream_offset) throws IsoBoxError {
        // debug ("IsoContainerBox(%s): read_box offset %lld", this.type_code, stream_offset);
        string type_code = "unknown";
        try {
            var box_size = this.source_stream.read_uint32 ();
            type_code = this.source_stream.read_4cc ();
            uint64 box_largesize = 0;
            if (box_size == 1) {
                box_largesize = this.source_stream.read_uint64 ();
                this.source_stream.skip_bytes (box_largesize - 16);
            } else {
                this.source_stream.skip_bytes (box_size - 8);
            }
            return make_box_for_type (type_code, stream_offset, box_size, box_largesize);
        } catch (Error error) {
            throw new IsoBoxError.PARSE_ERROR
                          ("IsoContainerBox.read_box(): IOError reading box type %s at offset %llu: %s",
                           type_code, stream_offset, error.message);
        }
    }

    /**
     * Make a typed box
     */
    protected IsoBox make_box_for_type (string type_code, uint64 stream_offset, 
                                        uint32 box_size, uint64 box_largesize)
            throws Error {
        // debug ("IsoContainerBox(%s).make_box_for_type(type_code %s,stream_offset %lld,box_size %u,largesize %llu)",
        //        this.type_code, type_code, stream_offset, box_size, box_largesize);
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
            case "mvex":
                return new IsoMovieExtendsBox.from_stream (this, type_code, this.source_stream,
                                                           stream_offset, box_size,
                                                           box_largesize);
            case "mehd":
                return new IsoMovieExtendsHeaderBox.from_stream (this, type_code,
                                                                 this.source_stream,
                                                                 stream_offset, box_size,
                                                                 box_largesize);
            case "trex":
                return new IsoTrackExtendsBox.from_stream (this, type_code, this.source_stream,
                                                           stream_offset, box_size,
                                                           box_largesize);
            case "moof":
                return new IsoMovieFragmentBox.from_stream (this, type_code, this.source_stream,
                                                            stream_offset, box_size,
                                                            box_largesize);
            case "mfhd":
                return new IsoMovieFragmentHeaderBox.from_stream (this, type_code,
                                                                  this.source_stream,
                                                                  stream_offset, box_size,
                                                                  box_largesize);
            case "traf":
                return new IsoTrackFragmentBox.from_stream (this, type_code, this.source_stream,
                                                            stream_offset, box_size,
                                                            box_largesize);
            case "tfhd":
                return new IsoTrackFragmentHeaderBox.from_stream (this, type_code,
                                                                  this.source_stream,
                                                                  stream_offset, box_size,
                                                                  box_largesize);
            case "trun":
                return new IsoTrackRunBox.from_stream (this, type_code, this.source_stream,
                                                       stream_offset, box_size, box_largesize);
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
        // debug ("IsoContainerBox(%s).load_children(%u)", this.type_code, levels);
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
    public void update_children (uint levels = 0) throws IsoBoxError {
        // debug ("IsoContainerBox(%s).update_children(%u)", this.type_code, levels);
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

    protected override void update_box_fields (uint64 payload_size = 0) throws IsoBoxError {
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

    private static const bool STRINGIFY_CHILDREN = false;

    protected string children_to_string () {
        var builder = new StringBuilder ();
        if (this.loaded) {
            if (STRINGIFY_CHILDREN) {
                if (this.children.size > 0) {
                    foreach (var box in this.children) {
                        builder.append (box.to_string ());
                        builder.append_c (',');
                    }
                    builder.truncate (builder.len-1);
                }
            } else {
                builder.append_printf ("(and %u sub-boxes)", this.children.size);
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
 * The AccessPoint (abstract) class defines a generic concept of an AccessPoint within an
 * content container track.
 *
 * Which fields are to be set at what point are context-specific.
 */
public abstract class Rygel.IsoAccessPoint {
    public Rygel.IsoSampleTableBox sample_table_box;
    public uint64 time_offset; /** Time offset within the content container */
    public uint64 byte_offset; /** Byte offset within the content container */
    public uint32 sample; /** Sample number within the content container */

    public IsoAccessPoint (Rygel.IsoSampleTableBox ? sample_table_box,
                           uint64 time_offset, uint64 byte_offset,
                           uint32 sample_number) {
        this.sample_table_box = sample_table_box;
        this.time_offset = time_offset;
        this.byte_offset = byte_offset;
        this.sample = sample_number;
    }

    public virtual uint32 get_timescale () throws Rygel.IsoBoxError {
        if (this.sample_table_box == null) {
            throw new Rygel.IsoBoxError.BOX_NOT_FOUND ("IsoAccessPoint.get_timescale(): no sample_table_box set for "
                                                       + this.to_string ());
        }
        return this.sample_table_box.get_media_box ().get_header_box ().timescale;
    }

    public virtual uint32 get_track_id () throws Rygel.IsoBoxError {
        if (this.sample_table_box == null) {
            throw new Rygel.IsoBoxError.BOX_NOT_FOUND ("IsoAccessPoint.get_track_id(): no sample_table_box set for "
                                                       + this.to_string ());
        }
        return this.sample_table_box.get_track_box ().get_header_box ().track_id;
    }

    public virtual string to_string () {
        if (this.sample_table_box == null) {
            return "track na,time_offset %llu,byte_offset %llu,sample_number %u"
                   .printf (this.time_offset, this.byte_offset, this.sample);
        } else {
            try {
                return "track %u,time_offset %llu (%0.3fs),byte_offset %llu,sample_number %u"
                       .printf (get_track_id (), this.time_offset,
                                (float)this.time_offset/get_timescale (),
                                this.byte_offset, this.sample);
            } catch (Rygel.IsoBoxError e) {
                return "[" + e.message + "]";
            }
        }
    }
}

/**
 * The file container box is the top-level box for a MP4/ISO BMFF file.
 * It can only contain boxes (no fields)
 */
public class Rygel.IsoFileContainerBox : IsoContainerBox {
    // Box cache references (MAKE SURE these are nulled out in update())
    protected IsoMovieBox movie_box = null;

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
        // debug ("IsoFileContainerBox(%s).parse_from_stream()", this.type_code);
        // The FileContainerBox doesn't have a base header
        this.source_stream.seek_to_offset (this.source_offset);
        this.children = base.read_boxes (0, this.size);
        return this.size;
    }

    protected override void update () throws IsoBoxError {
        this.movie_box = null;
        base.update ();
    }
    protected override void update_box_fields (uint64 payload_size = 0) throws IsoBoxError {
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

    public IsoFileTypeBox get_file_type_box () throws IsoBoxError {
        return first_box_of_class (typeof (IsoFileTypeBox)) as IsoFileTypeBox;
    }

    /**
     * Return the IsoMovieBox within the IsoFileContainerBox
     *
     * Note that this will cache the box reference until update() is called.
     */
    public IsoMovieBox get_movie_box () throws IsoBoxError {
        if (this.movie_box == null) {
            this.movie_box = first_box_of_class (typeof (IsoMovieBox)) as IsoMovieBox;
        }   
        return this.movie_box;
    }

    public bool is_fragmented () throws IsoBoxError {
        return (get_movie_box ().is_fragmented ());
    }

    /**
     * This will get the movie duration, in movie timescale units, accounting for movie
     * fragments.
     *
     * EditListBoxes will be used if directed - providing the duration based on the
     * durations of the edit entries.
     */
    public uint64 get_duration (bool use_edit_list=false) throws IsoBoxError {
        // debug ("IsoFileContainerBox.get_duration(use_edit_list=%s)",
        //        (use_edit_list ? "true": "false"));
        // Return the duration of the longest track
        uint64 longest_track_duration = 0;
        var movie_box = get_movie_box ();
        var track_list = movie_box.get_tracks ();
        for (var track_it = track_list.iterator (); track_it.next ();) {
            var track_box = track_it.get ();
            var track_id = track_box.get_header_box ().track_id;
            var track_media_duration = get_track_duration (track_id, use_edit_list);
            if (track_media_duration > longest_track_duration) {
                longest_track_duration = track_media_duration;
            }
            // debug ("  calculation duration for track %u: %llu", track_id, track_duration);
        }
        return longest_track_duration;
    }

    /**
     * Get the random access point times and associated offsets
     */
    public Gee.List<IsoAccessPoint> get_random_access_points () throws IsoBoxError {
        // debug ("IsoFileContainerBox.get_random_access_points()");
        var movie_box = get_movie_box ();
        var primary_track = movie_box.get_primary_media_track ();
        var primary_track_id = primary_track.get_header_box ().track_id;
        var sample_table_box = primary_track.get_sample_table_box ();
        Gee.List<IsoAccessPoint> access_points = null;
        uint32 sample_number = 0;
        uint64 sample_time = 0;
        access_points = sample_table_box.get_random_access_points (access_points,
                                                                   ref sample_number,
                                                                   ref sample_time);
        if (movie_box.is_fragmented ()) {
            var track_fragments = get_track_fragments_for_id (primary_track_id);
            // Walk all the track fragments and have them add their access points to the list
            foreach (var track_frag_box in track_fragments) {
                access_points = track_frag_box.get_random_access_points (access_points,
                                                                         ref sample_number,
                                                                         ref sample_time);
            }
        }
        return access_points;
    }

    public IsoAccessPoint get_random_access_point_for_time (uint64 target_time_us,
                                                            bool sample_after_time,
                                                            bool use_edit_list=false)
            throws IsoBoxError {
        debug ("IsoFileContainerBox.get_random_access_point_for_time(%lluus)",target_time_us);

        var access_points = get_random_access_points ();
        if (access_points.is_empty) {
            throw new IsoBoxError.VALUE_TOO_LARGE ("IsoFileContainerBox.get_random_access_point_for_time: No access points found");
        }

        // All access points must be from the same track (and share the same SampleTable)
        var master_sample_table = access_points.first ().sample_table_box;
        var master_media_header = master_sample_table.get_media_box ().get_header_box ();
        // Convert the requested time now, to simplify comparison
        var target_time = master_media_header.to_media_time_from (target_time_us, MICROS_PER_SEC);

        if (use_edit_list) {
            // TODO: Convert target_time based on edit list
        }

        debug ("  target time in media timescale: %llu (%0.3fs)",
                 target_time,(float)target_time/master_media_header.timescale);
        var last_access_point = access_points.first ();
        bool return_next_sample = false;
        foreach (var access_point in access_points) {
            if (access_point.time_offset > target_time) {
                if (!sample_after_time || return_next_sample) {
                    break;
                } else {
                    return_next_sample = true;
                }
            }
            last_access_point = access_point;
        }

        debug ("  found " + last_access_point.to_string ());
        return last_access_point;
    }

    public class FileEndAccessPoint : IsoAccessPoint {
        public FileEndAccessPoint (IsoSampleTableBox ? sample_table,
                                   uint64 time_offset, uint64 byte_offset, uint32 sample_number) {
            base (sample_table, time_offset, byte_offset, sample_number);
        }
        public override string to_string () {
            return "IsoFileContainerBox.FileEndAccessPoint[%s]".printf (base.to_string ());
        }
    }

    public IsoAccessPoint ? get_access_point_for_time (uint64 target_time_us,
                                                       bool sample_after_time,
                                                       bool use_edit_list=false)
            throws IsoBoxError {
        debug ("IsoFileContainerBox.get_access_point_for_time(%lluus,sample_after %s)",
               target_time_us, sample_after_time ? "true" : "false");

        var movie_box = get_movie_box ();
        var primary_track = movie_box.get_primary_media_track ();
        var primary_track_id = primary_track.get_header_box ().track_id;
        var sample_table_box = primary_track.get_sample_table_box ();
        var media_header = sample_table_box.get_media_box ().get_header_box ();
        var target_time = media_header.to_media_time_from (target_time_us, MICROS_PER_SEC);

        if (use_edit_list) {
            // TODO: Convert target_time based on edit list
        }

        uint32 sample_number = 0;
        uint64 sample_time = 0;
        IsoAccessPoint access_point;
        access_point = sample_table_box.access_point_for_time (target_time, sample_after_time,
                                                               ref sample_number,
                                                               ref sample_time);
        if (access_point != null) {
            return access_point;
        }
        if (movie_box.is_fragmented ()) {
            var track_fragments = get_track_fragments_for_id (primary_track_id);
            // Walk all the track fragments to find the target time
            foreach (var track_frag_box in track_fragments) {
                access_point = track_frag_box.access_point_for_time (target_time,
                                                                     sample_after_time,
                                                                     ref sample_number,
                                                                     ref sample_time);
                if (access_point != null) {
                    return access_point;
                }
            }
        }
        return new FileEndAccessPoint (sample_table_box,sample_time,this.size,sample_number);
    }

    /**
     * This will get the movie duration, in seconds, accounting for movie fragments.
     * 
     * EditListBoxes will be used if directed - providing the duration based on the
     * durations of the edit entries.
     */
    public float get_duration_seconds (bool use_edit_list=false) throws IsoBoxError {
        var total_duration = get_duration (use_edit_list);
        var timescale = get_movie_box ().get_header_box ().timescale;
        return (float)total_duration / timescale;
    }

    /**
     * This will get a List containing all TrackFragments for the given track_id in the order
     * they appear in the IsoFileContainerBox
     */
    public Gee.List<IsoTrackFragmentBox> get_track_fragments_for_id (uint track_id)
            throws IsoBoxError {
        var box_list = new Gee.ArrayList<IsoBox> ();
        foreach (var cur_box in this.children) {
            if (cur_box is IsoMovieFragmentBox) {
                try {
                    box_list.add ((cur_box as IsoMovieFragmentBox).get_track_fragment (track_id));
                } catch (IsoBoxError.BOX_NOT_FOUND err) {
                } // it's not an error for a MovieFragment to not have a track fragment with id
            }
        }
        return box_list;
    }

    /**
     * This will get the track duration, in movie timescale units, for the given track_id
     * - accounting for movie fragments.
     * 
     * EditListBoxes will be used if directed - providing the duration based on the
     * durations of the edit entries.
     */
    public uint64 get_track_duration (uint track_id, bool use_edit_list=false)
            throws IsoBoxError {
        // debug ("IsoFileContainerBox.get_track_duration(%u, use_edit_list=%s)",
        //        track_id, (use_edit_list ? "true": "false"));
        var movie_box = get_movie_box ();
        var track_box = movie_box.get_track_for_id (track_id);
        uint64 track_duration;
        if ((!use_edit_list && track_box.has_edit_box ())) {
            track_duration = track_box.get_header_box ().get_media_duration ();
        } else { // We can use the track duration (the edit list must be account for, if present)
            track_duration = track_box.get_header_box ().duration;
        }
        // debug ("  track box duration: %llu",track_duration);
        // If the track has edit lists, they're supposed to account for the fragments.
        // So only add the segment durations if there aren't edit lists 
        if ((!use_edit_list || !track_box.has_edit_box ()) && is_fragmented ()) {
            // debug ("  file is segmented and edit lists ignored/unavailable - adding in segments...");
            var movie_timescale = movie_box.get_header_box ().timescale;
            foreach (var cur_box in this.children) {
                if (cur_box is IsoMovieFragmentBox) {
                    var movie_fragment = cur_box as IsoMovieFragmentBox;
                    try {
                        var track_fragment_box = movie_fragment.get_track_fragment (track_id);
                        var track_fragment_duration = track_fragment_box
                                                      .get_duration (movie_timescale);
                        // debug ("  track fragment %s duration: %llu",
                        //        track_fragment_box.to_string (), track_fragment_duration);
                        track_duration += track_fragment_duration;
                    } catch (IsoBoxError.BOX_NOT_FOUND err) {
                        // debug ("  %s doesn't have track fragment for track id %u",
                        //        movie_fragment.to_string (), track_id);
                    }
                }
            }
        }
        // debug ("  total duration for track %u of %s: %llu",
        //        track_id, this.to_string (), track_duration);
        return track_duration;
    }
                
    /**
     * This will get the track duration, in seconds, accounting for movie fragments.
     * 
     * EditListBoxes will be used if directed - providing the duration based on the
     * durations of the edit entries.
     */
    public float get_track_duration_seconds (uint track_id, bool use_edit_list=false)
            throws IsoBoxError {
        var timescale = get_movie_box ().get_header_box ().timescale;
        return (float)get_track_duration (track_id, use_edit_list) / timescale;
    }

    /**
     * This will return an IsoTrackBox or IsoTrackFragmentBox that contains the sample
     * description for the given target_time, in the track's timescale. time_offset
     * will be set to the time offset into the track box for the target_time (the
     * difference between the track box's start time and the target time)
     *
     * EditListBoxes will be used if directed - providing the duration based on the
     * durations of the edit entries.
     * 
     * If the target_time is not contained in the track, IsoBoxError.BOX_NOT_FOUND
     * will be thrown.
     */
    public IsoBox get_track_box_for_time (uint track_id, uint64 target_time,
                                          out uint64 time_offset)
            throws IsoBoxError {
        var movie_box = get_movie_box ();
        var track_box = movie_box.get_track_for_id (track_id);
        var timescale = track_box.get_media_box ().get_header_box ().timescale;
        debug ("IsoFileContainerBox.get_box_for_time(track %u, time %llu (%0.2fs))",
               track_id, target_time, (float)target_time/timescale);

        var total_track_duration = track_box.get_header_box ().get_media_duration ();
        if (target_time <= total_track_duration) {
            time_offset = target_time;
            debug ("  returning box covering range 0-%llu (offset %llu): %s",
                   total_track_duration, time_offset, track_box.to_string ());
            return track_box; // The target time in the MovieBox samples
        }

        if (is_fragmented ()) {
            foreach (var cur_box in this.children) {
                if (cur_box is IsoMovieFragmentBox) {
                    var movie_fragment = cur_box as IsoMovieFragmentBox;
                    try {
                        var track_fragment = movie_fragment.get_track_fragment (track_id);
                        var track_duration = track_fragment.get_duration ();
                        // debug ("  track fragment %s duration: %llu (%0.3fs). total: %llu (%0.3fs)",
                        //        track_fragment.to_string (), track_fragment_duration,
                        //        (float)track_fragment_duration/timescale,
                        //        total_track_duration,
                        //        (float)total_track_duration/primary_media_header.timescale);
                        if (target_time <= total_track_duration + track_duration) {
                            time_offset = target_time - total_track_duration;
                            debug ("  returning box covering range %llu-%llu (offset %llu): %s",
                                   total_track_duration, total_track_duration+track_duration,
                                   time_offset, track_fragment.to_string ());
                            return track_fragment;
                        }
                        total_track_duration += track_duration;
                    } catch (IsoBoxError.BOX_NOT_FOUND err) {
                        // debug ("  %s doesn't have track fragment for track id %u",
                        //        movie_fragment.to_string (), track_id);
                    }
                }
            }
        }
        throw new IsoBoxError.BOX_NOT_FOUND ("%s does not have MovieBox/MovieBoxFragment for time %llu (%0.3fs)"
                                             .printf (this.to_string(), target_time,
                                                      (float)target_time/timescale));
    }

    /**
     * This will trim the IsoFileContainerBox to only contain samples between
     * start/end time with all metadata updated accordingly.
     *
     * The start_point/end_point will be resolved to the nearest preceding/following
     * samples on the primary track and all sample references outside the sample/byte range
     * will be removed.
     *
     * Samples with no tracks will be removed if the file is non-segmented and empty tracks
     * retained when the file is segmented.
     */
    public void trim_to_time_range (uint64 start_time_us, uint64 end_time_us,
                                    out IsoAccessPoint start_point,
                                    out IsoAccessPoint end_point,
                                    bool insert_empty_edit = false)
                throws IsoBoxError {
        message ("IsoFileContainerBox.trim_to_time_range(start %0.3fs, end %0.3fs)",
                 (float)start_time_us/MICROS_PER_SEC, (float)end_time_us/MICROS_PER_SEC);
        //
        // Find the start and end points for the time range
        //
        start_point = get_random_access_point_for_time (start_time_us, false);
        message ("  found start box: ");
        message ("    " + (start_point == null ? "null" : start_point.to_string ()));
        if (start_point == null) {
            throw new IsoBoxError.VALUE_TOO_LARGE
                      ("IsoFileContainerBox.trim_to_time_range: start time "
                       + start_time_us.to_string () + "us is too large for "
                       + this.to_string ());
        }

        end_point = get_access_point_for_time (end_time_us, true); // Get point just after end time
        message ("  found end box: ");
        message ("     " + (end_point == null ? "null" : end_point.to_string ()));

        //
        // trim
        //
        uint64 bytes_removed;
        var file_box_it = this.children.iterator ();

        bytes_removed = trim_movie_box (start_point, end_point, file_box_it);
        if (start_point is IsoTrackRunBox.AccessPoint) {
            bytes_removed += trim_segment_start (start_point as IsoTrackRunBox.AccessPoint,
                                             file_box_it);
        }
        if (!(end_point is IsoSampleTableBox.AccessPoint)) {
            bytes_removed += trim_segment_end (end_point, bytes_removed, file_box_it);
        }
        bytes_removed += remove_remaining_boxes (file_box_it);
        
        if (insert_empty_edit) {
        }

        update (); // propagate dependent field changes
    }

    /**
     * This will trim the MovieBox samples, advance file_box_iterator just past the MovieBox
     * or MovieBox mdat, and return the number of byte (references) removed in the process.
     */
    protected uint64 trim_movie_box (IsoAccessPoint start_point, IsoAccessPoint end_point,
                                  Gee.Iterator<IsoBox> file_box_iterator)
                throws IsoBoxError {
        message ("IsoFileContainerBox.trim_movie_box(start %s, end %s)",
                 start_point.to_string (), end_point.to_string ());
        var movie_box = this.get_movie_box ();
        var moov_mdat = movie_box.get_referenced_mdats () [0];
        uint64 bytes_removed = 0;
        bool moov_before_mdat = movie_box.precedes (moov_mdat);

        var old_moov_size = movie_box.size;

        if (!(start_point is IsoSampleTableBox.AccessPoint)) {
            message ("  the start point is not within the MovieBox - removing all MovieBox samples");
            movie_box.remove_all_sample_refs ();
            movie_box.update_children (100); // propagate dependent field changes 
            movie_box.update ();
            // Remove the MovieBox mdat
            while (file_box_iterator.next ()) {
                var cur_box = file_box_iterator.get ();
                if (cur_box == moov_mdat) {
                    message ("    removing " + cur_box.to_string ());
                    file_box_iterator.remove ();
                    bytes_removed += cur_box.size;
                    break;
                }
                message ("    skipping : " + cur_box.to_string ());
            }
            if (!moov_before_mdat) {
                // Advance iterator to the movie box
                while (file_box_iterator.next ()) {
                    var cur_box = file_box_iterator.get ();
                    message ("    skipping : " + cur_box.to_string ());
                    if (cur_box == movie_box) {
                        break;
                    }
                }
            }
            bytes_removed += old_moov_size - movie_box.size;
        } else {
            //
            // Update the MovieBox and the MovieBox's mdat
            //
            int64 chunk_offset_adjustment = 0;
            var movie_start_point = start_point as IsoSampleTableBox.AccessPoint;
            if (end_point is IsoSampleTableBox.AccessPoint) {
                message ("  the end point is within the movie box samples - trimming MovieBox end");
                movie_box.remove_samples_after_point (end_point as IsoSampleTableBox.AccessPoint);
                uint64 mdat_end_bytes_to_cut;
                mdat_end_bytes_to_cut = moov_mdat.source_offset + moov_mdat.size 
                                        - end_point.byte_offset;
                message ("mdat bytes to cut from end: %llu", mdat_end_bytes_to_cut);
                moov_mdat.source_payload_size -= mdat_end_bytes_to_cut;
                moov_mdat.update ();
                bytes_removed += mdat_end_bytes_to_cut;
            }

            if (movie_start_point.is_at_start) { // Nothing to remove from the start
                message ("  the start point is at the MovieBox start - nothing to trim");
            } else {
                message ("  the start point is within the MovieBox samples - trimming MovieBox start");
                movie_box.remove_samples_before_point (movie_start_point);
                uint64 mdat_start_bytes_to_cut = start_point.byte_offset
                                                 - moov_mdat.source_payload_offset
                                                 - moov_mdat.source_offset;
                message ("mdat bytes to cut from start: %llu", mdat_start_bytes_to_cut);
                // Adjust the mdat's offset to not include the cut data
                moov_mdat.source_payload_offset += mdat_start_bytes_to_cut;
                moov_mdat.source_payload_size -= mdat_start_bytes_to_cut;
                moov_mdat.update ();
                chunk_offset_adjustment -= (int64)mdat_start_bytes_to_cut;
                // TODO: Remove all mdats before the target and adjust any other mdats offsets
            }

            // Calculate the reduced movie size
            movie_box.update_children (100); // propagate dependent field changes 
            movie_box.update ();
            var movie_size_reduction = (int64)old_moov_size - (int64)movie_box.size;
            message ("  moov size reduction: %lld bytes (was %llu, now %llu)",
                     movie_size_reduction, old_moov_size, movie_box.size);
            bytes_removed += movie_size_reduction;

            if (moov_before_mdat) {
                chunk_offset_adjustment -= movie_size_reduction;
            }
            message ("  chunk offset adjustment: %lld bytes", chunk_offset_adjustment);

            if (chunk_offset_adjustment != 0) {
                movie_box.adjust_track_chunk_offsets (chunk_offset_adjustment); // No size change
            }

            if (moov_before_mdat) {
                // Advance iterator to the mdat (after the movie box)
                while (file_box_iterator.next ()) {
                    var cur_box = file_box_iterator.get ();
                    message ("  skipping : " + cur_box.to_string ());
                    if (cur_box == moov_mdat) {
                        break;
                    }
                }
            } else {
                // Advance iterator to the moov (after the mdat box)
                while (file_box_iterator.next ()) {
                    var cur_box = file_box_iterator.get ();
                    message ("  skipping : " + cur_box.to_string ());
                    if (cur_box == movie_box) {
                        break;
                    }
                }
            }
        }

        message ("  trim_movie_box removed %llu bytes", bytes_removed);
        return bytes_removed;
    }

    /**
     * This will remove sample references from MovieFragments up the the start point,
     * move the file_box_iterator to the MovieFragment referenced by start_point, and
     * return the number of byte (references) removed.
     */
    protected uint64 trim_segment_start (IsoTrackRunBox.AccessPoint start_point,
                                         Gee.Iterator<IsoBox> file_box_iterator)
                throws IsoBoxError {
        message ("IsoFileContainerBox.trim_segment_start(%s)", start_point.to_string ());

        var start_track_fragment = start_point.track_run_box.get_track_fragment_box ();
        var start_movie_fragment = start_track_fragment.get_movie_fragment_box ();
        message ("  removing fragments before " + start_movie_fragment.to_string ());

        uint64 bytes_removed = 0;
        while (file_box_iterator.next ()) {
            var cur_box = file_box_iterator.get ();
            if (cur_box.type_code == "mdat") {
                bytes_removed += cur_box.size;
                message ("    removing " + cur_box.to_string ());
                file_box_iterator.remove ();
            } else if (cur_box is IsoMovieFragmentBox) {
                if (cur_box == start_movie_fragment) {
                    break; // We're done removing
                }
                bytes_removed += cur_box.size;
                message ("    removing " + cur_box.to_string ());
                file_box_iterator.remove ();
            } else { // unexpected box
                message ("    skipping UNEXPECTED box: " + cur_box.to_string ());
            }
        }
        message ("    removed %llu bytes of fragments", bytes_removed);
        message ("    adjusting " + start_movie_fragment.to_string ());
        // start_movie_fragment.to_printer ( (l) => {message (l);}, "  PRE-ADJUST: ");
        var old_moof_size = start_movie_fragment.size;
        uint64 mdat_bytes_removed;
        message ("    removing samples before " + start_point.to_string ());
        start_movie_fragment.remove_samples_before_point (start_point,
                                                          out mdat_bytes_removed);
        start_movie_fragment.update_children (100); // propagate dependent field changes 
        start_movie_fragment.update ();
        // start_movie_fragment.to_printer ( (l) => {message (l);}, "  POST-ADJUST: ");
        message ("    start moof reduced by %llu bytes (old moof size %llu, new moof size %llu)",
                 old_moof_size - start_movie_fragment.size,start_movie_fragment.size,
                 mdat_bytes_removed);
        bytes_removed += old_moof_size - start_movie_fragment.size;
        message ("    start mdat reduced by %llu bytes",mdat_bytes_removed);
        bytes_removed += mdat_bytes_removed;
        message ("  trim_segment_start removed %llu bytes", bytes_removed);

        return bytes_removed;
    }

    /**
     * This will adjust any MovieFragments by preceding_bytes_removed starting at the
     * position of the file_box_iterator, trim the MovieFragment referenced by the
     * end_point (if any), advance the file_box_iterator to the last trimmed MovieFragment
     * (if any), and return the number of bytes trimmed from the MovieFragment.
     */
    protected uint64 trim_segment_end (IsoAccessPoint end_point,
                                    uint64 preceding_bytes_removed,
                                    Gee.Iterator<IsoBox> file_box_iterator)
                throws IsoBoxError {
        message ("IsoFileContainerBox.trim_segment_end(%s, preceding_bytes_removed %llu)",
                 end_point.to_string (), preceding_bytes_removed);

        IsoMovieFragmentBox end_movie_fragment = null;
        if (end_point is IsoTrackRunBox.AccessPoint) {
            var segment_end_point = end_point as IsoTrackRunBox.AccessPoint;
            var end_track_fragment = segment_end_point.track_run_box
                                                       .get_track_fragment_box ();
            end_movie_fragment = end_track_fragment.get_movie_fragment_box ();
        }

        // Adjust everything up to the end
        do {
            var cur_box = file_box_iterator.get ();
            if (cur_box is IsoMovieFragmentBox) {
                var movie_fragment_box = cur_box as IsoMovieFragmentBox;
                if (movie_fragment_box == end_movie_fragment) {
                    break;
                }
                message ("    adjusting (%lld bytes) %s",
                         -preceding_bytes_removed,movie_fragment_box.to_string ());
                movie_fragment_box.adjust_offsets (-(int64)preceding_bytes_removed);
                movie_fragment_box.update_children (100); // propagate field changes
                movie_fragment_box.update ();
            }
        } while (file_box_iterator.next ());

        uint64 bytes_removed = 0;
        if (end_point is IsoTrackRunBox.AccessPoint) {
            message ("  the end point is in a fragment - removing fragments after: ");
            message ("    " + end_movie_fragment.to_string ());
            // Trim the end fragment
            var old_moof_size = end_movie_fragment.size;
            uint64 mdat_bytes_removed;
            end_movie_fragment.remove_samples_after_point (end_point as IsoTrackRunBox.AccessPoint,
                                                           out mdat_bytes_removed);
            end_movie_fragment.update_children (100); // propagate dependent field changes 
            end_movie_fragment.update ();
            uint64 end_frag_bytes_trimmed = end_movie_fragment.size + mdat_bytes_removed
                                            - old_moof_size;
            bytes_removed += end_frag_bytes_trimmed;
            message ("    removed %llu bytes for end: %s",
                     end_frag_bytes_trimmed,end_movie_fragment.to_string ());
            // Move iterator past MovieFragment
            file_box_iterator.next ();
        }
        message ("  trim_segment_end removed %llu bytes", bytes_removed);

        return bytes_removed;
    }

    /**
     * This will remove all boxes starting at file_box_iterator until there are no more
     * boxes to remove and return the number of byte (references) removed in the process.
     */
    protected uint64 remove_remaining_boxes (Gee.Iterator<IsoBox> file_box_iterator) {
        uint64 bytes_removed = 0;
        while (file_box_iterator.next ()) {
            var cur_box = file_box_iterator.get ();
            bytes_removed += cur_box.size;
            message ("  removing " + cur_box.to_string ());
            file_box_iterator.remove ();
        }
        message ("  remove_remaining_boxes removed %llu bytes", bytes_removed);

        return bytes_removed;
    }

    protected void insert_empty_edit_lists (IsoAccessPoint start_point,
                                            IsoAccessPoint end_point) {
        // Create/replace the EditListBoxes on all tracks
        var track_list = get_tracks ();
        foreach (var track in track_list) {
            message ("  Inserting empty edit list for track %lld",
                     track.get_header_box ().track_id);

            var edit_list_box = track.create_edit_box ().get_edit_list_box ();
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
            // Alternate "simple" edit
            //    edit_list_box.edit_array = new IsoEditListBox.EditEntry[1];
            //    edit_list_box.set_edit_list_entry (0, master_track_duration,
            //                                       master_track_timescale,
            //                                       0,
            //                                       master_track_timescale,
            //                                       1, 0);
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
        // debug ("IsoGenericBox(%s).parse_from_stream()", this.type_code);
        var bytes_skipped = base.parse_from_stream ();
        // For the generic box, treat the box as an opaque blob of bytes that we can
        //  reference from the source file if/when needed.
        this.source_stream.skip_bytes (this.size - bytes_skipped);
        return this.size;
    }

    protected override void update_box_fields (uint64 payload_size = 0) throws IsoBoxError {
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
        // debug ("IsoFileTypeBox(%s).parse_from_stream()", this.type_code);
        var instream = this.source_stream;
        
        var bytes_consumed = base.parse_from_stream () + 8;
        this.major_brand = instream.read_4cc ();
        this.minor_version = instream.read_uint32 ();
        // Remaining box data is a list of compatible_brands
        uint64 num_brands = (this.source_size - bytes_consumed) / 4;
        this.compatible_brands = instream.read_4cc_array (new string[num_brands]);
        return this.source_size; // Everything in the box was consumed
    }

    protected override void update_box_fields (uint64 payload_size = 0) throws IsoBoxError {
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
    // Box cache references (MAKE SURE these are nulled out in update())
    protected IsoMovieHeaderBox movie_header_box = null;
    protected IsoMovieExtendsBox movie_extends_box = null;
    
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
        // debug ("IsoMovieBox(%s).parse_from_stream()", this.type_code);
        var bytes_consumed = base.parse_from_stream (); // IsoContainer/IsoBox
        this.children = base.read_boxes (this.source_offset + bytes_consumed,
                                         this.size - bytes_consumed);
        return this.source_size; // Everything in the box was consumed
    }

    protected override void update () throws IsoBoxError {
        movie_header_box = null;
        movie_extends_box = null;
        base.update ();
    }

    protected override void update_box_fields (uint64 payload_size = 0) throws IsoBoxError {
        base.update_box_fields (payload_size);
    }

    public override void write_fields_to_stream (IsoOutputStream outstream) throws Error {
        base.write_fields_to_stream (outstream);
        foreach (var box in this.children) {
            box.write_to_stream (outstream);
        }
    }

    public IsoMovieHeaderBox get_header_box () throws IsoBoxError {
        if (this.movie_header_box == null) {
            this.movie_header_box
                    = first_box_of_class (typeof (IsoMovieHeaderBox)) as IsoMovieHeaderBox;
        }
        return this.movie_header_box;
    }

    public Gee.List<IsoTrackBox> get_tracks ()
            throws IsoBoxError {
        var box_list = new Gee.ArrayList<IsoBox> ();
        foreach (var cur_box in this.children) {
            if (cur_box is IsoTrackBox) {
                box_list.add (cur_box as IsoTrackBox);
            }
        }
        return box_list;
    }

    /**
     * Return the "primary" track for the movie.
     *
     * This will return the first video track (if any), or the first audio track if there
     * are no video tracks.
     *
     * IsoBoxError.BOX_NOT_FOUND will be thrown if no audio or video tracks are in the
     * movie.
     */
    public IsoTrackBox get_primary_media_track () throws IsoBoxError {
        try {
            return get_first_track_of_type (Rygel.IsoMediaBox.MediaType.VIDEO);
        } catch (IsoBoxError.BOX_NOT_FOUND err) {
            try {
                return get_first_track_of_type (Rygel.IsoMediaBox.MediaType.AUDIO);
            } catch (IsoBoxError.BOX_NOT_FOUND err) {
                throw new IsoBoxError.BOX_NOT_FOUND ("no video or audio track found in "
                                                     + this.to_string ());
            }
        }
    }

    public IsoTrackBox get_first_track_of_type (IsoMediaBox.MediaType media_type) throws IsoBoxError {
        foreach (var cur_box in this.children) {
            if (cur_box is IsoTrackBox) {
                var track_box = cur_box as IsoTrackBox;
                if (track_box.is_media_type (media_type)) {
                    return track_box;
                }
            }
        }
        throw new IsoBoxError.BOX_NOT_FOUND
                              (this.to_string() + " does not have a track of type "
                               + media_type.to_string ());
    }

    public Gee.List<IsoTrackBox> get_tracks_of_type (IsoMediaBox.MediaType media_type)
            throws IsoBoxError {
        var box_list = new Gee.ArrayList<IsoBox> ();
        foreach (var cur_box in this.children) {
            if ((cur_box is IsoTrackBox)
                && ((cur_box as IsoTrackBox).is_media_type (media_type))) {
                box_list.add (cur_box);
            }
        }
        return box_list;
    }

    public IsoTrackBox get_first_sync_track () throws IsoBoxError {
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

    public Gee.List<IsoTrackBox> get_sync_tracks () throws IsoBoxError {
        var box_list = new Gee.ArrayList<IsoBox> ();
        foreach (var cur_box in this.children) {
            if ((cur_box is IsoTrackBox)
                && ((cur_box as IsoTrackBox).has_sync_sample_box ())) {
                box_list.add (cur_box);
            }
        }
        return box_list;
    }

    public IsoTrackBox get_track_for_id (uint track_id) throws IsoBoxError {
        foreach (var cur_box in this.children) {
            if (cur_box is IsoTrackBox) {
                var track_box = cur_box as IsoTrackBox;
                if (track_box.get_header_box ().track_id == track_id) {
                    return track_box;
                }
            }
        }
        throw new IsoBoxError.BOX_NOT_FOUND
                              (this.to_string() + " does not have an IsoTrackBox with track_id "
                               + track_id.to_string ());
    }

    /**
     * Return the duration of the longest track, in movie timescale, accounting for edit
     * list boxes if/when present
     */
    public uint64 get_longest_track_duration () throws IsoBoxError {
        check_loaded ("get_longest_track_duration");
        uint64 longest_track_duration = 0;
        foreach (var cur_box in this.children) {
            if (cur_box is IsoTrackBox) {
                var track_box = cur_box as IsoTrackBox;
                // The TrackHeaderBox duration is required to account for EditListBoxes
                var track_duration = track_box.get_header_box ().duration;
                if (track_duration > longest_track_duration) {
                    longest_track_duration = track_duration;
                }
            }
        }
        return longest_track_duration;
    }

    /**
     * Return the duration of the longest track, in movie timescale, accounting for
     * EditListBoxes if/when present
     */
    public float get_longest_track_duration_seconds () throws IsoBoxError {
        var longest_duration = get_longest_track_duration ();
        var timescale = get_header_box ().timescale;
        return (float)longest_duration / timescale;
    }

    /**
     * Return the duration of the longest track, in media timescale, not accounting for
     * EditListBoxes if/when present
     */
    public uint64 get_longest_track_media_duration () throws IsoBoxError {
        check_loaded ("get_longest_track_media_duration");
        uint64 longest_track_duration = 0;
        foreach (var cur_box in this.children) {
            if (cur_box is IsoTrackBox) {
                var track_box = cur_box as IsoTrackBox;
                var track_duration = track_box.get_header_box ().get_media_duration ();
                if (track_duration > longest_track_duration) {
                    longest_track_duration = track_duration;
                }
            }
        }
        return longest_track_duration;
    }

    /**
     * Return the duration of the longest track, in media timescale.
     */
    public float get_longest_track_media_duration_seconds () throws IsoBoxError {
        var longest_duration = get_longest_track_media_duration ();
        var timescale = get_header_box ().timescale;
        return (float)longest_duration / timescale;
    }

    public IsoMovieExtendsBox ? get_extends_box () throws IsoBoxError {
        if (this.movie_extends_box == null) {
            try {
                this.movie_extends_box
                        = first_box_of_class (typeof (IsoMovieExtendsBox)) as IsoMovieExtendsBox;
            } catch (IsoBoxError.BOX_NOT_FOUND err) {
                this.movie_extends_box = null;
            }
        }
        return this.movie_extends_box;
    }

    /**
     * return true if one or more tracks has an EditBox
     */
    public bool has_edit_lists () throws IsoBoxError {
        check_loaded ("has_edit_lists");
        foreach (var cur_box in this.children) {
            if (cur_box is IsoTrackBox) {
                var track_box = cur_box as IsoTrackBox;
                if (track_box.has_edit_box ()) {
                    return true;
                }
            }
        }
        return false;
    }

    public bool is_fragmented () throws IsoBoxError {
        return (get_extends_box () != null);
    }

    /**
     * This will remove all sample references before the target_point on the
     * target_point's track and samples on all other tracks that fall after the target_point
     * byte offset.
     *
     * Track and movie durations will be updated accordingly.
     *
     * Any tracks with no samples remaining will be removed if fragmentation is not indicated.
     */
    public void remove_samples_before_point (IsoSampleTableBox.AccessPoint target_point)
                throws IsoBoxError {
        message ("IsoMovieBox.remove_samples_before_point(%s)",target_point.to_string ());

        var movie_box_header = get_header_box ();
        var master_track = target_point.sample_table_box.get_track_box ();
        var master_track_id = master_track.get_header_box ().track_id;

        // Walk the tracks and remove samples before the target_point
        var track_list = get_tracks ();
        var is_fragmented = is_fragmented ();
        message ("  Removing samples before byte offset %llu for %d tracks",
                 target_point.byte_offset, track_list.size);
        // var track_duration = end_point.time_offset - start_point.time_offset;
        for (var track_it = track_list.iterator (); track_it.next ();) {
            var track = track_it.get ();
            var track_header = track.get_header_box ();
            message ("  Removing sample references on track %u", track_header.track_id);
            Rygel.IsoSampleTableBox.AccessPoint cut_point;
            if (track_header.track_id == master_track_id) {
                cut_point = target_point;
                message ("    Removing sample refs on sync track before sample %u",
                         cut_point.sample);
            } else {
                cut_point = new IsoSampleTableBox.AccessPoint.byte_offset_only
                                                                    (target_point.byte_offset);
                message ("    Removing sample refs on non-sync track before byte %llu",
                         cut_point.byte_offset);
            }
            var sample_table_box = track.get_sample_table_box ();
            sample_table_box.remove_sample_refs_before_point (ref cut_point);

            if (!is_fragmented && !sample_table_box.has_samples ()) {
                // There aren't any samples left in the track - delete it
                message ("    Track %u doesn't have sample refs - deleting it",
                         track_header.track_id);
                track_it.remove ();
                continue;
            }
            // Adjust track time metadata
            var media_header_box = track.get_media_box ().get_header_box ();
            media_header_box.duration -= cut_point.time_offset;
            message ("    set track media duration to %llu (%0.2fs)",
                     media_header_box.duration, media_header_box.get_duration_seconds ());
            track_header.set_duration (media_header_box.duration, media_header_box.timescale);
            message ("    set track movie duration to %llu (%0.2fs)",
                     track_header.duration, track_header.get_duration_seconds ());
        }
        var master_track_header = master_track.get_header_box ();
        movie_box_header.duration = master_track_header.duration;
        message ("  set movie duration to %llu (%0.2fs)",
                 movie_box_header.duration, movie_box_header.get_duration_seconds ());
    }

    /**
     * This will remove all sample references after, and including, the target_point on the
     * target_point's track and samples on all other tracks that fall after the target_point
     * byte offset.
     *
     * Track and movie durations will be updated accordingly.
     *
     * Any tracks with no samples remaining will be removed if fragmentation is not indicated.
     */
    public void remove_samples_after_point (IsoSampleTableBox.AccessPoint target_point)
                throws IsoBoxError {
        message ("IsoMovieBox.remove_samples_after_point(%s)",target_point.to_string ());
        var movie_box_header = get_header_box ();
        var master_track = target_point.sample_table_box.get_track_box ();
        var master_track_id = master_track.get_header_box ().track_id;

        // Walk the tracks and remove samples after the target_point
        var track_list = get_tracks ();
        var is_fragmented = is_fragmented ();
        message ("  Removing samples after byte offset %llu for %d tracks",
                 target_point.byte_offset, track_list.size);
        // var track_duration = end_point.time_offset - start_point.time_offset;
        for (var track_it = track_list.iterator (); track_it.next ();) {
            var track = track_it.get ();
            var track_header = track.get_header_box ();
            message ("  Removing sample references on track %u", track_header.track_id);
            Rygel.IsoSampleTableBox.AccessPoint cut_point;
            if (track_header.track_id == master_track_id) {
                cut_point = target_point;
                message ("    Removing sample refs on sync track after sample %u",
                         cut_point.sample);
            } else {
                cut_point = new IsoSampleTableBox.AccessPoint.byte_offset_only
                                                                    (target_point.byte_offset);
                message ("    Removing sample refs on non-sync track after byte %llu",
                         cut_point.byte_offset);
            }
            var sample_table_box = track.get_sample_table_box ();
            sample_table_box.remove_sample_refs_after_point (ref cut_point);

            if (!is_fragmented && !sample_table_box.has_samples ()) {
                // There aren't any samples left in the track - delete it
                message ("    Track %u doesn't have sample refs - deleting it",
                         track_header.track_id);
                track_it.remove ();
                continue;
            }
            // Adjust track time metadata
            var media_header_box = track.get_media_box ().get_header_box ();
            media_header_box.duration -= (media_header_box.duration - cut_point.time_offset);
            message ("    set track media duration to %llu (%0.2fs)",
                     media_header_box.duration, media_header_box.get_duration_seconds ());
            track_header.set_duration (media_header_box.duration, media_header_box.timescale);
            message ("    set track movie duration to %llu (%0.2fs)",
                     track_header.duration, track_header.get_duration_seconds ());
        }
        var master_track_header = master_track.get_header_box ();
        movie_box_header.duration = master_track_header.duration;
        message ("  set movie duration to %llu (%0.2fs)",
                 movie_box_header.duration, movie_box_header.get_duration_seconds ());
    }

    /**
     * This will remove all sample references from all tracks.
     *
     * Track and movie durations will be updated to 0. And any tracks with no samples
     * remaining will be removed if fragmentation is not indicated.
     *
     * EditListBoxes will be removed from all tracks.
     */
    public void remove_all_sample_refs () throws IsoBoxError {
        message ("IsoMovieBox.remove_all_sample_refs()");
        var movie_box_header = get_header_box ();
        movie_box_header.duration = 0;

        var track_list = get_tracks ();
        var is_fragmented = is_fragmented ();
        message ("  movie is %sfragmented", (is_fragmented ? "" : "not "));
        for (var track_it = track_list.iterator (); track_it.next ();) {
            var track = track_it.get ();
            var track_header = track.get_header_box ();
            if (is_fragmented) {
                message ("  Removing all sample references on track %u", track_header.track_id);
                var sample_table_box = track.get_sample_table_box ();
                sample_table_box.remove_all_sample_refs ();
                var media_header = track.get_media_box ().get_header_box ();
                media_header.duration = 0;
                track_header.duration = 0;
                track.remove_edit_box ();
            } else {
                message ("  Removing track %u", track_header.track_id);
                track_it.remove ();
            }
        }
    }

    public void adjust_track_chunk_offsets (int64 chunk_offset_adjustment) throws IsoBoxError {
        message ("IsoMovieBox.adjust_track_chunk_offsets(%lld)", chunk_offset_adjustment);
        var track_list = get_tracks ();
        foreach (var track in track_list) {
            message ("  Adjusting track %u offsets by %lld",
                     track.get_header_box ().track_id, chunk_offset_adjustment);
            var chunk_offset_box = track.get_sample_table_box ().get_chunk_offset_box ();
            // chunk_offset_box.to_printer ( (l) => {debug (l);}, "  PRE-ADJUST: ");
            chunk_offset_box.adjust_offsets (chunk_offset_adjustment);
            chunk_offset_box.update ();
            // chunk_offset_box.to_printer ( (l) => {debug (l);}, "  ADJUSTED: ");
        }
    }

    public Gee.List<IsoGenericBox> get_referenced_mdats () throws IsoBoxError {
        var mdats = new Gee.ArrayList<IsoGenericBox> ();
        var track_list = get_tracks ();
        uint64 target_offset = 0;
        foreach (var track in track_list) {
            var chunk_offset_box = track.get_sample_table_box ().get_chunk_offset_box ();
            if (chunk_offset_box.chunk_offset_array.length > 0) {
                target_offset = chunk_offset_box.chunk_offset_array[0];
            }
        }
        foreach (var cur_box in this.parent_box.children) {
            if (cur_box.type_code == "mdat") {
                if ((target_offset >= cur_box.source_offset)
                    && (target_offset < cur_box.source_offset+cur_box.size)) {
                    mdats.add (cur_box as IsoGenericBox);
                    return mdats;
                }
            }
        }
        throw new IsoBoxError.BOX_NOT_FOUND ("IsoMovieBox.get_referenced_mdats: "
                                             + this.to_string()
                                             + " does not have a mdat box for offset "
                                             + target_offset.to_string ());
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
 * This box defines overall information which is media-independent, and relevant to the
 * entire presentation considered as a whole.
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
        // debug ("IsoMovieHeaderBox(%s).parse_from_stream()", this.type_code);
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

    public override void update () throws IsoBoxError {
        if (this.force_large_header || fields_require_large_header ()) {
            this.version = 1;
        } else {
            this.version = 0;
        }

        base.update ();
    }

    protected override void update_box_fields (uint64 payload_size = 0) throws IsoBoxError {
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
    public void set_duration (uint64 duration, uint32 timescale) throws IsoBoxError {
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
     * This will get the duration of the movie in the movie timescale
     *
     * If the duration field is MAX, this will return the length of the longest track.
     * Otherwise, it will return the duration field. 
     */
    public uint64 get_duration () throws IsoBoxError {
        check_loaded ("IsoMovieHeaderBox.get_duration");
        if (((this.version == 0) && (this.duration == uint32.MAX))
            || ((this.version == 1) && (this.duration == uint64.MAX))) {
            // duration is undefined (all 1s), according to iso bmff specification

            var movie_box = get_parent_box (typeof (IsoMovieBox)) as IsoMovieBox;
            return movie_box.get_longest_track_duration ();
        } else {
            return this.duration;
        }
    }

    /**
     * This will get the duration, in seconds (accounting for the timescale)
     *
     * If the duration field is MAX, this will return the length of the longest track.
     * Otherwise, it will return the duration field.
     */
    public float get_duration_seconds () throws IsoBoxError {
        return (float)get_duration () / this.timescale;
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
                builder.append_printf (",ctime %llu,mtime %llu,timescale %u,duration %llu (%0.2fs),rate %0.2f,vol %0.2f",
                                       this.creation_time, this.modification_time, this.timescale,
                                       this.duration, get_duration_seconds (), this.rate, this.volume);
                builder.append (",matrix[");
                foreach (var dword in this.matrix) {
                    builder.append (dword.to_string ());
                    builder.append_c (',');
                }
                builder.truncate (builder.len-1);
                builder.append_printf ("],next_track %u", this.next_track_id);
            } catch (IsoBoxError e) {
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
        // debug ("IsoTrackBox(%s).parse_from_stream()", this.type_code);
        var bytes_consumed = base.parse_from_stream (); // IsoContainer/IsoBox
        this.children = base.read_boxes (this.source_offset + bytes_consumed,
                                         this.size - bytes_consumed);
        return this.source_size; // Everything in the box was consumed
    }

    protected override void update () throws IsoBoxError {
        track_header_box = null;
        media_box = null;
        edit_box = null;
        base.update ();
    }

    protected override void update_box_fields (uint64 payload_size = 0) throws IsoBoxError {
        base.update_box_fields (payload_size);
    }

    public override void write_fields_to_stream (IsoOutputStream outstream) throws Error {
        base.write_fields_to_stream (outstream);
        foreach (var box in this.children) {
            box.write_to_stream (outstream);
        }
    }

    public uint32 get_movie_timescale () throws IsoBoxError {
        return get_movie_box ().get_header_box ().timescale;
    }

    public uint32 get_media_timescale () throws IsoBoxError {
        return get_media_box ().get_header_box ().timescale;
    }

    /**
     * Return the IsoMovieBox containing this IsoTrackBox
     *
     * Note that this will cache the box reference until update() is called.
     */
    public IsoMovieBox get_movie_box () throws IsoBoxError {
        return get_parent_box (typeof (IsoMovieBox)) as IsoMovieBox;
    }

    /**
     * Return the IsoTrackHeaderBox within the IsoTrackBox
     *
     * Note that this will cache the box reference until update() is called.
     */
    public IsoTrackHeaderBox get_header_box () throws IsoBoxError {
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
    public IsoMediaBox get_media_box () throws IsoBoxError {
        if (this.media_box == null) {
            this.media_box = first_box_of_class (typeof (IsoMediaBox)) as IsoMediaBox;
        }
        return this.media_box;
    }

    /**
     * Returns true if the IsoTrackBox contains an EditBox
     */
    public bool has_edit_box () throws IsoBoxError {
        try {
            get_edit_box (); // Doing it this way lets the box get cached if/when found
            return true;
        } catch (IsoBoxError.BOX_NOT_FOUND err) {
            return false;
        }
    }

    /**
     * Return the IsoEditBox within the IsoTrackBox
     *
     * Note that this will cache the box reference until update() is called.
     */
    public IsoEditBox get_edit_box () throws IsoBoxError {
        if (this.edit_box == null) {
            this.edit_box = first_box_of_class (typeof (IsoEditBox)) as IsoEditBox;
        }
        return this.edit_box;
    }

    /**
     * Create an IsoEditBox with an empty IsoEditListBox and add it to the TrackBox,
     * replacing any exiting IsoEditBox.
     *
     * Note that this will cache the box reference until update() is called.
     */
    public IsoEditBox create_edit_box () throws IsoBoxError {
        remove_boxes_by_class (typeof (IsoEditBox));
        this.edit_box = new IsoEditBox (this);
        this.edit_box.create_edit_list_box ();
        this.children.insert (0, this.edit_box);
        return this.edit_box;
    }

    /**
     * Remove the EditBox from the track.
     */
    public bool remove_edit_box () throws IsoBoxError {
        bool removed = (remove_boxes_by_class (typeof (IsoEditBox)) > 0);
        this.edit_box = null;
        return removed;
    }

    public bool is_media_type (IsoMediaBox.MediaType media_type) throws IsoBoxError {
        return get_media_box ().is_media_type (media_type);
    }

    public IsoSampleTableBox get_sample_table_box () throws IsoBoxError {
        return (get_media_box ().get_media_information_box ().get_sample_table_box ());
    }

    public bool has_sync_sample_box () throws IsoBoxError {
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
        // debug ("IsoMovieHeaderBox(%s).parse_from_stream()", this.type_code);
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

    public override void update () throws IsoBoxError {
        if (this.force_large_header || fields_require_large_header ()) {
            this.version = 1;
        } else {
            this.version = 0;
        }

        base.update ();
    }

    protected override void update_box_fields (uint64 payload_size = 0) throws IsoBoxError {
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

    public IsoTrackBox get_track_box () throws IsoBoxError {
        return get_parent_box (typeof (IsoTrackBox)) as IsoTrackBox;
    }

    /**
     * This will set the duration, accounting for the source timescale
     */
    public void set_duration (uint64 duration, uint32 timescale) throws IsoBoxError {
        // The TrackBoxHeader duration timescale is the MovieBox's timescale
        var movie_timescale = get_track_box ().get_movie_timescale ();
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
     * This will get the track's movie duration, in seconds (accounting for the timescale
     * and EditListBoxes)
     */
    public float get_duration_seconds () throws IsoBoxError {
        check_loaded ("IsoTrackHeaderBox.get_duration_seconds");
        // The TrackBoxHeader duration timescale is the MovieBox's timescale
        var movie_timescale = get_track_box ().get_movie_timescale ();
        return (float)this.duration / movie_timescale;
    }

    /**
     * This will get the track's media duration, in movie timescale (not accounting for
     * EditListBoxes). Effectively, this is the sum of all media samples in the track,
     * expressed in movie time.
     */
    public uint64 get_media_duration () throws IsoBoxError {
        var media_header_box = get_track_box ().get_media_box ().get_header_box ();
        var movie_timescale = get_track_box ().get_movie_timescale ();
        return media_header_box.get_media_duration (movie_timescale);
    }

    /**
     * This will get the track's media duration, in seconds (accounting for the timescale
     * and not accounting for EditListBoxes). Effectively, this is a sum of all the sample
     * durations in the track.
     */
    public float get_media_duration_seconds () throws IsoBoxError {
        var media_header_box = get_track_box ().get_media_box ().get_header_box ();
        return media_header_box.get_media_duration_seconds ();
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
                builder.append_printf (",track_id %u,ctime %lld,mtime %lld,duration %lld (%0.2fs),layer %d,alt_group %d,vol %0.2f",
                                       this.track_id,this.creation_time, this.modification_time,
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
            } catch (IsoBoxError e) {
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
        // debug ("IsoMediaBox(%s).parse_from_stream()", this.type_code);
        var bytes_consumed = base.parse_from_stream (); // IsoContainer/IsoBox
        this.children = base.read_boxes (this.source_offset + bytes_consumed,
                                         this.size - bytes_consumed);
        return this.source_size; // Everything in the box was consumed
    }

    protected override void update () throws IsoBoxError {
        media_header_box = null;
        media_information_box = null;
        base.update ();
    }

    protected override void update_box_fields (uint64 payload_size = 0) throws IsoBoxError {
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
    public IsoMediaHeaderBox get_header_box () throws IsoBoxError {
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
    public IsoMediaInformationBox get_media_information_box () throws IsoBoxError {
        if (this.media_information_box == null) {
            this.media_information_box
                    = first_box_of_class (typeof (IsoMediaInformationBox)) as IsoMediaInformationBox;
        }
        return this.media_information_box;
    }

    public MediaType get_media_type () throws IsoBoxError {
        var media_information_box = get_media_information_box ();
        if (media_information_box.has_box_of_class (typeof (IsoSoundMediaHeaderBox))) {
            return MediaType.AUDIO;
        } else if (media_information_box.has_box_of_class (typeof (IsoVideoMediaHeaderBox))) {
            return MediaType.VIDEO;
        } else {
            return MediaType.UNDEFINED;
        }
    }

    public bool is_media_type (MediaType media_type) throws IsoBoxError {
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
        // debug ("IsoMediaHeaderBox(%s).parse_from_stream()", this.type_code);
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
     * This will get the duration, in seconds (accounting for the timescale)
     */
    public float get_duration_seconds () throws IsoBoxError {
        check_loaded ("IsoMediaHeaderBox.get_duration_seconds");
        return (float)this.duration / this.timescale;
    }

    /**
     * Convert the timeval in the given target_timescale to the IsoMediaHeaderBox's MediaTime
     * and return it.
     */
    public uint64 to_media_time_from (uint64 timeval, uint32 target_timescale)
            throws IsoBoxError {
        check_loaded ("IsoMediaHeaderBox.to_media_time_from",
                      timeval.to_string () + "," + target_timescale.to_string ());
        if (this.timescale == target_timescale) {
            return timeval;
        } else { // Convert
            if (timeval > uint32.MAX) {
                return (uint64)(((double)this.timescale/target_timescale) * timeval);
            } else { // Can use integer math
                return (timeval * this.timescale) / target_timescale;
            }
        }
    }

    /**
     * Convert the given mediatime to the target_timescale using the IsoMediaHeaderBox's MediaTime
     * and return it.
     */
    public uint64 from_media_time_to (uint64 mediatime, uint32 target_timescale)
            throws IsoBoxError {
        check_loaded ("IsoMediaHeaderBox.from_media_time_to",
                      mediatime.to_string () + "," + target_timescale.to_string ());
        if (this.timescale == target_timescale) {
            return mediatime;
        } else { // Convert
            if (mediatime > uint32.MAX) {
                return (uint64)(((double)target_timescale/this.timescale) * mediatime);
            } else { // Can use integer math
                return (mediatime * target_timescale) / this.timescale;
            }
        }
    }

    /**
     * This will set the duration, accounting for the source timescale
     */
    public void set_duration (uint64 duration, uint32 timescale) throws IsoBoxError {
        this.duration = to_media_time_from (duration, timescale);
        if (duration > uint32.MAX) {
            this.force_large_header = true;
        }
    }

    /**
     * This will get the media duration in the supplied timescale.
     * Effectively, this is the sum of all media samples in the track.
     */
    public uint64 get_media_duration (uint32 timescale) throws IsoBoxError {
        var media_box = get_parent_box (typeof (IsoMediaBox)) as IsoMediaBox;
        var sample_time_box = media_box.get_media_information_box ()
                                           .get_sample_table_box ()
                                               .get_sample_time_box ();
        var total_duration = sample_time_box.get_total_duration ();
        return from_media_time_to (total_duration, timescale);
    }

    /**
     * This will get the duration, in seconds (accounting for the timescale)
     */
    public float get_media_duration_seconds () throws IsoBoxError {
        var media_box = get_parent_box (typeof (IsoMediaBox)) as IsoMediaBox;
        var sample_time_box = media_box.get_media_information_box ()
                                           .get_sample_table_box ()
                                               .get_sample_time_box ();
        var total_duration = sample_time_box.get_total_duration ();
        return (float)total_duration / this.timescale;
    }

    public override void update () throws IsoBoxError {
        if (this.force_large_header || fields_require_large_header ()) {
            this.version = 1;
        } else {
            this.version = 0;
        }

        base.update ();
    }

    protected override void update_box_fields (uint64 payload_size = 0) throws IsoBoxError {
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
                builder.append_printf (",ctime %llu,mtime %llu,timescale %u,duration %llu (%0.2fs),language %s",
                                       this.creation_time, this.modification_time, this.timescale,
                                       this.duration, get_duration_seconds (), this.language);
            } catch (IsoBoxError e) {
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
        // debug ("IsoHandlerBox(%s).parse_from_stream()", this.type_code);
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

    protected override void update_box_fields (uint64 payload_size = 0) throws IsoBoxError {
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
        // debug ("IsoMediaInformationBox(%s).parse_from_stream()", this.type_code);
        var bytes_consumed = base.parse_from_stream (); // IsoContainer/IsoBox
        this.children = base.read_boxes (this.source_offset + bytes_consumed,
                                         this.size - bytes_consumed);
        return this.source_size; // Everything in the box was consumed
    }

    protected override void update_box_fields (uint64 payload_size = 0) throws IsoBoxError {
        base.update_box_fields (payload_size);
    }

    public override void write_fields_to_stream (IsoOutputStream outstream) throws Error {
        base.write_fields_to_stream (outstream);
        foreach (var box in this.children) {
            box.write_to_stream (outstream);
        }
    }

    public IsoSampleTableBox get_sample_table_box () throws IsoBoxError {
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
        // debug ("IsoVideoMediaHeaderBox(%s).parse_from_stream()", this.type_code);
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

    protected override void update_box_fields (uint64 payload_size = 0) throws IsoBoxError {
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
        // debug ("IsoSoundMediaHeaderBox(%s).parse_from_stream()", this.type_code);
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

    protected override void update_box_fields (uint64 payload_size = 0) throws IsoBoxError {
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
        // debug ("IsoSampleTableBox(%s).parse_from_stream()", this.type_code);
        var bytes_consumed = base.parse_from_stream (); // IsoContainer/IsoBox
        this.children = base.read_boxes (this.source_offset + bytes_consumed,
                                         this.size - bytes_consumed);
        return this.source_size; // Everything in the box was consumed
    }

    protected override void update () throws IsoBoxError {
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

    protected override void update_box_fields (uint64 payload_size = 0) throws IsoBoxError {
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
    public IsoMovieBox get_movie_box () throws IsoBoxError {
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
    public IsoTrackBox get_track_box () throws IsoBoxError {
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
    public IsoMediaBox get_media_box () throws IsoBoxError {
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
    public IsoTimeToSampleBox get_sample_time_box () throws IsoBoxError {
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
    public IsoSyncSampleBox get_sample_sync_box () throws IsoBoxError {
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
    public IsoSampleToChunkBox get_sample_chunk_box () throws IsoBoxError {
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
    public IsoSampleSizeBox get_sample_size_box () throws IsoBoxError {
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
    public IsoChunkOffsetBox get_chunk_offset_box () throws IsoBoxError {
        if (this.chunk_offset_box == null) {
            this.chunk_offset_box
                    = first_box_of_class (typeof (IsoChunkOffsetBox)) as IsoChunkOffsetBox;
        }
        return this.chunk_offset_box;
    }

    public class AccessPoint : IsoAccessPoint {
        public uint32 chunk;
        public uint32 samples_into_chunk;
        public uint64 bytes_into_chunk;
        public bool is_at_start;
        public bool is_at_end;

        public AccessPoint (IsoSampleTableBox ? sample_table, uint64 time_offset, uint64 byte_offset,
                            uint32 sample_number, uint32 chunk_number, uint32 samples_into_chunk,
                            uint64 bytes_into_chunk, bool at_start, bool at_end) {
            base (sample_table, time_offset, byte_offset, sample_number);
            this.chunk = chunk_number;
            this.samples_into_chunk = samples_into_chunk;
            this.bytes_into_chunk = bytes_into_chunk;
            this.is_at_start = at_start;
            this.is_at_end = at_end;
        }
        public AccessPoint.time_only (uint64 time_offset) {
            this (null, time_offset, 0, 0, 0, 0, 0, false, false);
        }
        public AccessPoint.time_and_sample (IsoSampleTableBox ? sample_table,
                                            uint64 time_offset, uint32 sample_number) {
            this (sample_table, time_offset, 0, sample_number, 0, 0, 0, sample_number==1, false);
        }

        public AccessPoint.byte_offset_only (uint64 byte_offset) {
            this (null, 0, byte_offset, 0, 0, 0, 0, false, false);
        }
        public override string to_string () {
            return "IsoSampleTableBox.AccessPoint[%s,chunk %u,samples_into_chunk %u,bytes_into_chunk %llu,%sat_start,%sat_end]"
                   .printf (base.to_string (),
                            this.chunk,this.samples_into_chunk,this.bytes_into_chunk,
                            (this.is_at_start ? "" : "not "),(this.is_at_end ? "" : "not "));
        }
    }

    public enum Proximity {UNDEFINED, BEFORE, AFTER, WITHIN}

    /**
     * Get the number of the last sample in the SampleTable.
     *
     * This is also the number of samples in the SampleTable (since samples are 1-based)
     */
    public uint32 get_last_sample_number () throws IsoBoxError {
        return (get_sample_size_box ().last_sample_number ());
    }
 
    /**
     * Calculate the AccessPoint byte_offset, chunk, samples_into_chunk, and bytes_into_chunk
     * using access_point.sample and the SampleToChunkBox, ChunkOffsetBox, and SampleSizeBox.
     *
     * Note: If the sample and/or chunk is beyond the number of samples/chunks in the
     *       SampleTable, the offsets will be set to refer to the point immediately after
     *       access_point.sample.
     */
    void access_point_offsets_for_sample (ref AccessPoint access_point) throws IsoBoxError {
        // debug ("access_point_offsets_for_sample(sample %u)",access_point.sample);
        var sample_to_chunk_box = get_sample_chunk_box ();
        var chunk_offset_box = get_chunk_offset_box ();
        var sample_size_box = get_sample_size_box ();
        var last_sample_number = sample_size_box.last_sample_number ();

        if (access_point.sample <= last_sample_number) {
            uint32 samples_into_chunk;
            access_point.chunk = sample_to_chunk_box.chunk_for_sample (access_point.sample,
                                                                       out samples_into_chunk);
            access_point.samples_into_chunk = samples_into_chunk;
            access_point.bytes_into_chunk = sample_size_box.sum_samples
                                                (access_point.sample - samples_into_chunk,
                                                 samples_into_chunk);
        } else if (access_point.sample == last_sample_number+1) {
            // debug ("   sample %u is 1 beyond the total sample count - returning point beyond last sample",
            //        access_point.sample);
            access_point.is_at_end = true;
            access_point.chunk = chunk_offset_box.last_chunk_number ();
            uint32 samples_in_chunk;
            var sample_for_chunk = sample_to_chunk_box.sample_for_chunk (access_point.chunk,
                                                                         out samples_in_chunk);
            access_point.samples_into_chunk = samples_in_chunk;
            access_point.bytes_into_chunk = sample_size_box.sum_samples
                                                (sample_for_chunk, samples_in_chunk);
        } else {
            throw new IsoBoxError.ENTRY_NOT_FOUND ("IsoSampleTableBox.access_point_offsets_for_sample: sample %u is too large for %s"
                                                   .printf (access_point.sample,
                                                            this.to_string( )));
        }
        access_point.byte_offset = chunk_offset_box.offset_for_chunk (access_point.chunk)
                                   + access_point.bytes_into_chunk;
        // debug ("   sample %u,chunk %u,samples_into_chunk %u,bytes_into_chunk %llu,byte_offset %llu",
        //        access_point.sample, access_point.chunk, access_point.samples_into_chunk,
        //        access_point.bytes_into_chunk, access_point.byte_offset);
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
                                              Proximity sample_proximity) throws IsoBoxError {
        debug ("IsoSampleTableBox.access_point_sample_for_byte_offset(access_point.byte_offset %llu, proximity %d)",
               access_point.byte_offset, sample_proximity);
        var chunk_offset_box = get_chunk_offset_box ();
        var sample_to_chunk_box = get_sample_chunk_box ();
        var sample_size_box = get_sample_size_box ();
        access_point.is_at_end = false;
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
                debug ("   byte offset %llu isn't in chunk %u",
                       access_point.byte_offset, access_point.chunk);
                switch (sample_proximity) {
                    case Proximity.BEFORE: // Use the last sample in the chunk
                        // The byte offset isn't within the chunk
                        access_point.sample--; // Just use the last sample of the preceding chunk
                        access_point.bytes_into_chunk = sample_size_box.sum_samples
                                                            (sample_for_chunk, samples_in_chunk-1);
                        debug ("   Proximity.BEFORE: returning last sample in chunk %u: sample %u",
                               access_point.chunk, access_point.sample);
                        break;
                    case Proximity.AFTER: // Use the first sample of the next chunk
                        var last_chunk_number = chunk_offset_box.last_chunk_number ();
                        if (access_point.chunk < last_chunk_number) {
                            access_point.chunk++;
                            access_point.bytes_into_chunk = 0;
                            debug ("   Proximity.AFTER: returning next chunk %u, sample %u",
                                   access_point.chunk, access_point.sample);
                        } else {
                            access_point.is_at_end = true;
                            access_point.bytes_into_chunk = sample_size_box.sum_samples
                                                              (sample_for_chunk, samples_in_chunk);
                            debug ("   Proximity.AFTER: beyond last chunk - returning last chunk %u, sample %u",
                                   access_point.chunk, access_point.sample);
                        }
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
            switch (sample_proximity) {
                case Proximity.BEFORE:
                    access_point.chunk = 0;
                    access_point.sample = 0;
                    access_point.bytes_into_chunk = 0;
                    break;
                case Proximity.AFTER: // Use the first sample of the first chunk
                    access_point.chunk = 1;
                    access_point.sample = 1;
                    access_point.bytes_into_chunk = 0;
                    break;
                case Proximity.WITHIN:
                    throw new IsoBoxError.ENTRY_NOT_FOUND ("IsoSampleTableBox.access_point_sample_for_byte_offset: byte offset %lld isn't within any chunk of %s (proximity WITHIN)"
                                                           .printf (access_point.byte_offset,
                                                                    this.to_string ()));
                default:
                    throw new IsoBoxError.ENTRY_NOT_FOUND ("IsoSampleTableBox.access_point_sample_for_byte_offset: Invalid proximity value %d"
                                                           .printf (sample_proximity));
            }
            debug ("   byte offset %llu precedes the first chunk - proximity %d: using chunk %u sample %u",
                   access_point.byte_offset, sample_proximity, access_point.chunk,
                   access_point.sample);
        }

        if (access_point.sample == 0) {
            access_point.is_at_start = true;
            access_point.time_offset = 0;
        } else {
            access_point.is_at_start = false;
            access_point.time_offset = get_sample_time_box ().time_for_sample (access_point.sample);
        }
        debug ("   calculated sample %u for byte offset %llu",
               access_point.sample, access_point.byte_offset);
    }

    /**
     * Calculate the access_point chunk and bytes_into_chunk values using the sample.
     * This will not set the access point time value.
     * 
     * Note: If the sample and/or chunk is beyond the number of samples/chunks in the
     *       SampleTable, the offsets will be set to refer to the point immediately after
     *       access_point.sample.
     */
    void access_point_chunk_for_sample (ref AccessPoint access_point) throws IsoBoxError {
        // debug ("IsoSampleTableBox.access_point_chunk_for_sample(access_point.sample %u)",
        //        access_point.sample);
        var sample_size_box = get_sample_size_box ();
        var last_sample_number = sample_size_box.last_sample_number ();
        if (access_point.sample <= last_sample_number) {
            var sample_to_chunk_box = get_sample_chunk_box ();
            uint32 samples_into_chunk;
            access_point.chunk = sample_to_chunk_box.chunk_for_sample (access_point.sample,
                                                                       out samples_into_chunk);
            access_point.bytes_into_chunk = sample_size_box.sum_samples
                                                (access_point.sample - samples_into_chunk,
                                                 samples_into_chunk);
        } else {
            // debug ("   sample %u is beyond the total sample count - returning point beyond last chunk",
            //        access_point.sample);
            access_point.is_at_end = true;
            access_point.sample = last_sample_number+1;
            var chunk_offset_box = get_chunk_offset_box ();
            access_point.chunk = chunk_offset_box.last_chunk_number ();
            uint32 samples_in_chunk;
            var sample_to_chunk_box = get_sample_chunk_box ();
            var sample_for_chunk = sample_to_chunk_box.sample_for_chunk (access_point.chunk,
                                                                         out samples_in_chunk);
            access_point.bytes_into_chunk = sample_size_box.sum_samples
                                                (sample_for_chunk, samples_in_chunk);
        }
        access_point.is_at_start = (access_point.sample == 0);
    }

    /**
     * Get the random access point times and associated offsets
     */
    public Gee.List<IsoAccessPoint> get_random_access_points
                                     (Gee.List<IsoAccessPoint> ? access_point_list,
                                      ref uint32 sample_number,
                                      ref uint64 sample_time)
            throws IsoBoxError {
        // debug ("IsoSampleTableBox.get_random_access_points(sample_number %u,sample_time %llu)",
        //        sample_number, sample_time);
        IsoSyncSampleBox sync_sample_box;
        try {
            sync_sample_box = first_box_of_class (typeof (IsoSyncSampleBox)) as IsoSyncSampleBox;
        } catch (Rygel.IsoBoxError.BOX_NOT_FOUND error) {
            sync_sample_box = null; // If SyncSampleBox is not present, all samples are sync points
        }

        var sample_size_box = get_sample_size_box ();
        var time_to_sample_box = get_sample_time_box ();

        var access_points = access_point_list;
        if (access_points == null) {
            access_points = new Gee.ArrayList<AccessPoint> ();
            sample_number = 1;
            sample_time = 0;
        }
        if (sync_sample_box == null) {
            // debug ("get_random_access_points: no SyncSampleBox - using TimeToSampleBox entries");
            var total_samples = time_to_sample_box.get_total_samples ();
            for (uint i=0; i<total_samples; i++) {
                var time_offset = time_to_sample_box.time_for_sample (i+1);
                var access_point = new AccessPoint.time_and_sample (this, time_offset, i+1);
                access_point_offsets_for_sample (ref access_point);
                // debug ("get_random_access_points: sample %u: time %0.3f, offset %llu",
                //        i+1, access_points[i].time_offset, access_points[i].byte_offset);
                access_points.add (access_point);
            }
        } else {
            // debug ("get_random_access_points: using SyncSampleBox");
            foreach (var sample in sync_sample_box.sample_number_array) {
                var time_offset = time_to_sample_box.time_for_sample (sample);
                var access_point = new AccessPoint.time_and_sample (this, time_offset, sample);
                access_point_offsets_for_sample (ref access_point);
                // debug ("get_random_access_points: sample %u: time %0.3f, offset %llu",
                //        sample, access_points[i].time_offset, access_points[i].byte_offset);
                access_points.add (access_point);
            }
        }
        sample_number += sample_size_box.last_sample_number ();
        sample_time += time_to_sample_box.get_total_duration ();

        return access_points;
    }

    /**
     * This will return an AccessPoint for the corresponding (relative) time within the
     * SampleTableBox, updating sample_number and sample_time as it progresses.
     *
     * sample_number, sample_time, and sample_byte_offset will be incremented while walking
     * the track run, allowing this function to be used across multiple TrackRunBoxes
     * 
     * If a sample for the time is not found in the sample list, null is returned.
     */
    public AccessPoint ? access_point_for_time (uint64 target_time, bool sample_after_time,
                                                ref uint32 sample_number,
                                                ref uint64 sample_time)
            throws IsoBoxError {
        // debug ("IsoSampleTableBox.access_point_for_time(target_time %llu,sample_after %s,sample_number %u,sample_time %llu)",
        //        target_time,sample_after_time ? "true" : "false",sample_number,sample_time);
        var time_to_sample_box = get_sample_time_box ();
        try {
            var sample = time_to_sample_box.sample_for_time (target_time);
            if (sample_after_time) {
                sample++;
            }
            var time_offset = time_to_sample_box.time_for_sample (sample);
            var access_point = new AccessPoint.time_and_sample (this, time_offset, sample);
            access_point_offsets_for_sample (ref access_point);
            return access_point;
        } catch (IsoBoxError.ENTRY_NOT_FOUND e) {
            var sample_size_box = get_sample_size_box ();
            sample_number += sample_size_box.last_sample_number ();
            sample_time += time_to_sample_box.get_total_duration ();
            return null;
        }
    }

    /**
     * This will remove all sample references that precede new_start
     *
     * The sample and/or time_offset may not be provided (and will be 0 when omitted) 
     */
    public void remove_sample_refs_before_point (ref AccessPoint new_start) throws IsoBoxError {
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

        debug ("   cut point for sample %u: %llu", new_start.sample, new_start.byte_offset);
        if (new_start.is_at_start) {
            debug ("   cut point is at the start - no samples references to remove");
            return;
        }

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
        if ((chunk_offset_box.chunk_offset_array.length > 0)
            && (new_start.bytes_into_chunk > 0)) {
            chunk_offset_box.chunk_offset_array[0] += new_start.bytes_into_chunk;
            debug ("   adjusting new first chunk offset from %llu to %llu",
                   chunk_offset_box.chunk_offset_array[0] - new_start.bytes_into_chunk,
                   chunk_offset_box.chunk_offset_array[0]);
        }
    }

    /**
     * This will remove the sample reference at new_end and everything that follows
     *
     * The sample and/or time_offset may not be provided (and will be 0 when omitted) 
     */
    public void remove_sample_refs_after_point (ref AccessPoint new_end) throws IsoBoxError {
        debug ("IsoSampleTableBox.remove_sample_refs_after_point(new_end.byte_offset %llu,sample %u,time_offset %llu)",
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

        debug ("   cut point for sample %u: %llu", new_end.sample, new_end.byte_offset);
        var last_sample_number = sample_size_box.last_sample_number ();
        if (new_end.is_at_end || new_end.sample == last_sample_number) {
            debug ("   cut point is at the end - no samples references to remove");
            return;
        }
        
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
     * This will remove all sample references from the table
     *
     */
    public void remove_all_sample_refs () throws IsoBoxError {
        debug ("IsoSampleTableBox.remove_all_sample_refs()");
        var chunk_offset_box = get_chunk_offset_box ();
        var sample_to_chunk_box = get_sample_chunk_box ();
        var sample_size_box = get_sample_size_box ();

        debug ("   removing all samples from TimeToSampleBox");
        var sample_time_box = get_sample_time_box ();
        sample_time_box.remove_sample_refs_after (0);

        debug ("   removing all samples from SampleSizeBox");
        sample_size_box.remove_sample_refs_after (0);

        debug ("   removing all samples from SampleToChunkBox");
        sample_to_chunk_box.remove_sample_refs_after (0);

        debug ("   removing all chunks from ChunkOffsetBox");
        chunk_offset_box.remove_chunk_refs_after (0);

        try {
            debug ("   removing all sync points from SyncSampleBox");
            get_sample_sync_box ().remove_sample_refs_after (0);
        } catch (Rygel.IsoBoxError.BOX_NOT_FOUND error) { /* it's an optional box */}
    }

    /**
     * Return true of the SampleTableBox has any valid samples
     */
    public bool has_samples () throws IsoBoxError {
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
        uint32 sample_delta; // duration per sample, in media timescale
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
        // debug ("IsoTimeToSampleBox(%s).parse_from_stream()", this.type_code);

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

    protected override void update_box_fields (uint64 payload_size = 0) throws IsoBoxError {
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

    public uint32 get_total_samples () throws IsoBoxError {
        check_loaded ("IsoTimeToSampleBox.get_total_samples");
        uint32 total_samples = 0;
        foreach (var cur_entry in this.sample_array) {
            total_samples += cur_entry.sample_count;
        }
        return total_samples;
    }

    /**
     * Returns the total duration of all samples in the IsoTimeToSampleBox, in the media timescale
     */
    public uint64 get_total_duration () throws IsoBoxError {
        check_loaded ("IsoTimeToSampleBox.get_total_duration");
        uint64 total_duration = 0;
        foreach (var cur_entry in this.sample_array) {
            total_duration += cur_entry.sample_count * cur_entry.sample_delta;
        }
        return total_duration;
    }

    /**
     * Return the sample number containing the given media time_val
     */
    public uint32 sample_for_time (uint64 time_val) throws IsoBoxError {
        check_loaded ("IsoTimeToSampleBox.sample_for_time", time_val.to_string ());
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

    public int64 time_for_sample (uint32 sample_number) throws IsoBoxError {
        check_loaded ("IsoTimeToSampleBox.time_for_sample", sample_number.to_string ());
        uint32 base_sample = 1;
        int64 base_time = 0;
        // debug ("time_for_sample(%u)", sample_number);
        foreach (var cur_entry in this.sample_array) {
            var offset_in_entry = sample_number - base_sample;
            // debug ("  Entry: sample_count %u, sample_delta %u",
            //        cur_entry.sample_count, cur_entry.sample_delta);
            if (offset_in_entry <= cur_entry.sample_count) { // This entry is for our sample
                return (base_time + (offset_in_entry * cur_entry.sample_delta));
            }
            base_sample += cur_entry.sample_count;
            base_time += cur_entry.sample_count * cur_entry.sample_delta;
            // debug ("  base_sample %u, base_time %llu",base_sample, base_time);
        }
        if (sample_number == base_sample+1) {
            debug ("  sample at end - returning total duration %lld",base_time);
            return base_time;
        } else {
            throw new IsoBoxError.ENTRY_NOT_FOUND ("IsoTimeToSampleBox.time_for_sample: sample %u not found in %s (total samples %u)"
                                                   .printf (sample_number, this.to_string (),
                                                            base_sample));
        }
    }

    public uint64 total_sample_duration () throws IsoBoxError {
        check_loaded ("IsoTimeToSampleBox.total_sample_duration");
        uint64 base_time = 0;
        foreach (var cur_entry in this.sample_array) {
            base_time += cur_entry.sample_count * cur_entry.sample_delta;
        }
        return base_time;
    }

    /**
     * Update the sample array to remove references to samples before sample_number.
     */
    public void remove_sample_refs_before (uint32 sample_number) throws IsoBoxError {
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
    public void remove_sample_refs_after (uint32 sample_number) throws IsoBoxError {
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
        // debug ("IsoSyncSampleBox(%s).parse_from_stream()", this.type_code);
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

    protected override void update_box_fields (uint64 payload_size = 0) throws IsoBoxError {
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
    public void remove_sample_refs_before (uint32 sample_number) throws IsoBoxError {
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
    public void remove_sample_refs_after (uint32 sample_number) throws IsoBoxError {
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
        // debug ("IsoSampleToChunkBox(%s).parse_from_stream()", this.type_code);
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

    protected override void update_box_fields (uint64 payload_size = 0) throws IsoBoxError {
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
            throws IsoBoxError {
        // debug ("IsoSampleToChunkBox.chunk_for_sample(sample_number %u)",sample_number);
        uint32 base_sample = 1;
        uint32 base_chunk = 1;
        uint32 last_entry_index = this.chunk_run_array.length;
        for (uint32 i=0; i < last_entry_index; i++) {
            var cur_entry = this.chunk_run_array[i];
            uint32 chunk_run_length, chunk_run_samples;
            if (i == last_entry_index - 1) { // The last entry describes all remaining samples
                chunk_run_length = uint32.MAX-base_chunk-1; 
                chunk_run_samples = uint32.MAX-base_sample-1;
            } else {
                chunk_run_length = this.chunk_run_array[i+1].first_chunk - cur_entry.first_chunk;
                chunk_run_samples = chunk_run_length * cur_entry.samples_per_chunk;
            }
            // debug ("   base_sample %u, base_chunk %u, chunk_run_length %u, chunk_run_samples %u",
            //        base_sample, base_chunk, chunk_run_length, chunk_run_samples);
            if ((base_sample + chunk_run_samples) > sample_number) { // This is our entry
                var samples_into_run = sample_number-base_sample;
                base_chunk += samples_into_run / cur_entry.samples_per_chunk;
                samples_into_chunk = samples_into_run % cur_entry.samples_per_chunk;
                // debug ("   found sample: base_chunk %u, samples_into_run %u, samples_into_chunk %u",
                //        base_chunk, samples_into_run, samples_into_chunk);
                return base_chunk;
            }
            base_chunk += chunk_run_length;
            base_sample += chunk_run_samples;
        }
        if (sample_number == base_sample+1) {
            // debug ("  sample at end - returning chunk %u",base_chunk);
            samples_into_chunk = 0;
            return base_chunk;
        } else {
            throw new IsoBoxError.ENTRY_NOT_FOUND ("IsoSampleToChunkBox.chunk_for_sample: sample index %u not found in %s (total samples %u)"
                                                   .printf (sample_number, this.to_string (),
                                                            base_sample));
        }
    }

    /**
     * Return the sample number of the first sample of the given chunk and the number of samples
     * in the given chunk in samples_in_chunk.
     */
    public uint32 sample_for_chunk (uint32 chunk_index, out uint32 samples_in_chunk)
            throws IsoBoxError {
        // debug ("IsoSampleToChunkBox.sample_for_chunk(chunk_index %u)",chunk_index);
        uint32 base_sample = 1;
        uint32 base_chunk = 1;
        uint32 last_entry_index = this.chunk_run_array.length;
        for (uint32 i=0; i < last_entry_index; i++) {
            var cur_entry = this.chunk_run_array[i];
            uint32 chunk_run_length, chunk_run_samples;
            if (i == last_entry_index - 1) { // The last entry describes all remaining samples
                chunk_run_length = uint32.MAX-base_chunk-1; 
                chunk_run_samples = uint32.MAX-base_sample-1;
            } else {
                chunk_run_length = this.chunk_run_array[i+1].first_chunk - cur_entry.first_chunk;
                chunk_run_samples = chunk_run_length * cur_entry.samples_per_chunk;
            }
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
        if (chunk_index == base_chunk) {
            // debug ("  chunk at end - returning sample %u",base_sample);
            samples_in_chunk = 0;
            return base_sample;
        } else {
            throw new IsoBoxError.ENTRY_NOT_FOUND ("IsoSampleToChunkBox.sample_for_chunk: chunk index %u not found in %s (total chunks %u)"
                                                   .printf (chunk_index, this.to_string (),
                                                            base_chunk));
        }
    }

    /**
     * Update the chunk run array to remove references to samples before sample_number.
     */
    public void remove_sample_refs_before (uint32 sample_number) throws IsoBoxError {
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
            uint32 chunk_run_length, chunk_run_samples;
            if (i == last_entry_index - 1) { // The last entry describes all remaining samples
                chunk_run_length = uint32.MAX-base_chunk-1; 
                chunk_run_samples = uint32.MAX-base_sample-1;
            } else {
                chunk_run_length = this.chunk_run_array[i+1].first_chunk - cur_entry.first_chunk;
                chunk_run_samples = chunk_run_length * cur_entry.samples_per_chunk;
            }
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
                // debug ("  sample_number %u is beyond the last sample (%u) - removing all sample refs",
                //        sample_number, base_sample-1);
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
    public void remove_sample_refs_after (uint32 sample_number) throws IsoBoxError {
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
            uint32  chunk_run_length, chunk_run_samples;
            if (i == last_entry_index - 1) { // The last entry describes all remaining samples
                chunk_run_length = uint32.MAX-base_chunk-1; 
                chunk_run_samples = uint32.MAX-base_sample-1;
            } else {
                chunk_run_length = this.chunk_run_array[i+1].first_chunk - cur_entry.first_chunk;
                chunk_run_samples = chunk_run_length * cur_entry.samples_per_chunk;
            }
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
        // debug ("IsoSampleSizeBox(%s).parse_from_stream()", this.type_code);
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

    protected override void update_box_fields (uint64 payload_size = 0) throws IsoBoxError {
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

    public uint64 sum_samples (uint32 start_sample, uint32 sample_count) throws IsoBoxError {
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
            throws IsoBoxError {
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
    public void remove_sample_refs_before (uint32 sample_number) throws IsoBoxError {
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
    public void remove_sample_refs_after (uint32 sample_number) throws IsoBoxError {
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

    /**
     * The number of sample references in the SampleSizeBox identifies the number of samples
     *  in the contained MediaBox.
     */
    public uint32 last_sample_number () {
        return ((this.sample_size == 0) ? this.entry_size_array.length : this.sample_count);
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
        // debug ("IsoChunkOffsetBox(%s).parse_from_stream()", this.type_code);
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

    protected override void update_box_fields (uint64 payload_size = 0) throws IsoBoxError {
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
                    throw new IsoBoxError.VALUE_TOO_LARGE ("IsoChunkOffsetBox.write_fields_to_stream: offset %llu (entry %u) is too large for %s"
                                                           .printf (this.chunk_offset_array[i], i,
                                                                    this.to_string ()));
                }
                outstream.put_uint32 ((uint32)this.chunk_offset_array[i]);
            }
        }
    }

    public uint32 last_chunk_number () throws IsoBoxError {
        return (this.chunk_offset_array.length);
    }

    public uint64 offset_for_chunk (uint32 chunk_number) throws IsoBoxError {
        if (chunk_number > this.chunk_offset_array.length) {
            throw new IsoBoxError.ENTRY_NOT_FOUND ("IsoChunkOffsetBox.offset_for_chunk: %s does not have an entry for chunk %u"
                                                   .printf (this.to_string (), chunk_number));
        }
        return (this.chunk_offset_array[chunk_number-1]);
    }

    /**
     * Remove the chunk references before the given chunk_number
     */
    public void remove_chunk_refs_before (uint32 chunk_number) throws IsoBoxError {
        if (chunk_number >= this.chunk_offset_array.length) {
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
    public void remove_chunk_refs_after (uint32 chunk_number) throws IsoBoxError {
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
    public void adjust_offsets (int64 byte_adjustment) throws IsoBoxError {
        for (uint32 i=0; i<this.chunk_offset_array.length; i++) {
            this.chunk_offset_array[i] += byte_adjustment;
        }
    }

    /**
     * Return the chunk number that most immediately precedes the given byte offset and
     * the byte offset of the chunk in chunk_byte_offset.
     *
     * If the byte offset precedes the first chunk, throw ENTRY_NOT_FOUND
     *
     * Note that the content at byte_offset may or may not be in the chunk.
     */
    public uint32 chunk_for_offset (uint64 byte_offset, out uint64 chunk_byte_offset)
            throws IsoBoxError {
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
        // debug ("IsoEditBox(%s).parse_from_stream()", this.type_code);
        var bytes_consumed = base.parse_from_stream (); // IsoContainer/IsoBox
        this.children = base.read_boxes (this.source_offset + bytes_consumed,
                                         this.size - bytes_consumed);
        return this.source_size; // Everything in the box was consumed
    }

    protected override void update () throws IsoBoxError {
        edit_list_box = null;
        base.update ();
    }

    protected override void update_box_fields (uint64 payload_size = 0) throws IsoBoxError {
        base.update_box_fields (payload_size);
    }

    /**
     * Return the IsoEditBox within the IsoTrackBox
     *
     * Note that this will cache the box reference until update() is called.
     */
    public IsoEditListBox get_edit_list_box () throws IsoBoxError {
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
    public IsoEditListBox create_edit_list_box (bool use_large_times=false) throws IsoBoxError {
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
 */
public class Rygel.IsoEditListBox : IsoFullBox {
    // Box cache references (MAKE SURE these are nulled out in update())
    protected IsoMovieHeaderBox movie_header_box = null;
    protected IsoTrackBox track_box = null;
    protected IsoMediaHeaderBox media_header_box = null;

    public bool use_large_times;
    public struct EditEntry {
        uint64 segment_duration; // in movie timescale
        int64 media_time; // in media timescale
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
        // debug ("IsoEditListBox(%s).parse_from_stream()", this.type_code);
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
                              (base.to_string () + " box version unsupported: "
                               + this.version.to_string ());
        }

        if (bytes_consumed != this.size) {
            throw new IsoBoxError.PARSE_ERROR
                          ("box size mismatch (parsed %lld, box size %lld)"
                           .printf(bytes_consumed, this.size));
        }
        return this.size;
    }

    protected override void update () throws IsoBoxError {
        this.movie_header_box = null;
        this.track_box = null;
        this.media_header_box = null;
        base.update ();
    }

    protected override void update_box_fields (uint64 payload_size = 0) throws IsoBoxError {
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
    public IsoTrackBox get_track_box () throws IsoBoxError {
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
    public IsoMovieHeaderBox get_movie_header_box () throws IsoBoxError {
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
    public IsoMediaHeaderBox get_media_header_box () throws IsoBoxError {
        if (this.media_header_box == null) {
            this.media_header_box = this.get_track_box ().get_media_box ().get_header_box ();
        }
        return this.media_header_box;
    }

    /**
     * Get the total duration of content described by the EditListBox (in movie timescale)
     */
    public uint64 get_duration () throws IsoBoxError {
        check_loaded ("IsoEditListBox.get_duration");
        uint64 total_duration = 0;
        foreach (var edit_entry in this.edit_array) {
            total_duration += edit_entry.segment_duration;
        }
        return total_duration;
    }

    /**
     * Sets a EditListBox entry, adjusting the media_time for the MovieHeaderBox timescale and
     * adjusting the duration value for the MediaHeaderBox timescale. 
     */
    public void set_edit_list_entry (uint32 index,
                                     uint64 duration, uint32 duration_timescale, 
                                     int64 media_time, uint32 media_timescale,
                                     int16 rate_integer, int16 rate_fraction) throws IsoBoxError {
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

    public string string_for_entry (uint32 index) throws IsoBoxError {
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
        for (uint32 i=0; i<this.edit_array.length; i++) {
            try {
                printer ("%s   Entry %u: %s".printf(prefix,i,this.string_for_entry (i)));
            } catch (IsoBoxError e) {
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
        // debug ("IsoDataInformationBox(%s).parse_from_stream()", this.type_code);
        var bytes_consumed = base.parse_from_stream (); // IsoContainer/IsoBox
        this.children = base.read_boxes (this.source_offset + bytes_consumed,
                                         this.size - bytes_consumed);
        return this.source_size; // Everything in the box was consumed
    }

    protected override void update_box_fields (uint64 payload_size = 0) throws IsoBoxError {
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
} // END class IsoDataInformationBox

/**
 * mvex box
 *
 * This box warns readers that there might be Movie Fragment Boxes in this file. To know
 * of all samples in the tracks, these Movie Fragment Boxes must be found and scanned in order,
 * and their information logically added to that found in the Movie Box.
 */
public class Rygel.IsoMovieExtendsBox : IsoContainerBox {
    // Box cache references (MAKE SURE these are nulled out in update())
    protected IsoMovieExtendsHeaderBox movie_extends_header_box = null;

    public IsoMovieExtendsBox (IsoContainerBox parent) {
        base (parent, "mvex");
    }

    public IsoMovieExtendsBox.from_stream (IsoContainerBox parent, string type_code,
                                              IsoInputStream stream, uint64 offset,
                                              uint32 size, uint64 largesize)
            throws Error {
        base.from_stream (parent, type_code, stream, offset, size, largesize);
    }

    public override uint64 parse_from_stream () throws Error {
        // debug ("IsoMovieExtendsBox(%s).parse_from_stream()", this.type_code);
        var bytes_consumed = base.parse_from_stream (); // IsoContainer/IsoBox
        this.children = base.read_boxes (this.source_offset + bytes_consumed,
                                         this.size - bytes_consumed);
        return this.source_size; // Everything in the box was consumed
    }

    protected override void update_box_fields (uint64 payload_size = 0) throws IsoBoxError {
        base.update_box_fields (payload_size);
    }

    public override void write_fields_to_stream (IsoOutputStream outstream) throws Error {
        base.write_fields_to_stream (outstream);
        foreach (var box in this.children) {
            box.write_to_stream (outstream);
        }
    }

    protected override void update () throws IsoBoxError {
        movie_extends_header_box = null;
        base.update ();
    }

    public IsoMovieExtendsHeaderBox get_header_box () throws IsoBoxError {
        if (this.movie_extends_header_box == null) {
            this.movie_extends_header_box
                    = first_box_of_class (typeof (IsoMovieExtendsHeaderBox))
                      as IsoMovieExtendsHeaderBox;
        }
        return this.movie_extends_header_box;
    }

    /**
     * Return the IsoTrackExtendsBox for the given track ID
     */
    public IsoTrackExtendsBox get_track_extends_for_track_id (uint32 track_id)
            throws IsoBoxError {
        foreach (var cur_box in this.children) {
            if (cur_box is IsoTrackExtendsBox) {
                var track_box = cur_box as IsoTrackExtendsBox;
                if (track_box.track_id == track_id) {
                    return track_box;
                }
            }
        }
        throw new IsoBoxError.BOX_NOT_FOUND
                              ("IsoMovieExtendsHeaderBox.get_track_extends_for_track_id(): %s does not have track %u",
                               to_string (), track_id);
    }

    public override string to_string () {
        return "IsoMovieExtendsBox[" + base.to_string () + "," + base.children_to_string () + "]";
    }
    
    public override void to_printer (IsoBox.LinePrinter printer, string prefix) {
        printer (prefix + "IsoMovieExtendsBox[" + base.to_string () + "] {");
        base.children_to_printer (printer, prefix + "  ");
        printer (prefix + "}");
    }
} // END class IsoMovieExtendsBox

/**
 * mehd box
 *
 * The Movie Extends Header is optional, and provides the overall duration, including fragments,
 * of a fragmented movie. If this box is not present, the overall duration must be computed by
 * examining each fragment.
 */
public class Rygel.IsoMovieExtendsHeaderBox : IsoFullBox {
    public bool use_large_duration;
    public uint64 fragment_duration;

    public IsoMovieExtendsHeaderBox (IsoMovieExtendsBox parent, bool use_large_duration) {
        base (parent, "mehd", use_large_duration ? 1 : 0, 0);
        this.use_large_duration = use_large_duration;
        this.fragment_duration = 0;
    }

    public IsoMovieExtendsHeaderBox.from_stream (IsoContainerBox parent, string type_code,
                                                 IsoInputStream stream, uint64 offset,
                                                 uint32 size, uint64 largesize)
            throws Error {
        base.from_stream (parent, type_code, stream, offset, size, largesize);
    }

    public override uint64 parse_from_stream () throws Error {
        // debug ("IsoMovieExtendsHeaderBox(%s).parse_from_stream()", this.type_code);
        var bytes_consumed = base.parse_from_stream ();

        switch (this.version) {
            case 0:
                this.fragment_duration = this.source_stream.read_uint32 ();
                bytes_consumed += 4;
                this.use_large_duration = false;
            break;
            case 1:
                this.fragment_duration = this.source_stream.read_uint64 ();
                bytes_consumed += 8;
                this.use_large_duration = true;
            break;
            default:
                throw new IsoBoxError.UNSUPPORTED_VERSION
                              ("box version %s unsupported for " + this.type_code);
        }

        if (bytes_consumed != this.size) {
            throw new IsoBoxError.PARSE_ERROR
                          ("box size mismatch for %s (parsed %lld, box size %lld)"
                           .printf(this.type_code, bytes_consumed, this.size));
        }
        return this.size;
    }

    protected override void update_box_fields (uint64 payload_size = 0) throws IsoBoxError {
        if (this.use_large_duration) {
            this.version = 1;
            payload_size += 8;
        } else {
            this.version = 0;
            payload_size += 4;
        }
        base.update_box_fields (payload_size);
    }

    public override void write_fields_to_stream (IsoOutputStream outstream) throws Error {
        base.write_fields_to_stream (outstream);
        if (this.use_large_duration) {
            assert (this.version == 1);
            outstream.put_uint64 (this.fragment_duration);
        } else {
            assert (this.version == 0);
            outstream.put_uint64 ((uint32)this.fragment_duration);
        }
    }

    public override string to_string () {
        var builder = new StringBuilder ("IsoMovieExtendsHeaderBox[");
        builder.append (base.to_string ());
        if (this.loaded) {
            builder.append_printf (",fragment_duration %llu", this.fragment_duration);
        } else {
            builder.append (",[unloaded fields]");
        }
        builder.append_c (']');
        return builder.str;
    }

    public override void to_printer (IsoBox.LinePrinter printer, string prefix) {
        printer (prefix + this.to_string ());
    }
} // END class IsoMovieExtendsHeaderBox

/**
 * Class to contain sample flags used in a number of different box types
 */
public class IsoSampleFlags {
    public uint8 is_leading;
    public uint8 sample_depends_on;
    public uint8 sample_is_depended_on;
    public uint8 sample_has_redundancy;
    public uint8 sample_padding_value;
    /**
     * The flag sample_is_non_sync_sample provides the same information as the sync
     * sample table [8.6.2]. When this value is set 0 for a sample, it is the same as if
     * the sample were not in a movie fragment and marked with an entry in the sync sample
     * table (or, if all samples are sync samples, the sync sample table were absent).
     */
    public bool sample_is_non_sync_sample;
    public uint16 sample_degradation_priority;

    public IsoSampleFlags (uint8 is_leading, uint8 sample_depends_on,
                           uint8 sample_is_depended_on, uint8 sample_has_redundancy,
                           uint8 sample_padding_value, bool sample_is_non_sync_sample,
                           uint16 sample_degradation_priority) {
        this.is_leading = is_leading;
        this.sample_depends_on = sample_depends_on;
        this.sample_is_depended_on = sample_is_depended_on;
        this.sample_has_redundancy = sample_has_redundancy;
        this.sample_padding_value = sample_padding_value;
        this.sample_is_non_sync_sample = sample_is_non_sync_sample;
        this.sample_degradation_priority = sample_degradation_priority;
    }

    public IsoSampleFlags.from_uint32 (uint32 packed_fields) {
        // debug ("IsoSampleFlags.from_uint32()");
        this.sample_degradation_priority = (uint16)(packed_fields & 0xFFFF);
        packed_fields >>= 16;
        this.sample_is_non_sync_sample = (packed_fields & 0x1) == 0x1;
        packed_fields >>= 1;
        this.sample_padding_value = (uint8)(packed_fields & 0x7);
        packed_fields >>= 3;
        this.sample_has_redundancy = (uint8)(packed_fields & 0x3);
        packed_fields >>= 2;
        this.sample_is_depended_on = (uint8)(packed_fields & 0x3);
        packed_fields >>= 2;
        this.sample_depends_on = (uint8)(packed_fields & 0x3);
        packed_fields >>= 2;
        this.is_leading = (uint8)(packed_fields & 0x3);
    }

    public uint32 to_uint32 () {
        uint32 packed_fields = 0;
        packed_fields |= this.is_leading & 0x3;
        packed_fields <<= 2;
        packed_fields |= this.sample_depends_on & 0x3;
        packed_fields <<= 2;
        packed_fields |= this.sample_is_depended_on & 0x3;
        packed_fields <<= 2;
        packed_fields |= this.sample_has_redundancy & 0x3;
        packed_fields <<= 3;
        packed_fields |= this.sample_padding_value & 0x7;
        packed_fields <<= 1;
        packed_fields |= (this.sample_is_non_sync_sample ? 0x1 : 0x0);
        packed_fields <<= 16;
        packed_fields |= this.sample_degradation_priority & 0xFFFF;
        return packed_fields;
    }

    public string to_string () {
        return ("IsoSampleFlags[leading %d,depends %d,depended %d,redundancy %d,sample_padding %d,is_non_sync %s,degradation_priority %d]"
                .printf (this.is_leading, this.sample_depends_on, this.sample_is_depended_on,
                         this.sample_has_redundancy, this.sample_padding_value,
                         (this.sample_is_non_sync_sample ? "true" : "false"), 
                         this.sample_degradation_priority));
    }
} // END class IsoSampleFlags

/**
 * trex box
 *
 * This sets up default values used by the movie fragments. By setting defaults in this way,
 * space and complexity can be saved in each Track Fragment Box.
 */
public class Rygel.IsoTrackExtendsBox : IsoFullBox {
    // Box cache references (MAKE SURE these are nulled out in update())
    protected IsoTrackBox track_box = null;

    public uint32 track_id;
    public uint32 default_sample_description_index;
    public uint32 default_sample_duration;
    public uint32 default_sample_size;
    public IsoSampleFlags default_sample_flags;

    public IsoTrackExtendsBox (IsoMovieBox parent, uint32 track_id,
                               uint32 default_sample_description_index,
                               uint32 default_sample_duration,
                               uint32 default_sample_size,
                               IsoSampleFlags default_sample_flags) {
        base (parent, "trex", 0, 0); // Version and flags are 0
        this.track_id = track_id;
        this.default_sample_description_index = default_sample_description_index;
        this.default_sample_duration = default_sample_duration;
        this.default_sample_size = default_sample_size;
        this.default_sample_flags = default_sample_flags;
    }

    public IsoTrackExtendsBox.from_stream (IsoContainerBox parent, string type_code,
                                           IsoInputStream stream, uint64 offset,
                                           uint32 size, uint64 largesize)
            throws Error {
        base.from_stream (parent, type_code, stream, offset, size, largesize);
    }

    public override uint64 parse_from_stream () throws Error {
        // debug ("IsoTrackExtendsBox(%s).parse_from_stream()", this.type_code);
        var bytes_consumed = base.parse_from_stream ();
        var instream = this.source_stream;

        this.track_id = instream.read_uint32 ();

        this.default_sample_description_index = instream.read_uint32 ();
        this.default_sample_duration = instream.read_uint32 ();
        this.default_sample_size = instream.read_uint32 ();
        this.default_sample_flags = new IsoSampleFlags.from_uint32 (instream.read_uint32 ());
        bytes_consumed += 20;

        if (bytes_consumed != this.size) {
            throw new IsoBoxError.PARSE_ERROR
                          ("box size mismatch for %s (parsed %lld, box size %lld)"
                           .printf (this.type_code, bytes_consumed, this.size));
        }
        return this.size;
    }

    protected override void update () throws IsoBoxError {
        this.track_box = null;
        base.update ();
    }

    protected override void update_box_fields (uint64 payload_size = 0) throws IsoBoxError {
        base.update_box_fields (payload_size + 20);
    }

    public override void write_fields_to_stream (IsoOutputStream outstream) throws Error {
        base.write_fields_to_stream (outstream);
        outstream.put_uint32 (this.track_id);
        outstream.put_uint32 (this.default_sample_description_index);
        outstream.put_uint32 (this.default_sample_duration);
        outstream.put_uint32 (this.default_sample_size);
        outstream.put_uint32 (this.default_sample_flags.to_uint32 ());
    }

    /**
     * Return the IsoTrackBox with the same track_id as this IsoTrackExtendsBox
     *
     * Note that this will cache the box reference until update() is called.
     */
    public IsoTrackBox get_track_box () throws IsoBoxError {
        if (this.track_box == null) {
            var movie_box = get_ancestor_by_level (2, typeof (IsoMovieBox)) as IsoMovieBox;
            this.track_box = movie_box.get_track_for_id (this.track_id);
        }
        return this.track_box;
    }

    /**
     * Get the timescale associated with this TrackExtendsBox (the associated Track's
     * media timescale)
     */
    public uint32 get_timescale () throws IsoBoxError {
        return get_track_box ().get_media_timescale ();
    }

    /**
     * This will get the default sample duration, in seconds (accounting for the timescale)
     */
    public float get_default_sample_duration_seconds () throws IsoBoxError {
        check_loaded ("IsoTrackExtendsBox.get_default_sample_duration_seconds");
        return (float)this.default_sample_duration / get_timescale ();
    }

    public override string to_string () {
        var builder = new StringBuilder ("IsoTrackExtendsBox[");
        builder.append (base.to_string ());
        try {
            builder.append_printf (",track_id %u,sample_description_index %u,sample_duration %u (%0.2fs),sample_size %u,default %s",
                                   this.track_id, this.default_sample_description_index,
                                   this.default_sample_duration,
                                   this.get_default_sample_duration_seconds (),
                                   this.default_sample_size,
                                   this.default_sample_flags.to_string ());
        } catch (IsoBoxError e) {
            builder.append (e.message);
        }
        builder.append_c (']');
        return builder.str;
    }

    public override void to_printer (IsoBox.LinePrinter printer, string prefix) {
        printer (prefix + to_string ());
    }
} // END class IsoTrackExtendsBox

/**
 * moof box
 * 
 * The movie fragments extend the presentation in time. They provide the information that
 * would previously have been in the Movie Box. The actual samples are in Media Data Boxes,
 * as usual, if they are in the same file. The data reference index is in the sample
 * description, so it is possible to build incremental presentations where the media data
 * is in files other than the file containing the Movie Box.
 */
public class Rygel.IsoMovieFragmentBox : IsoContainerBox {
    // Box cache references (MAKE SURE these are nulled out in update())
    protected IsoMovieBox movie_box = null;

    public IsoMovieFragmentBox (IsoContainerBox parent) {
        base (parent, "moof");
    }

    public IsoMovieFragmentBox.from_stream (IsoContainerBox parent, string type_code,
                                            IsoInputStream stream, uint64 offset,
                                            uint32 size, uint64 largesize)
            throws Error {
        base.from_stream (parent, type_code, stream, offset, size, largesize);
    }

    public override uint64 parse_from_stream () throws Error {
        // debug ("IsoMovieFragmentBox(%s).parse_from_stream()", this.type_code);
        var bytes_consumed = base.parse_from_stream (); // IsoContainer/IsoBox
        this.children = base.read_boxes (this.source_offset + bytes_consumed,
                                         this.size - bytes_consumed);
        return this.source_size; // Everything in the box was consumed
    }

    protected override void update () throws IsoBoxError {
        this.movie_box = null;
        base.update ();
    }
    protected override void update_box_fields (uint64 payload_size = 0) throws IsoBoxError {
        base.update_box_fields (payload_size);
    }

    public override void write_fields_to_stream (IsoOutputStream outstream) throws Error {
        base.write_fields_to_stream (outstream);
        foreach (var box in this.children) {
            box.write_to_stream (outstream);
        }
    }

    public IsoMovieBox get_movie_box () throws IsoBoxError {
        if (this.movie_box == null) {
            var root_container = get_root_container ();
            if (root_container is IsoFileContainerBox) {
                this.movie_box = (root_container as IsoFileContainerBox).get_movie_box ();
            } else {
                this.movie_box = root_container.first_box_of_class (typeof (IsoMovieBox))
                                 as IsoMovieBox;
            }
        }
        return this.movie_box;
    }

    /**
     * Return the duration of the longest track fragement, in movie timescale
     */
    public uint64 get_longest_track_duration () throws IsoBoxError {
        check_loaded ("IsoMovieFragmentBox.get_longest_track_duration");
        uint64 longest_track_duration = 0;
        var movie_timescale = get_movie_box ().get_header_box ().timescale;
        foreach (var cur_box in this.children) {
            if (cur_box is IsoTrackFragmentBox) {
                var track_fragment_box = cur_box as IsoTrackFragmentBox;
                var track_duration = track_fragment_box.get_duration (movie_timescale);
                if (track_duration > longest_track_duration) {
                    longest_track_duration = track_duration;
                }
            }
        }
        return longest_track_duration;
    }

    /**
     * Return the track fragment with the given track_id.
     *
     * Throws IsoBoxError.BOX_NOT_FOUND if no track fragment exists with the given track_id
     */
    public IsoTrackFragmentBox get_track_fragment (uint track_id) throws IsoBoxError {
        check_loaded ("IsoMovieFragmentBox.get_track_fragment");
        foreach (var cur_box in this.children) {
            if (cur_box is IsoTrackFragmentBox) {
                var track_fragment_box = cur_box as IsoTrackFragmentBox;
                if (track_fragment_box.get_header_box ().track_id == track_id) {
                    return track_fragment_box;
                }
            }
        }
        throw new IsoBoxError.BOX_NOT_FOUND
                              (this.to_string() + " does not have an IsoTrackFragmentBox with track_id "
                               + track_id.to_string ());
    }

    /**
     * Remove sample references before the designated AccessPoint and adjust the referenced
     * mdat(s) to exclude the sample data.
     *
     * Note: the size of the updated MovieBox won't reflect the box changed until
     * update_children() & update() are called.
     *
     * The number of bytes removed from the mdat(s) is returned in mdat_bytes_removed.
     */
    public void remove_samples_before_point (IsoTrackRunBox.AccessPoint target_point,
                                            out uint64 mdat_bytes_removed)
            throws IsoBoxError {
        // TODO: Implement me
        mdat_bytes_removed = 0;
    }

    /**
     * Remove sample references after the designated AccessPoint and adjust the referenced
     * mdat(s) to exclude the sample data.
     *
     * Note: the size of the updated MovieBox won't reflect the box changed until
     * update_children() & update() are called.
     *
     * The number of bytes removed from the mdat(s) is returned in mdat_bytes_removed
     */
    public void remove_samples_after_point (IsoTrackRunBox.AccessPoint target_point,
                                            out uint64 mdat_bytes_removed)
            throws IsoBoxError {
        // TODO: Implement me
        mdat_bytes_removed = 0;
    }

    /**
     * Adjust all offset references by byte_adjustment
     */
    public void adjust_offsets (int64 byte_adjustment) throws IsoBoxError {
        check_loaded ("IsoMovieFragmentBox.adjust_offsets",byte_adjustment.to_string ());
        foreach (var cur_box in this.children) {
            if (cur_box is IsoTrackFragmentBox) {
                var track_fragment_box = cur_box as IsoTrackFragmentBox;
                track_fragment_box.adjust_offsets (byte_adjustment);
            }
        }
    }

    public override string to_string () {
        return "IsoMovieFragmentBox[" + base.to_string () + "," + base.children_to_string () + "]";
    }

    public override void to_printer (IsoBox.LinePrinter printer, string prefix) {
        printer (prefix + "IsoMovieFragmentBox[" + base.to_string () + "] {");
        base.children_to_printer (printer, prefix + "  ");
        printer (prefix + "}");
    }
} // END class IsoMovieFragmentBox

/**
 * mfhd box
 *
 * The movie fragment header contains a sequence number, as a safety check. The sequence
 * number usually starts at 1 and must increase for each movie fragment in the file, in the
 * order in which they occur. This allows readers to verify integrity of the sequence; it is
 * an error to construct a file where the fragments are out of sequence.
 */
public class Rygel.IsoMovieFragmentHeaderBox : IsoFullBox {
    public uint32 sequence_number;

    public IsoMovieFragmentHeaderBox (IsoMovieBox parent, uint32 sequence_number) {
        base (parent, "mfhd", 0, 0);
        this.sequence_number = sequence_number;
    }

    public IsoMovieFragmentHeaderBox.from_stream (IsoContainerBox parent, string type_code,
                                                 IsoInputStream stream, uint64 offset,
                                                 uint32 size, uint64 largesize)
            throws Error {
        base.from_stream (parent, type_code, stream, offset, size, largesize);
    }

    public override uint64 parse_from_stream () throws Error {
        // debug ("IsoMovieFragmentHeaderBox(%s).parse_from_stream()", this.type_code);
        var bytes_consumed = base.parse_from_stream ();
        this.sequence_number = this.source_stream.read_uint32 ();
        bytes_consumed += 4;

        if (bytes_consumed != this.size) {
            throw new IsoBoxError.PARSE_ERROR
                          ("box size mismatch for %s (parsed %lld, box size %lld)"
                           .printf(this.type_code, bytes_consumed, this.size));
        }
        return this.size;
    }

    protected override void update_box_fields (uint64 payload_size = 0) throws IsoBoxError {
        base.update_box_fields (payload_size+4);
    }

    public override void write_fields_to_stream (IsoOutputStream outstream) throws Error {
        base.write_fields_to_stream (outstream);
        outstream.put_uint32 (this.sequence_number);
    }

    public override string to_string () {
        return "IsoMovieFragmentHeaderBox[%s,sequence_number %u]"
               .printf(base.to_string (), this.sequence_number);
    }

    public override void to_printer (IsoBox.LinePrinter printer, string prefix) {
        printer (prefix + this.to_string ());
    }
} // END class IsoMovieFragmentHeaderBox

/**
 * traf box
 *
 * Within the movie fragment there is a set of track fragments, zero or more per track.
 * The track fragments in turn contain zero or more track runs, each of which document a
 * contiguous run of samples for that track. Within these structures, many fields are
 * optional and can be defaulted.
 */
public class Rygel.IsoTrackFragmentBox : IsoContainerBox {
    // Box cache references (MAKE SURE these are nulled out in update())
    protected IsoTrackFragmentHeaderBox track_frag_header_box = null;
    protected IsoTrackExtendsBox track_extends_box = null;
    protected IsoMediaBox media_box = null;
    // Cached values (MAKE SURE these are nulled out in update())
    protected bool total_duration_cached = false;
    protected uint64 total_duration;
    protected bool total_sample_size_cached = false;
    protected uint64 total_sample_size;

    public IsoTrackFragmentBox (IsoMovieFragmentBox parent) {
        base (parent, "traf");
    }

    public IsoTrackFragmentBox.from_stream (IsoContainerBox parent, string type_code,
                                            IsoInputStream stream, uint64 offset,
                                            uint32 size, uint64 largesize)
            throws Error {
        base.from_stream (parent, type_code, stream, offset, size, largesize);
    }

    public override uint64 parse_from_stream () throws Error {
        // debug ("IsoTrackFragmentBox(%s).parse_from_stream()", this.type_code);
        var bytes_consumed = base.parse_from_stream (); // IsoContainer/IsoBox
        this.children = base.read_boxes (this.source_offset + bytes_consumed,
                                         this.size - bytes_consumed);
        return this.source_size; // Everything in the box was consumed
    }

    protected override void update () throws IsoBoxError {
        track_frag_header_box = null;
        track_extends_box = null;
        media_box = null;
        total_duration_cached = false;
        total_sample_size_cached = false;
        base.update ();
    }

    protected override void update_box_fields (uint64 payload_size = 0) throws IsoBoxError {
        base.update_box_fields (payload_size);
    }

    public override void write_fields_to_stream (IsoOutputStream outstream) throws Error {
        base.write_fields_to_stream (outstream);
        foreach (var box in this.children) {
            box.write_to_stream (outstream);
        }
    }

    /**
     * Return the IsoTrackFragmentHeaderBox within the IsoTrackFragmentBox
     *
     * Note that this will cache the box reference until update() is called.
     */
    public IsoTrackFragmentHeaderBox get_header_box () throws IsoBoxError {
        if (this.track_frag_header_box == null) {
            this.track_frag_header_box = first_box_of_class (typeof (IsoTrackFragmentHeaderBox))
                                         as IsoTrackFragmentHeaderBox;
        }   
        return this.track_frag_header_box;
    }

    /**
     * Return the IsoTrackExtendsBox with the same track_id as this IsoTrackFragmentBox
     *
     * Note that this will cache the box reference until update() is called.
     */
    public IsoTrackExtendsBox get_track_extends_box () throws IsoBoxError {
        if (this.track_extends_box == null) {
            var track_id = get_header_box ().track_id;
            var movie_box = get_movie_fragment_box ().get_movie_box ();
            this.track_extends_box = movie_box.get_extends_box ()
                                              .get_track_extends_for_track_id (track_id);
        }   
        return this.track_extends_box;
    }

    public IsoMovieFragmentBox get_movie_fragment_box () throws IsoBoxError {
        return get_parent_box (typeof (IsoMovieFragmentBox)) as IsoMovieFragmentBox;
    }

    /**
     * Return the IsoMediaBox associated with this TrackFragment in the MovieBox
     */
    public IsoMediaBox get_media_box () throws IsoBoxError {
        if (this.media_box == null) {
            this.media_box = get_track_extends_box ().get_track_box ().get_media_box ();
        }
        return this.media_box;
    }

    /**
     * Get the timescale associated with this Track Fragment (the associated Track's
     * media timescale)
     */
    public uint32 get_timescale () throws IsoBoxError {
        return get_media_box ().get_header_box ().timescale;
    }

    /**
     * Calculate the total duration for all track runs in the TrackFragment
     * (in the track's timescale)
     */
    public uint64 get_duration (uint32 timescale=0) throws IsoBoxError {
        check_loaded ("IsoTrackFragmentBox.get_duration");
        if (!this.total_duration_cached) {
            this.total_duration = 0;
            if (!get_header_box ().flag_set (IsoTrackFragmentHeaderBox.DURATION_IS_EMPTY_FLAG)) {
                var track_run_boxes = get_boxes_by_class (typeof (IsoTrackRunBox));
                foreach (var box in track_run_boxes) {
                    this.total_duration += (box as IsoTrackRunBox).get_total_sample_duration ();
                }
            }
            this.total_duration_cached = true;
        }
        if (timescale == 0) {
            return this.total_duration;
        } else {
            // Convert the value
            var media_header_box = get_media_box ().get_header_box ();
            return media_header_box.from_media_time_to (this.total_duration, timescale);
        }
    }

    /**
     * Calculate the total size for all samples in all track runs in the TrackFragment
     */
    public uint64 get_total_sample_size () throws IsoBoxError {
        check_loaded ("IsoTrackFragmentBox.get_total_sample_size");
        if (!this.total_sample_size_cached) {
            this.total_sample_size = 0;
            var track_run_boxes = get_boxes_by_class (typeof (IsoTrackRunBox));
            foreach (var box in track_run_boxes) {
                this.total_sample_size += (box as IsoTrackRunBox).get_total_sample_size ();
            }
            this.total_sample_size_cached = true;
        }
        return this.total_sample_size;
    }

    /**
     * Get the random access point times (in timescale units) and associated offsets
     *
     * track_time_offset will be incremented according to the duration of all samples in
     * the track fragment
     */
    public Gee.List<IsoAccessPoint> get_random_access_points
            (Gee.List<IsoAccessPoint> ? access_point_list,
             ref uint32 sample_number, ref uint64 track_time_offset)
                throws IsoBoxError {
        check_loaded ("IsoTrackFragmentBox.get_random_access_points");
        var parent_movie_fragment = get_movie_fragment_box ();
        var track_header = get_header_box ();

        var access_points = access_point_list ?? new Gee.ArrayList<IsoTrackRunBox.AccessPoint> ();
        if (track_header.flag_set (IsoTrackFragmentHeaderBox.DURATION_IS_EMPTY_FLAG)) {
            return access_points; // No samples, no runs. We're done here...
        }
        // Calculate the base position for the runs in the track fragment
        uint64 base_fragment_offset;
        if (track_header.flag_set (IsoTrackFragmentHeaderBox.BASE_DATA_OFFSET_PRESENT_FLAG)) {
            base_fragment_offset = track_header.base_data_offset;
        } else if (track_header.flag_set (IsoTrackFragmentHeaderBox.DEFAULT_BASE_IS_MOOF_FLAG)) {
            base_fragment_offset = parent_movie_fragment.source_offset;
        } else {
            base_fragment_offset = parent_movie_fragment.source_offset + parent_movie_fragment.size;
        }
        // Walk the track runs
        uint64 file_byte_offset = base_fragment_offset;
        var track_run_boxes = get_boxes_by_class (typeof (IsoTrackRunBox));
        foreach (var box in track_run_boxes) {
            var track_run = box as IsoTrackRunBox;
            if (track_run.flag_set (IsoTrackRunBox.DATA_OFFSET_PRESENT_FLAG)) {
                file_byte_offset = base_fragment_offset + track_run.data_offset;
            }
            track_run.get_random_access_points (access_points,
                                                ref sample_number,
                                                ref track_time_offset,
                                                ref file_byte_offset);
        }
        return access_points;
    }

    public IsoAccessPoint ? access_point_for_time (uint64 target_time, bool sample_after,
                                                   ref uint32 sample_number,
                                                   ref uint64 track_time_offset)
                throws IsoBoxError {
        check_loaded ("IsoTrackFragmentBox.access_point_for_time");
        var parent_movie_fragment = get_movie_fragment_box ();
        var track_header = get_header_box ();

        if (track_header.flag_set (IsoTrackFragmentHeaderBox.DURATION_IS_EMPTY_FLAG)) {
            throw new IsoBoxError.VALUE_TOO_LARGE ("IsoTrackFragmentBox.access_point_for_time: DURATION_IS_EMPTY_FLAG is set for "
                                                   + this.to_string ());
        }
        // Calculate the base position for the runs in the track fragment
        uint64 base_fragment_offset;
        if (track_header.flag_set (IsoTrackFragmentHeaderBox.BASE_DATA_OFFSET_PRESENT_FLAG)) {
            base_fragment_offset = track_header.base_data_offset;
        } else if (track_header.flag_set (IsoTrackFragmentHeaderBox.DEFAULT_BASE_IS_MOOF_FLAG)) {
            base_fragment_offset = parent_movie_fragment.source_offset;
        } else {
            base_fragment_offset = parent_movie_fragment.source_offset + parent_movie_fragment.size;
        }
        // Walk the track runs
        uint64 file_byte_offset = base_fragment_offset;
        var track_run_boxes = get_boxes_by_class (typeof (IsoTrackRunBox));
        foreach (var box in track_run_boxes) {
            var track_run = box as IsoTrackRunBox;
            if (track_run.flag_set (IsoTrackRunBox.DATA_OFFSET_PRESENT_FLAG)) {
                file_byte_offset = base_fragment_offset + track_run.data_offset;
            }
            var run_access_point = track_run.access_point_for_time (target_time, sample_after,
                                                                    ref sample_number,
                                                                    ref track_time_offset,
                                                                    ref file_byte_offset);
            if (run_access_point != null) {
                return run_access_point;
            }
        }
        return null;
    }

    /**
     * Adjust all offset references by byte_adjustment
     */
    public void adjust_offsets (int64 byte_adjustment) throws IsoBoxError {
        check_loaded ("IsoTrackFragmentBox.adjust_offsets",byte_adjustment.to_string ());
        var track_header = get_header_box ();
        if (track_header.flag_set (IsoTrackFragmentHeaderBox.BASE_DATA_OFFSET_PRESENT_FLAG)) {
            track_header.base_data_offset += byte_adjustment;
        }
        // Nothing to do in other cases - the track run offsets are anchored to the MovieFragment
    }

    public override string to_string () {
        return "IsoTrackFragmentBox[" + base.to_string () + "," + base.children_to_string () + "]";
    }
    
    public override void to_printer (IsoBox.LinePrinter printer, string prefix) {
        var builder = new StringBuilder (prefix);
        builder.append ("IsoTrackFragmentBox[");
        builder.append (base.to_string ());
        builder.append (",total_sample_duration ");
        try {
            builder.append (get_duration ().to_string ());
        } catch (IsoBoxError err) {
            builder.append (err.message);
        }
        try {
            var timescale = get_timescale ();
            builder.append_printf (" (%0.2fs)", (float)get_duration ()/timescale);
        } catch (IsoBoxError err) {
            builder.append_printf (" (%s)", err.message);
        }
        builder.append (",total_sample_size ");
        try {
            builder.append (get_total_sample_size ().to_string ());
        } catch (IsoBoxError err) {
            builder.append (err.message);
        }
        builder.append ("] {");
        printer (builder.str);
        base.children_to_printer (printer, prefix + "  ");
        printer (prefix + "}");
    }
} // END IsoTrackFragmentBox

/**
 * tfhd box
 *
 * Each movie fragment can add zero or more fragments to each track; and a track fragment
 * can add zero or more contiguous runs of samples. The track fragment header sets up
 * information and defaults used for those runs of samples.
 */
public class Rygel.IsoTrackFragmentHeaderBox : IsoFullBox {
    /**
     * Indicates the presence of the base-data-offset field.
     *   This provides an explicit anchor for the data offsets in each track run (see below).
     *   If not provided, the base-data-offset for the first track in the movie fragment is
     *   the position of the first byte of the enclosing Movie Fragment Box, and for second
     *   and subsequent track fragments, the default is the end of the data defined by the
     *   preceding fragment. Fragments 'inheriting' their offset in this way must all use the
     *   same data-reference (i.e., the data for these tracks must be in the same file).
     */
    public const uint32 BASE_DATA_OFFSET_PRESENT_FLAG = 0x01;

    /**
     * Indicates the presence of this field, which over-rides, in this fragment, the default
     * set up in the Track Extends Box.
     */
    public const uint32 SAMPLE_DESCRIPTION_INDEX_PRESENT_FLAG = 0x02;

    public const uint32 DEFAULT_SAMPLE_DURATION_PRESENT_FLAG = 0x08;
    public const uint32 DEFAULT_SAMPLE_SIZE_PRESENT_FLAG = 0x10;
    public const uint32 DEFAULT_SAMPLE_FLAGS_PRESENT_FLAG = 0x20;

    /**
     * Indicates that the duration provided in either default-sample-duration, or by the
     * default-duration in the Track Extends Box, is empty, i.e. that there are no samples
     * for this time interval. It is an error to make a presentation that has both edit
     * lists in the Movie Box, and empty-duration fragments.
     */
    public const uint32 DURATION_IS_EMPTY_FLAG = 0x10000;

    /**
     * If base-data-offset-present is zero, this indicates that the base-data-offset for this
     * track fragment is the position of the first byte of the enclosing Movie Fragment Box.
     * Support for the default-base-is-moof flag is require under the ‘iso5’ brand, and it
     * shall not be used in brands or compatible brands earlier than iso5.
     */
    public const uint32 DEFAULT_BASE_IS_MOOF_FLAG = 0x20000;

    public uint32 track_id;
    public uint64 base_data_offset; // optional (indicated by flags)
    public uint32 sample_description_index; // optional (indicated by flags)
    public uint32 default_sample_duration; // optional (indicated by flags)
    public uint32 default_sample_size; // optional (indicated by flags)
    public IsoSampleFlags default_sample_flags; // optional (indicated by flags)

    /**
     * This constructor will create a IsoTrackFragmentBox for the track_id presuming that
     * all optional fields are not set. Optional fields should be set via the get/set
     * functions after construction.
     */
    public IsoTrackFragmentHeaderBox (IsoMovieBox parent, uint32 track_id) {
        base (parent, "tfhd", 0, 0);
        this.track_id = track_id;
    }

    public IsoTrackFragmentHeaderBox.from_stream (IsoContainerBox parent, string type_code,
                                                  IsoInputStream stream, uint64 offset,
                                                  uint32 size, uint64 largesize)
            throws Error {
        base.from_stream (parent, type_code, stream, offset, size, largesize);
        
    }

    public override uint64 parse_from_stream () throws Error {
        // debug ("IsoTrackFragmentHeaderBox(%s).parse_from_stream()", this.type_code);
        var bytes_consumed = base.parse_from_stream ();
        var instream = this.source_stream;

        this.track_id = instream.read_uint32 ();
        bytes_consumed += 4;

        if (flag_set_loaded (BASE_DATA_OFFSET_PRESENT_FLAG)) {
            this.base_data_offset = instream.read_uint64 ();
            bytes_consumed += 8;
        }
        if (flag_set_loaded (SAMPLE_DESCRIPTION_INDEX_PRESENT_FLAG)) {
            this.sample_description_index = instream.read_uint32 ();
            bytes_consumed += 4;
        }
        if (flag_set_loaded (DEFAULT_SAMPLE_DURATION_PRESENT_FLAG)) {
            this.default_sample_duration = instream.read_uint32 ();
            bytes_consumed += 4;
        }
        if (flag_set_loaded (DEFAULT_SAMPLE_SIZE_PRESENT_FLAG)) {
            this.default_sample_size = instream.read_uint32 ();
            bytes_consumed += 4;
        }
        if (flag_set_loaded (DEFAULT_SAMPLE_FLAGS_PRESENT_FLAG)) {
            this.default_sample_flags = new IsoSampleFlags.from_uint32(instream.read_uint32 ());
            bytes_consumed += 4;
        }

        if (bytes_consumed != this.size) {
            throw new IsoBoxError.PARSE_ERROR
                          ("box size mismatch for %s (parsed %lld, box size %lld) at offset %llu"
                           .printf(this.type_code, bytes_consumed, this.size,
                                   this.source_offset));
        }
        return this.size;
    }

    protected override void update_box_fields (uint64 payload_size = 0) throws IsoBoxError {
        payload_size += 4 + (flag_set (BASE_DATA_OFFSET_PRESENT_FLAG) ? 8 : 0)
                        + (flag_set (SAMPLE_DESCRIPTION_INDEX_PRESENT_FLAG) ? 4 : 0)
                        + (flag_set (DEFAULT_SAMPLE_DURATION_PRESENT_FLAG) ? 4 : 0)
                        + (flag_set (DEFAULT_SAMPLE_SIZE_PRESENT_FLAG) ? 4 : 0)
                        + (flag_set (DEFAULT_SAMPLE_FLAGS_PRESENT_FLAG) ? 4 : 0);
        base.update_box_fields (payload_size);
    }

    /**
     * Return the IsoTrackFragmentBox containing this IsoTrackFragmentHeaderBox
     *
     * Note that this will cache the box reference until update() is called.
     */
    public IsoTrackFragmentBox get_track_fragment_box () throws IsoBoxError {
        return get_parent_box (typeof (IsoTrackFragmentBox)) as IsoTrackFragmentBox;
    }

    /**
     * Get the default sample_description_index for this IsoTrackFragmentHeaderBox,
     * if defined. If not defined, return the default sample_description_index defined
     * in the track's TrackExtendsBox.
     */
    public uint32 get_default_sample_description_index () throws IsoBoxError {
        if (flag_set (SAMPLE_DESCRIPTION_INDEX_PRESENT_FLAG)) {
            return this.sample_description_index;
        } else {
            var track_extends_box = get_track_fragment_box ().get_track_extends_box ();
            return track_extends_box.default_sample_description_index;
        }
    }

    /**
     * Get the default sample_duration for this IsoTrackFragmentHeaderBox,
     * if defined. If not defined, return the default sample_duration defined
     * in the track's TrackExtendsBox.
     */
    public uint32 get_default_sample_duration () throws IsoBoxError {
        if (flag_set (DEFAULT_SAMPLE_DURATION_PRESENT_FLAG)) {
            return this.default_sample_duration;
        } else {
            var track_extends_box = get_track_fragment_box ().get_track_extends_box ();
            return track_extends_box.default_sample_duration;
        }
    }

    /**
     * Get the default sample_size for this IsoTrackFragmentHeaderBox,
     * if defined. If not defined, return the default sample_size defined
     * in the track's TrackExtendsBox.
     */
    public uint32 get_default_sample_size () throws IsoBoxError {
        if (flag_set (DEFAULT_SAMPLE_SIZE_PRESENT_FLAG)) {
            return this.default_sample_size;
        } else {
            var track_extends_box = get_track_fragment_box ().get_track_extends_box ();
            return track_extends_box.default_sample_size;
        }
    }

    /**
     * Get the default sample_flags for this IsoTrackFragmentHeaderBox,
     * if defined. If not defined, return the default sample_flags defined
     * in the track's TrackExtendsBox.
     */
    public IsoSampleFlags get_default_sample_flags () throws IsoBoxError {
        if (flag_set (DEFAULT_SAMPLE_FLAGS_PRESENT_FLAG)) {
            return this.default_sample_flags;
        } else {
            var track_extends_box = get_track_fragment_box ().get_track_extends_box ();
            return track_extends_box.default_sample_flags;
        }
    }

    /**
     * This will get the default sample duration, in seconds (accounting for the timescale)
     */
    public float get_default_sample_duration_seconds () throws IsoBoxError {
        check_loaded ("IsoTrackFragmentHeaderBox.get_default_sample_duration_seconds");
        if (!flag_set (DEFAULT_SAMPLE_DURATION_PRESENT_FLAG)) {
            throw new IsoBoxError.ENTRY_NOT_FOUND
                          ("IsoTrackFragmentHeaderBox.get_default_sample_duration_seconds(): the DEFAULT_SAMPLE_DURATION_PRESENT_FLAG flag isn't set");
        }
        return (float)this.default_sample_duration / get_track_fragment_box ().get_timescale ();
    }

    public override void write_fields_to_stream (IsoOutputStream outstream) throws Error {
        base.write_fields_to_stream (outstream);
        outstream.put_uint32 (this.track_id);
        if (flag_set (BASE_DATA_OFFSET_PRESENT_FLAG)) {
            outstream.put_uint64 (this.base_data_offset);
        }
        if (flag_set (SAMPLE_DESCRIPTION_INDEX_PRESENT_FLAG)) {
            outstream.put_uint32 (this.sample_description_index);
        }
        if (flag_set (DEFAULT_SAMPLE_DURATION_PRESENT_FLAG)) {
            outstream.put_uint32 (this.default_sample_duration);
        }
        if (flag_set (DEFAULT_SAMPLE_SIZE_PRESENT_FLAG)) {
            outstream.put_uint32 (this.default_sample_size);
        }
        if (flag_set (DEFAULT_SAMPLE_FLAGS_PRESENT_FLAG)) {
            outstream.put_uint32 (this.default_sample_flags.to_uint32 ());
        }
    }

    public override string to_string () {
        var builder = new StringBuilder ("IsoTrackFragmentHeaderBox[");
        builder.append (base.to_string ());
        if (this.loaded) {
            builder.append_printf (",track_id %u",this.track_id);
            if (flag_set_loaded (BASE_DATA_OFFSET_PRESENT_FLAG)) {
                builder.append_printf (",base_data_offset %llu",this.base_data_offset);
            }
            if (flag_set_loaded (SAMPLE_DESCRIPTION_INDEX_PRESENT_FLAG)) {
                builder.append_printf (",sample_description_index %u",
                                       this.sample_description_index);
            }
            if (flag_set_loaded (DEFAULT_SAMPLE_DURATION_PRESENT_FLAG)) {
                builder.append_printf (",default_sample_duration %u",
                                       this.default_sample_duration);
                try {
                    builder.append_printf (" (%0.2fs)", get_default_sample_duration_seconds ());
                } catch (IsoBoxError err) {
                    builder.append_printf (" (%s)", err.message);
                }
            }
            if (flag_set_loaded (DEFAULT_SAMPLE_SIZE_PRESENT_FLAG)) {
                builder.append_printf (",default_sample_size %u",
                                       this.default_sample_size);
            }
            if (flag_set_loaded (DEFAULT_SAMPLE_FLAGS_PRESENT_FLAG)) {
                builder.append (",default ");
                builder.append (this.default_sample_flags.to_string ());
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
} // END class IsoTrackFragmentHeaderBox

/**
 * trun box
 *
 * Within the Track Fragment Box, there are zero or more Track Run Boxes. If the
 * duration-is-empty flag is set in the tf_flags, there are no track runs. A track run
 * documents a contiguous set of samples for a track.
 */
public class Rygel.IsoTrackRunBox : IsoFullBox {
    // Cached values (MAKE SURE these are nulled out in update())
    protected bool total_duration_cached = false;
    protected uint64 total_duration;
    protected bool total_sample_size_cached = false;
    protected uint64 total_sample_size;

    /**
     * indicates that data for this run starts immediately after the data of the previous
     * run, or at the base-data-offset defined by the track fragment header if this is the
     * first run in a track fragment, If the data-offset is present, it is relative to the
     * base-data-offset established in the track fragment header.
     */
    public const uint32 DATA_OFFSET_PRESENT_FLAG = 0x01;

    /**
     * this over-rides the default flags for the first sample only. This makes it possible
     * to record a group of frames where the first is a key and the rest are difference
     * frames, without supplying explicit flags for every sample. If this flag and field
     * are used, sample-flags shall not be present.
     */
    public const uint32 FIRST_SAMPLE_FLAGS_PRESENT_FLAG = 0x04;

    /**
     * indicates that each sample has its own duration, otherwise the default is used.
     */
    public const uint32 SAMPLE_DURATION_PRESENT_FLAG = 0x100;
    
    /**
     * indicates that each sample has its own size, otherwise the default is used.
     */
    public const uint32 SAMPLE_SIZE_PRESENT_FLAG = 0x200;

    /**
     * indicates that each sample has its own flags, otherwise the default is used.
     */
    public const uint32 SAMPLE_FLAGS_PRESENT_FLAG = 0x400;

    /**
     * indicates that each sample has a composition time offset (e.g. as used for I/P/B
     * video in MPEG).
     */
    public const uint32 SAMPLE_COMP_TIME_OFFSETS_PRESENT = 0x800;

    public int32 data_offset;
    public IsoSampleFlags first_sample_flags;

    public struct SampleEntry { // These are all optional, based on the flags set
        uint32 sample_duration;
        uint32 sample_size;
        IsoSampleFlags sample_flags;
        uint32 sample_comp_time_offset;
    }
    public SampleEntry[] sample_entry_array;

    public uint64 first_sample_offset = 0; // 0 == undefined

    public class AccessPoint : IsoAccessPoint {
        public IsoTrackRunBox track_run_box;
        public uint32 sample_run_index; /** The sample index within the track run (0-based) */
        public IsoSampleFlags sample_flags; /** effective sample flags for the */

        public AccessPoint (IsoTrackRunBox track_run_box, uint64 time_offset, uint64 byte_offset,
                            uint32 sample_number, uint32 sample_run_index, IsoSampleFlags sample_flags) {
            IsoSampleTableBox sample_table = null;
            if (track_run_box != null) {
                try { // to extract the track box
                    sample_table = track_run_box.get_track_fragment_box ()
                                                 .get_track_extends_box ()
                                                  .get_track_box ()
                                                   .get_sample_table_box ();
                } catch (IsoBoxError e) {}
            }
            base (sample_table, time_offset, byte_offset, sample_number);
            this.track_run_box = track_run_box;
            this.sample_run_index = sample_run_index;
            this.sample_flags = sample_flags;
        }
        public override string to_string () {
            return "IsoTrackRunBox.AccessPoint[%s,sample_run_index %u,%s,%s]"
                   .printf (base.to_string (),this.sample_run_index,
                            this.track_run_box.to_string(),
                            this.sample_flags.to_string());
        }
    }

    public IsoTrackRunBox (IsoContainerBox parent) {
        base (parent, "trun", 0, 0); // Version/flags 0
        this.sample_entry_array = new SampleEntry[0];
    }

    public IsoTrackRunBox.from_stream (IsoContainerBox parent, string type_code,
                                           IsoInputStream stream, uint64 offset,
                                           uint32 size, uint64 largesize)
            throws Error {
        base.from_stream (parent, type_code, stream, offset, size, largesize);
    }

    public override uint64 parse_from_stream () throws Error {
        // debug ("IsoTrackRunBox(%s).parse_from_stream()", this.type_code);
        var bytes_consumed = base.parse_from_stream ();
        var instream = this.source_stream;

        var sample_count = instream.read_uint32 ();
        bytes_consumed += 4;

        if (flag_set_loaded (DATA_OFFSET_PRESENT_FLAG)) {
            this.data_offset = instream.read_int32 ();
            bytes_consumed += 4;
        }

        if (flag_set_loaded (FIRST_SAMPLE_FLAGS_PRESENT_FLAG)) {
            this.first_sample_flags = new IsoSampleFlags.from_uint32 (instream.read_uint32 ());
            bytes_consumed += 4;
        }

        var sample_duration_present = flag_set_loaded (SAMPLE_DURATION_PRESENT_FLAG);
        var sample_size_present = flag_set_loaded (SAMPLE_SIZE_PRESENT_FLAG);
        var sample_flags_present = flag_set_loaded (SAMPLE_FLAGS_PRESENT_FLAG);
        var sample_comp_time_offset_present = flag_set_loaded (SAMPLE_COMP_TIME_OFFSETS_PRESENT);

        // Sample entries may be 0, 4, 8, 12, or 16 bytes, depending on flags...
        uint8 bytes_per_sample_entry = (sample_duration_present ? 4 : 0)
                                       + (sample_size_present ? 4 : 0)
                                       + (sample_flags_present ? 4 : 0)
                                       + (sample_comp_time_offset_present ? 4 : 0);

        this.sample_entry_array = new SampleEntry[sample_count];

        for (uint32 i=0; i<sample_count; i++) {
            if (sample_duration_present) {
                this.sample_entry_array[i].sample_duration = instream.read_uint32 ();
            }
            if (sample_size_present) {
                this.sample_entry_array[i].sample_size = instream.read_uint32 ();
            }
            if (sample_flags_present) {
                this.sample_entry_array[i].sample_flags
                                        = new IsoSampleFlags.from_uint32 (instream.read_uint32 ());
            }
            if (sample_comp_time_offset_present) {
                this.sample_entry_array[i].sample_comp_time_offset = instream.read_uint32 ();
            }
        }

        bytes_consumed += bytes_per_sample_entry * sample_count;

        if (bytes_consumed != this.size) {
            throw new IsoBoxError.PARSE_ERROR
                          ("box size mismatch for %s (parsed %lld, box size %lld) at offset %llu"
                           .printf(this.type_code, bytes_consumed, this.size,
                                   this.source_offset));
        }
        return this.size;
    }

    protected override void update () throws IsoBoxError {
        this.total_duration_cached = false;
        this.total_sample_size_cached = false;
        this.first_sample_offset = 0;
        base.update ();
    }

    protected override void update_box_fields (uint64 payload_size = 0) throws IsoBoxError {

        payload_size += 4 + (flag_set (DATA_OFFSET_PRESENT_FLAG) ? 4 : 0)
                        + (flag_set (FIRST_SAMPLE_FLAGS_PRESENT_FLAG) ? 4 : 0);
        uint8 bytes_per_sample_entry = (flag_set (SAMPLE_DURATION_PRESENT_FLAG) ? 4 : 0)
                                       + (flag_set (SAMPLE_SIZE_PRESENT_FLAG) ? 4 : 0)
                                       + (flag_set (SAMPLE_FLAGS_PRESENT_FLAG) ? 4 : 0)
                                       + (flag_set (SAMPLE_COMP_TIME_OFFSETS_PRESENT) ? 4 : 0);
        payload_size += sample_entry_array.length * bytes_per_sample_entry;
        base.update_box_fields (payload_size);
    }

    public bool data_offset_present () throws IsoBoxError {
        return flag_set (DATA_OFFSET_PRESENT_FLAG);
    }

    /**
     * Return the IsoTrackFragmentBox containing this IsoTrackRunBox
     *
     * Note that this will cache the box reference until update() is called.
     */
    public IsoTrackFragmentBox get_track_fragment_box () throws IsoBoxError {
        return get_parent_box (typeof (IsoTrackFragmentBox)) as IsoTrackFragmentBox;
    }

    /**
     * Calculate the total duration for all samples in the run and return it
     * (in the track's timescale)
     *
     * Note: This will use the Track Fragment's default duration if the samples in this
     *       run don't contain duration values.
     */
    public uint64 get_total_sample_duration () throws IsoBoxError {
        check_loaded ("IsoTrackRunBox.get_total_sample_duration");
        if (!this.total_duration_cached) {
            var entry_count = this.sample_entry_array.length;
            if (flag_set (SAMPLE_DURATION_PRESENT_FLAG)) {
                // debug ("IsoTrackRunBox.get_total_sample_duration: Adding sample durations...");
                this.total_duration = 0;
                for (uint32 i=0; i<entry_count; i++) {
                    this.total_duration += this.sample_entry_array[i].sample_duration;
                }
            } else {
                // debug ("IsoTrackRunBox.get_total_sample_duration: Calculating total sample duration...");
                var track_fragment_header = get_track_fragment_box ().get_header_box ();
                this.total_duration = track_fragment_header.get_default_sample_duration ()
                                      * entry_count;
            }
            this.total_duration_cached = true;
        }
        return this.total_duration;
    }

    /**
     * Calculate the total size for all samples in the run and return it (in bytes) 
     *
     * Note: This will use the Track Fragment's default duration if the samples in this
     *       run don't contain duration values.
     */
    public uint64 get_total_sample_size () throws IsoBoxError {
        check_loaded ("IsoTrackRunBox.get_total_sample_size");
        if (!this.total_sample_size_cached) {
            var entry_count = this.sample_entry_array.length;
            if (flag_set (SAMPLE_DURATION_PRESENT_FLAG)) {
                this.total_sample_size = 0;
                for (uint32 i=0; i<entry_count; i++) {
                    this.total_sample_size += this.sample_entry_array[i].sample_size;
                }
            } else {
                var track_fragment_header = get_track_fragment_box ().get_header_box ();
                this.total_sample_size = track_fragment_header.get_default_sample_size ()
                                         * entry_count;
            }
            this.total_sample_size_cached = true;
        }
        return this.total_sample_size;
    }

    /**
     * Get the random access point times and associated byte offsets for the track run
     *
     * sample_number, sample_time, and sample_byte_offset will be incremented while walking
     * the track run, allowing this function to be used across multiple TrackRunBoxes
     * 
     * sample_byte_offset should be set to the byte of the run start (the TrackFragment's
     * base offset or the byte after the preceding run in the fragment). It will be advanced
     * to the byte position 1 beyond the last sample in the run
     *
     * note: the sample_byte_offset will be cached within the IsoTrackRunBox
     */
    public Gee.List<IsoAccessPoint> get_random_access_points
                                     (Gee.List<IsoAccessPoint> ? access_point_list,
                                      ref uint32 sample_number,
                                      ref uint64 sample_time, 
                                      ref uint64 sample_byte_offset)
            throws IsoBoxError {
        // debug ("IsoTrackRunBox.get_random_access_points(sample_number %u,sample_time %llu,sample_byte_offset %llu)",
        //        sample_number,sample_time,sample_byte_offset);

        check_loaded ("IsoTrackRunBox.get_random_access_points");

        var access_points = access_point_list ?? new Gee.ArrayList<AccessPoint> ();

        if (this.sample_entry_array.length == 0) {
            return access_points; // No samples, no AccessPoints
        }

        var track_frag_header = get_track_fragment_box ().get_header_box ();
        var default_sample_flags = track_frag_header.get_default_sample_flags ();
        var default_sample_size = track_frag_header.get_default_sample_size ();
        var default_sample_duration = track_frag_header.get_default_sample_duration ();

        var sample_duration_present = flag_set_loaded (SAMPLE_DURATION_PRESENT_FLAG);
        var sample_size_present = flag_set_loaded (SAMPLE_SIZE_PRESENT_FLAG);
        var sample_flags_present = flag_set_loaded (SAMPLE_FLAGS_PRESENT_FLAG);

        this.first_sample_offset = sample_byte_offset; // cache it

        uint32 cur_index = 0;
        if (flag_set (FIRST_SAMPLE_FLAGS_PRESENT_FLAG)) {
            if (!this.first_sample_flags.sample_is_non_sync_sample) {
                var first_access_point = new AccessPoint
                                             (this,
                                              sample_time,
                                              sample_byte_offset,
                                              sample_number,
                                              cur_index, 
                                              this.first_sample_flags);
                // debug ("  created " + access_point.to_string ());
                access_points.add (first_access_point);
            }
            sample_number ++;
            sample_time += sample_duration_present ? this.sample_entry_array[0].sample_duration
                                                   : default_sample_duration;
            sample_byte_offset += sample_size_present ? this.sample_entry_array[0].sample_size
                                                      : default_sample_size;
            cur_index ++;
        }

        // Walk the samples, look for sync samples, and move time/byte offsets forward
        IsoSampleFlags cur_sample_flags = default_sample_flags;
        while (cur_index < this.sample_entry_array.length) {
            var cur_entry = this.sample_entry_array[cur_index];
            if (sample_flags_present) {
                cur_sample_flags = cur_entry.sample_flags;
            }
            if (!cur_sample_flags.sample_is_non_sync_sample) {
                var access_point = new AccessPoint (this,
                                                    sample_time,
                                                    sample_byte_offset,
                                                    sample_number,
                                                    cur_index,
                                                    cur_sample_flags);
                // debug ("  created " + access_point.to_string ());
                access_points.add (access_point);
            }
            sample_number ++;
            sample_time += sample_duration_present ? cur_entry.sample_duration
                                                   : default_sample_duration;
            sample_byte_offset += sample_size_present ? cur_entry.sample_size
                                                      : default_sample_size;
            cur_index ++;
        }
        return access_points;
    }

    /**
     * This will return an AccessPoint for the corresponding (relative) time within the
     * TrackRunBox, updating sample_number, sample_time, and sample_byte_offset as it
     * progresses.
     *
     * sample_number, sample_time, and sample_byte_offset will be incremented while walking
     * the track run, allowing this function to be used across multiple TrackRunBoxes
     * 
     * sample_byte_offset should be set to the byte of the run start (the TrackFragment's
     * base offset or the byte after the preceding run in the fragment). It will be advanced
     * to the byte position 1 beyond the last sample in the run
     *
     * note: the sample_byte_offset will be cached within the IsoTrackRunBox
     *
     * If a sample for the time is not found in the sample list, null is returned.
     */
    public AccessPoint ? access_point_for_time (uint64 target_time, bool sample_after_time,
                                                ref uint32 sample_number,
                                                ref uint64 sample_time, 
                                                ref uint64 sample_byte_offset)
            throws IsoBoxError {
        check_loaded ("IsoTrackRunBox.access_point_for_time");
        // debug ("IsoTrackRunBox.access_point_for_time(target_time %llu,sample_number %u,sample_time %llu,sample_byte_offset %llu)",
        //        target_time,sample_number,sample_time,sample_byte_offset);
        var track_frag_header = get_track_fragment_box ().get_header_box ();
        var default_sample_flags = track_frag_header.get_default_sample_flags ();
        var default_sample_size = track_frag_header.get_default_sample_size ();
        var default_sample_duration = track_frag_header.get_default_sample_duration ();

        var sample_duration_present = flag_set_loaded (SAMPLE_DURATION_PRESENT_FLAG);
        var sample_size_present = flag_set_loaded (SAMPLE_SIZE_PRESENT_FLAG);
        var sample_flags_present = flag_set_loaded (SAMPLE_FLAGS_PRESENT_FLAG);

        // Walk the samples looking for the time
        this.first_sample_offset = sample_byte_offset; // cache it

        uint32 cur_index = 0;
        IsoSampleFlags cur_sample_flags = default_sample_flags;
        bool return_next_sample = false;
        while (cur_index < this.sample_entry_array.length) {
            var cur_entry = this.sample_entry_array[cur_index];
            if (sample_flags_present) {
                cur_sample_flags = cur_entry.sample_flags;
            }
            var sample_duration = sample_duration_present ? cur_entry.sample_duration
                                                          : default_sample_duration;
            var sample_size = sample_size_present ? cur_entry.sample_size
                                                  : default_sample_size;
            if (target_time < sample_time + sample_duration) {
                if (!sample_after_time || return_next_sample) {
                    return new AccessPoint (this,
                                            sample_time,
                                            sample_byte_offset,
                                            sample_number,
                                            cur_index,
                                            cur_sample_flags);
                } else {
                    return_next_sample = true;
                }
            }
            sample_number ++;
            sample_time += sample_duration;
            sample_byte_offset += sample_size;
            cur_index ++;
        }
        return null;
    }

    public override void write_fields_to_stream (IsoOutputStream outstream) throws Error {
        base.write_fields_to_stream (outstream);
        var entry_count = this.sample_entry_array.length;
        outstream.put_uint32 (entry_count);

        if (flag_set (DATA_OFFSET_PRESENT_FLAG)) {
            outstream.put_int32 (this.data_offset);
        }

        if (flag_set (FIRST_SAMPLE_FLAGS_PRESENT_FLAG)) {
            outstream.put_uint32 (this.first_sample_flags.to_uint32 ());
        }

        var sample_duration_present = flag_set (SAMPLE_DURATION_PRESENT_FLAG);
        var sample_size_present = flag_set (SAMPLE_SIZE_PRESENT_FLAG);
        var sample_flags_present = flag_set (SAMPLE_FLAGS_PRESENT_FLAG);
        var sample_comp_time_offset_present = flag_set (SAMPLE_COMP_TIME_OFFSETS_PRESENT);

        for (uint32 i=0; i<entry_count; i++) {
            if (sample_duration_present) {
                outstream.put_uint32 (this.sample_entry_array[i].sample_duration);
            }
            if (sample_size_present) {
                outstream.put_uint32 (this.sample_entry_array[i].sample_size);
            }
            if (sample_flags_present) {
                outstream.put_uint32 (this.sample_entry_array[i].sample_flags.to_uint32 ());
            }
            if (sample_comp_time_offset_present) {
                outstream.put_uint32 (this.sample_entry_array[i].sample_comp_time_offset);
            }
        }
    }

    public override string to_string () {
        var builder = new StringBuilder ("IsoTrackRunBox[");
        builder.append (base.to_string ());
        if (this.loaded) {
            builder.append_printf (",entry_count %d", this.sample_entry_array.length);
            if (flag_set_loaded (DATA_OFFSET_PRESENT_FLAG)) {
                builder.append_printf (",data_offset %d", this.data_offset);
            }
            if (flag_set_loaded (FIRST_SAMPLE_FLAGS_PRESENT_FLAG)) {
                builder.append(",first ");
                builder.append(this.first_sample_flags.to_string ());
            }
        } else {
            builder.append (",[unloaded fields]");
        }
        builder.append_c (']');
        return builder.str;
    }

    public override void to_printer (IsoBox.LinePrinter printer, string prefix) {
        printer ("%s%s {".printf (prefix,this.to_string ()));   
        if (this.loaded) {
            uint timescale = 0;
            var sample_duration_present = flag_set_loaded (SAMPLE_DURATION_PRESENT_FLAG);
            var sample_size_present = flag_set_loaded (SAMPLE_SIZE_PRESENT_FLAG);
            var sample_flags_present = flag_set_loaded (SAMPLE_FLAGS_PRESENT_FLAG);
            var sample_comp_time_offset_present = flag_set_loaded (SAMPLE_COMP_TIME_OFFSETS_PRESENT);

            try {
                var total_duration = get_total_sample_duration ();
                timescale = get_track_fragment_box ().get_timescale ();
                printer ("%s  total sample duration: %llu (%0.2fs)"
                         .printf (prefix,total_duration, (float)total_duration/timescale));
            } catch (IsoBoxError e) {
                printer ("%s  total sample duration: (error: %s)".printf (prefix,e.message));
            }
            try {
                printer ("%s  total sample size: %llu".printf (prefix,get_total_sample_size ()));
            } catch (IsoBoxError e) {
                printer ("%s  total sample size: (error: %s)".printf (prefix,e.message));
            }
            printer (prefix + "  sample entries {");
            for (uint32 i=0; i<this.sample_entry_array.length; i++) {
                var builder = new StringBuilder (prefix);
                builder.append_printf ("   entry %u: ", i);
                bool need_comma = false;
                if (sample_duration_present) {
                    builder.append_printf ("sample_duration %u",
                                           this.sample_entry_array[i].sample_duration);
                    if (timescale != 0) {
                        builder.append_printf (" (%0.2fs)",
                                               this.sample_entry_array[i].sample_duration/timescale);
                    }
                    need_comma = true;
                }
                if (sample_size_present) {
                    if (need_comma) builder.append_c (',');
                    builder.append_printf ("sample_size %u", this.sample_entry_array[i].sample_size);
                    need_comma = true;
                }
                if (sample_flags_present) {
                    if (need_comma) builder.append_c (',');
                    builder.append ("sample ");
                    builder.append (this.sample_entry_array[i].sample_flags.to_string ());
                    need_comma = true;
                }
                if (sample_comp_time_offset_present) {
                    if (need_comma) builder.append_c (',');
                    builder.append_printf ("sample_comp_time_offset %u",
                                           this.sample_entry_array[i].sample_comp_time_offset);
                    need_comma = true;
                }
                if (this.first_sample_offset != 0) {
                    if (need_comma) builder.append_c (',');
                    builder.append ("first_sample_offset ");
                    builder.append (this.first_sample_offset.to_string ());
                    need_comma = true;
                }
                printer (builder.str);
            }
            printer (prefix + "  }");
        } else {
            printer (prefix + "[unloaded entries]");
        }
        printer ("%s}".printf (prefix));
    }
} // END class IsoTrackRunBox

// For testing
public static int main (string[] args) {
    int MICROS_PER_SEC = 1000000;
	try {
        bool trim_file = false;
        bool with_empty_edit = false;
        bool print_infile = false;
        uint64 print_infile_levels = 0;
        bool print_outfile = false;
        int64 print_outfile_levels = -1;
        bool print_access_points = false;
        bool print_movie_duration = false;
        bool print_track_durations = false;
        bool print_track_box_for_time = false;
        double time_for_track = 0.0;
        string adhoc_test_name = null;
        uint64 time_range_start_us = 0, time_range_end_us = 0;
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
                                if ((i+1 < args.length)
                                     && int64.try_parse (args[i+1], out print_outfile_levels)) {
                                    i++;
                                } else { // Default to printing whatever level is loaded
                                    print_outfile_levels = -1;
                                }
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
                            case "track-for-time":
                                print_track_box_for_time = true;
                                if ((i+1 < args.length)
                                     && double.try_parse (args[i+1], out time_for_track)) {
                                    i++;
                                } else { // Default to printing whatever level is loaded
                                    throw new OptionError.BAD_VALUE (option + " " + args[i] + " requires a parameter");
                                }
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
            stderr.printf ("\t[-print (infile [levels]|outfile [levels]|access-points|movie-duration|track-duration|track-for-time [time])]: Print various details to the standard output\n");
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

        if (print_access_points) {
            //
            // Enumerating track sync points
            //
            // Fully load/parse the input file (0 indicates full depth)
            file_container_box.load_children (0);
            var access_points = file_container_box.get_random_access_points ();
            foreach (var access_point in access_points) {
                stdout.printf ("  time val %9llu:%9.3f seconds, byte offset %12llu, sample %u\n",
                               access_point.time_offset,
                               (float)access_point.time_offset/access_point.get_timescale (),
                               access_point.byte_offset, access_point.sample);
                // stdout.printf ("   %s\n", access_point.to_string ());
            }
            stdout.printf ("}\n");
            stdout.flush ();
        }

        if (adhoc_test_name != null) {
            stdout.printf ("\nRUNNING ADHOC TEST %s {\n", adhoc_test_name);
            
            switch (adhoc_test_name) {
                case "isosampleflags":
                    uint32 [] flags_fields = {0x0cceffff,0x331AAAA}; // Some bit patterns
                    foreach (var dword in flags_fields) {
                        var samp_flags = new IsoSampleFlags.from_uint32 (dword);
                        stdout.printf ("    IsoSampleFlags from %08x:\n      %s\n",
                                       dword, samp_flags.to_string ());
                        stdout.printf ("    %s to uint32:\n      %08x\n",
                                       samp_flags.to_string (), samp_flags.to_uint32 ());
                    }
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
            stdout.printf  ("  Requested time range: %0.3fs-%0.3fs\n",
                            (float)time_range_start_us/MICROS_PER_SEC,
                            (float)time_range_end_us/MICROS_PER_SEC);
            Rygel.IsoAccessPoint start_point, end_point;
            file_container_box.trim_to_time_range (time_range_start_us, time_range_end_us,
                                                   out start_point, out end_point, with_empty_edit);
            stdout.printf  ("  Effective time range: %0.3fs-%0.3fs\n",
                            (float)start_point.time_offset/start_point.get_timescale (),
                            (float)end_point.time_offset/end_point.get_timescale ());
            stdout.printf  ("  Effective byte range: %llu-%llu (0x%llx-0x%llx) (%llu bytes)\n",
                     start_point.byte_offset, end_point.byte_offset,
                     start_point.byte_offset, end_point.byte_offset,
                     end_point.byte_offset-start_point.byte_offset);
            stdout.printf  ("  Generated mp4 is %llu bytes\n", file_container_box.size);
        }

        if (print_movie_duration) {
            // TODO: should the load_children() be in the get_duration methods?
            file_container_box.load_children (5); // need to get down to the MediaHeaderBox
            stdout.printf ("\nMOVIE DURATION: %0.3f seconds\n",
                           file_container_box.get_duration_seconds (true));
            file_container_box.load_children (7); // need to get down to the SampleSizeBox
            stdout.printf ("MEDIA DURATION: %0.3f seconds\n",
                           file_container_box.get_duration_seconds ());
        }

        if (print_track_durations) {
            stdout.printf ("\nTRACK DURATIONS {\n");
            file_container_box.load_children (7); // need to get down to the SampleSizeBox
            var movie_box = file_container_box.get_movie_box ();
            var track_list = movie_box.get_tracks ();
            for (var track_it = track_list.iterator (); track_it.next ();) {
                var track_box = track_it.get ();
                var track_id = track_box.get_header_box ().track_id;
                var track_media_duration = file_container_box
                                           .get_track_duration_seconds (track_id);
                var track_duration = file_container_box.get_track_duration_seconds (track_id,true);
                string media_type;
                switch (track_box.get_media_box ().get_media_type ()) {
                    case Rygel.IsoMediaBox.MediaType.AUDIO:
                        media_type = " (audio)";
                        break;
                    case Rygel.IsoMediaBox.MediaType.VIDEO:
                        media_type = " (video)";
                        break;
                    default:
                        media_type = "";
                        break;
                }
                
                stdout.printf ("  track %u%s: duration %0.2f seconds (media duration %0.2f seconds)\n",
                               track_id, media_type, track_duration, track_media_duration);
            }
            stdout.printf ("}\n");
        }

        if (print_track_box_for_time) {
            file_container_box.load_children (7); // need to get down to the SampleSizeBox
            var movie_box = file_container_box.get_movie_box ();
            var track_box = movie_box.get_primary_media_track ();
            var track_header = track_box.get_header_box ();
            var media_box_header = track_box.get_media_box ().get_header_box ();
            var track_media_time = media_box_header.to_media_time_from
                                      ((uint64)(time_for_track*MICROS_PER_SEC), MICROS_PER_SEC); 
            stdout.printf ("\nTRACK FOR TIME %0.3fs (media time %llu):\n",
                           time_for_track, track_media_time);
            uint64 box_time_offset;
            var found_box = file_container_box.get_track_box_for_time (track_header.track_id,
                                                                       track_media_time,
                                                                       out box_time_offset);
            found_box.to_printer ( (l) => {stdout.puts (l); stdout.putc ('\n');}, "  ");
            stdout.printf ("  Time offset into box: %llu (%0.3fs)\n",
                           box_time_offset,(float)box_time_offset/media_box_header.timescale);
            stdout.flush ();
        }

        if (print_outfile) {
            if (print_outfile_levels >= 0) {
                uint levels = (uint)print_outfile_levels;
                file_container_box.load_children (levels);
            }
            stdout.printf ("\nPARSED OUTPUT CONTAINER:\n");
            file_container_box.to_printer ( (l) => {stdout.puts (l); stdout.putc ('\n');}, "  ");
            stdout.flush ();
        }

        if (out_file != null) {
            //
            // Write new mp4
            //
            stdout.printf ("\nWRITING TO OUTPUT FILE: %s\n", out_file.get_path ());
            file_container_box.load_children (0); // In case it hasn't already been loaded yet
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


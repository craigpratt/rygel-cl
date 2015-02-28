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

public abstract class Rygel.MP2TransportStream {
    public Gee.List<MP2TSPacket> ts_packets = new Gee.ArrayList<MP2TSPacket> ();
    public ExtDataInputStream source_stream;
    public uint64 first_packet_offset;
    public uint64 source_size;
    private bool loaded = false;
    
    public delegate void LinePrinter (string line);

    protected MP2TransportStream.from_stream (ExtDataInputStream stream, 
                                              uint64 offset, uint64 size)
            throws Error {
        this.source_stream = stream;
        this.first_packet_offset = offset;
        this.source_size = size;
    }

    public virtual uint64 parse_from_stream (uint64 ? num_packets=0) throws Error {
        uint64 packet_count = 0, offset = this.first_packet_offset;
        uint bytes_per_packet = 188;
        this.source_stream.seek_to_offset (offset);
        while (offset + bytes_per_packet <= this.source_size) {
            // debug ("Parsing packet %lld at offset %lld", packet_count, offset);
            var ts_packet = new MP2TSPacket.from_stream (this.source_stream, offset);
            ts_packets.add (ts_packet);
            ts_packet.parse_from_stream_seek ();
            offset += bytes_per_packet;
            // debug ("Parsed " + ts_packet.to_string ());
            packet_count++;
            if ((num_packets > 0) && (packet_count >= num_packets)) {
                break;
            }
        }
        this.loaded = true;
        return offset - this.first_packet_offset;
    }
    
    public virtual MP2PATTable get_first_pat_table () throws Error {
        var pat_table = new MP2PATTable ();
        var pat_section = new MP2PATSection ();
        foreach (var ts_packet in this.ts_packets) {
            if (ts_packet.pid == 0) {
                var offset = ts_packet.source_offset + ts_packet.header_size;
                this.source_stream.seek_to_offset (offset);
                if (pat_section.add_ts_packet_seek (ts_packet)) {
                    if (pat_table.add_section (pat_section)) {
                        return pat_table;
                    }
                    pat_section = new MP2PATSection ();
                }
            }
        }
        throw new IOError.FAILED ("No PAT table found in %d packets",
                                  this.ts_packets.size);
    }

    public virtual MP2PMTTable get_first_pmt_table (uint16 pmt_pid) throws Error {
        var pmt_table = new MP2PMTTable ();
        var pmt_section = new MP2PMTSection ();
        foreach (var ts_packet in this.ts_packets) {
            if (ts_packet.pid == pmt_pid) {
                var offset = ts_packet.source_offset + ts_packet.header_size;
                this.source_stream.seek_to_offset (offset);
                if (pmt_section.add_ts_packet_seek (ts_packet)) {
                    if (pmt_table.add_section (pmt_section)) {
                        return pmt_table;
                    }
                    pmt_section = new MP2PMTSection ();
                }
            }
        }
        throw new IOError.FAILED ("No PMT table found on PID %u (0x%x) in %d packets",
                                  pmt_pid, pmt_pid, this.ts_packets.size);
    }
    
    public virtual Gee.List<MP2TSPacket> get_packets_for_pid (uint16 pid) {
        var packet_list = new Gee.ArrayList<MP2TSPacket> ();
        foreach (var ts_packet in this.ts_packets) {
            if (ts_packet.pid == pid) {
                packet_list.add (ts_packet);
            }
        }
        return packet_list;
    }
    
    public virtual void to_printer (LinePrinter printer, string prefix) {
        if (this.loaded) {
            uint64 pos = 0;
            foreach (var packet in this.ts_packets) {
                printer (prefix + pos.to_string () + ": " + packet.to_string ());
                pos++;
            }
        } else {
            printer (prefix + "[unloaded packets]");
        }
    }

    public virtual void to_printer_with_pid (LinePrinter printer, string prefix, 
                                             int16 pid) {
        if (this.loaded) {
            uint64 pos = 0;
            foreach (var packet in this.ts_packets) {
                if (packet.pid == pid) {
                    printer (prefix + pos.to_string () + ": " + packet.to_string ());
                    pos++;
                }
            }
        } else {
            printer (prefix + "[unloaded packets]");
        }
    }
} // END class MP2TransportStream

public class Rygel.MP2TransportStreamFile : MP2TransportStream {
    public GLib.File ts_file;

    public MP2TransportStreamFile.from_stream (FileInputStream file_stream, uint64 length)
               throws Error {
        var input_stream = new ExtDataInputStream (file_stream);
        base.from_stream (input_stream, 0, length);
    }

    public MP2TransportStreamFile (GLib.File ts_file) throws Error {
        var file_info = ts_file.query_info (GLib.FileAttribute.STANDARD_SIZE, 0);
        this.from_stream (ts_file.read (), file_info.get_size ());
        this.ts_file = ts_file;
    }

    public override void to_printer (MP2TransportStream.LinePrinter printer, string prefix) {
        printer (prefix + "MPEG2 Transport Stream: source "
                 + (this.ts_file != null ? this.ts_file.get_basename () : "stream")
                 + " {");
        base.to_printer (printer, prefix + "  ");
        printer (prefix + "}");
    }
} // END class MP2TransportStreamFile

public class Rygel.MP2TSRestamper {
    protected ExtDataInputStream source_stream;
    public uint64 source_offset;
    public uint64 source_size;

    protected MP2TSRestamper.from_stream (GLib.FileInputStream source_stream, 
                                          uint64 offset, uint64 size)
            throws Error {
        this.source_stream = new ExtDataInputStream (source_stream);
        this.source_offset = offset;
        this.source_size = size;
    }

    public MP2TSRestamper.from_file (GLib.File ts_file) throws Error {
        var file_info = ts_file.query_info (GLib.FileAttribute.STANDARD_SIZE, 0);
        this.from_stream (ts_file.read (), 0, file_info.get_size ());
        // TODO: Look for packet start code (in case file is not packet aligned)
    }

    public virtual void restamp_to_stream_scaled (ExtDataOutputStream ostream,
                                                  uint32 scale_ms,
                                                  uint16 [] ? pids_to_scale,
                                                  uint16 [] ? pids_to_remove) 
            throws Error {
        debug ("restamp_to_stream_scaled (scale=%u (%0.3fx))",scale_ms,scale_ms/1000.0);
        var pid_remove_set = new Gee.HashSet<uint16> ();
        foreach (var pid in pids_to_remove) {
            pid_remove_set.add (pid);
        }
        var pid_scale_set = new Gee.HashSet<uint16> ();
        if (pids_to_scale != null) {
            foreach (var pid in pids_to_scale) {
                pid_scale_set.add (pid);
            }
        } else {
            var pat = get_first_pat_table ();
            debug ("  Found PAT:");
            pat.to_printer ((l) =>  {debug (l);}, "   ");
            var pmt = get_pmt_table (pat.get_programs ().first ().pid);
            debug ("  Found PMT:");
            pat.to_printer ((l) =>  {debug (l);}, "   ");
            foreach (var stream_info in pmt.get_streams ()) {
                if (stream_info.is_audio () || stream_info.is_video ()) {
                    pid_scale_set.add (stream_info.pid);
                } 
            }
        }
        var c_counters = new HashTable <uint16, uint8> (direct_hash, direct_equal);
        uint64 packet_count = 0, offset = this.source_offset;
        uint bytes_per_packet = 188;
        this.source_stream.seek_to_offset (offset);
        while (offset + bytes_per_packet <= this.source_size) {
            // debug ("Restamping packet %lld at offset %lld", packet_count, offset);
            var ts_packet = new MP2TSPacket.from_stream (this.source_stream, offset);
            var header_bytes_parsed = ts_packet.parse_from_stream_noseek ();
            offset += bytes_per_packet;
            // debug ("Parsed %llu bytes: %s", header_bytes_parsed, ts_packet.to_string ());
            if (pid_remove_set.contains (ts_packet.pid)) {
                ts_packet.skip_payload ();
            } else {
                packet_count++;
                if (ts_packet.adaptation_field != null) {
                    // debug ("  changing PCR of %s\n", ts_packet.to_string ());
                    ts_packet.adaptation_field.pcr 
                        = (ts_packet.adaptation_field.pcr * 1000) / scale_ms;
                }
                var c_counter = c_counters.get (ts_packet.pid);
                ts_packet.continuity_counter = c_counter;
                c_counters.replace (ts_packet.pid, (c_counter+1) % 16);
                if (ts_packet.payload_unit_start_indicator
                    && pid_scale_set.contains (ts_packet.pid)) {
                    ts_packet.parse_pes_from_stream_noseek ();
                    // debug ("  changing PTS/DTS of %s\n", ts_packet.to_string ());
                    ts_packet.pes_packet.pes_header.pts 
                      = (ts_packet.pes_packet.pes_header.pts * 1000) / scale_ms;
                    ts_packet.pes_packet.pes_header.dts 
                      = (ts_packet.pes_packet.pes_header.dts * 1000) / scale_ms;
                }
                // debug ("writing " + ts_packet.to_string ());
                ts_packet.fields_to_stream (ostream);
                ts_packet.payload_to_stream_noseek (ostream);
            }
        }
    } // END restamp_to_stream_scaled ()

    public virtual MP2PATTable get_first_pat_table () throws Error {
        var pat_section = new MP2PATSection ();
        var pat_table = new MP2PATTable ();

        uint64 packet_count = 0, ts_offset = this.source_offset;
        uint bytes_per_packet = 188;
        this.source_stream.seek_to_offset (ts_offset);
        while (ts_offset + bytes_per_packet <= this.source_size) {
            var ts_packet = new MP2TSPacket.from_stream (this.source_stream, 
                                                         ts_offset);
            ts_packet.parse_from_stream_noseek ();
            ts_offset += bytes_per_packet;
            // debug ("Parsed " + ts_packet.to_string ());
            packet_count++;
            if (ts_packet.pid == 0) {
                var offset = ts_packet.source_offset + ts_packet.header_size;
                this.source_stream.seek_to_offset (offset);
                if (pat_section.add_ts_packet_seek (ts_packet)) {
                    if (pat_table.add_section (pat_section)) {
                        return pat_table;
                    }
                    pat_section = new MP2PATSection ();
                }
            }
        }
        throw new IOError.FAILED ("No PAT table found in %lld packets",
                                  packet_count);
    }

    public virtual MP2PMTTable get_pmt_table (uint16 pmt_pid) 
            throws Error {
        var pmt_section = new MP2PMTSection ();
        var pmt_table = new MP2PMTTable ();

        uint64 packet_count = 0, ts_offset = this.source_offset;
        uint bytes_per_packet = 188;
        this.source_stream.seek_to_offset (ts_offset);
        while (ts_offset + bytes_per_packet <= this.source_size) {
            var ts_packet = new MP2TSPacket.from_stream (this.source_stream, 
                                                         ts_offset);
            ts_packet.parse_from_stream_noseek ();
            ts_offset += bytes_per_packet;
            // debug ("Parsed " + ts_packet.to_string ());
            packet_count++;
            if (ts_packet.pid == pmt_pid) {
                var offset = ts_packet.source_offset + ts_packet.header_size;
                this.source_stream.seek_to_offset (offset);
                if (pmt_section.add_ts_packet_noseek (ts_packet)) {
                    if (pmt_table.add_section (pmt_section)) {
                        return pmt_table;
                    }
                    pmt_section = new MP2PMTSection ();
                }
            } else {
                ts_packet.skip_payload ();
            }
        }
        throw new IOError.FAILED ("No PMT table found in %lld packets",
                                  packet_count);
    }
} // END class MP2TSRestampper

public class Rygel.MP2TSPacket {
    public unowned ExtDataInputStream source_stream;
    public uint64 source_offset;
    public bool source_verbatim;

    public bool transport_error_indicator;
    public bool payload_unit_start_indicator;
    public bool transport_priority;
    public uint16 pid; // 13 bits
    public uint8 transport_scrambling_control; // 2 bits
    public uint8 adaptation_field_control; // 2 bits
    public uint8 continuity_counter; // 4 bits
    public MP2TSAdaptationField adaptation_field;
    public MP2PESPacket pes_packet = null;
    public bool has_payload;
    public uint8 header_size;
    public uint8 payload_size; // bytes of payload in this packet

    protected bool loaded; // Indicates the packet fields/children are populated/parsed

    public MP2TSPacket () {
    }

    public MP2TSPacket.from_stream (ExtDataInputStream stream, uint64 offset)
            throws Error {
        this.source_stream = stream;
        this.source_offset = offset;
        this.source_verbatim = true;
        this.loaded = false;
    }

    public virtual uint64 parse_from_stream_seek () throws Error {
        this.source_stream.seek_to_offset (this.source_offset);
        return (parse_from_stream_noseek ());
    }

    public virtual uint64 parse_from_stream_noseek () throws Error {
        var instream = this.source_stream;
        
        var sync_byte = instream.read_byte ();
        if (sync_byte != 0x47) {
            throw new IOError.FAILED ("TS packet sync_byte mismatch at %lld (0x%llx): found 0x%x, expected 0x47",
                                      instream.tell (), instream.tell (), sync_byte);
        }

        var octet_2_3 = instream.read_uint16 ();
        this.transport_error_indicator = Bits.getbit_16 (octet_2_3, 15);
        this.payload_unit_start_indicator = Bits.getbit_16 (octet_2_3, 14);
        this.transport_priority = Bits.getbit_16 (octet_2_3, 13);
        this.pid = Bits.getbits_16 (octet_2_3, 0, 13);
        // debug ("Found sync 0x%x, PID %d (0x%x)", this.sync_byte, this.pid, this.pid);

        var octet_4 = instream.read_byte ();
        this.transport_scrambling_control = Bits.getbits_8 (octet_4, 6, 2);
        this.adaptation_field_control = Bits.getbits_8 (octet_4, 4, 2);
        this.continuity_counter = Bits.getbits_8 (octet_4, 0, 4);
        uint8 bytes_consumed = 4;
        if (this.adaptation_field_control <= 1) {
            this.adaptation_field = null;
        } else {
            this.adaptation_field = new MP2TSAdaptationField ();
            bytes_consumed += this.adaptation_field.parse_from_stream (instream);
        }
        this.has_payload = (this.adaptation_field_control & 1) == 1;
        this.header_size = bytes_consumed;
        assert (bytes_consumed <= 188);
        this.payload_size = 188 - bytes_consumed;

        this.source_verbatim = false;
        this.loaded = true;

        return bytes_consumed;
    }
    
    public void load () throws Error {
        if (!loaded) {
            parse_from_stream_seek ();
        }
    }

    /**
     * Parse the PES header contained in the TS packet. 
     */
    public virtual uint64 parse_pes_from_stream_seek () throws Error {
        if (!this.payload_unit_start_indicator) {
            throw new IOError.FAILED ("Attempt to parse PES from TS packet that's not a payload start at %llu (0x%llx): ",
                                      this.source_stream.tell (), this.source_stream.tell (),
                                      this.to_string ());
        }

        var pes_offset = this.source_offset + this.header_size;
        var pes_packet = new MP2PESPacket.from_stream (this.source_stream, pes_offset);
        var bytes_parsed = pes_packet.parse_from_stream_seek ();
        this.pes_packet = pes_packet;
        return bytes_parsed;
    }

    /**
     * Parse the PES header contained in the TS packet. 
     */
    public virtual uint64 parse_pes_from_stream_noseek () throws Error {
        if (!this.payload_unit_start_indicator) {
            throw new IOError.FAILED ("Attempt to parse PES from TS packet that's not a payload start at %llu (0x%llx): ",
                                      this.source_stream.tell (), this.source_stream.tell (),
                                      this.to_string ());
        }

        var pes_offset = this.source_offset + this.header_size;
        var pes_packet = new MP2PESPacket.from_stream (this.source_stream, pes_offset);
        var bytes_parsed = pes_packet.parse_from_stream_noseek ();
        this.pes_packet = pes_packet;
        return bytes_parsed;
    }

    public virtual uint64 to_stream (ExtDataOutputStream ostream) throws Error {
        if (this.source_verbatim) {
            // debug ("to_stream(%s): Writing from source stream: %s",
            //        this.type_code, this.to_string ());
            this.source_stream.seek_to_offset (this.source_offset);
            ostream.put_from_instream (this.source_stream, 188);
        } else {
            // debug ("to_stream(%s): Writing from fields: %s",
            //        this.type_code, this.to_string ());
            fields_to_stream (ostream);
        }
        return 188;
    }

    public virtual uint64 fields_to_stream (ExtDataOutputStream ostream) 
            throws Error {
        ostream.put_byte (0x47);

        uint16 octet_2_3 = (this.transport_error_indicator ? 1 : 0) << 15;
        octet_2_3 |= (this.payload_unit_start_indicator ? 1 : 0) << 14;
        octet_2_3 |= (this.transport_priority ? 1 : 0) << 13;
        octet_2_3 |= this.pid;
        ostream.put_uint16 (octet_2_3);
        
        uint8 octet_4 = (this.transport_scrambling_control) << 6;
        octet_4 |= this.adaptation_field_control << 4;
        octet_4 |= this.continuity_counter;
        ostream.put_byte (octet_4);
        
        uint64 bytes_written = 4;
        
        if (this.adaptation_field != null) {
            bytes_written += this.adaptation_field.fields_to_stream (ostream);
        }
        if (this.pes_packet != null) {
            bytes_written += this.pes_packet.fields_to_stream (ostream);
        }
        return bytes_written;
    }
    
    public virtual uint64 skip_payload () 
            throws Error {
        uint64 offset = this.header_size;
        if (this.pes_packet != null) {
            offset += this.pes_packet.header_size;
        }
        uint64 payload_size = 188 - offset;
        this.source_stream.skip_bytes (payload_size);
        return payload_size;
    }

    public virtual uint64 payload_to_stream_noseek (ExtDataOutputStream ostream) 
            throws Error {
        uint64 offset = this.header_size;
        if (this.pes_packet != null) {
            offset += this.pes_packet.header_size;
        }
        uint64 payload_size = 188 - offset;
        ostream.put_from_instream (this.source_stream, payload_size);
        return payload_size;
    }

    public virtual uint64 payload_to_stream_seek (ExtDataOutputStream ostream) 
            throws Error {
        uint64 offset = this.header_size;
        if (this.pes_packet != null) {
            offset += this.pes_packet.header_size;
        }
        this.source_stream.seek_to_offset (this.source_offset + offset);
        uint64 payload_size = 188 - offset;
        ostream.put_from_instream (this.source_stream, payload_size);
        return payload_size;
    }

    public string to_string () {
        var builder = new StringBuilder ("MP2TSPacket[");
        append_fields_to (builder);
        builder.append_c (']');
        return builder.str;
    }

    protected void append_fields_to (StringBuilder builder) {
        if (!this.loaded) {
            builder.append ("fields_not_loaded");
        } else {
            builder.append_printf ("offset %lld,pid %d (0x%x),flags[",
                                   this.source_offset, this.pid,this.pid);
            bool first = true;
            if (this.transport_error_indicator) {
                builder.append ("ERR");
                first = false;
            }
            if (this.payload_unit_start_indicator) {
                if (!first) builder.append_c ('+');
                builder.append ("PUSI");
                first = false;
            }
            if (this.transport_priority) {
                if (!first) builder.append_c ('+');
                builder.append ("PRI");
            }
            builder.append_c (']');
            if (this.transport_scrambling_control != 0) {
                builder.append_printf (",scram %x", 
                                       this.transport_scrambling_control);
            }
            builder.append_printf (",cc %d", this.continuity_counter);
            if (this.has_payload) {
                builder.append_printf (",header_size %d", this.header_size);
            }
            if (this.adaptation_field != null) {
                builder.append_c (',');
                builder.append (this.adaptation_field.to_string ());
            }
            if (this.pes_packet != null) {
                builder.append_c (',');
                builder.append (this.pes_packet.to_string ());
            }
        }
    }

    public class MP2TSAdaptationField {
        public bool is_empty;
        public bool discontinuity_indicator;
        public bool random_access_indicator;
        public bool elementary_stream_priority_indicator;
        public bool pcr_flag;
        public bool opcr_flag;
        public bool splicing_point_flag;
        public bool transport_private_data_flag;
        public bool adaptation_field_extension_flag;
        public uint64 pcr;
        public uint64 opcr;
        public uint8 splice_countdown;
        public uint8 private_data_length;
        public Bytes private_data;
        public uint8 num_stuffing_bytes;
        public MP2TSAdaptationFieldExt adaptation_field_ext;

        public MP2TSAdaptationField () {
        }

        public uint8 parse_from_stream (ExtDataInputStream instream)
                throws Error {
            var adaptation_field_length = instream.read_byte ();
            // Note: length doesn't include the 1-byte length field
            
            if (adaptation_field_length == 0) {
                this.is_empty = true;
                return 1;
            }

            var octet_2 = instream.read_byte ();
            this.discontinuity_indicator = Bits.getbit_8 (octet_2, 7);
            this.random_access_indicator = Bits.getbit_8 (octet_2, 6);
            this.elementary_stream_priority_indicator = Bits.getbit_8 (octet_2, 5);
            this.pcr_flag = Bits.getbit_8 (octet_2, 4);
            this.opcr_flag = Bits.getbit_8 (octet_2, 3);
            this.splicing_point_flag = Bits.getbit_8 (octet_2, 2);
            this.transport_private_data_flag = Bits.getbit_8 (octet_2, 1);
            this.adaptation_field_extension_flag = Bits.getbit_8 (octet_2, 0);
            uint8 bytes_consumed = 2;

            if (this.pcr_flag) {
                var pcr_fields = instream.read_bytes_uint64 (6); // 48 bits
                this.pcr = Bits.getbits_64 (pcr_fields, 15, 33) * 300;
                this.pcr += (uint16)Bits.getbits_64 (pcr_fields, 0, 9);
                bytes_consumed += 6;
            }

            if (this.opcr_flag) {
                var opcr_fields = instream.read_bytes_uint64 (6); // 48 bits
                this.opcr = Bits.getbits_64 (opcr_fields, 15, 33) * 300;
                this.opcr += (uint16)Bits.getbits_64 (opcr_fields, 0, 9);
                bytes_consumed += 6;
            }
            
            if (this.splicing_point_flag) {
                this.splice_countdown = instream.read_byte ();
                bytes_consumed += 1;
            }

            if (this.transport_private_data_flag) {
                this.private_data_length = instream.read_byte ();
                bytes_consumed += 1;
                this.private_data = instream.read_bytes (this.private_data_length);
                bytes_consumed += this.private_data_length;
            }
            
            if (this.adaptation_field_extension_flag) {
                this.adaptation_field_ext = new MP2TSAdaptationFieldExt ();
                bytes_consumed += this.adaptation_field_ext.parse_from_stream (instream);
            }
            // debug ("adaptation field length: %d", this.adaptation_field_length);
            // debug ("bytes consumed: %lld", bytes_consumed);
            if (bytes_consumed > adaptation_field_length+1) {
                throw new IOError.FAILED ("Found %d bytes in adaptation field of %d bytes at %lld (0x%llx): %s",
                                          instream.tell (), instream.tell (),
                                          bytes_consumed, adaptation_field_length+1, to_string ());
            }
            this.num_stuffing_bytes = adaptation_field_length + 1 
                                      - bytes_consumed;
            instream.skip_bytes (this.num_stuffing_bytes);
            bytes_consumed += num_stuffing_bytes;

            return bytes_consumed;
        }

        public virtual uint8 get_size () {
            if (this.is_empty) {
                return 1;
            } else {
                return (2 + (this.pcr_flag ? 6 : 0) 
                          + (this.opcr_flag ? 6 : 0)
                          + (this.splicing_point_flag ? 1 : 0)
                          + (this.transport_private_data_flag 
                             ? (this.private_data.length + 1) : 0)
                          + (this.adaptation_field_extension_flag ?
                            this.adaptation_field_ext.get_size () : 0)
                          + this.num_stuffing_bytes);
            }
        }

        public virtual uint8 fields_to_stream (ExtDataOutputStream ostream) 
                throws Error {
            if (this.is_empty) {
                ostream.put_byte (get_size () - 1);
            }
            var header_size = get_size ();
            ostream.put_byte (header_size - 1);
            uint8 bytes_written = 1;
            if (!this.is_empty) {
                uint8 octet_2 
                    = (this.discontinuity_indicator ? 1 : 0) << 7
                      | (this.random_access_indicator ? 1 : 0) << 6
                      | (this.elementary_stream_priority_indicator ? 1 : 0) << 5
                      | (this.pcr_flag ? 1 : 0) << 4
                      | (this.opcr_flag ? 1 : 0) << 3
                      | (this.splicing_point_flag ? 1 : 0) << 2
                      | (this.transport_private_data_flag ? 1 : 0) << 1
                      | this.adaptation_field_extension_flag;
                ostream.put_byte (octet_2);
                bytes_written++;
                if (this.pcr_flag) {
                    uint64 pcr_fields;
                    uint64 pcr_base = this.pcr / 300;
                    pcr_fields = pcr_base << 15
                                 | 0x3F << 9 // reserved bits
                                 | (this.pcr - pcr_base*300);
                    ostream.put_bytes_uint64 (pcr_fields, 6); // 48 bits
                    bytes_written += 6;
                }
                if (this.opcr_flag) {
                    uint64 opcr_fields;
                    uint64 opcr_base = this.opcr / 300;
                    opcr_fields = opcr_base << 15
                                  | 0x3F << 9 // reserved bits
                                  | (this.opcr - opcr_base*300);
                    ostream.put_bytes_uint64 (opcr_fields, 6); // 48 bits
                    bytes_written += 6;
                }
                if (this.splicing_point_flag) {
                    ostream.put_byte (this.splice_countdown);
                    bytes_written++;
                }
                if (this.transport_private_data_flag) {
                    if (this.private_data.length > 255) {
                        throw new IOError.FAILED ("private_data too large for adaptation field (%d)" 
                                                  .printf (this.private_data.length));
                    }
                    ostream.put_byte ((uint8)this.private_data.length);
                    ostream.write_bytes (this.private_data);
                    bytes_written +=  (uint8)this.private_data.length + 1;
                }
                if (this.adaptation_field_extension_flag) {
                    if (this.adaptation_field_ext == null) {
                        throw new IOError.FAILED ("adaptation_field_extension_flag set with null adaptation_field_ext");
                    }
                    bytes_written += this.adaptation_field_ext
                                            .fields_to_stream (ostream);
                }
                for (uint8 i=0; i<this.num_stuffing_bytes; i++) {
                    ostream.put_byte (0xFF);
                    bytes_written++;
                }
            }
            
            return bytes_written;
        }

        public string to_string () {
            var builder = new StringBuilder ("adaptation[");
            append_fields_to (builder);
            builder.append_c (']');
            return builder.str;
        }

        public void append_fields_to (StringBuilder builder) {
            builder.append_printf ("len %d,flags[",this.get_size ());
            bool first = true;
            if (this.discontinuity_indicator) {
                builder.append ("DIS");
                first = false;
            }
            if (this.random_access_indicator) {
                if (!first) builder.append_c ('+');
                builder.append ("RAN");
                first = false;
            }
            if (this.elementary_stream_priority_indicator) {
                if (!first) builder.append_c ('+');
                builder.append ("PRI");
            }
            builder.append_c (']');
            if (this.pcr_flag) {
                builder.append_printf (",pcr %lld (0x%llx) (%0.3fs)", 
                                       this.pcr, this.pcr, this.pcr/27000000.0);
            }
            if (this.opcr_flag) {
                builder.append_printf (",orig_pcr %lld (0x%llx) (%0.3fs)", 
                                       this.opcr, this.opcr, this.opcr/27000000.0);
            }
            if (this.splicing_point_flag) {
                builder.append_printf (",splice_cd %d (0x%x)",
                                        this.splice_countdown, this.splice_countdown);
            }
            if (this.transport_private_data_flag) {
                builder.append_printf (",private_data (%d bytes)",
                                        this.private_data_length);
            }
            if (this.adaptation_field_extension_flag 
                && this.adaptation_field_ext != null) {
                builder.append_c (',');
                builder.append (this.adaptation_field_ext.to_string ());
            }
        }

        public class MP2TSAdaptationFieldExt {
            public uint8 adaptation_field_ext_length;
            public bool ltw_flag;
            public bool piecewise_rate_flag;
            public bool seamless_splice_flag;
            public bool ltw_valid_flag;
            public uint16 ltw_offset;
            public uint32 piecewise_rate;
            public uint8 splice_type;
            public uint64 dts_next_au;
            public uint8 num_reserved_bytes;

            public MP2TSAdaptationFieldExt () {
            }

            public virtual uint8 parse_from_stream (ExtDataInputStream instream) 
                    throws Error {
                this.adaptation_field_ext_length = instream.read_byte ();
                // Note: length doesn't include the 1-byte length field

                var octet_2 = instream.read_byte ();
                this.ltw_flag = Bits.getbit_8 (octet_2, 7);
                this.piecewise_rate_flag = Bits.getbit_8 (octet_2, 6);
                this.seamless_splice_flag = Bits.getbit_8 (octet_2, 5);
                uint8 bytes_consumed = 2;

                if (this.ltw_flag) {
                    var ltw_fields = instream.read_uint16 ();
                    this.ltw_valid_flag = Bits.getbit_16 (ltw_fields, 15);
                    this.ltw_offset = Bits.getbits_16 (ltw_fields, 0, 15);
                    bytes_consumed += 2;
                }

                if (this.piecewise_rate_flag) {
                    var pr_fields = instream.read_bytes_uint32 (3); // 24 bits
                    this.piecewise_rate = Bits.getbits_32 (pr_fields, 0, 22);
                    bytes_consumed += 3;
                }
                
                if (this.seamless_splice_flag) {
                    var ss_field_1 = instream.read_byte ();
                    this.splice_type = (uint8)Bits.getbits_8 (ss_field_1, 4, 4);
                    this.dts_next_au = Bits.getbits_8 (ss_field_1, 1, 3) << 30;
                    var ss_field_2 = instream.read_uint16 ();
                    this.dts_next_au |= Bits.getbits_16 (ss_field_2, 1, 15) << 15;
                    ss_field_2 = instream.read_uint16 ();
                    this.dts_next_au |= Bits.getbits_16 (ss_field_2, 1, 15);
                    bytes_consumed += 5;
                }
                // debug ("adaptation field extension length: %d", this.adaptation_field_ext_length);
                // debug ("bytes consumed: %lld", bytes_consumed);

                if (bytes_consumed > this.adaptation_field_ext_length+1) {
                    throw new IOError.FAILED ("Found %d bytes in adaptation field extension of %d bytes: %s",
                                              bytes_consumed, 
                                              this.adaptation_field_ext_length+1,
                                              to_string ());
                }
                if (bytes_consumed > this.adaptation_field_ext_length+1) {
                    throw new IOError.FAILED ("Found %d bytes in adaptation field extension of %d bytes",
                                              bytes_consumed, this.adaptation_field_ext_length+1);
                }
                this.num_reserved_bytes = this.adaptation_field_ext_length+1 - bytes_consumed;
                instream.skip_bytes (this.num_reserved_bytes);
                bytes_consumed += this.num_reserved_bytes;

                return bytes_consumed;
            }

            public virtual uint8 get_size () {
                return (2 + (this.ltw_flag ? 2 : 0) 
                          + (this.piecewise_rate_flag ? 3 : 0)
                          + (this.seamless_splice_flag ? 5 : 0)
                          + this.num_reserved_bytes);
            }

            public virtual uint8 fields_to_stream (ExtDataOutputStream ostream) 
                    throws Error {
                ostream.put_byte (get_size () - 1);
                uint8 octet_2 
                    = (this.ltw_flag ? 1 : 0) << 7
                      | (this.piecewise_rate_flag ? 1 : 0) << 6
                      | (this.seamless_splice_flag ? 1 : 0) << 5
                      | 0x1F; // reserved bits set to '1'
                ostream.put_byte (octet_2);
                uint8 bytes_written = 2;
                
                if (this.ltw_flag) {
                    uint16 ltw = (this.ltw_valid_flag ? 1 : 0) << 15
                                 | this.ltw_offset;
                    ostream.put_uint16 (ltw);
                    bytes_written += 2;
                }
                if (this.piecewise_rate_flag) {
                    uint32 pr = 3 << 22 | this.piecewise_rate;
                    ostream.put_bytes_uint32 (pr, 3); // 24 bits
                    bytes_written += 3;
                }
                if (this.seamless_splice_flag) {
                    uint8 ss_field_1;
                    ss_field_1 = this.splice_type << 4
                                 | (uint8)Bits.getbits_64 (this.dts_next_au,
                                                           30, 3) << 1
                                 | 1; // marker bit
                    ostream.put_byte (ss_field_1);
                    uint16 ss_field_2;
                    ss_field_2 = (uint16)Bits.getbits_64 (this.dts_next_au,
                                                         15, 15) << 1
                                 | 1; // marker bit
                    ostream.put_uint16 (ss_field_2);
                    ss_field_2 = (uint16)Bits.getbits_64 (this.dts_next_au, 
                                                          0, 15) << 1
                                 | 1; // marker bit
                    ostream.put_uint16 (ss_field_2);
                    bytes_written += 5;
                }
                
                for (uint i=0; i < this.num_reserved_bytes; i++) {
                    ostream.put_byte (0xFF);
                    bytes_written++;
                }
                return bytes_written;
            }

            public string to_string () {
                var builder = new StringBuilder ("adaptation-ext[");
                append_fields_to (builder);
                builder.append_c (']');
                return builder.str;
            }

            public void append_fields_to (StringBuilder builder) {
                builder.append_printf ("len %d",this.adaptation_field_ext_length);
                if (this.ltw_flag) {
                    builder.append_printf (",ltw_valid %s, ltw_offset %d",
                                           this.ltw_valid_flag ? "1" : "0", 
                                           this.ltw_offset);
                }
                if (this.piecewise_rate_flag) {
                    builder.append_printf (",piecewise_rate %ld,", this.piecewise_rate);
                }
                if (this.seamless_splice_flag) {
                    builder.append_printf (",splice_type %d,", this.splice_type);
                }
            }
        } // END class MP2TSAdaptationFieldExt 
    } // END class MP2TSAdaptationField
} // END class MP2TSPacket

// For 192-byte TS packets
public class Rygel.TimestampedMP2TSPacket : MP2TSPacket {
    public uint32 timestamp; // for 192-byte packets
} // END class TimestampedMP2TSPacket

public class Rygel.MP2Table {
    public MP2TableSection[] section_list;
    public uint8 total_sections;
    public uint8 num_sections_acquired;
    public bool all_sections_acquired;
    public uint8 version_number;
    
    public MP2Table () {
        this.total_sections = 0;
        this.num_sections_acquired = 0;
        this.all_sections_acquired = false;
        this.version_number = 0;
    }

    public bool add_section (MP2TableSection section) {
        if (this.total_sections == 0 
            || (this.version_number != section.version_number)) {
            this.all_sections_acquired = false;
            this.total_sections = section.last_section_number+1;
            this.version_number = section.version_number;
            this.section_list = new MP2TableSection[this.total_sections];
            for (uint8 i=0; i<this.total_sections; i++) {
                this.section_list[i] = null;
            }
        }
        if (this.section_list[section.section_number] == null) {
            this.section_list[section.section_number] = section;
            if ((++this.num_sections_acquired) == this.total_sections) {
                this.all_sections_acquired = true;
            }
        }
        return this.all_sections_acquired;
    }
    
    public bool sections_aquired () {
        return this.all_sections_acquired;
    }

    public virtual string to_string () {
        var builder = new StringBuilder ("MP2Table[");
        append_fields_to (builder);
        builder.append_c (']');
        return builder.str;
    }

    public virtual void append_fields_to (StringBuilder builder) {
        builder.append_printf ("version %u,num_sections %u,sections:[",
                               this.version_number, this.total_sections);
        uint num=1;
        foreach (var section in this.section_list) {
            builder.append_printf ("%u:[",num++);
            section.append_fields_to (builder);
            builder.append ("],");
        }
        builder.truncate (builder.len-1);
        builder.append_c (']');
    }

    public virtual void sections_to_printer (MP2TransportStream.LinePrinter printer, 
                                    string prefix, string table_name) {
        printer ("%s%s: version %u,num_sections %u"
                 .printf (prefix, table_name, this.version_number, 
                          this.total_sections));
        uint index=1;
        foreach (var section in this.section_list) {
            printer ("%s   Section %u: ".printf (prefix, index++));
            section.to_printer (printer, prefix + "      ");;
        }
    }

    public virtual void to_printer (MP2TransportStream.LinePrinter printer, 
                                    string prefix) {
        sections_to_printer (printer, prefix, "MP2Table");
    }
} // END class MP2Table

public class Rygel.MP2TableFactory {
} // END class MP2TableFactory

public abstract class Rygel.MP2Section {
    public Gee.List<MP2TSPacket> ts_packets = new Gee.ArrayList<MP2TSPacket> ();
    protected ByteArray section_buffer;
    public Bytes section_data = null;
    public uint8 table_id;
    public bool section_syntax_indicator;
    public uint16 section_length;
    public bool loaded = false;

    public MP2Section () {
    }

    public MP2Section.from_packets (Gee.List ts_packets) throws Error {
        // TODO
    }

    public bool add_ts_packet_seek (MP2TSPacket ts_packet) throws Error {
        ts_packet.source_stream.seek_to_offset (ts_packet.source_offset + ts_packet.header_size);
        return add_ts_packet_noseek (ts_packet);
    }

    public bool add_ts_packet_noseek (MP2TSPacket ts_packet) throws Error {
        // debug ("add_ts_packet_noseek(%s)",ts_packet.to_string ());
        if (this.section_data != null) {
            return true;
        }
        var instream = ts_packet.source_stream;
        uint8 packet_payload_len = 188 - ts_packet.header_size;
        uint bytes_to_read;
        Error err = null;
        if (ts_packet.payload_unit_start_indicator) {
            var pointer_offset = instream.read_byte ();
            packet_payload_len--;
            if (this.section_buffer == null) { // Packet is start of section (and maybe end)
                // debug ("Found section start in " + ts_packet.to_string ());
                instream.skip_bytes (pointer_offset);
                packet_payload_len -= pointer_offset;
                uint8 header[3];
                instream.read (header);
                this.table_id = header[0];
                uint16 octet_2_3 = (header[1] << 8) | header[2];
                this.section_syntax_indicator = Bits.getbit_16 (octet_2_3, 15);
                this.section_length = Bits.getbits_16 (octet_2_3, 0, 12);
                this.section_buffer = new ByteArray.sized (this.section_length);
                this.section_buffer.append (header);
                bytes_to_read = uint.min (packet_payload_len, this.section_length);
            } else { // Packet must be the end of this section (and start of another)
                // debug ("Found section end in " + ts_packet.to_string ());
                packet_payload_len = pointer_offset;
                bytes_to_read = uint.min (packet_payload_len, 
                                          this.section_length-this.section_buffer.len);
                if (!(this.section_buffer.len == this.section_length)) {
                    err = new IOError.FAILED ("Last packet for section didn't complete section (expected %u bytes, found %u)", 
                                              this.section_length, this.section_buffer.len);
                }
            }
        } else { // No PUSI bit -> no pointer byte
            if (this.section_buffer == null) {
                bytes_to_read = 0;
                // debug ("Skipping - start not found: " + ts_packet.to_string ());
            } else {
                // debug ("Found section continuation in " + ts_packet.to_string ());
                bytes_to_read = uint.min (packet_payload_len, 
                                          this.section_length-this.section_buffer.len);
            }
        }
        if (bytes_to_read > 0) {
            // debug ("Copying %u bytes of section data", bytes_to_read);
            this.section_buffer.append (instream.read_bytes (bytes_to_read).get_data ());
        }
        uint bytes_remaining = packet_payload_len - bytes_to_read;
        if (bytes_remaining > 0) {
            // debug ("Skipping %u bytes of packet data", bytes_remaining);
            instream.skip_bytes (bytes_remaining);
        }
        if (err != null) {
            throw err;
        }
        if (this.section_buffer.len == this.section_length+3) {
            // debug ("Packet completes section: " + ts_packet.to_string ());
            this.section_data = ByteArray.free_to_bytes (this.section_buffer);
            this.parse_section_data ();
            this.section_buffer = null;
            return true;
        } else {
            return false;
        }
    }

    public uint16 parse_section_data () throws Error {
        if (this.section_data == null) {
            throw new IOError.FAILED ("parse_section_data called without section data loaded");
        }
        var mis = new MemoryInputStream.from_bytes (this.section_data);
        var dis = new ExtDataInputStream (mis);
        //var builder = new StringBuilder ();
        //for (int i=0; i<this.section_data.length; i++) {
        //    builder.append_printf ("0x%02x ",this.section_data[i]);
        //}
        //debug ("section_data: " + builder.str);
        return (fields_from_stream (dis));
    }

    public virtual uint16 fields_from_stream (ExtDataInputStream instream) 
            throws Error {
        this.table_id = instream.read_byte ();
        var octet_2_3 = instream.read_uint16 ();
        this.section_syntax_indicator = Bits.getbit_16 (octet_2_3, 15);
        this.section_length = Bits.getbits_16 (octet_2_3, 0, 12);
        return 3;
    }

    /**
     * Parse the section from the the TS packet(s) containing the section. 
     */
    public virtual uint64 parse_from_ts_packets () throws Error {
//        if (!this.payload_unit_start_indicator) {
//            throw new IOError.FAILED ("Attempt to parse section from TS packet that's not a payload start: ",
//                                      this.to_string ());
//        }
//        var offset = this.source_offset + this.header_size;
//        source_stream.seek_to_offset (offset);
//        var pointer_field = source_stream.read_byte ();
//        source_stream.skip_bytes (pointer_field);
//        offset += 1 + pointer_field;
//        uint8 peek_buf[1];
//        source_stream.peek (peek_buf);

//        this.section = MP2SectionFactory.section_from_offset (this.source_stream, offset, 
//                                                              peek_buf[1]);
//        if (this.section == null) {
//            throw new IOError.FAILED ("Attempt to parse unknown table type 0x%x",
//                                      peek_buf[1]);
//        }
//        return this.section.parse_from_stream ();
        return 0;
    }


    public virtual string to_string () {
        var builder = new StringBuilder ("MP2TSPacket[");
        append_fields_to (builder);
        builder.append_c (']');
        return builder.str;
    }

    public virtual void append_fields_to (StringBuilder builder) {
        builder.append_printf ("table_id %u,length %lld",
                               this.table_id, this.section_length);
    }

    public virtual void to_printer (MP2TransportStream.LinePrinter printer, string prefix) {
        printer ("%s%s".printf (prefix,this.to_string ()));
    }
} // END class MP2Section

public class Rygel.MP2SectionFactory {
    /**
     * Create a Section from the given Transport Stream packet.
     * 
     * The TSPacket must be parsed/populated as a precondition.
     */
    public static MP2Section ? section_for_table_id (uint8 table_id)
            throws Error {
        switch (table_id) {
            case 0x00: // PAT
                return new MP2PATSection ();
            case 0x02: // PMT
                return new MP2PMTSection ();
            case 0x01: // CA
            case 0x03: // TS description
            case 0x04: // scene description section
            case 0x05: // object descriptor section
            default:
                return null;
        }
    }
} // END class MP2SectionFactory

public abstract class Rygel.MP2TableSection : MP2Section {
    public uint8 version_number;
    public uint8 section_number;
    public uint8 last_section_number;
} // END class MP2TableSection

public class Rygel.MP2PATSection : MP2TableSection {
    public uint16 tsid;
    public bool current_next;
    public Gee.List<Program> program_list = null;
    public uint32 crc;

    public class Program {
        public uint16 program_number;
        public uint16 pid;

        public uint8 parse_from_stream (ExtDataInputStream instream)
                throws Error {
            this.program_number = instream.read_uint16 ();
            this.pid = Bits.readbits_16 (instream, 0, 13);
            return 4;
        }
        public string to_string () {
            var builder = new StringBuilder ("PATProgram[");
            append_fields_to (builder);
            builder.append_c (']');
            return builder.str;
        }

        public void append_fields_to (StringBuilder builder) {
            builder.append_printf ("program_num %u (0x%x),pmt_pid %d (0x%x)",
                                   this.program_number, this.program_number,
                                   this.pid, this.pid);
        }
    }

    public MP2PATSection () {
        base ();
    }

    public override uint16 fields_from_stream (ExtDataInputStream instream) 
            throws Error {
        var bytes_consumed = base.fields_from_stream (instream);
        if (this.table_id != 0x00) {
            throw new IOError.FAILED ("PAT table_id not 0 (found 0x%x)", table_id);
        }
        this.tsid = instream.read_uint16 ();

        var octet_6 = instream.read_byte ();
        this.version_number = Bits.getbits_8 (octet_6, 1, 5);
        this.current_next = Bits.getbit_8 (octet_6, 0);

        this.section_number = instream.read_byte ();
        this.last_section_number = instream.read_byte ();
        bytes_consumed += 5;

        var num_programs = (this.section_length-9) / 4; // 4 bytes per program
        this.program_list = new Gee.ArrayList<Program> ();
        for (uint8 i=0; i<num_programs; i++) {
            var program = new Program ();
            bytes_consumed += program.parse_from_stream (instream);
            this.program_list.add (program);
        }
        this.crc = instream.read_uint32 ();
        bytes_consumed += 4;
        this.loaded = true;
        return bytes_consumed;
    }
    
    public override string to_string () {
        var builder = new StringBuilder ("MP2PATSection[");
        append_fields_to (builder);
        builder.append_c (']');
        return builder.str;
    }

    public override void append_fields_to (StringBuilder builder) {
        if (!this.loaded) {
            builder.append ("fields_not_loaded");
        } else {
            base.append_fields_to (builder);
            builder.append_printf (",tsid %u (0x%x),version %u,sect_num %u of %u,programs:[",
                                   this.tsid, this.tsid,
                                   this.version_number, this.section_number,
                                   this.last_section_number);
            if ((this.program_list != null) && (this.program_list.size > 0)) {
                uint index=1;
                foreach (var program in this.program_list) {
                    builder.append_printf ("%u:[", index++);
                    program.append_fields_to (builder);
                    builder.append ("],");
                }
                builder.truncate (builder.len-1);
            }
            builder.append_printf ("],crc 0x%x", this.crc);
        }
    }

    public override void to_printer (MP2TransportStream.LinePrinter printer, 
                                     string prefix) {
        printer ("%s%s".printf (prefix, this.to_string ()));
        uint index=1;
        foreach (var program in this.program_list) {
            var builder = new StringBuilder ();
            builder.append_printf ("%s   program %u: ", prefix, index++);
            program.append_fields_to (builder);
            printer (builder.str);
        }
    }
} // END class Rygel.MP2PATSection

public class Rygel.MP2PATTable : MP2Table {
    public uint16 get_program_count () {
        uint16 total = 0;
        foreach (var section in this.section_list) {
            MP2PATSection pat_section = (MP2PATSection)section;
            total += (uint16) pat_section.program_list.size;
        }
        return total;
    }

    public MP2PATSection.Program get_program_by_index (int index) throws Error {
        foreach (var section in this.section_list) {
            MP2PATSection pat_section = (MP2PATSection)section;
            var programs_in_section = pat_section.program_list.size;
            if (index < programs_in_section) {
                return (pat_section.program_list.get (index));
            }
            index -= programs_in_section;
        }
        throw new IOError.FAILED ("Bad program index %u: %s", index,
                                  this.to_string ());
    }

    public Gee.List<MP2PATSection.Program> get_programs () throws Error {
        var program_list = new Gee.ArrayList<MP2PATSection.Program> ();
        foreach (var section in this.section_list) {
            MP2PATSection pat_section = (MP2PATSection)section;
            program_list.add_all (pat_section.program_list);
        }
        return program_list;
    }

    public override void to_printer (MP2TransportStream.LinePrinter printer, 
                                    string prefix) {
        sections_to_printer (printer, prefix, "PAT Table");
    }
} // END class MP2PATTable

public class Rygel.MP2PMTSection : MP2TableSection {

    public const uint8 STREAM_TYPE_RESERVED = 0x00;
    public const uint8 STREAM_TYPE_MPEG1_VIDEO = 0x01;
    public const uint8 STREAM_TYPE_MPEG2_VIDEO = 0x02;
    public const uint8 STREAM_TYPE_MPEG1_AUDIO = 0x03;
    public const uint8 STREAM_TYPE_MPEG2_AUDIO = 0x04;
    public const uint8 STREAM_TYPE_PRIVATE_SECTIONS = 0x05;
    public const uint8 STREAM_TYPE_PRIVATE_PES = 0x06;
    public const uint8 STREAM_TYPE_MHEG = 0x07;
    public const uint8 STREAM_TYPE_DSMCC = 0x08;
    public const uint8 STREAM_TYPE_AUX_PES = 0x09;
    public const uint8 STREAM_TYPE_DSMCC_A = 0x0A;
    public const uint8 STREAM_TYPE_DSMCC_B = 0x0B;
    public const uint8 STREAM_TYPE_DSMCC_C = 0x0C;
    public const uint8 STREAM_TYPE_DSMCC_D = 0x0D;
    public const uint8 STREAM_TYPE_AUX_PES_2 = 0x0E;
    public const uint8 STREAM_TYPE_AAC_ADTS = 0x0F;
    public const uint8 STREAM_TYPE_MPEG4_H263 = 0x10;
    public const uint8 STREAM_TYPE_MPEG4_LOAS = 0x11;
    public const uint8 STREAM_TYPE_MPEG4_FLEXMUX_PES = 0x12;
    public const uint8 STREAM_TYPE_MPEG4_FLEXMUX_SECTIONS = 0x13;
    public const uint8 STREAM_TYPE_DSMCC_DOWNLOAD = 0x14;
    public const uint8 STREAM_TYPE_METADATA_PES = 0x15;
    public const uint8 STREAM_TYPE_METADATA_SECTIONS = 0x16;
    public const uint8 STREAM_TYPE_METADATA_DSMCC_DATA = 0x17;
    public const uint8 STREAM_TYPE_METADATA_DSMCC_OBJECT = 0x18;
    public const uint8 STREAM_TYPE_DSMCC_DOWNLOAD_2 = 0x19;
    public const uint8 STREAM_TYPE_IPMP = 0x1A;
    public const uint8 STREAM_TYPE_H264_VIDEO = 0x1B;
    public const uint8 STREAM_TYPE_H265_VIDEO = 0x24;
    public const uint8 STREAM_TYPE_CHINESE_VIDEO = 0x42;
    public const uint8 STREAM_TYPE_DCII_VIDEO = 0x80;
    public const uint8 STREAM_TYPE_ATSC_AC3_AUDIO = 0x81;
    public const uint8 STREAM_TYPE_SCTE_SUBTITLE = 0x82;
    public const uint8 STREAM_TYPE_TRUEHD_AUDIO = 0x83;
    public const uint8 STREAM_TYPE_DDPLUS_AUDIO = 0x84;
    public const uint8 STREAM_TYPE_DTS8_AUDIO = 0x85;
    public const uint8 STREAM_TYPE_DTS8_LOSSLESS_AUDIO = 0x86;
    public const uint8 STREAM_TYPE_DDPLUS_ATSC_AUDIO = 0x87;
    public const uint8 STREAM_TYPE_BLURAY_SUBTITLE = 0x90;
    public const uint8 STREAM_TYPE_DSMCC_NET_RESOURCE = 0x95;
    public const uint8 STREAM_TYPE_DCII_TEXT = 0xC0;
    public const uint8 STREAM_TYPE_PRIVATE = 0xC1;
    public const uint8 STREAM_TYPE_DSMCC_SYNCRONOUS_DATA = 0xC2;
    public const uint8 STREAM_TYPE_DIRAC_VIDEO = 0xD1;
    public const uint8 STREAM_TYPE_MSWM9_VIDEO = 0xEA;


    public static string stream_type_to_string (uint8 stream_type) {
        switch (stream_type) {
            case STREAM_TYPE_RESERVED: return "RESERVED";
            case STREAM_TYPE_MPEG1_VIDEO: return "MPEG1_VIDEO";
            case STREAM_TYPE_MPEG2_VIDEO: return "MPEG2_VIDEO";
            case STREAM_TYPE_MPEG1_AUDIO: return "MPEG1_AUDIO";
            case STREAM_TYPE_MPEG2_AUDIO: return "MPEG2_AUDIO";
            case STREAM_TYPE_PRIVATE_SECTIONS: return "PRIVATE_SECTIONS";
            case STREAM_TYPE_PRIVATE_PES: return "PRIVATE_PES";
            case STREAM_TYPE_MHEG: return "MHEG";
            case STREAM_TYPE_DSMCC: return "DSMCC";
            case STREAM_TYPE_AUX_PES: return "AUX_PES";
            case STREAM_TYPE_DSMCC_A: return "DSMCC_A";
            case STREAM_TYPE_DSMCC_B: return "DSMCC_B";
            case STREAM_TYPE_DSMCC_C: return "DSMCC_C";
            case STREAM_TYPE_DSMCC_D: return "DSMCC_D";
            case STREAM_TYPE_AUX_PES_2: return "AUX_PES_2";
            case STREAM_TYPE_AAC_ADTS: return "AAC_ADTS";
            case STREAM_TYPE_MPEG4_H263: return "MPEG4_H263";
            case STREAM_TYPE_MPEG4_LOAS: return "MPEG4_LOAS";
            case STREAM_TYPE_MPEG4_FLEXMUX_PES: return "MPEG4_FLEXMUX_PES";
            case STREAM_TYPE_MPEG4_FLEXMUX_SECTIONS: return "MPEG4_FLEXMUX_SECTIONS";
            case STREAM_TYPE_DSMCC_DOWNLOAD: return "DSMCC_DOWNLOAD";
            case STREAM_TYPE_METADATA_PES: return "METADATA_PES";
            case STREAM_TYPE_METADATA_SECTIONS: return "METADATA_SECTIONS";
            case STREAM_TYPE_METADATA_DSMCC_DATA: return "METADATA_DSMCC_DATA";
            case STREAM_TYPE_METADATA_DSMCC_OBJECT: return "METADATA_DSMCC_OBJECT";
            case STREAM_TYPE_DSMCC_DOWNLOAD_2: return "DSMCC_DOWNLOAD_2";
            case STREAM_TYPE_IPMP: return "IPMP";
            case STREAM_TYPE_H264_VIDEO: return "H264_VIDEO";
            case STREAM_TYPE_H265_VIDEO: return "H265_VIDEO";
            case STREAM_TYPE_CHINESE_VIDEO: return "CHINESE_VIDEO";
            case STREAM_TYPE_DCII_VIDEO: return "DCII_VIDEO";
            case STREAM_TYPE_ATSC_AC3_AUDIO: return "ATSC_AC3_AUDIO";
            case STREAM_TYPE_SCTE_SUBTITLE: return "SCTE_SUBTITLE";
            case STREAM_TYPE_TRUEHD_AUDIO: return "TRUEHD_AUDIO";
            case STREAM_TYPE_DDPLUS_AUDIO: return "DDPLUS_AUDIO";
            case STREAM_TYPE_DTS8_AUDIO: return "DTS8_AUDIO";
            case STREAM_TYPE_DTS8_LOSSLESS_AUDIO: return "DTS8_LOSSLESS_AUDIO";
            case STREAM_TYPE_DDPLUS_ATSC_AUDIO: return "DDPLUS_ATSC_AUDIO";
            case STREAM_TYPE_BLURAY_SUBTITLE: return "BLURAY_SUBTITLE";
            case STREAM_TYPE_DSMCC_NET_RESOURCE: return "DSMCC_NET_RESOURCE";
            case STREAM_TYPE_DCII_TEXT: return "DCII_TEXT";
            case STREAM_TYPE_PRIVATE: return "PRIVATE";
            case STREAM_TYPE_DSMCC_SYNCRONOUS_DATA: return "DSMCC_SYNCRONOUS_DATA";
            case STREAM_TYPE_DIRAC_VIDEO: return "DIRAC_VIDEO";
            case STREAM_TYPE_MSWM9_VIDEO: return "MSWM9_VIDEO";
            default: return "UNKNOWN";
        }
    }

    public uint16 program_number;
    public bool current_next;
    public uint16 pcr_pid;
    public uint16 program_info_length;
    public Gee.List<MP2Descriptor> descriptor_list;
    public Gee.List<StreamInfo> stream_info_list = null;
    public uint32 crc;

    public class StreamInfo {
        public uint8 stream_type;
        public uint16 pid;
        public uint16 es_info_length;
        public Gee.List<MP2Descriptor> descriptor_list;

        public uint16 parse_from_stream (ExtDataInputStream instream)
                throws Error {
            this.stream_type = instream.read_byte ();
            this.pid = Bits.readbits_16 (instream, 0, 13);
            this.es_info_length = Bits.readbits_16 (instream, 0, 12);
            uint16 bytes_consumed = 5;
            this.descriptor_list = new ArrayList <MP2Descriptor> ();
            uint64 desc_bytes_read = 0;
            while (desc_bytes_read < this.es_info_length) {
                var desc = new MP2Descriptor.from_stream (instream, 
                                                          instream.tell ());
                desc_bytes_read += desc.parse_from_stream ();
                this.descriptor_list.add (desc);
            }
            if (desc_bytes_read != this.es_info_length) {
                throw new IOError.FAILED ("Found more descriptor bytes than expected (found %u, expected %u)", 
                                          desc_bytes_read, 
                                          this.es_info_length);
            }
            bytes_consumed += this.es_info_length;
            return bytes_consumed;
        }
        
        public bool is_audio () {
            switch (this.stream_type) {
                case STREAM_TYPE_MPEG1_AUDIO: 
                case STREAM_TYPE_MPEG2_AUDIO: 
                case STREAM_TYPE_AAC_ADTS: 
                case STREAM_TYPE_MPEG4_LOAS: 
                case STREAM_TYPE_ATSC_AC3_AUDIO: 
                case STREAM_TYPE_TRUEHD_AUDIO: 
                case STREAM_TYPE_DDPLUS_AUDIO: 
                case STREAM_TYPE_DTS8_AUDIO: 
                case STREAM_TYPE_DTS8_LOSSLESS_AUDIO: 
                case STREAM_TYPE_DDPLUS_ATSC_AUDIO: 
                    return true;
                default: 
                    return false;
            }
        }

        public bool is_video () {
            switch (this.stream_type) {
                case STREAM_TYPE_MPEG1_VIDEO: 
                case STREAM_TYPE_MPEG2_VIDEO: 
                case STREAM_TYPE_MPEG4_H263: 
                case STREAM_TYPE_H264_VIDEO: 
                case STREAM_TYPE_H265_VIDEO: 
                case STREAM_TYPE_CHINESE_VIDEO: 
                case STREAM_TYPE_DCII_VIDEO: 
                case STREAM_TYPE_DIRAC_VIDEO: 
                case STREAM_TYPE_MSWM9_VIDEO: 
                    return true;
                default: 
                    return false;
            }
        }

        public string to_string () {
            var builder = new StringBuilder ("StreamInfo[");
            append_fields_to (builder);
            builder.append_c (']');
            return builder.str;
        }

        public void append_fields_to (StringBuilder builder) {
            builder.append_printf ("stream_type %u (0x%x) (%s),pid %d (0x%x)",
                                   this.stream_type, this.stream_type,
                                   stream_type_to_string (this.stream_type),
                                   this.pid, this.pid);
            uint num=1;
            if ((this.descriptor_list != null) 
                 && (this.descriptor_list.size > 0)) {
                builder.append (",descriptors:[");
                foreach (var desc in this.descriptor_list) {
                    builder.append_printf ("%u:[", num++);
                    desc.append_fields_to (builder);
                    builder.append ("],");
                }
                builder.truncate (builder.len-1);
                builder.append_c (']');
            }
        }
    } // END class StreamInfo

    public MP2PMTSection () {
        base ();
    }

    public override uint16 fields_from_stream (ExtDataInputStream instream) throws Error {
        var bytes_consumed = base.fields_from_stream (instream);
        if (this.table_id != 0x02) {
            throw new IOError.FAILED ("PMT table_id not 2 (found 0x%x)", table_id);
        }
        this.program_number = instream.read_uint16 ();

        var octet_6 = instream.read_byte ();
        this.version_number = Bits.getbits_8 (octet_6, 1, 5);
        this.current_next = Bits.getbit_8 (octet_6, 0);

        this.section_number = instream.read_byte ();
        this.last_section_number = instream.read_byte ();
        this.pcr_pid = Bits.readbits_16 (instream, 0, 13);
        this.program_info_length = Bits.readbits_16 (instream, 0, 12);
        bytes_consumed += 9;
        {
            uint64 descriptor_bytes_read = 0;
            while (descriptor_bytes_read < this.program_info_length) {
                var descriptor = new MP2Descriptor.from_stream 
                                  (instream, bytes_consumed 
                                             + descriptor_bytes_read);
                this.descriptor_list.add (descriptor);
                descriptor_bytes_read += descriptor.parse_from_stream ();
            }
            if (descriptor_bytes_read != this.program_info_length) {
                throw new IOError.FAILED ("Found more descriptor bytes than expected (found %u, expected %u)", 
                                          descriptor_bytes_read, 
                                          this.program_info_length);
            }
            bytes_consumed += (uint8)this.program_info_length;
        }
        {
            this.stream_info_list = new ArrayList <StreamInfo> ();
            uint8 total_stream_bytes = this.section_length - bytes_consumed - 1;
            uint64 stream_bytes_read = 0;
            while (stream_bytes_read < total_stream_bytes) {
                var stream_info = new StreamInfo ();
                stream_bytes_read += stream_info.parse_from_stream (instream);
                this.stream_info_list.add (stream_info);
                
            }
            if (stream_bytes_read != total_stream_bytes) {
                throw new IOError.FAILED ("Found more es stream bytes than expected (found %u, expected %u)", 
                                          stream_bytes_read, 
                                          total_stream_bytes);
            }
            bytes_consumed += total_stream_bytes;
        }

        this.crc = instream.read_uint32 ();
        bytes_consumed += 4;
        this.loaded = true;
        return bytes_consumed;
    }
    
    public override string to_string () {
        var builder = new StringBuilder ("MP2PMTSection[");
        append_fields_to (builder);
        builder.append_c (']');
        return builder.str;
    }

    public override void append_fields_to (StringBuilder builder) {
        if (!this.loaded) {
            builder.append ("fields_not_loaded");
        } else {
            base.append_fields_to (builder);
            builder.append_printf (",program_num %u (0x%x),pcr_pid %u (0x%x),version %u,sect_num %u of %u",
                                   this.program_number, this.program_number, 
                                   this.pcr_pid, this.pcr_pid, this.version_number, 
                                   this.section_number, this.last_section_number);
            uint num=1;
            if ((this.descriptor_list != null) 
                 && (this.descriptor_list.size > 0)) {
                builder.append (",descriptors:[");
                foreach (var descriptor in this.descriptor_list) {
                    builder.append_printf ("%u:[", num);
                    builder.append (descriptor.to_string ());
                    builder.append ("],");
                }
                builder.truncate (builder.len-1);
                builder.append_c (']');
            }
            builder.append (",streams:[");
            if ((this.stream_info_list != null)
                && (this.stream_info_list.size > 0)) {
                num = 1;
                foreach (var stream_info in this.stream_info_list) {
                    builder.append_printf ("%u:[", num++);
                    stream_info.append_fields_to (builder);
                    builder.append ("],");
                }
                builder.truncate (builder.len-1);
            }
            builder.append_printf ("],crc 0x%x", this.crc);
        }
    }

    public override void to_printer (MP2TransportStream.LinePrinter printer, 
                                     string prefix) {
        printer ("%s%s".printf (prefix,this.to_string ()));
        uint index=1;
        foreach (var stream_info in this.stream_info_list) {
            var builder = new StringBuilder ();
            builder.append_printf ("%s   estream %u: ", prefix, index++);
            stream_info.append_fields_to (builder);
            printer (builder.str);
        }
    }
} // END class Rygel.MP2PMTSection

public class Rygel.MP2PMTTable : MP2Table {
    public Gee.List<MP2PMTSection.StreamInfo> get_streams () throws Error {
        var stream_list = new Gee.ArrayList<MP2PMTSection.StreamInfo> ();
        foreach (var section in this.section_list) {
            MP2PMTSection pmt_section = (MP2PMTSection)section;
            stream_list.add_all (pmt_section.stream_info_list);
        }
        return stream_list;
    }

    public override string to_string () {
        var builder = new StringBuilder ("MP2PMTTable[");
        append_fields_to (builder);
        builder.append_c (']');
        return builder.str;
    }

    protected override void append_fields_to (StringBuilder builder) {
        builder.append_printf ("version %u,num_sections %u,streams:[",
                               this.version_number, this.total_sections);
        uint num=1;
        foreach (var section in this.section_list) {
            MP2PMTSection pmt_section = (MP2PMTSection)section;
            builder.append_printf ("%u:[",num++);
            pmt_section.append_fields_to (builder);
            builder.append ("],");
        }
        builder.truncate (builder.len-1);
        builder.append_c (']');
    }

    public override void to_printer (MP2TransportStream.LinePrinter printer, 
                                    string prefix) {
        sections_to_printer (printer, prefix, "PMT Table");
    }
} // END class MP2PMTTable

public class Rygel.MP2DescriptorFactory {
    public static MP2Descriptor create_descriptor_from_stream (
                                    ExtDataInputStream instream) 
            throws Error {
        uint8 peek_buf[1];
        instream.peek (peek_buf);
        var cur_offset = instream.tell ();
        switch (peek_buf[0]) { // the descriptor tag
            // TODO: Add specific descriptor subclass references here...
            default:
            return new MP2Descriptor.from_stream (instream, cur_offset);
        }
    }
} // END MP2DescriptorFactory

public class Rygel.MP2Descriptor {
    public unowned ExtDataInputStream source_stream;
    public uint64 source_offset;
    public bool source_verbatim;
    public bool loaded;

    public uint8 tag;
    public uint8 length;

    public MP2Descriptor () {
    }

    public MP2Descriptor.from_stream (ExtDataInputStream stream, uint64 offset)
            throws Error {
        this.source_stream = stream;
        this.source_offset = offset;
        this.source_verbatim = true;
        this.loaded = false;
    }

    public virtual uint64 parse_from_stream () throws Error {
        // debug ("parse_from_stream()", this.type_code);
        // Note: This currently assumes the stream is pre-positioned for the PES packet
        var instream = this.source_stream;

        this.tag = instream.read_byte ();
        this.length = instream.read_byte ();
        instream.skip_bytes (this.length);
        this.loaded = true;
        return (this.length + 2);
    }
    
    public string to_string () {
        var builder = new StringBuilder ("MP2Descriptor[");
        append_fields_to (builder);
        builder.append_c (']');
        return builder.str;
    }

    public void append_fields_to (StringBuilder builder) {
        if (!this.loaded) {
            builder.append ("fields_not_loaded");
        } else {
            builder.append_printf ("offset %llu,tag %u,len %u", 
                                   this.source_offset, this.tag, this.length);
        }
    }
} // END class MP2Descriptor

public class Rygel.MP2PESPacket {
    public const uint8 STREAM_ID_PSM = 0xBC;
    public const uint8 STREAM_ID_PRIVATE_1 = 0xBD;
    public const uint8 STREAM_ID_PADDING = 0xBE;
    public const uint8 STREAM_ID_PRIVATE_2 = 0xBF;
    public const uint8 STREAM_ID_ECM = 0xF0;
    public const uint8 STREAM_ID_EMM = 0xF1;
    public const uint8 STREAM_ID_DSMCC = 0xF2;
    public const uint8 STREAM_ID_ISO13522 = 0xF3;
    public const uint8 STREAM_ID_H222_A = 0xF4;
    public const uint8 STREAM_ID_H222_B = 0xF5;
    public const uint8 STREAM_ID_H222_C = 0xF6;
    public const uint8 STREAM_ID_H222_D = 0xF7;
    public const uint8 STREAM_ID_H222_E = 0xF8;
    public const uint8 STREAM_ID_ANCILLARY = 0xF9;
    public const uint8 STREAM_ID_ISO14496_SL = 0xFA;
    public const uint8 STREAM_ID_ISO14496_FLEXMUX = 0xFB;
    public const uint8 STREAM_ID_PSD = 0xFF;
    public const uint8 STREAM_ID_AUDIO = 0xC0;
    public const uint8 STREAM_ID_AUDIO_MASK = 0xE0;
    public const uint8 STREAM_ID_VIDEO = 0xE0;
    public const uint8 STREAM_ID_VIDEO_MASK = 0xF0;

    public static string stream_id_to_string (uint8 stream_id) {
        switch (stream_id) {
            case STREAM_ID_PSM:
                return "PSM";
            case STREAM_ID_PRIVATE_1:
                return "private_1";
            case STREAM_ID_PADDING:
                return "padding";
            case STREAM_ID_PRIVATE_2:
                return "private 2";
            case STREAM_ID_ECM:
                return "ECM";
            case STREAM_ID_EMM:
                return "EMM";
            case STREAM_ID_DSMCC:
                return "DSMCC";
            case STREAM_ID_ISO13522:
                return "ISO13522";
            case STREAM_ID_H222_A:
                return "H222_A";
            case STREAM_ID_H222_B:
                return "H222_B";
            case STREAM_ID_H222_C:
                return "H222_C";
            case STREAM_ID_H222_D:
                return "H222_D";
            case STREAM_ID_H222_E:
                return "H222_E";
            case STREAM_ID_ANCILLARY:
                return "ancillary";
            case STREAM_ID_ISO14496_SL:
                return "ISO14496 SL";
            case STREAM_ID_ISO14496_FLEXMUX:
                return "ISO14496 FLEXMUX";
            case STREAM_ID_PSD:
                return "PSD";
            default:
                if ((stream_id & STREAM_ID_AUDIO_MASK) == STREAM_ID_AUDIO) {
                    return "audio";
                }
                if ((stream_id & STREAM_ID_VIDEO_MASK) == STREAM_ID_VIDEO) {
                    return "video";
                }
                
                return "unknown";
        }
    }

    public unowned ExtDataInputStream source_stream;
    public uint64 source_offset;
    public bool source_verbatim;

    public uint8 stream_id;
    public uint16 packet_length; // Can be 0 for video streams
    public MP2PESHeader pes_header;
    public bool has_payload;
    public uint8 header_size; // offset of the data portion of the TS packet

    protected bool loaded; // Indicates the packet fields/children are populated/parsed

    public MP2PESPacket () {
    }

    public MP2PESPacket.from_stream (ExtDataInputStream stream, uint64 offset)
            throws Error {
        this.source_stream = stream;
        this.source_offset = offset;
        this.source_verbatim = true;
        this.loaded = false;
    }

    public virtual uint64 parse_from_stream_seek () throws Error {
        this.source_stream.seek_to_offset (this.source_offset);
        return parse_from_stream_noseek ();
    }

    public virtual uint64 parse_from_stream_noseek () throws Error {
        var instream = this.source_stream;

        var start_code_prefix = instream.read_bytes_uint32 (3);
        if (start_code_prefix != 0x000001) {
            throw new IOError.FAILED ("PES start code mismatch: 0x%x",
                                      start_code_prefix);
        }
        
        this.stream_id = instream.read_byte ();
        this.packet_length = instream.read_uint16 ();
        uint8 bytes_consumed = 6;

        if (!has_pes_header ()) {
            this.pes_header = null;
        } else {
            this.pes_header = new MP2PESHeader ();
            try {
                bytes_consumed += this.pes_header.parse_from_stream (instream);
            } catch (Error err) {
                throw new IOError.FAILED ("Error %lld bytes into parse: %s",
                                          this.source_offset + bytes_consumed, 
                                          err.message);
            }
        }
        this.has_payload = this.stream_id != STREAM_ID_PADDING;
        this.header_size = bytes_consumed;
        if ((this.packet_length != 0)
            && (bytes_consumed > this.packet_length+6)) {
            throw new IOError.FAILED ("Found %d bytes in PES packet of %d bytes: %s",
                                      bytes_consumed, this.packet_length+6,
                                      to_string ());
        }
        this.source_verbatim = false;
        this.loaded = true;

        return bytes_consumed;
    }

    public virtual uint16 get_size () {
        return (6 + ((this.pes_header != null) 
                     ? this.pes_header.get_size () : 0));
    }

    public virtual uint64 fields_to_stream (ExtDataOutputStream ostream) throws Error {
        ostream.put_bytes_uint32 (0x000001, 3);
        ostream.put_byte (this.stream_id);
        ostream.put_uint16 (this.packet_length);
        uint16 bytes_written = 6;
        if (this.pes_header != null) {
            bytes_written += this.pes_header.fields_to_stream (ostream);
        }

        return bytes_written;
    }

    public bool is_audio () {
        return ((this.stream_id & STREAM_ID_AUDIO_MASK) == STREAM_ID_AUDIO);
    }
    
    public bool is_video () {
        return ((this.stream_id & STREAM_ID_VIDEO_MASK) == STREAM_ID_VIDEO);
    }

    public bool has_pes_header () {
        switch (this.stream_id) {
            case STREAM_ID_PSM:
            case STREAM_ID_PADDING:
            case STREAM_ID_PRIVATE_2:
            case STREAM_ID_ECM:
            case STREAM_ID_EMM:
            case STREAM_ID_PSD:
            case STREAM_ID_DSMCC:
            case STREAM_ID_H222_E:
                return false;
            default:
                return true;
        }
    }
   
    public string to_string () {
        var builder = new StringBuilder ("MP2PESPacket[");
        append_fields_to (builder);
        builder.append_c (']');
        return builder.str;
    }

    protected void append_fields_to (StringBuilder builder) {
        if (!this.loaded) {
            builder.append ("fields_not_loaded");
        } else {
            builder.append_printf ("offset %lld,stream_id %d (0x%x) (%s),length %d (0x%x)",
                                   this.source_offset, 
                                   this.stream_id, this.stream_id,
                                   stream_id_to_string (this.stream_id),
                                   this.packet_length, this.packet_length);
            if (this.has_payload) {
                builder.append_printf (",header_size %lld", this.header_size);
            }
            if (this.pes_header != null) {
                builder.append_c (',');
                this.pes_header.append_fields_to (builder);
            }
        }
    }

    public class MP2PESHeader {
        public uint8 scrambling_control;
        public bool priority;
        public bool data_alignment_indicator;
        public bool copyright;
        public bool original_or_copy;
        public bool pts_flag;
        public bool dts_flag;
        public bool escr_flag;
        public bool es_rate_flag;
        public bool dsm_trick_mode_flag;
        public bool additional_copy_info_flag;
        public bool crc_flag;
        public bool extension_flag;
        public uint64 pts;
        public uint64 dts;
        public uint64 escr;
        public uint32 es_rate;
        public uint8 dsm_trick_mode;
        public uint8 additional_copy_info;
        public uint16 previous_packet_crc;
        public MP2PESExtension extension;
        public uint8 num_stuffing_bytes;

        public MP2PESHeader () {
        }

        public uint8 parse_from_stream (ExtDataInputStream instream)
                throws Error {
            var octet_1 = instream.read_byte ();
            this.scrambling_control = Bits.getbits_8 (octet_1, 4, 2);
            this.priority = Bits.getbit_8 (octet_1, 3);
            this.data_alignment_indicator = Bits.getbit_8 (octet_1, 2);
            this.copyright = Bits.getbit_8 (octet_1, 1);
            this.original_or_copy = Bits.getbit_8 (octet_1, 0);

            var octet_2 = instream.read_byte ();
            this.pts_flag = Bits.getbit_8 (octet_2, 7);
            this.dts_flag = Bits.getbit_8 (octet_2, 6);
            this.escr_flag = Bits.getbit_8 (octet_2, 5);
            this.es_rate_flag = Bits.getbit_8 (octet_2, 4);
            this.dsm_trick_mode_flag = Bits.getbit_8 (octet_2, 3);
            this.additional_copy_info_flag = Bits.getbit_8 (octet_2, 2);
            this.crc_flag = Bits.getbit_8 (octet_2, 1);
            this.extension_flag = Bits.getbit_8 (octet_2, 0);
            
            var header_data_length = instream.read_byte ();
            
            uint8 bytes_consumed = 3;

            if (this.pts_flag) {
                var pts_field_1 = instream.read_byte ();
                this.pts = Bits.getbits_8 (pts_field_1, 1, 3) << 30;
                var pts_field_2 = instream.read_uint16 ();
                this.pts |= Bits.getbits_16 (pts_field_2, 1, 15) << 15;
                pts_field_2 = instream.read_uint16 ();
                this.pts |= Bits.getbits_16 (pts_field_2, 1, 15);
                bytes_consumed += 5;
            }
            if (this.dts_flag) {
                var dts_field_1 = instream.read_byte ();
                this.dts = Bits.getbits_8 (dts_field_1, 1, 3) << 30;
                var dts_field_2 = instream.read_uint16 ();
                this.dts |= Bits.getbits_16 (dts_field_2, 1, 15) << 15;
                dts_field_2 = instream.read_uint16 ();
                this.dts |= Bits.getbits_16 (dts_field_2, 1, 15);
                bytes_consumed += 5;
            }
            if (this.escr_flag) {
                var escr_fields = instream.read_bytes_uint64 (6); // 48 bits
                this.escr = Bits.getbits_64 (escr_fields, 43, 3) << 30;
                this.escr |= Bits.getbits_64 (escr_fields, 27, 15) << 15;
                this.escr |= Bits.getbits_64 (escr_fields, 11, 15);
                this.escr *= 300;
                this.escr += (uint16)Bits.getbits_64 (escr_fields, 1, 9);
                bytes_consumed += 6;
            }
            if (this.es_rate_flag) {
                this.es_rate = Bits.getbits_16 (instream.read_uint16 (), 1, 22);
                bytes_consumed += 2;
            }
            if (this.dsm_trick_mode_flag) {
                this.dsm_trick_mode = instream.read_byte ();
                bytes_consumed += 1;
            }
            if (this.additional_copy_info_flag) {
                this.additional_copy_info 
                        = Bits.getbits_8 (instream.read_byte (), 0, 7);
                bytes_consumed += 1;
            }
            if (this.crc_flag) {
                this.previous_packet_crc = instream.read_uint16 ();
                bytes_consumed += 2;
            }
            if (this.extension_flag) {
                this.extension = new MP2PESExtension ();
                bytes_consumed += this.extension.parse_from_stream (instream);
            }

            if (bytes_consumed > header_data_length+3) {
                throw new IOError.FAILED ("Parsed %d bytes in PES extension with length of %d bytes: %s",
                                          bytes_consumed, header_data_length+3,
                                          to_string ());
            }
            this.num_stuffing_bytes = header_data_length+3 - bytes_consumed;
            instream.skip_bytes (this.num_stuffing_bytes);
            bytes_consumed += this.num_stuffing_bytes;

            return bytes_consumed;
        }

        public virtual uint8 get_size () {
            return (3 + (this.pts_flag ? 5 : 0) 
                      + (this.dts_flag ? 5 : 0)
                      + (this.escr_flag ? 6 : 0)
                      + (this.es_rate_flag ? 2 : 0) 
                      + (this.dsm_trick_mode_flag ? 1 : 0) 
                      + (this.additional_copy_info_flag ? 1 : 0) 
                      + (this.crc_flag ? 2 : 0) 
                      + (this.extension_flag ? this.extension.get_size () : 0)
                      + this.num_stuffing_bytes);
        }

        public virtual uint8 fields_to_stream (ExtDataOutputStream ostream) 
                throws Error {
            uint8 octet_1 = 0x80 
                            | this.scrambling_control << 4
                            | (this.priority ? 1 : 0) << 3
                            | (this.data_alignment_indicator ? 1 : 0) << 2
                            | (this.copyright ? 1 : 0) << 1
                            | (this.original_or_copy ? 1 : 0);
            ostream.put_byte (octet_1);

            uint8 octet_2 = (this.pts_flag ? 1 : 0) << 7
                            | (this.dts_flag ? 1 : 0) << 6
                            | (this.escr_flag ? 1 : 0) << 5
                            | (this.es_rate_flag ? 1 : 0) << 4
                            | (this.dsm_trick_mode_flag ? 1 : 0) << 3
                            | (this.additional_copy_info_flag ? 1 : 0) << 2
                            | (this.crc_flag ? 1 : 0) << 1
                            | (this.extension_flag ? 1 : 0);
            ostream.put_byte (octet_2);

            ostream.put_byte (get_size () - 3);

            uint8 bytes_written = 3;

            if (this.pts_flag) {
                ostream.put_byte (0x20 | (this.dts_flag ? 1 : 0) << 4 
                                    | Bits.getbits_64 (this.pts, 30, 3) << 1
                                    | 0x01); // marker bit
                ostream.put_uint16 ((uint16)
                                      (Bits.getbits_64 (this.pts, 15, 15) << 1
                                       | 0x0001)); // marker bit
                ostream.put_uint16 ((uint16)
                                      (Bits.getbits_64 (this.pts, 0, 15) << 1
                                       | 0x0001)); // marker bit
                bytes_written += 5;
            }
            if (this.dts_flag) {
                ostream.put_byte (0x11 
                                    | Bits.getbits_64 (this.dts, 30, 3) << 1);
                ostream.put_uint16 ((uint16)
                                      (Bits.getbits_64 (this.dts, 15, 15) << 1
                                       | 0x0001)); // marker bit
                ostream.put_uint16 ((uint16)
                                      (Bits.getbits_64 (this.dts, 0, 15) << 1
                                       | 0x0001)); // marker bit
                bytes_written += 5;
            }
            if (this.escr_flag) {
                uint64 escr_fields;
                uint64 escr_base = this.escr / 300;
                uint16 escr_ext = (uint16)this.escr % 300;

                escr_fields = 0xC40004000401; // reserved/marker bits
                escr_fields = Bits.getbits_64 (escr_base, 30, 3) << 43
                              | Bits.getbits_64 (escr_base, 15, 15) << 27
                              | Bits.getbits_64 (escr_base, 0, 15) << 11
                              | escr_ext < 1;
                ostream.put_bytes_uint64 (escr_fields, 6); // 48 bits
                bytes_written += 6;
            }
            if (this.es_rate_flag) {
                ostream.put_bytes_uint32 (0x800001 | this.es_rate << 1, 
                                          3); // 24 bits
                bytes_written += 3;
            }
            if (this.dsm_trick_mode_flag) {
                ostream.put_byte (this.dsm_trick_mode);
                bytes_written++;
            }
            if (this.additional_copy_info_flag) {
                ostream.put_byte (0x40 | this.additional_copy_info);
                bytes_written++;
            }
            if (this.crc_flag) {
                ostream.put_uint16 (this.previous_packet_crc);
                bytes_written += 2;
            }
            if (this.extension_flag) {
                bytes_written += this.extension.fields_to_stream (ostream);
            }

            return bytes_written;
        }
        
        public string to_string () {
            var builder = new StringBuilder ("MP2PESHeader[");
            append_fields_to (builder);
            builder.append_c (']');
            return builder.str;
        }

        public void append_fields_to (StringBuilder builder) {
            builder.append_printf ("scram %d,flags[", this.scrambling_control);
            bool first = true;
            if (this.priority) {
                builder.append ("PRI");
                first = false;
            }
            if (this.data_alignment_indicator) {
                if (!first) builder.append_c ('+');
                builder.append ("ALIGN");
                first = false;
            }
            if (this.copyright) {
                if (!first) builder.append_c ('+');
                builder.append ("CR");
                first = false;
            }
            if (this.original_or_copy) {
                if (!first) builder.append_c ('+');
                builder.append ("COPY");
                first = false;
            }
            if (this.pts_flag) {
                if (!first) builder.append_c ('+');
                builder.append ("PTS");
                first = false;
            }
            if (this.dts_flag) {
                if (!first) builder.append_c ('+');
                builder.append ("DTS");
                first = false;
            }
            if (this.escr_flag) {
                if (!first) builder.append_c ('+');
                builder.append ("ESCR");
                first = false;
            }
            if (this.es_rate_flag) {
                if (!first) builder.append_c ('+');
                builder.append ("ESRATE");
                first = false;
            }
            if (this.dsm_trick_mode_flag) {
                if (!first) builder.append_c ('+');
                builder.append ("DSMTRICK");
                first = false;
            }
            if (this.additional_copy_info_flag) {
                if (!first) builder.append_c ('+');
                builder.append ("ADDCOPY");
                first = false;
            }
            if (this.crc_flag) {
                if (!first) builder.append_c ('+');
                builder.append ("CRC");
                first = false;
            }
            if (this.extension_flag) {
                if (!first) builder.append_c ('+');
                builder.append ("EXT");
            }
            builder.append_c (']');

            if (this.pts_flag) {
                builder.append_printf (",pts %lld (0x%llx)(%0.3fs)", 
                                       this.pts, this.pts, this.pts/90000.0);
            }
            if (this.dts_flag) {
                builder.append_printf (",dts %lld (0x%llx)(%0.3fs)", 
                                       this.dts, this.dts, this.dts/90000.0);
            }
            if (this.escr_flag) {
                builder.append_printf (",escr_%lld (0x%llx)", this.escr, this.escr);
            }
            if (this.es_rate_flag) {
                builder.append_printf (",es_Rate %ld (0x%lx)", this.es_rate, this.es_rate);
            }
            if (this.dsm_trick_mode_flag) {
                builder.append_printf ("dsmcc_trick 0x%x", this.dsm_trick_mode);
            }
            if (this.additional_copy_info_flag) {
                builder.append_printf (",add_copy %d (0x%x)", 
                                       this.additional_copy_info,  
                                       this.additional_copy_info);
            }
            if (this.crc_flag) {
                builder.append_printf (",prev_pes_crc %d (0x%x)", 
                                       this.previous_packet_crc,  
                                       this.previous_packet_crc);
            }
            if (this.extension_flag) {
                builder.append_c (',');
                this.extension.append_fields_to (builder);
            }
        }

        public class MP2PESExtension {
            public bool private_data_flag;
            public bool pack_header_field_flag;
            public bool program_packet_sequence_counter_flag;
            public bool p_std_buffer_flag;
            public bool extension_flag_2;
            public Bytes private_data;
            public Bytes pack_header;
            public uint8 program_packet_sequence_counter;
            public bool mpeg1_mpeg2_identifier;
            public uint8 original_stuff_length;
            public bool p_std_buffer_scale;
            public uint16 p_std_buffer_size;
            public uint8 extension_field_length;

            public MP2PESExtension () {
            }

            public uint8 parse_from_stream (ExtDataInputStream instream)
                    throws Error {
                var octet_1 = instream.read_byte ();
                this.private_data_flag = Bits.getbit_8 (octet_1, 7);
                this.pack_header_field_flag = Bits.getbit_8 (octet_1, 6);
                this.program_packet_sequence_counter_flag = Bits.getbit_8 (octet_1, 5);
                this.p_std_buffer_flag = Bits.getbit_8 (octet_1, 4);
                this.extension_flag_2 = Bits.getbit_8 (octet_1, 0);

                uint8 bytes_consumed = 1;

                if (this.private_data_flag) {
                    instream.skip_bytes (16); // 128 bits
                    bytes_consumed += 16;
                }
                if (this.pack_header_field_flag) {
                    var pack_field_length = instream.read_byte ();
                    this.pack_header = instream.read_bytes (pack_field_length);
                    bytes_consumed += pack_field_length + 1;
                }
                if (this.program_packet_sequence_counter_flag) {
                    var ppsc_fields = instream.read_uint16 ();
                    this.program_packet_sequence_counter 
                            = (uint8)Bits.getbits_16 (ppsc_fields, 8, 7);
                    this.mpeg1_mpeg2_identifier = Bits.getbit_16 (ppsc_fields, 6);
                    this.original_stuff_length 
                            = (uint8)Bits.getbits_16 (ppsc_fields, 0, 6);
                    bytes_consumed += 6;
                }
                if (this.p_std_buffer_flag) {
                    var pstdb_fields = instream.read_uint16 ();
                    this.p_std_buffer_scale = Bits.getbit_16 (pstdb_fields, 13);
                    this.p_std_buffer_size = Bits.getbits_16 (pstdb_fields, 0, 13);
                    bytes_consumed += 2;
                }
                if (this.extension_flag_2) {
                    this.extension_field_length 
                            = Bits.getbits_8 (instream.read_byte (), 0, 7);
                    instream.skip_bytes (this.extension_field_length);
                    bytes_consumed += this.extension_field_length + 1;
                }
                return bytes_consumed;
            }
            
            public virtual uint8 get_size () {
                return (1 + (this.private_data_flag ? 16 : 0) 
                          + (this.pack_header_field_flag 
                                    ? this.pack_header.length : 0)
                          + (this.program_packet_sequence_counter_flag ? 6 : 0)
                          + (this.p_std_buffer_flag ? 2 : 0) 
                          + (this.extension_flag_2 
                                    ? this.extension_field_length : 0));
            }

            public virtual uint8 fields_to_stream (ExtDataOutputStream ostream) 
                    throws Error {
                uint8 octet_1;
                octet_1 = (this.private_data_flag ? 1 : 0) << 7
                           | (this.pack_header_field_flag ? 1 : 0) << 6
                           | (this.program_packet_sequence_counter_flag ? 1 : 0) 
                                << 5
                           | (this.p_std_buffer_flag ? 1 : 0) << 4
                           | 0x0E // reserved bits
                           | (this.extension_flag_2 ? 1 : 0);
                ostream.put_byte (octet_1);
                uint8 bytes_written = 1;
                
                if (this.private_data_flag) {
                    if (this.private_data.length != 16) {
                        throw new IOError.FAILED ("private_data length must be 16 bytes (is %d bytes)" 
                                                  .printf (this.private_data.length));
                    }
                    ostream.write_bytes (this.private_data);
                    bytes_written +=  16;
                }
                if (this.program_packet_sequence_counter_flag) {
                    ostream.put_byte (0x80 // marker bit
                                      | this.program_packet_sequence_counter);
                    ostream.put_byte (0x80 // marker bit
                                      | (this.mpeg1_mpeg2_identifier ? 1 : 0) << 6
                                      | this.original_stuff_length);
                    bytes_written += 2;
                }
                if (this.p_std_buffer_flag) {
                    ostream.put_uint16 (0x4000
                                        | (this.p_std_buffer_scale ? 1 : 0) << 13
                                        | this.p_std_buffer_size);
                    bytes_written += 2;
                }
                if (this.extension_flag_2) {
                    if (this.extension_field_length > 128) {
                        throw new IOError.FAILED ("PES extention field too large (%d)" 
                                                  .printf (this.extension_field_length));
                    }
                    ostream.put_byte ((uint8)this.extension_field_length);
                    for (uint8 i=0; i<this.extension_field_length; i++) {
                        ostream.put_byte (0xFF); // reserved
                    }
                    bytes_written += this.extension_field_length + 1;
                }

                return bytes_written;
            }
            public string to_string () {
                var builder = new StringBuilder ("MP2PESExtension[");
                append_fields_to (builder);
                builder.append_c (']');
                return builder.str;
            }
            public void append_fields_to (StringBuilder builder) {
                builder.append ("flags[");
                bool first = true;
                if (this.private_data_flag) {
                    builder.append ("PRIV");
                    first = false;
                }
                if (this.pack_header_field_flag) {
                    if (!first) builder.append_c ('+');
                    builder.append ("PACK");
                    first = false;
                }
                if (this.program_packet_sequence_counter_flag) {
                    if (!first) builder.append_c ('+');
                    builder.append ("SEQ_COUNT");
                    first = false;
                }
                if (this.p_std_buffer_flag) {
                    if (!first) builder.append_c ('+');
                    builder.append ("STD_BUF");
                    first = false;
                }
                if (this.extension_flag_2) {
                    if (!first) builder.append_c ('+');
                    builder.append ("EXT2");
                }
                builder.append_c (']');

                if (this.pack_header_field_flag) {
                    builder.append_printf (",pack_field_len %d", 
                                           this.pack_header.length);
                }
                if (this.program_packet_sequence_counter_flag) {
                    builder.append_printf (",seq_counter %d,mpeg1/2_id %s,orig_stuff_len %d", 
                                           this.program_packet_sequence_counter,
                                           this.mpeg1_mpeg2_identifier ? "1" : "0",
                                           this.original_stuff_length);
                }
                if (this.p_std_buffer_flag) {
                    builder.append_printf (",buf_scale %s,buf_size %d", 
                                           this.p_std_buffer_scale ? "1" : "0",
                                           this.p_std_buffer_size);
                }
                if (this.extension_flag_2) {
                    builder.append_printf (",ext_2_len %d",
                                           this.extension_field_length);
                }
            }
        } // END class MP2PESExtension
    } // END class MP2PESHeader
} // END class MP2PESPacket

/**
 * A series of related TS packets that can be handled as a unit (e.g. 
 * a sequence of TS packets that makes up an iframe or gop.
 * 
 */
public class Rygel.MP2TSBlob {
    public unowned ExtDataInputStream source_stream;
    public uint64 source_offset;
    public bool source_verbatim;
    public uint32 num_packets;
    // Has a whole number of TS packets and a PES header in the first TS
    //  packet payload.
    // Data will be verbatim from the source except for the PCR, continuity 
    //  counter, and PTS/DTS.
}

class Rygel.MP2ParsingTest : GLib.Object {
    // Can compile/run this with:
    // valac --main=Rygel.MP2ParsingTest.mp2_test --disable-warnings --pkg gio-2.0 --pkg gee-0.8 --pkg posix -g  --target-glib=2.32 "odid-mp2-parser.vala" odid-stream-ext.vala 
    public static int mp2_test (string[] args) {
        int MILLIS_PER_SEC = 1000;
        int MICROS_PER_SEC = 1000000;
        try {
            bool print_infile = false;
            uint64 packets_to_parse = 0;
            bool print_outfile = false;
            int64 print_outfile_packets = -1, print_infile_packets = -1;
            bool print_pat_pmt = false;
            bool print_pes_headers = false;
            bool print_ts_packets_with_pes = false;
            int16 only_pid = -1;
            bool print_access_points = false;
            bool print_movie_duration = false;
            string adhoc_test_name = null;
            uint64 time_range_start_us = 0, time_range_end_us = 0;
            File in_file = null;
            File out_file = null;
            bool buf_out_stream_test = false;
            uint64 buf_out_stream_buf_size = 0;
            bool trim_file = false;
            uint restamp_scale = 0;
            bool restamp = false;

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
                            if ((i+1 < args.length)
                                 && uint64.try_parse (args[i+1], out packets_to_parse)) {
                                i++;
                            } else { // Default to parsing all packets
                                packets_to_parse = 0;
                            }
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
                        case "-restamp":
                            if (restamp) {
                                throw new OptionError.BAD_VALUE ("Only one %s option may be specified",
                                                                 option);
                            }
                            if (i+1 == args.length) {
                                throw new OptionError.BAD_VALUE (option + " requires a parameter");
                            }
                            var restamp_param = args[++i];
                            double scale_factor;
                            if (!double.try_parse (restamp_param, out scale_factor)) {
                                throw new OptionError.BAD_VALUE ("Bad restamp scale factor: " 
                                                                 + restamp_param);
                            }
                            restamp_scale = (uint)(scale_factor * MILLIS_PER_SEC);
                            restamp = true;
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
                                         && int64.try_parse (args[i+1], out print_infile_packets)) {
                                        i++;
                                    } else { // Default to printing all levels
                                        print_infile_packets = -1;
                                    }
                                    break;
                                case "outfile":
                                    print_outfile = true;
                                    if ((i+1 < args.length)
                                         && int64.try_parse (args[i+1], out print_outfile_packets)) {
                                        i++;
                                    } else { // Default to printing all levels
                                        print_outfile_packets = -1;
                                    }
                                    break;
                                case "pat_pmt":
                                    print_pat_pmt = true;
                                    break;
                                case "pes_headers":
                                    print_pes_headers = true;
                                    if ((i+1 < args.length)
                                         && (args[i+1] == "+ts")) {
                                        i++;
                                        print_ts_packets_with_pes = true;
                                    } else { // Default to printing all levels
                                        print_infile_packets = -1;
                                    }
                                    break;
                                case "only_pid":
                                    if (i++ == args.length) {
                                        throw new OptionError.BAD_VALUE (option + " requires a parameter");
                                    }
                                    int64 pid;
                                    if (!int64.try_parse (args[i], out pid) 
                                        || (pid < 0) || (pid > 0x1FFF)) {
                                        throw new OptionError.BAD_VALUE ("Bad PID value: " + args[i]);
                                    }
                                    only_pid = (int16) pid;
                                    break;
                                case "access-points":
                                    print_access_points = true;
                                    break;
                                case "movie-duration":
                                    print_movie_duration = true;
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
                            switch (adhoc_test_name) {
                                case "getbits_64":
                                    uint64 testval = 0x12345678AABBCCCC;
                                    // 63      55      47      39      31     23      15       7      0
                                    // |       |       |       |       |       |       |       |      |
                                    // 1001001000110100010101100111100010101010101110111100110011001100
                                    stderr.printf ("Bits 0-7: 0x%02llx\n", Bits.getbits_64 (testval, 0, 8));
                                    stderr.printf ("Bits 1-7: 0x%02llx\n", Bits.getbits_64 (testval, 1, 7));
                                    stderr.printf ("Bits 2-7: 0x%02llx\n", Bits.getbits_64 (testval, 2, 6));
                                    stderr.printf ("Bits 0-15: 0x%02llx\n", Bits.getbits_64 (testval, 0, 16));
                                    stderr.printf ("Bits 16-23: 0x%02llx\n", Bits.getbits_64 (testval, 16, 8));
                                    stderr.printf ("Bits 56-63: 0x%02llx\n", Bits.getbits_64 (testval, 56, 8));
                                    stderr.printf ("All bits: ");
                                    for (int bit=63; bit >= 0; bit--) {
                                        stderr.printf ("%lld", Bits.getbits_64 (testval, bit, 1));
                                    }
                                    stderr.printf ("\n");
                                break;
                                case "getbits_32":
                                    uint32 testval = 0x159EAABB;
                                    // 31     23      15       7      0
                                    // |       |       |       |      |
                                    // 00010101100111101010101010111011
                                    stderr.printf ("Bits 0-7: 0x%02llx\n", Bits.getbits_32 (testval, 0, 8));
                                    stderr.printf ("Bits 1-7: 0x%02llx\n", Bits.getbits_32 (testval, 1, 7));
                                    stderr.printf ("Bits 2-7: 0x%02llx\n", Bits.getbits_32 (testval, 2, 6));
                                    stderr.printf ("Bits 0-15: 0x%02llx\n", Bits.getbits_32 (testval, 0, 16));
                                    stderr.printf ("Bits 16-23: 0x%02llx\n", Bits.getbits_32 (testval, 16, 8));
                                    stderr.printf ("All bits: ");
                                    for (int bit=31; bit >= 0; bit--) {
                                        stderr.printf ("%lld", Bits.getbits_32 (testval, bit, 1));
                                    }
                                    stderr.printf ("\n");
                                break;
                                default:
                                    throw new OptionError.BAD_VALUE ("Unknown adhoc test: %s", adhoc_test_name);
                            }
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
                stderr.printf ("\t[-timerange x-y]: Reduce the samples in the MP2 to those falling between time range x-y (decimal seconds)\n");
                stderr.printf ("\t[-print (infile [levels]|outfile [levels]|pat_pmt|pes_headers [+ts]|only_pid <pid>|access-points|movie-duration|track-duration|track-for-time [time])]: Print various details to the standard output\n");
                stderr.printf ("\t[-restamp <scale-factor]: Restamp the output file with PCR/PTS/DTS scaled by scale-factor\n");
                stderr.printf ("\t[-outfile <filename>]: Write the resulting MP2 to the given filename\n");
                stderr.printf ("\t[-bufoutstream [buffer_size]]: Test running the resulting MP2 through the BufferGeneratingOutputStream\n");
                return 1;
            }

            stdout.printf ("\nINPUT FILE: %s\n", in_file.get_path ());
            stdout.flush ();
            MP2TransportStreamFile mp2_file = null;

            MP2TransportStream.LinePrinter my_printer 
                    = (l) =>  {stdout.puts (l); stdout.putc ('\n');};


            if (print_infile) {
                mp2_file = new Rygel.MP2TransportStreamFile (in_file);
                mp2_file.parse_from_stream (packets_to_parse);
                stdout.printf ("\nPARSED TS INPUT FILE (%s packets)\n",
                               ((packets_to_parse == 0) 
                                ? "all" : packets_to_parse.to_string ()));
                if (only_pid < 0) {
                    mp2_file.to_printer (my_printer, "  ");
                } else {
                    mp2_file.to_printer_with_pid (my_printer, "  ", only_pid);
                }
            }

            MP2PMTSection.StreamInfo target_stream = null;
            MP2PATSection.Program target_program = null;

            if (print_pat_pmt || print_pes_headers) {
                if (mp2_file == null) {
                    mp2_file = new Rygel.MP2TransportStreamFile (in_file);
                    mp2_file.parse_from_stream (packets_to_parse);
                    stdout.printf ("\nPARSED TS INPUT FILE (%s packets)\n",
                                   ((packets_to_parse == 0) 
                                    ? "all" : packets_to_parse.to_string ()));
                }
                var pat = mp2_file.get_first_pat_table ();
                if (print_pat_pmt) {
                    stdout.printf ("\nFOUND PAT:\n");
                    pat.to_printer (my_printer, "   ");
                }
                foreach (var program in pat.get_programs ()) {
                    try {
                        var pmt = mp2_file.get_first_pmt_table (program.pid);
                        if (print_pat_pmt) {
                            stdout.printf ("\nFOUND PMT ON PID %u:\n", program.pid);
                            pmt.to_printer (my_printer, "   ");
                        }
                        stdout.flush ();
                        foreach (var stream_info in pmt.get_streams ()) {
                            if (target_stream == null) {
                                if ((only_pid < 0) 
                                    && (stream_info.stream_type 
                                        == MP2PMTSection.STREAM_TYPE_MPEG2_VIDEO)) {
                                    target_program = program;
                                    target_stream = stream_info;
                                } else {
                                    if (stream_info.pid == only_pid) {
                                        target_stream = stream_info;
                                    }
                                }
                            }
                        }
                        if (target_stream == null) {
                            if (only_pid < 0) {
                                stderr.printf ("\nNo stream found in program %d\n", 
                                               program.program_number);
                            } else {
                                stderr.printf ("\nNo stream found in program %d for PID %d\n", 
                                               program.program_number, only_pid);
                            }
                        }
                    } catch (Error err) {
                        error ("Error getting PMT/video PES: %s", err.message);
                    }
                }
            }
            if (print_pes_headers) {
                if (mp2_file == null) {
                    mp2_file = new Rygel.MP2TransportStreamFile (in_file);
                    mp2_file.parse_from_stream (packets_to_parse);
                    stdout.printf ("\nPARSED TS INPUT FILE (%s packets)\n",
                                   ((packets_to_parse == 0) 
                                    ? "all" : packets_to_parse.to_string ()));
                }
                stdout.printf ("\nPES packets on %s\n\n", 
                               target_stream.to_string ());
                var ts_packets = mp2_file.get_packets_for_pid 
                                        (target_stream.pid);
                foreach (var ts_packet in ts_packets) {
                    if (ts_packet.payload_unit_start_indicator) {
                        if (print_ts_packets_with_pes) {
                            stdout.printf (" %s\n",
                                           ts_packet.to_string ());
                        }
                        var pes_offset = ts_packet.source_offset 
                                         + ts_packet.header_size;
                        var pes_packet 
                            = new MP2PESPacket.from_stream (mp2_file.source_stream, 
                                                            pes_offset);
                        pes_packet.parse_from_stream_seek ();
                        stdout.printf ("   %s\n", 
                                       pes_packet.to_string ());
                    }
                }
            }
            if (out_file != null) {
                stdout.printf ("\nWRITING TO OUTPUT FILE: %s\n", out_file.get_path ());
                if (out_file.query_exists ()) {
                    out_file.delete ();
                }
                var out_stream = new Rygel.ExtDataOutputStream (
                                       out_file.create (
                                         FileCreateFlags.REPLACE_DESTINATION));

                if (!restamp) {
                    if (mp2_file == null) {
                        mp2_file = new Rygel.MP2TransportStreamFile (in_file);
                        mp2_file.parse_from_stream (packets_to_parse);
                        stdout.printf ("\nPARSED TS INPUT FILE (%s packets)\n",
                                       ((packets_to_parse == 0) 
                                        ? "all" : packets_to_parse.to_string ()));
                    }
                    uint64 packets_written = 0;
                    foreach (var ts_packet in mp2_file.ts_packets) {
                        ts_packet.fields_to_stream (out_stream);
                        ts_packet.payload_to_stream_noseek (out_stream);
                        packets_written++;
                    }
                    stdout.printf ("\nWrote %llu packets to %s\n",
                                   packets_written, out_file.get_path ());
                } else {
                    stdout.printf ("\n  Restamping packets. Scale: %fx\n", 
                                   (double)restamp_scale/MILLIS_PER_SEC);
                    var restamper = new MP2TSRestamper.from_file (in_file);
                    restamper.restamp_to_stream_scaled (out_stream, restamp_scale, null, null);
                    stdout.printf ("\nRestamping complete. Outfile: %s\n", out_file.get_path ());
                }
                out_stream.close ();
            }
        } catch (Error err) {
            error ("Error: %s", err.message);
        }
        return 0;
    }
} // END class MP2ParsingTest

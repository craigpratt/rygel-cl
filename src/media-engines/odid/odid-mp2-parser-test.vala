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

class Rygel.MP2ParserTest : GLib.Object {
    // Can compile/run this with:
    // valac --disable-warnings --pkg gio-2.0 --pkg gee-0.8 --pkg posix -g  --target-glib=2.32 odid-mp2-parser-test.vala odid-mp2-parser.vala odid-stream-ext.vala 
    public static int main (string[] args) {
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
            int32 restamp_scale = 0;
            bool restamp = false;
            uint8 packet_size = 188;

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
                        case "-packsize":
                            if (i+1 == args.length) {
                                throw new OptionError.BAD_VALUE (option + " requires a parameter");
                            }
                            var packsize_param = args[++i];
                            uint64 packsize;
                            if (!uint64.try_parse (packsize_param, out packsize)) {
                                throw new OptionError.BAD_VALUE ("Bad packet size value: " 
                                                                 + packsize_param);
                            }
                            if ((packet_size != 188) && (packet_size != 192)) {
                                throw new OptionError.BAD_VALUE ("Unsupported packet size %u - only 188- and 192-byte packets supported", 
                                                                 packet_size);
                            }
                            packet_size = (uint8) packsize;
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
                                buf_out_stream_buf_size = packet_size*1000;
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
                            restamp_scale = (int)(scale_factor * MILLIS_PER_SEC);
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
                                    stderr.printf ("Bits 0-7: 0x%02" + uint64.FORMAT_MODIFIER + "x\n", 
                                                   Bits.getbits_64 (testval, 0, 8));
                                    stderr.printf ("Bits 1-7: 0x%02" + uint64.FORMAT_MODIFIER + "x\n", 
                                                   Bits.getbits_64 (testval, 1, 7));
                                    stderr.printf ("Bits 2-7:  0x%02" + uint64.FORMAT_MODIFIER + "x\n", 
                                                   Bits.getbits_64 (testval, 2, 6));
                                    stderr.printf ("Bits 0-15: 0x%02" + uint64.FORMAT_MODIFIER + "x\n", 
                                                   Bits.getbits_64 (testval, 0, 16));
                                    stderr.printf ("Bits 16-23: 0x%02" + uint64.FORMAT_MODIFIER + "x\n", 
                                                   Bits.getbits_64 (testval, 16, 8));
                                    stderr.printf ("Bits 56-63: 0x%02" + uint64.FORMAT_MODIFIER + "x\n", 
                                                   Bits.getbits_64 (testval, 56, 8));
                                    stderr.printf ("All bits: ");
                                    for (int bit=63; bit >= 0; bit--) {
                                        stderr.printf ("%" + uint64.FORMAT, Bits.getbits_64 (testval, bit, 1));
                                    }
                                    stderr.printf ("\n");
                                break;
                                case "getbits_32":
                                    uint32 testval = 0x159EAABB;
                                    // 31     23      15       7      0
                                    // |       |       |       |      |
                                    // 00010101100111101010101010111011
                                    stderr.printf ("Bits 0-7: 0x%02ux\n", Bits.getbits_32 (testval, 0, 8));
                                    stderr.printf ("Bits 1-7: 0x%02ux\n", Bits.getbits_32 (testval, 1, 7));
                                    stderr.printf ("Bits 2-7: 0x%02ux\n", Bits.getbits_32 (testval, 2, 6));
                                    stderr.printf ("Bits 0-15: 0x%02ux\n", Bits.getbits_32 (testval, 0, 16));
                                    stderr.printf ("Bits 16-23: 0x%02ux\n", Bits.getbits_32 (testval, 16, 8));
                                    stderr.printf ("All bits: ");
                                    for (int bit=31; bit >= 0; bit--) {
                                        stderr.printf ("%u", Bits.getbits_32 (testval, bit, 1));
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
                stderr.printf ("\t[-packsize <188,192>]: Sets the TS packet size (default: 188)\n");   
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
                mp2_file = new Rygel.MP2TransportStreamFile (in_file, packet_size);
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
                    mp2_file = new Rygel.MP2TransportStreamFile (in_file, packet_size);
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
                                    && stream_info.is_video ()) {
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
                    mp2_file = new Rygel.MP2TransportStreamFile (in_file, packet_size);
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
                    } else if (print_ts_packets_with_pes 
                               && ts_packet.adaptation_field_control > 1) {
                        stdout.printf (" %s\n",
                                       ts_packet.to_string ());
                    }
                }
            }
            if (out_file != null) {
                if (out_file.query_exists ()) {
                    out_file.delete ();
                }
                var out_stream = new Rygel.ExtDataOutputStream (
                                       out_file.create (
                                         FileCreateFlags.REPLACE_DESTINATION));
                if (!restamp) {
                    if (mp2_file == null) {
                        mp2_file = new Rygel.MP2TransportStreamFile (in_file, packet_size);
                        mp2_file.parse_from_stream (packets_to_parse);
                        stdout.printf ("\nPARSED TS INPUT FILE (%s packets)\n",
                                       ((packets_to_parse == 0) 
                                        ? "all" : packets_to_parse.to_string ()));
                    }
                    uint64 packets_written = 0;
                    
                    stdout.printf ("\nWRITING TO OUTPUT FILE: %s\n", out_file.get_path ());
                    foreach (var ts_packet in mp2_file.ts_packets) {
                        ts_packet.fields_to_stream (out_stream);
                        ts_packet.payload_to_stream_seek (out_stream);
                        packets_written++;
                    }
                    stdout.printf ("\nWrote %" + uint64.FORMAT + " packets to %s\n",
                                   packets_written, out_file.get_path ());
                } else {
                    stdout.printf ("\nRESTAMPING TO OUTPUT FILE: %s (scale %0.3fx)\n", 
                                   out_file.get_path (),(double)restamp_scale/MILLIS_PER_SEC);
                    var restamper = new MP2TSRestamper.from_file (in_file, packet_size);
                    restamper.restamp_to_stream_scaled (out_stream, restamp_scale, null, null);
                    stdout.printf ("\nRestamping complete. Outfile: %s\n", out_file.get_path ());
                }
                out_stream.close ();
            }
            if (buf_out_stream_test) {
                //
                // Test writing to BufferGeneratingOutputStream
                //
                if (restamp_scale == 0) {
                    stderr.printf ("  Restamp scale required (-restamp <scale>) with -bufoutstream\n");
                    return 2;
                }
                uint64 byte_count = 0;
                uint32 buffer_size = (uint32)buf_out_stream_buf_size;
                stdout.printf ("  Using buffer size %u (0x%x)\n", buffer_size, buffer_size);
                var my_buf_gen_stream = new BufferGeneratingOutputStream (buffer_size,
                                                                          (bytes, last_buffer) =>
                    {
                        if (bytes != null) {
                            var buffer = bytes.get_data ();
                            stdout.printf ("    Received %u bytes (%02x %02x %02x %02x %02x %02x) - offset %" 
                                           + uint64.FORMAT + " (0x%" + uint64.FORMAT_MODIFIER + "x)\n",
                                           buffer.length, buffer[0], buffer[1], buffer[2],
                                           buffer[3], buffer[4], buffer[5], 
                                           byte_count, byte_count);
                            byte_count += bytes.length;
                        }
                        if (last_buffer) {
                            stdout.printf ("  Last buffer received. Total bytes received: %"
                                           + uint64.FORMAT + "\n", byte_count);
                        }
                    }, true /* paused */ );
                var gen_thread = new Thread<void*> ( "mp2 stream generator", () => {
                    stderr.printf ("  Generator started\n");
                    Rygel.ExtDataOutputStream out_stream = null;
                    try {
                        var restamper = new MP2TSRestamper.from_file_subrange (in_file, 0, 0, 
                                                                               packet_size);
                        stderr.printf ("  Generator writing %fx restamped stream\n",
                                       (float)restamp_scale/MILLIS_PER_SEC);
                        out_stream = new Rygel.ExtDataOutputStream (my_buf_gen_stream);
                        restamper.restamp_to_stream_scaled (out_stream, 2000, null, null);
                        stderr.printf ("  Generator done writing.\n");
                    } catch (Error err) {
                        error ("Error opening/writing: %s", err.message);
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
                Thread.usleep (2000000);
                stdout.printf (" Resuming BufferGeneratingOutputStream\n");
                my_buf_gen_stream.resume ();
                Thread.usleep (400000);
                my_buf_gen_stream.pause ();
                stdout.printf (" Paused BufferGeneratingOutputStream\n");
                Thread.usleep (700000);
                stdout.printf (" Resuming BufferGeneratingOutputStream\n");
                my_buf_gen_stream.resume ();
                gen_thread.join ();
                stdout.printf ("}\nCompleted mp2 generation (%" + uint64.FORMAT + " bytes)\n", 
                               byte_count);
            }
        } catch (Error err) {
            error ("Error: %s", err.message);
        }
        return 0;
    }
} // END class MP2ParsingTest

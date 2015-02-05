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

class Rygel.MP2ParsingTest : GLib.Object {
    private static int main (string[] args) {
        int MICROS_PER_SEC = 1000000;
        try {
            bool print_infile = false;
            uint64 print_infile_levels = 0;
            bool print_outfile = false;
            int64 print_outfile_levels = -1;
            bool print_access_points = false;
            bool print_movie_duration = false;
            string adhoc_test_name = null;
            uint64 time_range_start_us = 0, time_range_end_us = 0;
            File in_file = null;
            File out_file = null;
            bool buf_out_stream_test = false;
            uint64 buf_out_stream_buf_size = 0;
            bool trim_file = false;

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
                stderr.printf ("\t[-print (infile [levels]|outfile [levels]|access-points|movie-duration|track-duration|track-for-time [time])]: Print various details to the standard output\n");
                stderr.printf ("\t[-outfile <filename>]: Write the resulting MP2 to the given filename\n");
                stderr.printf ("\t[-bufoutstream [buffer_size]]: Test running the resulting MP2 through the BufferGeneratingOutputStream\n");
                return 1;
            }

            stdout.printf ("\nINPUT FILE: %s\n", in_file.get_path ());
            stdout.flush ();
        } catch (Error err) {
            error ("Error: %s", err.message);
        }
        return 0;
    }
} // END class MP2ParsingTest

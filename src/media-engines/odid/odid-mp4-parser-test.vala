/*
 * Copyright (C) 2015 Cable Television Laboratories, Inc.
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

class Rygel.IsoParserTest {
    // Can compile/run this using:
    // valac --disable-warnings --pkg gio-2.0 --pkg gee-0.8 --pkg posix -g  --target-glib=2.32 --disable-warnings odid-mp4-parser-test.vala odid-mp4-parser.vala odid-stream-ext.vala 

    public static int main (string[] args) {
        int MICROS_PER_SEC = 1000000;
        try {
            bool trim_file = false;
            bool with_edit_list = false;
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
                                with_edit_list = true;
                                range_param = range_param.substring (1);
                            } else {
                                with_edit_list = false;
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
                stderr.printf ("\t                     (The caret (^) will cause an edit list box to be inserted into the generated stream)\n");
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
                stdout.printf  ("\nTRIMMING INPUT FILE: (%s edit list)\n",
                                (with_edit_list ? "with" : "no"));
                stdout.printf  ("  Requested time range: %0.3fs-%0.3fs\n",
                                (float)time_range_start_us/MICROS_PER_SEC,
                                (float)time_range_end_us/MICROS_PER_SEC);
                Rygel.IsoAccessPoint start_point, end_point;
                file_container_box.trim_to_time_range (time_range_start_us, time_range_end_us,
                                                       out start_point, out end_point, with_edit_list);
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
                var out_stream = new Rygel.ExtDataOutputStream (
                                       out_file.create (FileCreateFlags.REPLACE_DESTINATION) );
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
                    Rygel.ExtDataOutputStream out_stream;
                    try {
                        stderr.printf ("  Generator writing...\n");
                        out_stream = new Rygel.ExtDataOutputStream (my_buf_gen_stream);
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
} // END class IsoParsingTest

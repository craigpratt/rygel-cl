/*
 * Copyright (C) 2014  Cable Television Laboratories, Inc.
 * Contact: http://www.cablelabs.com/
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

public class Rygel.ODIDControlChannel : Object {
    public delegate string CommandFunction (string command);

    protected uint16 listen_port;
    protected Cancellable cancellable;
    protected unowned CommandFunction command_function;
    protected Gee.List<DataOutputStream> ostream_list 
                = new Gee.ArrayList<DataOutputStream> ();

    protected static uint channel_counter = 1;
    public ODIDControlChannel (uint16 port, CommandFunction command_function) {
        this.listen_port = port;
        this.command_function = command_function;
    }

    public async void listen (Cancellable cancellable) {
        this.cancellable = cancellable;

        try {
            SocketListener listener = new SocketListener ();
            listener.add_inet_port (this.listen_port, null);

            while (true) {
                SocketConnection connection = yield listener.accept_async (this.cancellable);
                debug ("Connection opened on port %d", this.listen_port);
                worker_func.begin (connection);
            }
        } catch (Error e) {
            message ("Error: %s", e.message);
        }
    }

    private async void worker_func (SocketConnection connection) {
        DataInputStream istream = null;
        DataOutputStream ostream = null;
        var channel_id = ODIDControlChannel.channel_counter++;
        try {
            istream = new DataInputStream (connection.input_stream);
            ostream = new DataOutputStream (connection.output_stream);
            this.ostream_list.add (ostream);

            debug ("Opened command channel %u", channel_id);
            ostream.put_string ("Opened odid command channel %u\n"
                                .printf(channel_id), this.cancellable);
            while (true) {
                string command_line = yield istream.read_line_async (Priority.DEFAULT, this.cancellable);
                if (command_line != null) {
                    command_line = command_line._delimit ("\n\r", ' ');
                    command_line = command_line._strip ();
                }
                if (command_line == null
                    || (command_line == "quit")
                    || (command_line == "exit")) {
                    break;
                }
                if (command_line.length == 0) {
                    continue;
                }

                debug ("Channel %u: Received command line: \"%s\"",
                       channel_id, command_line);

                string response = this.command_function (command_line) + "\n";
                debug ("Channel %u:   Response: \"%s\"", channel_id, response);

                ostream.put_string (response, this.cancellable);
                ostream.put_byte ('\n', this.cancellable);
            }
            ostream.put_string ("Closing odid command channel %u\n"
                                .printf(channel_id), this.cancellable);
        } catch (Error e) {
            message ("Error: %s", e.message);
        }
        debug ("Closed command channel %u", channel_id);
        if (ostream != null) {
            this.ostream_list.remove (ostream);
        }
    }

    /**
     * Send a message to the command channel output
     *
     * Note: This will currently only output to the most recently connected stream
     */
    public void send_message (string message_string) {
        try {
            foreach (var ostream in this.ostream_list) {
                ostream.put_string (message_string, this.cancellable);
                ostream.put_byte ('\n', this.cancellable);
            }
        } catch (Error e) {
            message ("Error: %s", e.message);
        }
    }
}

/*
 * Copyright (C) 2013 Cable Television Laboratories, Inc.
 *
 * Author: Parthiban Balasubramanian <P.Balasubramanian-contractor@cablelabs.com>
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
using GLib;
using GUPnP;

public class Rygel.ConnectionManagerProtocolInfo : GLib.Object {

    private static ConnectionManagerProtocolInfo cm_protocol_info = null;

    internal class CMSProtocolInfo {
        public string name;
        public GUPnP.DLNAOperation op_param;
        public string[] ps_flag;
        public GUPnP.DLNAFlags flags;

        public CMSProtocolInfo (string name, GUPnP.DLNAOperation op_param,
                                string[] ps_flag, GUPnP.DLNAFlags flags) {
            this.name = name;
            this.op_param = op_param;
            this.ps_flag = ps_flag;
            this.flags = flags;
        }

        public void combine_fourth_field_values (GUPnP.DLNAOperation op_param,
                                                 string[] ps_flag,
                                                 GUPnP.DLNAFlags flags) {
            this.op_param |= op_param;
            this.flags |= flags;

            add_missing_speeds (this.ps_flag, ps_flag);
        }

        private void add_missing_speeds (string[] old_ps, string[] new_ps) {
            Gee.List<string> combined_speed = new Gee.ArrayList<string> ();

            foreach (var old_ps_str in old_ps) {
                combined_speed.add (old_ps_str);
            }

            foreach (var new_ps_str in new_ps) {
                if (!combined_speed.contains (new_ps_str)) {
                    combined_speed.add (new_ps_str);
                }
            }
            this.ps_flag = combined_speed.to_array ();
        }

        private string append_reserved_zeros (string flag_str) {
            return flag_str + "00000000" + "00000000" + "00000000";
        }

        public string to_string () {
            StringBuilder sb_name = new StringBuilder();
            // If no other 4th param available, then remove the ';' at the end
            sb_name.append (this.name);
            if (this.op_param == DLNAOperation.NONE &&
                this.ps_flag == null &&
                this.flags == DLNAFlags.NONE) {
                sb_name.truncate (sb_name.len - 1);
            }

            // Work around due to core resulting from string.joinv call.
            StringBuilder sb = new StringBuilder();
            if (this.ps_flag != null) {
                sb.append("DLNA.ORG_PS=");
                foreach (var flag in this.ps_flag) {
                    sb.append(flag);
                    sb.append("\\,");
                }
                sb.truncate(sb.len - 2); // remove last comma
                sb.append(";");
            }
            
            return sb_name.str +
                     (this.op_param == DLNAOperation.NONE ? ""
                      : "DLNA.ORG_OP=" + "%0.2x".printf (this.op_param) + ";")
                     + sb.str
                     + (this.flags == DLNAFlags.NONE ? ""
                        :  append_reserved_zeros ("DLNA.ORG_FLAGS="
                                                  + "%0.8x".printf (this.flags)));
        }
    }

    private HashMap<string,CMSProtocolInfo> union_protocol_string
                        = new HashMap< string,CMSProtocolInfo > ();

    private ConnectionManagerProtocolInfo () {

    }

    public static ConnectionManagerProtocolInfo get_default () {
        if (cm_protocol_info == null) {
            cm_protocol_info = new ConnectionManagerProtocolInfo ();
        }
        return cm_protocol_info;
    }

    public void update_source_protocol_info (Rygel.RootDevice root_device,
                                             MediaObjects media_objects,
                                             HTTPServer http_server) {

        union_protocol_string.clear ();
        // Iterate through all media objects and extract protocolinfo
        foreach (var media_object in media_objects) {
            var res_list = media_object.get_resource_list_for_server (http_server);
            foreach (var media_resource in res_list) {
                var protocolInfo = media_resource.get_protocol_info ();

                if (protocolInfo == null) {
                    continue;
                }

                debug ("Got ProtocolInfo : %s ", protocolInfo.to_string ());
                string[] key = protocolInfo.to_string ().split (":", 4);

                if (key == null) {
                    continue;
                }

                // Fourth field must start with DLNA.ORG_PN
                if ((key[3] != null) &&
                    (key[3].index_of ("DLNA.ORG_PN=",0) != -1)) {
                    string hash_key = protocolInfo.protocol + ":" +
                                 (protocolInfo.network == null ?
                                                           "*" :
                                                           protocolInfo.network) +
                                                           ":" +
                                 protocolInfo.mime_type + ":" +
                                 "DLNA.ORG_PN=" + protocolInfo.dlna_profile+";";

                    if (union_protocol_string.has_key (hash_key)) {
                        CMSProtocolInfo cms_info = union_protocol_string.get (hash_key);

                        // TODO: Check if the update is needed.

                        // Call to combine the fourth field values if any..
                        cms_info.combine_fourth_field_values
                                 (protocolInfo.get_dlna_operation (),
                                  protocolInfo.get_play_speeds (),
                                  protocolInfo.get_dlna_flags () );
                    } else {
                        union_protocol_string.set (hash_key,
                                                   new CMSProtocolInfo
                                                     (hash_key,
                                                      protocolInfo.get_dlna_operation (),
                                                      protocolInfo.get_play_speeds (),
                                                      protocolInfo.get_dlna_flags () ) );
                    }
                }
            }
        }

        // Update the variable to publish the source protocol info
        publish_protocol_info (root_device);
    }

    private void publish_protocol_info (Rygel.RootDevice root_device) {
        var new_protocol_string = new StringBuilder ();
        int index = 0;
        int protocolinfo_length = (this.union_protocol_string != null)
                                  ? this.union_protocol_string.size : 0;

        foreach (var str_protocol_info in this.union_protocol_string.entries) {
            string temp_str = str_protocol_info.value.to_string ();
            message ("ProtocolInfo String added : %s ",temp_str);
            new_protocol_string.append (temp_str);
            if (++index < protocolinfo_length)
                new_protocol_string.append (",");
        }

        debug ("New SourceProtocolinfo : %s",new_protocol_string.str);
        // Find the ConnectionManager Service and update SourceProtocolInfo variable
        foreach (var service in root_device.services) {
            if (service.get_type ().is_a (typeof (Rygel.ConnectionManager))) {
                var connection_manager = (Rygel.ConnectionManager) service;
                connection_manager.set_source_protocol_info (new_protocol_string.str);
            }
        }
    }

}

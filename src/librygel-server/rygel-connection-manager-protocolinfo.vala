/*
 * Copyright (C) 2013  Cable Television Laboratories, Inc.
 * Contact: http://www.cablelabs.com/
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
 * IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL APPLE INC. OR ITS CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

using Gee;
using GLib;
using GUPnP;

/**
 * Author : Parthiban Balasubramanian <p.balasubramanian@cablelabs.com>
 */
public class Rygel.ConnectionManagerProtocolInfo : GLib.Object {

    private static ConnectionManagerProtocolInfo cm_protocol_info = null;

    internal class CMSProtocolInfo {
        public string name;
        public GUPnP.DLNAOperation op_param;
        public string[] ps_flag;
        public GUPnP.DLNAFlags flags;

        public CMSProtocolInfo(string name, GUPnP.DLNAOperation op_param, string[] ps_flag, GUPnP.DLNAFlags flags) {
            this.name = name;
            this.op_param = op_param;
            this.ps_flag = ps_flag;
            this.flags = flags;
        }

        public void combine_fourth_field_values (GUPnP.DLNAOperation op_param, string[] ps_flag, GUPnP.DLNAFlags flags) {
            this.op_param |= op_param;
            this.flags |= flags;

            add_missing_speeds (this.ps_flag, ps_flag);
        }

        private void add_missing_speeds (string[] old_ps, string[] new_ps) {
            Gee.List<string> combined_speed = new Gee.ArrayList<string>();

            foreach (var old_ps_str in old_ps) {
                combined_speed.add (old_ps_str);
            }

            foreach (var new_ps_str in new_ps) {
                if (!combined_speed.contains (new_ps_str)) {
                    combined_speed.add (new_ps_str);
                }
            }
            this.ps_flag = combined_speed.to_array();
        }

        private string append_reserved_zeros (string flag_str) {
            return flag_str + "00000000" + "00000000" + "00000000";
        }

        public string to_string() {
              return this.name +
                     (this.op_param == DLNAOperation.NONE ? "" : "DLNA.ORG_OP=" + "%0.2x".printf (this.op_param) + ";")+
                     (ps_flag != null ? "DLNA.ORG_PS=" + string.joinv("\\,", this.ps_flag) + ";" : "") +
                     (this.flags == DLNAFlags.NONE ? "" :  append_reserved_zeros ("DLNA.ORG_FLAGS=" + "%0.8x".printf (this.flags)));
        }
    }

    private HashMap<string,CMSProtocolInfo> union_protocol_string
                        = new HashMap< string,CMSProtocolInfo >();

    private ConnectionManagerProtocolInfo() {

    }

    public static ConnectionManagerProtocolInfo get_default() {
        if (cm_protocol_info == null) {
            cm_protocol_info = new ConnectionManagerProtocolInfo();
        }
        return cm_protocol_info;
    }

    public async void update_source_protocol_info (Rygel.RootDevice root_device, MediaContainer container , Cancellable? cancellable) {

        uint total_matches;
        var s_container = (container as SearchableContainer);
        MediaObjects media_objects = null;

        try {
            media_objects= yield s_container.search (null , 0 , -1, out total_matches,
                                             s_container.sort_criteria,
                                             cancellable);
        } catch (Error err) {
            warning ("Updating SourceProtocolInfo using CDS list failed.");
            return ;
        }
        foreach (var media_item in media_objects) {
            if (media_item is MediaItem) {
                MediaItem t_item = (media_item as MediaItem);

                foreach (var media_resource in t_item.media_resources) {
                    MediaResource t_resource = (media_resource as MediaResource);
                    string protocolInfo = t_resource.protocol_info.to_string();

                    debug ("Got ProtocolInfo : %s ", protocolInfo);
                    string[] key = protocolInfo.split (":");

                    // Fourth field must start with DLNA.ORG_PN
                    if (key[3].index_of ("DLNA.ORG_PN=",0) != -1) {
                        string hash_key = t_resource.protocol_info.protocol + ":" +
                                     t_resource.protocol_info.network + ":" +
                                     t_resource.protocol_info.mime_type + ":" +
                                     "DLNA.ORG_PN=" + t_resource.protocol_info.dlna_profile+";";

                        if (union_protocol_string.has_key (hash_key)) {
                            CMSProtocolInfo cms_info = union_protocol_string.get (hash_key);

                            // TODO: Check if the update is needed.

                            // Call to combine the fourth field values if any..
                            cms_info.combine_fourth_field_values
                                     (t_resource.protocol_info.get_dlna_operation(),
                                      t_resource.protocol_info.get_play_speeds(),
                                      t_resource.protocol_info.get_dlna_flags());
                        } else {
                            union_protocol_string.set(hash_key,
                                                      new CMSProtocolInfo
                                                      (hash_key,
                                                       t_resource.protocol_info.get_dlna_operation(),
                                                       t_resource.protocol_info.get_play_speeds(),
                                                       t_resource.protocol_info.get_dlna_flags()));
                        }
                    }
                }
            }
        }

        // Update the variable to publish the source protocol info
        pubilsh_protocol_info (root_device);
    }

    private void pubilsh_protocol_info (Rygel.RootDevice root_device) {
        string new_protocol_string = "";
        Gee.List<string> updated_protocol_info = new Gee.ArrayList<string>();

        foreach (var str_protocol_info in this.union_protocol_string.entries) {
            updated_protocol_info.add (str_protocol_info.value.to_string());
        }

        if (updated_protocol_info.size != 0) {
            new_protocol_string = string.joinv (",",updated_protocol_info.to_array());
            message ("New Protocolinfo : %s",new_protocol_string);

            // Find the ConnectionManager Service and update SourceProtocolInfo variable
            foreach (var service in root_device.services) {
                if (service.get_type().is_a (typeof (Rygel.ConnectionManager))) {
                    var connection_manager = (Rygel.ConnectionManager) service;
                    connection_manager.set_source_protocol_info(new_protocol_string);
                }
            }
        }
    }

}

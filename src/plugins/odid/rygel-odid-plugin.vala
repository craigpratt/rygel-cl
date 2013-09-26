/*
 * Copyright (C) 2008-2009 Jens Georg <mail@jensge.org>.
 *
 * This file is part of Rygel.
 *
 * Rygel is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * Rygel is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 */
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

using Rygel;
using GUPnP;

private const string TRACKER_PLUGIN = "Tracker";

/**
 * Simple plugin which exposes the media contents of a directory via UPnP.
 *
 */
public void module_init (PluginLoader loader) {
    try {
        // Instantiate the plugin object (it may fail if loading
        // database did not succeed):
        var plugin = new ODID.Plugin ();

        // Check what other plugins are loaded,
        // and check when other plugins are loaded later:
        Idle.add (() => {
           foreach (var loaded_plugin in loader.list_plugins ()) {
                on_plugin_available (loaded_plugin, plugin);
           }

           loader.plugin_available.connect ((new_plugin) => {
               on_plugin_available (new_plugin, plugin);
           });

           return false;
        });

        loader.add_plugin (plugin);
    } catch (Error error) {
        warning ("Failed to load %s: %s",
                 ODID.Plugin.NAME,
                 error.message);
    }
}

public void on_plugin_available (Plugin plugin, Plugin our_plugin) {
    // Do not allow this plugin and the tracker plugin to both be
    // active at the same time,
    // because they serve the same purpose.
    if (plugin.name == TRACKER_PLUGIN) {
        if (our_plugin.active && !plugin.active) {
            // The Tracker plugin might be activated later,
            // so shut this plugin down if that happens.
            plugin.notify["active"].connect (() => {
                if (plugin.active) {
                    shutdown_media_export ();
                    our_plugin.active = !plugin.active;
                }
            });
        } else if (our_plugin.active == plugin.active) {
            if (plugin.active) {
                // The Tracker plugin is already active,
                // so shut this plugin down immediately.
                shutdown_media_export ();
            } else {
                // Log that we are starting this plugin
                // because the Tracker plugin is not active instead.
                message ("Plugin '%s' inactivate, activating '%s' plugin",
                         TRACKER_PLUGIN,
                         ODID.Plugin.NAME);
            }
            our_plugin.active = !plugin.active;
        }
    }
}

private void shutdown_media_export () {
    message ("Deactivating plugin '%s' in favor of plugin '%s'",
             ODID.Plugin.NAME,
             TRACKER_PLUGIN);
    try {
        var config = MetaConfig.get_default ();
        var enabled = config.get_bool ("ODID", "enabled");
        if (enabled) {
            var root = Rygel.ODID.RootContainer.get_instance ();

            root.shutdown ();
        }
    } catch (Error error) {};
}

public class Rygel.ODID.Plugin : Rygel.MediaServerPlugin {
    public const string NAME = "ODID";

    /**
     * Instantiate the plugin.
     */
    public Plugin () throws Error {
        // Ensure that root container could be created and thus
        // database could be opened:
        RootContainer.ensure_exists ();
        // Call the base constructor,
        // passing the instance of our root container.
        base (RootContainer.get_instance (),
              NAME,
              null,
              PluginCapabilities.UPLOAD |
              PluginCapabilities.TRACK_CHANGES);
    }
}

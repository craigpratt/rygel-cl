/*
 * Copyright (C) 2009 Jens Georg <mail@jensge.org>.
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


using Gee;

public class Rygel.ODID.RecursiveFileMonitor : Object {
    private Cancellable        cancellable;
    HashMap<File, FileMonitor> monitors;
    bool                       monitor_changes;

    public RecursiveFileMonitor (Cancellable? cancellable) {
        this.monitor_changes = true;
        var config = MetaConfig.get_default ();
        config.setting_changed.connect (this.on_config_changed);
        this.on_config_changed (config, Plugin.NAME, "monitor-changes");

        if (!this.monitor_changes) {
            message (_("Will not monitor file changes"));
        }

        this.cancellable = cancellable;
        this.monitors = new HashMap<File, FileMonitor> ((HashDataFunc<File>) File.hash,
                                                        (EqualDataFunc<File>) File.equal);
        if (cancellable != null) {
            cancellable.cancelled.connect (this.cancel);
        }
    }

    public void on_monitor_changed (File             file,
                                    File?            other_file,
                                    FileMonitorEvent event_type) {
        if (this.monitor_changes) {
            this.changed (file, other_file, event_type);
        }

        switch (event_type) {
            case FileMonitorEvent.CREATED:
                this.add.begin (file);

                break;
            case FileMonitorEvent.DELETED:
                var file_monitor = this.monitors.get (file);
                if (file_monitor != null) {
                    debug ("Folder %s gone; removing watch",
                           file.get_uri ());
                    this.monitors.unset (file);
                    file_monitor.cancel ();
                    file_monitor.changed.disconnect (this.on_monitor_changed);
                }

                break;
            default:
                // do nothing
                break;
        }
    }

    public async void add (File file) {
        if (this.monitors.has_key (file)) {
            return;
        }

        try {
            var info = yield file.query_info_async
                                        (FileAttribute.STANDARD_TYPE,
                                         FileQueryInfoFlags.NONE,
                                         Priority.DEFAULT,
                                         null);
            if (info.get_file_type () == FileType.DIRECTORY) {
                var file_monitor = file.monitor_directory
                                        (FileMonitorFlags.NONE,
                                         this.cancellable);
                this.monitors.set (file, file_monitor);
                file_monitor.changed.connect (this.on_monitor_changed);
            }
        } catch (Error err) {
            warning (_("Failed to get file info for %s"), file.get_uri ());
        }
    }

    public void cancel () {
        foreach (var monitor in this.monitors.values) {
            monitor.cancel ();
        }

        this.monitors.clear ();
    }

    public signal void changed (File             file,
                                File?            other_file,
                                FileMonitorEvent event_type);

    private void on_config_changed (Configuration config,
                                    string section,
                                    string key) {
        if (section != Plugin.NAME || key != "monitor-changes") {
            return;
        }

        try {
            this.monitor_changes = config.get_bool (Plugin.NAME,
                                                    "monitor-changes");
        } catch (Error error) { }
    }
}

/*
 * Copyright (C) 2008, 2009 Nokia Corporation.
 * Copyright (C) 2012 Intel Corporation.
 * Copyright (C) 2013 Cable Television Laboratories, Inc.
 *
 * Author: Zeeshan Ali (Khattak) <zeeshanak@gnome.org>
 *                               <zeeshan.ali@nokia.com>
 *         Jens Georg <jensg@openismus.com>
 *         Doug Galligan <doug@sentosatech.com>
 *         Craig Pratt <craig@ecaspia.com>
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

using GUPnP;
using Gee;

public class Rygel.HTTPServer : Rygel.StateMachine, GLib.Object {
    public string path_root { get; private set; }

    // Reference to root container of associated ContentDirectory
    public MediaContainer root_container;
    public GUPnP.Context context;
    private ArrayList<HTTPRequest> requests;
    private bool locally_hosted;

    public Cancellable cancellable { get; set; }

    public HTTPServer (ContentDirectory content_dir,
                       string           name) {

        this.root_container = content_dir.root_container;
        this.context = content_dir.context;
        this.requests = new ArrayList<HTTPRequest> ();
        this.cancellable = content_dir.cancellable;
        this.locally_hosted = this.context.interface == "lo"
                              || this.context.host_ip == "127.0.0.1";
        this.path_root = "/" + name;
    }

    public async void run () {
        context.server.add_handler (this.path_root, this.server_handler);
        context.server.request_aborted.connect (this.on_request_aborted);
        context.server.request_started.connect (this.on_request_started);

        if (this.cancellable != null) {
            this.cancellable.cancelled.connect (this.on_cancelled);
        }
    }

    public bool need_proxy (string uri) {
        return Uri.parse_scheme (uri) != "http";
    }

    private void on_cancelled (Cancellable cancellable) {
        // Cancel all state machines
        this.cancellable.cancel ();

        context.server.remove_handler (this.path_root);

        this.completed ();
    }

    public string create_uri_for_item (MediaObject object,
                                         string extension,
                                         int       thumbnail_index,
                                         int       subtitle_index,
                                         string?   resource_name) {
        var uri = new HTTPItemURI (object,
                                   this,
                                   extension,
                                   thumbnail_index,
                                   subtitle_index,
                                   resource_name );

        return uri.to_string ();
    }

    public bool recognizes_uri (string uri) {
        if (!uri.has_prefix ("http:")) {
            return false;
        }
        try {
            new HTTPItemURI.from_string (uri, this);
            return true;
        } catch (Error error) {
            return false;
        }
    }

    public string get_protocol () {
        return "http-get";
    }

    public bool is_local () {
        return (this.locally_hosted);
    }

    /**
     * Set or unset options the server supports/doesn't support
     *
     * Resources should be setup assuming server supports all optional delivery modes
     */
    public void set_resource_delivery_options (MediaResource res) {
        res.protocol = get_protocol ();
        // Set this just to be safe
        res.dlna_flags |= DLNAFlags.DLNA_V15;
        // This server supports all DLNA delivery modes - so leave those flags alone
    }

    private void on_request_completed (StateMachine machine) {
        var request = machine as HTTPRequest;

        this.requests.remove (request);

        debug ("HTTP %s request for URI '%s' handled.",
               request.msg.method,
               request.msg.get_uri ().to_string (false));
    }

    private void server_handler (Soup.Server               server,
                                 Soup.Message              msg,
                                 string                    server_path,
                                 HashTable<string,string>? query,
                                 Soup.ClientContext        soup_client) {
        if (msg.method == "POST") {
            // Already handled
            return;
        }

        debug ("HTTP %s request for URI '%s'. Headers:",
               msg.method,
               msg.get_uri ().to_string (false));
        msg.request_headers.foreach ((name, value) => {
                debug ("%s : %s", name, value);
        });

        this.queue_request (new HTTPGet (this, server, soup_client, msg));
    }

    private void on_request_aborted (Soup.Server        server,
                                     Soup.Message       message,
                                     Soup.ClientContext client) {
        foreach (var request in this.requests) {
            if (request.msg == message) {
                request.cancellable.cancel ();
                debug ("HTTP client aborted %s request for URI '%s'.",
                       request.msg.method,
                       request.msg.get_uri ().to_string (false));

                break;
            }
        }
    }

    private void on_request_started (Soup.Server        server,
                                     Soup.Message       message,
                                     Soup.ClientContext client) {
        message.got_headers.connect (this.on_got_headers);
    }

    private void on_got_headers (Soup.Message msg) {
        if (msg.method == "POST" &&
            msg.uri.path.has_prefix (this.path_root)) {
            debug ("HTTP POST request for URI '%s'",
                   msg.get_uri ().to_string (false));

            this.queue_request (new HTTPPost (this, this.context.server, msg));
        }
    }

    private void queue_request (HTTPRequest request) {
        request.completed.connect (this.on_request_completed);
        this.requests.add (request);
        request.run.begin ();
    }
}

/*
 * Copyright (C) 2009 Jens Georg <mail@jensge.org>.
 * Copyright (C) 2010 Nokia Corporation.
 *
 * Authors: Jens Georg <mail@jensge.org>
 *          Zeeshan Ali (Khattak) <zeeshan.ali@nokia.com>
 *                                <zeeshanak@gnome.org>
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
 * Modifications made by Cable Television Laboratories, Inc.
 * Copyright (C) 2013  Cable Television Laboratories, Inc.
 * Contact: http://www.cablelabs.com/
 *
 * Author: Craig Pratt <craig@ecaspia.com>
 */

using Gee;

public class Rygel.HTTPItemURI : Object {
    public string item_id { get; set; }
    public int thumbnail_index { get; set; default = -1; }
    public int subtitle_index { get; set; default = -1; }
    public string? resource_name { get; set; default = null; }
    public unowned HTTPServer http_server { get; set; }

    private string real_extension;
    public string extension {
        owned get {
            if (this.real_extension != "") {
                return "." + this.real_extension;
            }
            return "";
        }
        set {
            this.real_extension = value;
        }
    }

    public HTTPItemURI (MediaObject object,
                        HTTPServer http_server,
                        string     extension,
                        int        thumbnail_index = -1,
                        int        subtitle_index = -1,
                        string?    resource_name = null) {
        this.item_id = object.id;
        this.thumbnail_index = thumbnail_index;
        this.subtitle_index = subtitle_index;
        this.http_server = http_server;
        this.extension = extension;
        this.resource_name = resource_name;
    }

    // Base 64 Encoding with URL and Filename Safe Alphabet
    // http://tools.ietf.org/html/rfc4648#section-5
    private string base64_urlencode (string data) {
        var enc64 = Base64.encode ((uchar[]) data.to_utf8 ());
        enc64 = enc64.replace ("/", "_");

        return enc64.replace ("+", "-");
    }

    private uchar[] base64_urldecode (string data) {
       var dec64 = data.replace ("_", "/");
       dec64 = dec64.replace ("-", "+");

       return Base64.decode (dec64);
    }

    public HTTPItemURI.from_string (string     uri,
                                    HTTPServer http_server)
                                    throws HTTPRequestError {
        // do not decode the path here as it may contain encoded slashes
        this.thumbnail_index = -1;
        this.subtitle_index = -1;
        this.http_server = http_server;
        this.extension = "";

        var request_uri = uri.replace (http_server.path_root, "");
        var parts = request_uri.split ("/");

        if (parts.length < 2 || parts.length % 2 == 0) {
            throw new HTTPRequestError.BAD_REQUEST (_("Invalid URI '%s'"),
                                                    request_uri);
        }

        string last_part = parts[parts.length - 1];
        int dot_index = last_part.last_index_of (".");

        if (dot_index > -1) {
            this.extension = last_part.substring (dot_index + 1);
            parts[parts.length - 1] = last_part.substring (0, dot_index);
        }

        for (int i = 1; i < parts.length - 1; i += 2) {
            switch (parts[i]) {
                case "i":
                    var data = this.base64_urldecode
                                        (Soup.URI.decode (parts[i + 1]));
                    StringBuilder builder = new StringBuilder ();
                    builder.append ((string) data);
                    this.item_id = builder.str;
                    break;
                case "th":
                    this.thumbnail_index = int.parse (parts[i + 1]);
                    break;
                case "sub":
                    this.subtitle_index = int.parse (parts[i + 1]);
                    break;
                case "res":
                    this.resource_name = Soup.URI.decode (parts[i + 1]);
                    break;
                default:
                    break;
            }
        }

        if (this.item_id == null) {
            throw new HTTPRequestError.NOT_FOUND (_("Not found"));
        }
    }

    public string to_string() {
        // there seems to be a problem converting strings properly to arrays
        // you need to call to_utf8() and assign it to a variable to make it
        // work properly

        var data = this.base64_urlencode (this.item_id);
        var escaped = Uri.escape_string (data, "", true);
        string path = "/i/" + escaped;

        if (this.resource_name != null) {
            escaped = Uri.escape_string (this.resource_name, "", true);
            path += "/res/" + escaped;
        } else if (this.thumbnail_index >= 0) {
            path += "/th/" + this.thumbnail_index.to_string ();
        } else if (this.subtitle_index >= 0) {
            path += "/sub/" + this.subtitle_index.to_string ();
        }
        path += this.extension;

        return this.create_uri_for_path (path);
    }

    private string create_uri_for_path (string path) {
        return "http://%s:%u%s%s".printf (this.http_server.context.host_ip,
                                          this.http_server.context.port,
                                          this.http_server.path_root,
                                          path);
    }
}

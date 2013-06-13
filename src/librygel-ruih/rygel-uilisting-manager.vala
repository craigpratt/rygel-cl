/*
 * Copyright (C) 2013 Cablelabs 
 *
 * Author: Cablelabs 
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
using Xml;


/**
 * Responsible for handling changes to UIListing xml.
 */
internal class Rygel.UIListingManager : GLib.Object {

    private string file;
    private Service ruih;
    public Cancellable cancellable { get; set; }

    public UIListingManager(Service service, string file) {
        this.file = file;
        this.ruih = service;
    }

    public int run () {

        string lastevent = ""; 
        while(true) {
            // Check every 5 secs
            Thread.usleep(5000000);
            string xmlstr = getUIListing(RuihService.UIISTING_PATH);
            if ( xmlstr != lastevent) {
                lastevent = xmlstr;
                debug("Sending new event to subscribers\n" + xmlstr);
                ruih.notify("UIListingUpdate", typeof (string), xmlstr);
            }
        }

    }

    public string getUIListing(string path) {

        Parser.init();
        Xml.Doc* uilistingdoc = Parser.parse_file (path);
        if (uilistingdoc == null) {
            return "";
        }

        string xmlstr;
        uilistingdoc->dump_memory (out xmlstr);
        delete uilistingdoc; 
        return xmlstr;

    }

}

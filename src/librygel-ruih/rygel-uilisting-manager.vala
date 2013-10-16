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
 *
 * Author: Neha Shanbhag <N.Shanbhag@cablelabs.com>
 */

using Gee;
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
                string event = createUIListingUpdate(xmlstr, lastevent);
                lastevent = xmlstr;
                debug("Sending new event to subscribers  " + event);
                ruih.notify("UIListingUpdate", typeof (string), event);
            }
        }

    }

    public string getUIListing(string path) {

        // Parse XML and put in string
        Xml.Doc* uilistingdoc = Parser.parse_file (path);
        if (uilistingdoc == null) {
            return "";
        }

        string xmlstr;
        uilistingdoc->dump_memory (out xmlstr);
        delete uilistingdoc; 
        return xmlstr;

    }

    private string createUIListingUpdate(string xmlstr, string lastevent) {
        // parse out the uiID from both strings 
        string [] strArray = xmlstr.split("</ui>");
        string [] nextArray = lastevent.split("</ui>");

        // create HashSet to avoid dups
        var uiIDs = new HashSet<string> ();
        foreach( unowned string str in strArray ) {
            // find <ui>
            int index = str.index_of("<ui>");
            if (index != -1) {
                uiIDs.add(str.substring(index));
            }
        }
        foreach( unowned string str in nextArray ) {
            // find <ui>
            int index = str.index_of("<ui>");
            if (index != -1) {
                uiIDs.add(str.substring(index));
            }
        }

        string event = "";
        foreach (string ui in uiIDs) {
            int index = ui.index_of("<uiID>");
            int endIndex = ui.index_of("</uiID>") + "</uiID>".length;
            event = ui.substring(index,endIndex - index) + "\n";
        }

        return event;

    }


}

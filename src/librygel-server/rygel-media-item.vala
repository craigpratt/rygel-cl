/* 
 * Copyright (C) 2013  Cable Television Laboratories, Inc.
 * Contact: http://www.cablelabs.com/
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
 *
 * Author: Craig Pratt <craig@ecaspia.com>
 *
 * This file is part of Rygel.
 */

using GUPnP;

/**
 * Abstract class representing a MediaItem
 *
 * MediaItems must live in a container and may not contain other MediaItems
 */
public abstract class Rygel.MediaItem : MediaObject {

    public string description { get; set; default = null; }

    internal override int compare_by_property (MediaObject media_object,
                                               string      property) {
        if (!(media_object is MediaItem)) {
           return 1;
        }

        var item = media_object as MediaItem;

        switch (property) {
        case "dc:creator":
            return this.compare_string_props (this.creator, item.creator);
        case "dc:date":
            return this.compare_by_date (item);
        default:
            return base.compare_by_property (item, property);
        }
    }

    private int compare_by_date (MediaItem item) {
        if (this.date == null) {
            return -1;
        } else if (item.date == null) {
            return 1;
        } else {
            var our_date = this.date;
            var other_date = item.date;

            if (!our_date.contains ("T")) {
                our_date += "T00:00:00Z";
            }

            if (!other_date.contains ("T")) {
                other_date += "T00:00:00Z";
            }

            var tv1 = TimeVal ();
            assert (tv1.from_iso8601 (this.date));

            var tv2 = TimeVal ();
            assert (tv2.from_iso8601 (item.date));

            var ret = this.compare_long (tv1.tv_sec, tv2.tv_sec);
            if (ret == 0) {
                ret = this.compare_long (tv1.tv_usec, tv2.tv_usec);
            }

            return ret;
        }
    }

    private int compare_long (long a, long b) {
        if (a < b) {
            return -1;
        } else if (a > b) {
            return 1;
        } else {
            return 0;
        }
    }
    
    internal override void apply_didl_lite (DIDLLiteObject didl_object) {
        base.apply_didl_lite (didl_object);

        this.creator = didl_object.get_creator ();
        this.date = didl_object.date;
        this.description = didl_object.description;
    }

    internal override DIDLLiteObject? serialize (Serializer serializer,
                                                 HTTPServer http_server)
                                                 throws Error {
        var didl_item = serializer.add_item ();

        didl_item.id = this.id;

        if (this.ref_id != null) {
            didl_item.ref_id = this.ref_id;
        }

        if (this.parent != null) {
            didl_item.parent_id = this.parent.id;
        } else {
            didl_item.parent_id = "0";
        }

        if (this.restricted) {
            didl_item.restricted = true;
        } else {
            didl_item.restricted = false;
            didl_item.dlna_managed = this.ocm_flags;
        }

        didl_item.title = this.title;
        didl_item.upnp_class = this.upnp_class;

        if (this.date != null) {
            didl_item.date = this.date;
        }

        if (this.creator != null && this.creator != "") {
            var creator = didl_item.add_creator ();
            creator.name = this.creator;
        }

        if (this.description != null) {
            didl_item.description = this.description;
        }

        if (this is TrackableItem) {
            didl_item.update_id = this.object_update_id;
        }

        return didl_item;
    }
}

/*
 * Copyright (C) 2009-2012 Nokia Corporation.
 * Copyright (C) 2012 Intel Corporation.
 *
 * Author: Zeeshan Ali (Khattak) <zeeshanak@gnome.org>
 *                               <zeeshan.ali@nokia.com>
 *         Jens Georg <jensg@openismus.com>
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

// TODO: Fix or eliminate in next patch

using GUPnP;

/**
 * The base Transcoder class. Each implementation derives from it and must
 * implement create_source() and get_distance().
 *
 * Transcoders are obtained from rygel_media_engine_get_transcoders() and
 * are only expected to support the derived #RygelDataSource types provided
 * by the same media engine.
 */
public abstract class Rygel.Transcoder : GLib.Object {
    public string mime_type { get; construct; }
    public string dlna_profile { get; construct; }
    public string extension { get; construct; }
    // DLNA operation specific to the transcoder
    public GUPnP.DLNAOperation operation { get; set; }
    // DLNA flags specific to the transcoder
    public GUPnP.DLNAFlags flags { get; set; }

    /**
     * Creates a transcoding source.
     *
     * The provided original #RygelDataSource will have been implemented by the
     * same media engine that provided the #RygelTranscoder,
     * allowing the #RygelTranscoder to access specific resources of the
     * underlying multimedia backend used by the media engine.
     *
     * @param src the media item to create the transcoding source for
     * @param src the original (non-transcoding) source
     *
     * @return      the new transcoding source
     */
    public abstract DataSource create_source (MediaItem  item,
                                              DataSource src) throws Error;

    //TODO: It would be simpler for this to take a DIDLLiteResource to be filled,
    //rather than taking a didl_item, requiring the call of the base class, and then
    //returning the DIDLLiteResource.
    /**
     * Derived classes should implement this function to fill a GUPnPDIDLLiteResource,
     * representing the transcoded content, with parameters specific to the transcoder,
     * such as bitrate or resolution. The GUPnPDIDLLiteResource should be instantiated
     * by calling this base class implementation, passing the provided didl_item, item
     * and manager parameters.
     *
     * @param didl_item The DIDLLite item for which to create the resource, by calling the base class implementation.
     * @param item The media item for which to create the DIDLiteResource, by calling the base class implementation.
     * @param manager The transcoder manager to pass to the base class implemenetation.
     * @return The new resource.
     */
    public virtual DIDLLiteResource? add_resource (DIDLLiteItem     didl_item,
                                                   MediaItem        item,
                                                   TranscodeManager manager)
                                                   throws Error {
        return null;
    }

    /**
     * Returns whether this trancoder can handle the specified DLNA profile.
     * This is determined by the #RygelTranscodeManager, which checks
     * the suitability of each #RygelTranscoder by calling
     * rygel_transcoder_get_distance() with each #RygelMediaItem,
     * choosing one DLNA profile for each transcoder to handle.
     *
     * @param target A DLNA profile name as obtained from rygel_media_item_get_dlna_profile().
     *
     * @return True if the transcoder can handle the specified DLNA profile.
     */
    public bool can_handle (string target) {
        return target == this.dlna_profile;
    }

    /**
     * Gets a numeric value that gives an gives an estimate of how hard
     * it would be for this transcoder to trancode @item to the target profile of this transcoder.
     *
     * @param item the media item to calculate the distance for
     *
     * @return      the distance from the @item, uint.MIN if providing such a
     *              value is impossible or uint.MAX if it doesn't make any
     *              sense to use this transcoder for @item
     */
    public abstract uint get_distance (MediaItem item);

    protected bool mime_type_is_a (string mime_type1, string mime_type2) {
        string content_type1 = ContentType.get_mime_type (mime_type1);
        string content_type2 = ContentType.get_mime_type (mime_type2);

        return ContentType.is_a (content_type1, content_type2);
    }
}

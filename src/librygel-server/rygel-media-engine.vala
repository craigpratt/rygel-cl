/*
 * Copyright (C) 2012 Intel Corporation.
 *
 * Author: Jens Georg <jensg@openismus.com>
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

public errordomain Rygel.MediaEngineError {
    NOT_FOUND
}

/**
 * This is the base class for media engines that contain knowledge about 
 * the streaming and (optionally) the transcoding and seeking capabilites
 * of the media library in use. Derived classes also instantiate any
 * transcoding objects supported by the media engine and specify the list
 * of media formats the engine is capable of playing.
 *
 * See, for instance, Rygel's built-in "gstreamer" and "simple" media engines,
 * or the external rygel-gst-0-10-media-engine module.
 *
 * The actual media engine used by Rygel at runtime is specified
 * by the media-engine configuration key.
 * For instance, in rygel.conf:
 * media-engine=librygel-media-engine-gst.so
 *
 * Media engines should also derive their own #RygelDataSource,
 * returning an instance of it from create_data_source_for_resource().
 *
 * If this media engine supports transcoding then it will typically
 * implement a set of transcoding classes, typically with one 
 * base class and a number of sub-classes - one for each transcoding
 * format you want to support. These should be returned by the
 * get_transcoders() virtual function. The base transcoder class could
 * provide a generic way to create a #RygelDataSource capable of
 * providing Rygel with a transcoded version of a file using the
 * underlying media framework. The sub-classes could contain the
 * various media-framework-specific parameters required to 
 * transcode to a given format and implement a heuristic that
 * can be used to order an item's transcoded resources.
 *
 * See the
 * <link linkend="implementing-media-engines">Implementing Media Engines</link> section.
 */
public abstract class Rygel.MediaEngine : GLib.Object {
    private static MediaEngine instance;

    public static void init () throws Error {
        // lazy-load the engine plug-in
        var loader = new EngineLoader ();
        MediaEngine.instance = loader.load_engine ();
        if (MediaEngine.instance == null) {
            throw new MediaEngineError.NOT_FOUND
                                        (_("No media engine found."));
        }
    }

    /**
     * Get the singleton instance of the currently used media engine.
     *
     * @return An instance of a concrete #RygelMediaEngine implementation.
     */
    public static MediaEngine get_default () {
        if (instance == null) {
            error (_("MediaEngine.init was not called. Cannot continue."));
        }

        return instance;
    }

    /**
     * Get a list of the DLNA profiles that the media engine can stream.
     *
     * This information is needed to implement DLNA's
     * ConnectionManager.GetProtocolInfo call and to determine whether Rygel
     * can accept an uploaded file.
     *
     * @return A list of #RygelDLNAProfile<!-- -->s
     */
    public abstract unowned List<DLNAProfile> get_dlna_profiles ();

    /**
     * Get the supported MediaResources for the given content uri.
     *
     * The MediaResources returned may include formats/profiles that don't match the
     * raw source content byte-for-byte. 
     * 
     * Each MediaResource returned in the List must have a unique "name" field
     * (containing only alphanumeric characters). The order of resources in
     * the List should be from most-preferred to least-preferred. And some fields
     * related to the delivery protocol will be over-written (e.g. the host address
     * portion of the URI and the protocol field/deliver flags of the protocolInfo).
     *
     * Note: To reduce overhead, this call will only be made when source content is
     * added or changed (the results will be cached).
     *
     * @return A list of #MediaResources<!-- -->s or null if no resources are supported
     *         for the item.
     */
    public abstract Gee.List<MediaResource>? get_resources_for_uri(string uri);

    /**
     * Get a list of the transcoders that are provided by this media engine.
     *
     * @return A list of #RygelTranscoder<!-- -->s or null if not supported.
     */
    public abstract unowned List<Transcoder>? get_transcoders ();

    /**
     * Get a data source for the URI which renders the content specified by the uri
     * according to the MediaResource-specified parameters.
     *
     * Note that the provided #resource will be field-wise equivalent with a MediaResource
     * obtained from #get_resources_for_uri, but subclasses should not expect objects
     * references from #get_resources_for_uri to be provided to this method. If #resource
     * is null, then the DataSource returned should render the raw (unmodified) content.
     *
     * @param uri to create the data source for.
     * @param resource format to render for the data source.
     * @return A data source representing the uri rendered according to resource parameters
     */
    public abstract DataSource? create_data_source_for_resource
                                (string uri, MediaResource ? resource);
}

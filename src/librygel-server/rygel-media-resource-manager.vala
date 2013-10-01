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
 * Author: Craig Pratt <craig@ecaspia.com>
 *
 * This file is part of Rygel.
 */

using Gee;
using GLib;
using GUPnP;

/**
 * The RenderingManager is responsible for management/caching of MediaResources for content URIs.
 * It operates in concert with the configured MediaEngine to enumerate and cache the
 * MediaResources associated with a uri.
 */
public class Rygel.MediaResourceManager : GLib.Object {
    // Our singleton
    private static MediaResourceManager the_resource_manager;

    /**
     * Get the MediaResourceManager reference
     */
    public static MediaResourceManager get_default () {
        if (MediaResourceManager.the_resource_manager == null) {
            MediaResourceManager.the_resource_manager = new MediaResourceManager ();
        }

        return MediaResourceManager.the_resource_manager;
    }
    
    protected Regex address_regex;

    public MediaResourceManager () {
        try {
            address_regex = new Regex (Regex.escape_string ("@ADDRESS@"));
        } catch (GLib.RegexError err) {
            assert_not_reached ();
        }
    }

    private HashMap<string,Gee.List<MediaResource>> resource_table
                        = new HashMap< string,Gee.List<MediaResource> >();

    /**
     * Get the MediaResources the configured MediaEngine supports for the given URI.
     */
    public Gee.List<MediaResource> get_resources_for_source_uri(string uri) {
        Gee.List <MediaResource> resources;

        if (resource_table.has_key(uri)) {
            resources = resource_table.get(uri);
        }
        else
        {
            var engine = MediaEngine.get_default();
            Gee.List<MediaResource> engine_resources;
            engine_resources = engine.get_resources_for_uri(uri);
            if (engine_resources == null) {
                warning ("MediaResourceManager.get_resources_for_source_uri: No resources found for %s", uri);
            }
            adapt_resources_for_delivery(engine_resources);
            resource_table.set(uri, engine_resources);
            resources = engine_resources;
        }

        return resources;
    }

    /**
     * Get the MediaResource given URI with name resource_name or null if no resource
     * with the given name exists.
     */
    public MediaResource ? get_resource_for_source_uri_and_name(string uri, string resource_name) {
        message("MediaResourceManager.get_resources_for_source_uri_and_name(%s, %s)", uri, resource_name);

        Gee.List <MediaResource> resources = get_resources_for_source_uri(uri);

        foreach (var resource in resources)
        {
            if (resource.get_name() == resource_name)
            {
                return resource;
            }
        }

        return null;
    }

    /**
     * Update the MediaResources the configured MediaEngine supports for the given URI.
     *
     * This should be called every time there's a change in the content referenced by the
     * URI that would affect the published metadata.
     */
    public void update_resources_for_uri(string uri, Gee.List <MediaResource> ? resources) {
        message("MediaResourceManager.update_resources_for_uri: " + uri);
        var engine = MediaEngine.get_default();
        Gee.List<MediaResource> engine_resources;
        engine_resources = engine.get_resources_for_uri(uri);
        if (engine_resources == null) {
            message("MediaResourceManager: No resources found for %s", uri);
        }
        resource_table.set(uri, engine_resources);
    }

    /**
     * Remove the MediaResources the configured MediaEngine supports for the given URI.
     *
     * This should be called when the content referenced by the URI has been removed or
     * made inaccessible.
     */
    public void remove_resources_for_uri(string uri) {
        message("MediaResourceManager.remove_resources_for_uri: " + uri);
        resource_table.unset(uri);
    }

    public void adapt_resources_for_delivery(Gee.List <MediaResource> ? resources) {
        foreach (MediaResource resource in resources) {
            var protocol_info = resource.protocol_info;
            protocol_info.protocol = "http-get";
            protocol_info.dlna_flags |= DLNAFlags.DLNA_V15 
                                        | DLNAFlags.STREAMING_TRANSFER_MODE 
                                        | DLNAFlags.BACKGROUND_TRANSFER_MODE 
                                        | DLNAFlags.CONNECTION_STALL;
        }
    }
}

/*
 * Copyright (C) 2013 CableLabs
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
    public Gee.List<MediaResource> get_resources_for_uri(string uri) {
        message("MediaResourceManager.get_resources_for_uri: " + uri);

        Gee.List <MediaResource> resources;

        if (resource_table.has_key(uri)) {
            resources = resource_table.get(uri);
        }
        else
        {
            message("MediaResourceManager.get_resources_for_uri: Calling engine for resources");
            var engine = MediaEngine.get_default();
            Gee.List<MediaResource> engine_resources;
            engine_resources = engine.get_resources_for_uri(uri);
            if (engine_resources == null) {
                message("MediaResourceManager: No resources found for %s", uri);
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
    public MediaResource ? get_resource_for_uri_and_name(string uri, string resource_name) {
        message("MediaResourceManager.get_resources_for_uri_and_name(%s, %s)", uri, resource_name);

        Gee.List <MediaResource> resources = get_resources_for_uri(uri);

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

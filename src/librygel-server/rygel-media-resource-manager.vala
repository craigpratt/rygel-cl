/*
 * Copyright (C) 2013 CableLabs
 */

using Gee;
using GLib;

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
    
    public MediaResourceManager () { }

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
            resource_table.set(uri, engine_resources);
            resources = engine_resources;
        }

        return resources;
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
}

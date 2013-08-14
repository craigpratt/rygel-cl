/*
 * Copyright (C) 2013 CableLabs
 */

using Gee;
using GLib;

/**
 * The RenderingManager is responsible for management/caching of MediaRenderings for content URIs.
 * It operates in concert with the configured MediaEngine to enumerate 
 */
public class Rygel.RenderingManager : GLib.Object {
    // Our singleton
    private static RenderingManager the_rendering_manager;

    /**
     * Get the RenderingManager reference
     */
    public static RenderingManager get_default () {
        if (RenderingManager.the_rendering_manager == null) {
            RenderingManager.the_rendering_manager = new RenderingManager ();
        }

        return RenderingManager.the_rendering_manager;
    }
    
    public RenderingManager () { }

    private HashMap<string,Gee.List<MediaRendering>> rendering_table
                        = new HashMap< string,Gee.List<MediaRendering> >();

    /**
     * Get the MediaRenderings the configured MediaEngine supports for the given URI.
     */
    public Gee.List<MediaRendering> get_renderings_for_uri
                                        (string uri, Gee.List <MediaResource> ? resources) {
        message("RenderingManager.get_renderings_for_uri: " + uri);
        Gee.List<MediaRendering> renderings;

        if (rendering_table.has_key(uri)) {
            renderings = rendering_table.get(uri);
        }
        else
        {
            message("RenderingManager.get_renderings_for_uri: Calling engine for renderings");
            var engine = MediaEngine.get_default();
            Gee.List<MediaRendering> engine_renderings;
            engine_renderings = engine.get_renderings_for_uri(uri, resources);
            if (engine_renderings == null) {
                message("RenderingManager: No renderings found for %s", uri);
            }
            rendering_table.set(uri, engine_renderings);
            renderings = engine_renderings;
        }

        return renderings;
    }

    /**
     * Update the MediaRenderings the configured MediaEngine supports for the given URI.
     *
     * This should be called every time there's a change in the content referenced by the
     * URI that would affect the published metadata.
     */
    public void update_renderings_for_uri(string uri, Gee.List <MediaResource> ? resources) {
        message("RenderingManager.update_renderings_for_uri: " + uri);
        var engine = MediaEngine.get_default();
        Gee.List<MediaRendering> engine_renderings;
        engine_renderings = engine.get_renderings_for_uri(uri, resources);
        if (engine_renderings == null) {
            message("RenderingManager: No renderings found for %s", uri);
        }
        rendering_table.set(uri, engine_renderings);
    }

    /**
     * Remove the MediaRenderings the configured MediaEngine supports for the given URI.
     *
     * This should be called when the content referenced by the URI has been removed or
     * made inaccessible.
     */
    public void remove_renderings_for_uri(string uri) {
        message("RenderingManager.remove_renderings_for_uri: " + uri);
        rendering_table.unset(uri);
    }
}

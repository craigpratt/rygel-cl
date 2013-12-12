/*
 * Copyright (C) 2009,2010 Jens Georg <mail@jensge.org>.
 * Copyright (C) 2013 Intel Corporation.
 * Copyright (C) 2013 Cable Television Laboratories, Inc.
 *
 * Author: Jens Georg <mail@jensge.org>
 *         Doug Galligan <doug@sentosatech.com>
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

using Gee;
using GUPnP;
using Sqlite;

public errordomain Rygel.ODID.MediaCacheError {
    SQLITE_ERROR,
    GENERAL_ERROR,
    INVALID_TYPE,
    UNSUPPORTED_SEARCH
}

internal enum Rygel.ODID.ObjectType {
    CONTAINER,
    ITEM
}

internal struct Rygel.ODID.ExistsCacheEntry {
    int64 mtime;
    int64 size;
}

/**
 * Persistent storage of media objects.
 *
 * ODIDDB is a sqlite3 backed persistent storage of media objects.
 */
public class Rygel.ODID.MediaCache : Object {
    // Private members
    private Database                           db;
    private ObjectFactory                      factory;
    private SQLFactory                         sql;
    private HashMap<string, ExistsCacheEntry?> exists_cache;

    // Private static members
    private static MediaCache instance;

    // Constructors
    private MediaCache () throws Error {
        var db_name = "odid";
        try {
            var config = MetaConfig.get_default ();
            if (config.get_bool (ODID.Plugin.NAME, "use-temp-db")) {
                db_name = ":memory:";
            }
        } catch (Error error) { }
        this.sql = new SQLFactory ();
        debug ("Opening database %s", db_name);
        this.open_db (db_name);
        this.factory = new ObjectFactory ();
    }

    // Public static functions
    public static string get_id (string uri) {
        return Checksum.compute_for_string (ChecksumType.MD5, uri);
    }

    public static void ensure_exists () throws Error {
        if (MediaCache.instance == null) {
            MediaCache.instance = new MediaCache ();
        }
    }

    public static MediaCache get_default () {
        return MediaCache.instance;
    }

    // Public functions
    public void remove_by_id (string id) throws DatabaseError {
        GLib.Value[] values = { id };
        this.db.exec (this.sql.make (SQLString.DELETE), values);
    }

    public void remove_object (MediaObject object) throws DatabaseError,
                                                          MediaCacheError {
        this.remove_by_id (object.id);
    }

    /**
     * Add the container to the cache, in a database transcation,
     * rolling back the transaction if necessary.
     */
    public void save_container (MediaContainer container) throws Error {
        try {
            db.begin ();
            create_object (container);
            db.commit ();
        } catch (DatabaseError error) {
            db.rollback ();

            throw error;
        }
    }

    /**
     * Add the item to the cache.
     */
    public void save_item (Rygel.ODID.MediaItem item,
                           bool override_guarded = false) throws Error {
        try {
            db.begin ();
            save_resources (item);
            create_object (item, override_guarded);
            db.commit ();
        } catch (DatabaseError error) {
            warning (_("Failed to add item with ID %s: %s"),
                     item.id,
                     error.message);
            db.rollback ();

            throw error;
        }
    }

    /**
     * Create a new container or item instance based on the ID.
     *
     * The Rygel server discards the object when the browse request is finished,
     * after serializing the result.
     */
    public MediaObject? get_object (string object_id) throws DatabaseError {
        GLib.Value[] values = { object_id };
        MediaObject parent = null;

        var cursor = this.exec_cursor (SQLString.GET_OBJECT, values);

        foreach (var statement in cursor) {
            var parent_container = parent as MediaContainer;
            var object = this.get_object_from_statement
                                        (parent_container,
                                         statement);
            object.parent_ref = parent_container;
            parent = object;
        }

        return parent;
    }

    public MediaContainer? get_container (string container_id)
                                          throws DatabaseError,
                                                 MediaCacheError {
        var object = get_object (container_id);
        if (object != null && !(object is MediaContainer)) {
            throw new MediaCacheError.INVALID_TYPE ("Object with id %s is " +
                                                    "not a MediaContainer",
                                                    container_id);
        }

        return object as MediaContainer;
    }

    public int get_child_count (string container_id) throws DatabaseError {
        GLib.Value[] values = { container_id };

        return this.query_value (SQLString.CHILD_COUNT, values);
    }

    public uint32 get_update_id () {
        // Return the highest object ID in the database so far.
        try {
            return this.query_value (SQLString.MAX_UPDATE_ID);
        } catch (Error error) { }

        return 0;
    }

    public void get_track_properties (string id,
                                      out uint32 object_update_id,
                                      out uint32 container_update_id,
                                      out uint32 total_deleted_child_count) {
        GLib.Value[] values = { id };

        object_update_id = 0;
        container_update_id = 0;
        total_deleted_child_count = 0;

        try {
            var cursor = this.db.exec_cursor ("SELECT object_update_id, " +
                                              "container_update_id, " +
                                              "deleted_child_count " +
                                              "FROM Object WHERE upnp_id = ?",
                                              values);
            var statement = cursor.next ();
            object_update_id = (uint32) statement->column_int64 (0);
            container_update_id = (uint32) statement->column_int64 (1);
            total_deleted_child_count = (uint32) statement->column_int64 (2);

            return;
        } catch (Error error) {
            warning ("Failed to get update ids: %s", error.message);
        }

    }

    public bool exists (File      file,
                        out int64 timestamp,
                        out int64 size) throws DatabaseError {
        var uri = file.get_uri ();
        GLib.Value[] values = { uri };

        if (this.exists_cache.has_key (uri)) {
            var entry = this.exists_cache.get (uri);
            this.exists_cache.unset (uri);
            timestamp = entry.mtime;
            size = entry.size;

            return true;
        }

        var cursor = this.exec_cursor (SQLString.EXISTS, values);
        var statement = cursor.next ();
        timestamp = statement->column_int64 (1);

        // Placeholder item
        if (timestamp == int64.MAX) {
            timestamp = 0;
        }
        size = statement->column_int64 (2);

        return statement->column_int (0) == 1;
    }

    public MediaObjects get_children (MediaContainer container,
                                      string         sort_criteria,
                                      long           offset,
                                      long           max_count)
                                      throws Error {
        MediaObjects children = new MediaObjects ();

        GLib.Value[] values = { container.id,
                                offset,
                                max_count };

        var sql = this.sql.make (SQLString.GET_CHILDREN);

        var sort_order = MediaCache.translate_sort_criteria (sort_criteria);
        var cursor = this.db.exec_cursor (sql.printf (sort_order), values);

        foreach (var statement in cursor) {
            children.add (this.get_object_from_statement (container,
                                                          statement));
            children.last ().parent_ref = container;
        }

        return children;
    }

    public MediaObjects get_objects_by_search_expression
                                        (SearchExpression? expression,
                                         string?           container_id,
                                         string            sort_criteria,
                                         uint              offset,
                                         uint              max_count,
                                         out uint          total_matches)
                                         throws Error {
        var args = new GLib.ValueArray (0);
        var filter = MediaCache.translate_search_expression (expression, args);

        if (expression != null) {
            debug ("Original search: %s", expression.to_string ());
            debug ("Parsed search expression: %s", filter);
        }

        var max_objects = modify_limit (max_count);
        total_matches = (uint) get_object_count_by_filter (filter,
                                                           args,
                                                           container_id);

        return this.get_objects_by_filter (filter,
                                           args,
                                           container_id,
                                           sort_criteria,
                                           offset,
                                           max_objects);
    }

    public long get_object_count_by_search_expression
                                        (SearchExpression? expression,
                                         string?           container_id)
                                         throws Error {
        var args = new GLib.ValueArray (0);
        var filter = MediaCache.translate_search_expression (expression, args);

        if (expression != null) {
            debug ("Original search: %s", expression.to_string ());
            debug ("Parsed search expression: %s", filter);
        }

        for (int i = 0; i < args.n_values; i++) {
            var arg = args.get_nth (i);
            debug ("Arg %d: %s", i, arg.holds (typeof (string)) ?
                                        arg.get_string () :
                                        arg.strdup_contents ());
        }

        return this.get_object_count_by_filter (filter,
                                                args,
                                                container_id);
    }

    public long get_object_count_by_filter
                                        (string          filter,
                                         GLib.ValueArray args,
                                         string?         container_id)
                                         throws Error {
        if (container_id != null) {
            GLib.Value v = container_id;
            args.prepend (v);
        }

        debug ("Parameters to bind: %u", args.n_values);
        unowned string pattern;
        SQLString string_id;
        if (container_id != null) {
            string_id = SQLString.GET_OBJECT_COUNT_BY_FILTER_WITH_ANCESTOR;
        } else {
            string_id = SQLString.GET_OBJECT_COUNT_BY_FILTER;
        }
        pattern = this.sql.make (string_id);

        return this.db.query_value (pattern.printf (filter), args.values);
    }

    public MediaObjects get_objects_by_filter (string          filter,
                                               GLib.ValueArray args,
                                               string?         container_id,
                                               string          sort_criteria,
                                               long            offset,
                                               long            max_count)
                                               throws Error {
        var children = new MediaObjects ();
        GLib.Value v = offset;
        args.append (v);
        v = max_count;
        args.append (v);
        MediaContainer parent = null;

        debug ("Parameters to bind: %u", args.n_values);
        for (int i = 0; i < args.n_values; i++) {
            var arg = args.get_nth (i);
            debug ("Arg %d: %s", i, arg.holds (typeof (string)) ?
                                        arg.get_string () :
                                        arg.strdup_contents ());
        }

        unowned string sql;
        if (container_id != null) {
            sql = this.sql.make (SQLString.GET_OBJECTS_BY_FILTER_WITH_ANCESTOR);
        } else {
            sql = this.sql.make (SQLString.GET_OBJECTS_BY_FILTER);
        }

        var sort_order = MediaCache.translate_sort_criteria (sort_criteria);
        var cursor = this.db.exec_cursor (sql.printf (filter, sort_order),
                                          args.values);
        foreach (var statement in cursor) {
            unowned string parent_id = statement.column_text (ObjectColumn.PARENT);

            if (parent == null || parent_id != parent.id) {
                if (parent_id == null) {
                    parent = new NullContainer.root ();
                } else {
                    parent = new NullContainer (parent_id, null, "ODID");
                }
            }

            if (parent != null) {
                children.add (this.get_object_from_statement (parent,
                                                              statement));
                children.last ().parent_ref = parent;
            } else {
                warning ("Inconsistent database: item %s " +
                         "has no parent %s",
                         statement.column_text (ObjectColumn.ID),
                         parent_id);
            }
        }

        return children;
    }

    public void debug_statistics () {
        try {
            debug ("Database statistics:");
            var cursor = this.exec_cursor (SQLString.STATISTICS);
            foreach (var statement in cursor) {
                debug ("%s: %d",
                       statement.column_text (0),
                       statement.column_int (1));
            }
        } catch (Error error) { }
    }

    public ArrayList<string> get_child_ids (string container_id)
                                            throws DatabaseError {
        ArrayList<string> children = new ArrayList<string> ();
        GLib.Value[] values = { container_id  };

        var cursor = this.exec_cursor (SQLString.CHILD_IDS, values);
        foreach (var statement in cursor) {
            children.add (statement.column_text (0));
        }

        return children;
    }

    public Gee.List<string> get_meta_data_column_by_filter
                                        (string          column,
                                         string          filter,
                                         GLib.ValueArray args,
                                         long            offset,
                                         long            max_count)
                                         throws Error {
        GLib.Value v = offset;
        args.append (v);
        v = max_count;
        args.append (v);

        var data = new ArrayList<string> ();

        unowned string sql = this.sql.make (SQLString.GET_RESOURCE_COLUMN);
        var cursor = this.db.exec_cursor (sql.printf (column, filter),
                                          args.values);
        foreach (var statement in cursor) {
            data.add (statement.column_text (0));
        }

        return data;
    }

    /**
     * TODO
     */
    public Gee.List<string> get_object_attribute_by_search_expression
                                        (string            attribute,
                                         SearchExpression? expression,
                                         long              offset,
                                         uint              max_count)
                                         throws Error {
        var args = new ValueArray (0);
        var filter = MediaCache.translate_search_expression (expression,
                                                             args,
                                                             "AND");

        debug ("Parsed filter: %s", filter);

        var column = MediaCache.map_operand_to_column (attribute);
        var max_objects = modify_limit (max_count);

        return this.get_meta_data_column_by_filter (column,
                                                    filter,
                                                    args,
                                                    offset,
                                                    max_objects);
    }

    public string get_reset_token () {
        try {
            var cursor = this.exec_cursor (SQLString.RESET_TOKEN);
            var statement = cursor.next ();

            return statement->column_text (0);
        } catch (DatabaseError error) {
            warning ("Failed to get reset token");

            return UUID.get ();
        }
    }

    public void save_reset_token (string token) {
        try {
            GLib.Value[] args = { token };

            this.db.exec ("UPDATE schema_info SET reset_token = ?", args);
        } catch (DatabaseError error) {
            warning ("Failed to persist ServiceResetToken: %s", error.message);
        }
    }

    public void drop_virtual_folders () {
        try {
            this.db.exec ("DELETE FROM object WHERE " +
                          "upnp_id LIKE 'virtual-parent:%'");
        } catch (DatabaseError error) {
            warning ("Failed to drop virtual folders: %s", error.message);
        }
    }

    public void make_object_guarded (MediaObject object,
                                     bool guarded = true) {
        var guarded_val = guarded ? 1 : 0;

        try {
            GLib.Value[] values = { guarded_val,
                                    object.id };

            this.db.exec (this.sql.make (SQLString.MAKE_GUARDED), values);
        } catch (DatabaseError error) {
            warning ("Failed to mark item %s as guarded (%d): %s",
                     object.id,
                     guarded_val,
                     error.message);
        }
    }

    public string create_reference (MediaObject object, MediaContainer parent)
                                    throws Error {
        if (object is MediaContainer) {
            var msg = _("Cannot create references to containers");

            throw new MediaCacheError.GENERAL_ERROR (msg);
        }

        object.parent = parent;

        // If the original is already a ref_id, point to the original item as
        // we should not daisy-chain reference items.
        if (object.ref_id == null) {
            object.ref_id = object.id;
        }
        object.id = UUID.get ();

        this.save_item (object as Rygel.ODID.MediaItem);

        return object.id;
    }

    // Private functions
    private bool is_object_guarded (string id) {
        try {
            GLib.Value[] id_value = { id };

            return this.query_value (SQLString.IS_GUARDED,
                                     id_value) == 1;
        } catch (DatabaseError error) {
            warning ("Failed to get whether item %s is guarded: %s",
                     id,
                     error.message);

            return false;
        }
    }

    public void rebuild_exists_cache () throws DatabaseError {
        this.exists_cache = new HashMap<string, ExistsCacheEntry?> ();
        var cursor = this.exec_cursor (SQLString.EXISTS_CACHE);
        foreach (var statement in cursor) {
            var entry = ExistsCacheEntry ();
            entry.mtime = statement.column_int64 (1);
            entry.size = statement.column_int64 (0);
            this.exists_cache.set (statement.column_text (2), entry);
        }
    }

    private uint modify_limit (uint max_count) {
        if (max_count == 0) {
            return -1;
        } else {
            return max_count;
        }
    }

    private void open_db (string name) throws Error {
        this.db = new Database (name);
        int old_version = -1;
        int current_version = int.parse (SQLFactory.SCHEMA_VERSION);

        try {
            var upgrader = new MediaCacheUpgrader (this.db, this.sql);
            if (upgrader.needs_upgrade (out old_version)) {
                upgrader.upgrade (old_version);
            } else if (old_version == current_version) {
                upgrader.fix_schema ();
            } else {
                warning ("The version \"%d\" of the detected database" +
                         " is newer than our supported version \"%d\"",
                         old_version,
                         current_version);
                this.db = null;

                throw new MediaCacheError.GENERAL_ERROR ("Database format" +
                                                         " not supported");
            }
            upgrader.ensure_indices ();
        } catch (DatabaseError error) {
            debug ("Could not find schema version;" +
                   " checking for empty database...");
            try {
                var rows = this.db.query_value ("SELECT count(type) FROM " +
                                                "sqlite_master WHERE rowid=1");
                if (rows == 0) {
                    debug ("Empty database, creating new schema version %s",
                            SQLFactory.SCHEMA_VERSION);
                    if (!create_schema ()) {
                        this.db = null;

                        return;
                    }
                } else {
                    warning ("Incompatible schema... cannot proceed");
                    this.db = null;

                    return;
                }
            } catch (DatabaseError error) {
                warning ("Something weird going on: %s", error.message);
                this.db = null;

                throw new MediaCacheError.GENERAL_ERROR ("Invalid database");
            }
        }
    }

    private void save_resources (Rygel.ODID.MediaItem item) throws Error {
        // Remove and pre-existing resources
        this.db.exec (this.sql.make (SQLString.DELETE_RESOURCES), { item.id });

        int index = 0;
        foreach (MediaResource resource in item.get_resource_list ())
        {
            // TODO: Remove this if/when ProtocolInfo.to_string is no longer used
            resource.protocol = "http-get"; // Prevents ProtocolInfo assertion error
            // Fill common properties
            GLib.Value[] values = { resource.size,
                                    resource.width,
                                    resource.height,
                                    Database.null (),
                                    Database.null (),
                                    resource.bitrate,
                                    resource.sample_freq,
                                    resource.bits_per_sample,
                                    resource.audio_channels,
                                    -1,
                                    resource.color_depth,
                                    resource.duration,
                                    item.id,
                                    resource.get_protocol_info ().to_string (),
                                    resource.cleartext_size,
                                    Database.null (),
                                    -1,
                                    resource.uri,
                                    resource.get_name (),
                                    resource.extension,
                                    index++ };
            this.db.exec (this.sql.make (SQLString.SAVE_RESOURCE), values);
        }
    }

    private void update_guarded_object (MediaObject object) throws Error {
        int type = ObjectType.CONTAINER;
        GLib.Value parent;

        if (object is Rygel.ODID.MediaItem) {
            type = ObjectType.ITEM;
        }

        if (object.parent == null) {
            parent = Database.@null ();
        } else {
            parent = object.parent.id;
        }

        GLib.Value[] values = { type,
                                parent,
                                object.upnp_class,
                                object.date,
                                object.creator,
                                object.modified,
                                object.uris.is_empty ? null : object.uris[0],
                                object.object_update_id,
                                -1,
                                -1,
                                object.id
                              };
        if (object is MediaContainer) {
            var container = object as MediaContainer;
            values[6] = container.total_deleted_child_count;
            values[7] = container.update_id;
        }

        this.db.exec (this.sql.make (SQLString.UPDATE_GUARDED_OBJECT), values);
    }

    private void create_normal_object (MediaObject object,
                                       bool is_guarded) throws Error {
        int type = ObjectType.CONTAINER;
        GLib.Value parent;

        if (object is Rygel.ODID.MediaItem) {
            type = ObjectType.ITEM;
        }

        if (object.parent == null) {
            parent = Database.@null ();
        } else {
            parent = object.parent.id;
        }

        GLib.Value[] values = { object.id,
                                object.title,
                                type,
                                parent,
                                object.upnp_class,
                                object.date,
                                object.creator,
                                object.modified,
                                object.uris.is_empty ? null : object.uris[0],
                                object.object_update_id,
                                -1,
                                -1,
                                is_guarded ? 1 : 0,
                                object.ref_id ?? null
                              };
        if (object is MediaContainer) {
            var container = object as MediaContainer;
            values[8] = container.total_deleted_child_count;
            values[9] = container.update_id;
        }

        this.db.exec (this.sql.make (SQLString.INSERT), values);
    }

    /**
     * Add the container or item to the cache.
     */
    private void create_object (MediaObject object,
                                bool override_guarded = false) throws Error {
        var is_guarded = this.is_object_guarded (object.id);

        if (!override_guarded && is_guarded) {
            update_guarded_object (object);
        } else {
            create_normal_object (object, (is_guarded || override_guarded));
        }
    }

    /**
     * Create the current schema.
     *
     * If schema creation fails, schema will be rolled back
     * completely.
     *
     * @returns: true on success, false on failure
     */
    private bool create_schema () {
        try {
            db.begin ();
            db.exec (this.sql.make (SQLString.SCHEMA));
            db.exec (this.sql.make (SQLString.TRIGGER_COMMON));
            db.exec (this.sql.make (SQLString.TABLE_CLOSURE));
            db.exec (this.sql.make (SQLString.INDEX_COMMON));
            db.exec (this.sql.make (SQLString.TRIGGER_CLOSURE));
            db.exec (this.sql.make (SQLString.TRIGGER_REFERENCE));
            db.commit ();
            db.analyze ();
            this.save_reset_token (UUID.get ());

            return true;
        } catch (Error err) {
            warning ("Failed to create schema: %s", err.message);
            db.rollback ();
        }

        return false;
   }

    /**
     * Create a new container or item based on a SQL result.
     *
     * The Rygel server discards the object when the browse request is finished,
     * after serializing the result.
     *
     * @param parent The object's parent container.
     * @param statement a SQLite result indicating the container's details.
     */
    private MediaObject? get_object_from_statement (MediaContainer? parent,
                                                    Statement       statement) {
        MediaObject object = null;
        unowned string title = statement.column_text (ObjectColumn.TITLE);
        unowned string object_id = statement.column_text (ObjectColumn.ID);
        unowned string uri = statement.column_text (ObjectColumn.URI);

        switch (statement.column_int (ObjectColumn.TYPE)) {
            case 0:
                // this is a container
                object = factory.get_container (object_id, title, 0, uri);
                var container = object as MediaContainer;
                if (uri != null) {
                    container.uris.add (uri);
                }
                container.total_deleted_child_count = (uint32) statement.column_int64
                                        (ObjectColumn.DELETED_CHILD_COUNT);
                container.update_id = (uint) statement.column_int64
                                        (ObjectColumn.CONTAINER_UPDATE_ID);
                break;
            case 1:
                // this is an item
                unowned string upnp_class = statement.column_text
                                        (ObjectColumn.CLASS);
                object = factory.get_item (parent,
                                           object_id,
                                           title,
                                           upnp_class);

                if (uri != null) {
                    (object as Rygel.ODID.MediaItem).add_uri (uri);
                }

                fill_item (statement, object as Rygel.ODID.MediaItem);

                break;
            default:
                assert_not_reached ();
        }

        if (object != null) {
            object.modified = statement.column_int64 (ObjectColumn.TIMESTAMP);
            if (object.modified  == int64.MAX && object is Rygel.ODID.MediaItem) {
                object.modified = 0;
            }
            object.object_update_id = (uint) statement.column_int64
                                        (ObjectColumn.OBJECT_UPDATE_ID);
            object.ref_id = statement.column_text (ObjectColumn.REFERENCE_ID);
        }

        return object;
    }

    private void fill_item (Statement statement, Rygel.ODID.MediaItem item) {
        // Fill common properties and resources from the database
        item.date = statement.column_text (ObjectColumn.DATE);
        item.creator = statement.column_text (ObjectColumn.CREATOR);
        GLib.Value[] values = { item.id };

        var resources_list = item.get_resource_list ();

        try {
            var cursor = this.exec_cursor (SQLString.GET_RESOURCES_BY_OBJECT,    
                                              values);

            foreach (var resource_stmt in cursor) {
                MediaResource res = new MediaResource (resource_stmt.column_text (ResourceColumn.NAME));

                var pi = new ProtocolInfo.from_string (resource_stmt.column_text
                                                          (ResourceColumn.PROTOCOL_INFO));
                res.set_protocol_info (pi);

                res.duration        = resource_stmt.column_int (ResourceColumn.DURATION);
                res.width           = resource_stmt.column_int (ResourceColumn.WIDTH);
                res.height          = resource_stmt.column_int (ResourceColumn.HEIGHT);
                res.bitrate         = resource_stmt.column_int (ResourceColumn.BITRATE);
                res.sample_freq     = resource_stmt.column_int (ResourceColumn.SAMPLE_FREQ);
                res.bits_per_sample = resource_stmt.column_int (ResourceColumn.BITS_PER_SAMPLE);
                res.audio_channels  = resource_stmt.column_int (ResourceColumn.CHANNELS);
                res.uri             = resource_stmt.column_text (ResourceColumn.EXTERNAL_URI);
                res.extension       = resource_stmt.column_text (ResourceColumn.EXTENSION);
                res.color_depth     = resource_stmt.column_int (ResourceColumn.COLOR_DEPTH);
                res.size            = resource_stmt.column_int64 (ResourceColumn.SIZE);
                res.cleartext_size  = resource_stmt.column_int64 (ResourceColumn.CLEARTEXT_SIZE);

                resources_list.add (res);
            }

        } catch (Error error) {
            warning ("Failed to get update ids: %s", error.message);
        }
    }

    private static string translate_search_expression
                                        (SearchExpression? expression,
                                         ValueArray        args,
                                         string            prefix = "WHERE")
                                         throws Error {
        if (expression == null) {
            return "";
        }

        var filter = MediaCache.search_expression_to_sql (expression, args);

        return " %s %s".printf (prefix, filter);
    }

    private static string? search_expression_to_sql
                                        (SearchExpression? expression,
                                         GLib.ValueArray   args)
                                         throws Error {
        if (expression == null) {
            return "";
        }

        if (expression is LogicalExpression) {
            return MediaCache.logical_expression_to_sql
                                        (expression as LogicalExpression, args);
        } else {
            return MediaCache.relational_expression_to_sql
                                        (expression as RelationalExpression,
                                         args);
        }
    }

    private static string logical_expression_to_sql
                                        (LogicalExpression expression,
                                         GLib.ValueArray   args)
                                         throws Error {
        string left_sql_string = MediaCache.search_expression_to_sql
                                        (expression.operand1,
                                         args);
        string right_sql_string = MediaCache.search_expression_to_sql
                                        (expression.operand2,
                                         args);
        unowned string operator_sql_string = "OR";

        if (expression.op == LogicalOperator.AND) {
            operator_sql_string = "AND";
        }

        return "(%s %s %s)".printf (left_sql_string,
                                    operator_sql_string,
                                    right_sql_string);
    }

    private static string? map_operand_to_column (string     operand,
                                                  out string? collate = null,
                                                  bool        for_sort = false)
                                                  throws Error {
        string column = null;
        bool use_collation = false;

        switch (operand) {
            case "res":
                column = "o.uri";
                break;
            case "res@duration":
                column = "r.duration";
                break;
            case "@refID":
                column = "o.reference_id";
                break;
            case "@id":
                column = "o.upnp_id";
                break;
            case "@parentID":
                column = "o.parent";
                break;
            case "upnp:class":
                column = "o.class";
                break;
            case "dc:title":
                column = "o.title";
                use_collation = true;
                break;
            case "upnp:artist":
            case "upnp:author":
                column = "r.author";
                use_collation = true;
                break;
            case "dc:creator":
                column = "o.creator";
                use_collation = true;
                break;
            case "dc:date":
                if (for_sort) {
                    column = "o.date";
                } else {
                    column = "strftime(\"%Y\", o.date)";
                }
                break;
            case "upnp:album":
                column = "r.album";
                use_collation = true;
                break;
            case "upnp:genre":
            case "dc:genre":
                // FIXME: Remove dc:genre, upnp:genre is the correct one
                column = "r.genre";
                use_collation = true;
                break;
            case "upnp:originalTrackNumber":
                column = "r.track";
                break;
            case "rygel:originalVolumeNumber":
                column = "r.disc";
                break;
            case "upnp:objectUpdateID":
                column = "o.object_update_id";
                break;
            case "upnp:containerUpdateID":
                column = "o.container_update_id";
                break;
            default:
                var message = "Unsupported column %s".printf (operand);

                throw new MediaCacheError.UNSUPPORTED_SEARCH (message);
        }

        if (use_collation) {
            collate = "COLLATE CASEFOLD";
        } else {
            collate = "";
        }

        return column;
    }

    private static string? relational_expression_to_sql
                                        (RelationalExpression exp,
                                         GLib.ValueArray      args)
                                         throws Error {
        GLib.Value? v = null;
        string collate = null;

        string column = MediaCache.map_operand_to_column (exp.operand1,
                                                          out collate);
        SqlOperator operator;

        switch (exp.op) {
            case SearchCriteriaOp.EXISTS:
                string sql_function;
                if (exp.operand2 == "true") {
                    sql_function = "%s IS NOT NULL AND %s != ''";
                } else {
                    sql_function = "%s IS NULL OR %s = ''";
                }

                return sql_function.printf (column, column);
            case SearchCriteriaOp.EQ:
            case SearchCriteriaOp.NEQ:
            case SearchCriteriaOp.LESS:
            case SearchCriteriaOp.LEQ:
            case SearchCriteriaOp.GREATER:
            case SearchCriteriaOp.GEQ:
                if (column == "o.class" &&
                    exp.op == SearchCriteriaOp.EQ &&
                    exp.operand2 == "object.container") {
                    operator = new SqlOperator ("=", "o.type_fk");
                    v = (int) ObjectType.CONTAINER;
                } else {
                    v = exp.operand2;
                    operator = new SqlOperator.from_search_criteria_op
                                            (exp.op, column, collate);
                }
                break;
            case SearchCriteriaOp.CONTAINS:
                operator = new SqlFunction ("contains", column);
                v = exp.operand2;
                break;
            case SearchCriteriaOp.DOES_NOT_CONTAIN:
                operator = new SqlFunction ("NOT contains", column);
                v = exp.operand2;
                break;
            case SearchCriteriaOp.DERIVED_FROM:
                if (column == "o.class" &&
                    exp.operand2.has_prefix ("object.container")) {
                    operator = new SqlOperator ("=", "o.type_fk");
                    v = (int) ObjectType.CONTAINER;
                } else {
                    operator = new SqlOperator ("LIKE", column);
                    v = "%s%%".printf (exp.operand2);
                }
                break;
            default:
                warning ("Unsupported op %d", exp.op);
                return null;
        }

        if (v != null) {
            args.append (v);
        }

        return operator.to_string ();
    }

    private DatabaseCursor exec_cursor (SQLString      id,
                                        GLib.Value[]?  values = null)
                                        throws DatabaseError {
        return this.db.exec_cursor (this.sql.make (id), values);
    }

    private int query_value (SQLString      id,
                             GLib.Value[]?  values = null)
                             throws DatabaseError {
        return this.db.query_value (this.sql.make (id), values);
    }

    private static string translate_sort_criteria (string sort_criteria) {
        string? collate;
        var builder = new StringBuilder ("ORDER BY ");
        var fields = sort_criteria.split (",");
        foreach (unowned string field in fields) {
            try {
                var column = MediaCache.map_operand_to_column
                                        (field[1:field.length],
                                         out collate,
                                         true);
                if (field != fields[0]) {
                    builder.append (",");
                }
                builder.append_printf ("%s %s %s ",
                                       column,
                                       collate,
                                       field[0] == '-' ? "DESC" : "ASC");
            } catch (Error error) {
                warning ("Skipping unsupported field: %s", field);
            }
        }

        return builder.str;
    }
}

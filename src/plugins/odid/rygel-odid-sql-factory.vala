/*
 * Copyright (C) 2010,2011 Jens Georg <mail@jensge.org>.
 *
 * Author: Jens Georg <mail@jensge.org>
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
 */

internal enum Rygel.ODID.ResourceColumn {
    SIZE,
    PROTOCOL_INFO,
    CLEARTEXT_SIZE,
    DURATION,
    WIDTH,
    HEIGHT,
    ALBUM,
    GENRE,
    BITRATE,
    SAMPLE_FREQ,
    BITS_PER_SAMPLE,
    CHANNELS,
    TRACK,
    DISK,
    EXTERNAL_URI,
    NAME,
    EXTENSION,
    COLOR_DEPTH
}

internal enum Rygel.ODID.ObjectColumn {
    TYPE,
    TITLE,
    ID,
    PARENT,
    CLASS,
    DATE,
    CREATOR,
    TIMESTAMP,
    URI,
    OBJECT_UPDATE_ID,
    DELETED_CHILD_COUNT,
    CONTAINER_UPDATE_ID,
    REFERENCE_ID
}

internal enum Rygel.ODID.SQLString {
    SAVE_RESOURCE,
    DELETE_RESOURCES,
    INSERT,
    DELETE,
    GET_OBJECT,
    GET_CHILDREN,
    GET_OBJECTS_BY_FILTER,
    GET_OBJECTS_BY_FILTER_WITH_ANCESTOR,
    GET_OBJECT_COUNT_BY_FILTER,
    GET_OBJECT_COUNT_BY_FILTER_WITH_ANCESTOR,
    GET_RESOURCES_BY_OBJECT,
    GET_RESOURCE_COLUMN,
    CHILD_COUNT,
    EXISTS,
    CHILD_IDS,
    TABLE_RESOURCE,
    TABLE_CLOSURE,
    TRIGGER_CLOSURE,
    TRIGGER_COMMON,
    INDEX_COMMON,
    SCHEMA,
    EXISTS_CACHE,
    STATISTICS,
    RESET_TOKEN,
    MAX_UPDATE_ID,
    MAKE_GUARDED,
    IS_GUARDED,
    UPDATE_GUARDED_OBJECT,
    TRIGGER_REFERENCE
}

internal class Rygel.ODID.SQLFactory : Object {
    private const string SAVE_RESOURCE_STRING =
    "INSERT OR REPLACE INTO Resource " +
        "(size, width, height, " +
         "author, album, bitrate, " +
         "sample_freq, bits_per_sample, channels, " +
         "track, color_depth, duration, object_fk, " +
         "protocol_info, cleartext_size, genre, disc, external_uri, name, extension) VALUES " +
         "(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)";

    private const string INSERT_OBJECT_STRING =
    "INSERT OR REPLACE INTO Object " +
        "(upnp_id, title, type_fk, parent, class, date, creator, timestamp, uri, " +
         "object_update_id, deleted_child_count, container_update_id, " +
         "is_guarded, reference_id) VALUES " +
        "(?,?,?,?,?,?,?,?,?,?,?,?,?,?)";

    private const string UPDATE_GUARDED_OBJECT_STRING =
    "UPDATE Object SET " +
        "type_fk = ?, " +
        "parent = ?, " +
        "class = ?, " +
        "date = ?, " +
        "creator = ?, " +
        "timestamp = ?, " +
        "uri = ?, " +
        "object_update_id = ?, " +
        "deleted_child_count = ?, " +
        "container_update_id = ? " +
        "where upnp_id = ?";

    private const string DELETE_BY_ID_STRING =
    "DELETE FROM Object WHERE upnp_id IN " +
        "(SELECT descendant FROM closure WHERE ancestor = ?)";

    private const string DELETE_RESOURCES_BY_ID_STRING =
    "DELETE from Resource WHERE object_fk = ?";   

    private const string ALL_OBJECT_STRING =
    "o.type_fk, o.title, o.upnp_id, o.parent, o.class, o.date, o.creator, o.timestamp, " +
    "o.uri, o.object_update_id, " +
    "o.deleted_child_count, o.container_update_id, o.reference_id ";

    private const string ALL_RESOURCE_STRING =
    "r.size, r.protocol_info, r.cleartext_size, r.duration, r.width, r.height, r.album, r.genre, r.bitrate, r.sample_freq, r.bits_per_sample, r.channels, r.track, r.disc, r.external_uri, r.name, r.extension, r.color_depth ";

    private const string GET_OBJECT_WITH_PATH =
    "SELECT DISTINCT " + ALL_OBJECT_STRING +
    "FROM Object o " +
        "JOIN Closure c ON (o.upnp_id = c.ancestor) " +
            "WHERE c.descendant = ? ORDER BY c.depth DESC";

    /**
     * This is the database query used to retrieve the children for a
     * given object.
     *
     * Sorting is as follows:
     *   - by type: containers first, then items if both are present
     *   - by upnp_class: items are sorted according to their class
     *   - by track: sorted by track
     *   - and after that alphabetically
     */
    private const string GET_CHILDREN_STRING =
    "SELECT " + ALL_OBJECT_STRING +
    "FROM Object o " +
        "JOIN Closure c ON (o.upnp_id = c.descendant) " +
    "WHERE c.ancestor = ? AND c.depth = 1 %s" +
    "LIMIT ?,?";

    private const string GET_OBJECTS_BY_FILTER_STRING_WITH_ANCESTOR =
    "SELECT DISTINCT " + ALL_OBJECT_STRING +
    "FROM Object o " +
        "JOIN Closure c ON o.upnp_id = c.descendant AND c.ancestor = ? " +
        "LEFT OUTER JOIN Resource r " +
            "ON o.upnp_id = r.object_fk %s %s " +
    "LIMIT ?,?";

    private const string GET_OBJECTS_BY_FILTER_STRING =
    "SELECT DISTINCT " + ALL_OBJECT_STRING +
    "FROM Object o " +
        "LEFT OUTER JOIN Resource r " +
            "ON o.upnp_id = r.object_fk %s %s " +
    "LIMIT ?,?";

    private const string GET_OBJECT_COUNT_BY_FILTER_STRING_WITH_ANCESTOR =
    "SELECT DISTINCT COUNT(o.type_fk) FROM Object o " +
        "JOIN Closure c ON o.upnp_id = c.descendant AND c.ancestor = ? " +
        "LEFT OUTER JOIN Resource r " +
            "ON o.upnp_id = r.object_fk %s";

    private const string GET_OBJECT_COUNT_BY_FILTER_STRING =
    "SELECT COUNT(1) FROM Resource r %s";

    private const string GET_RESOURCES_BY_OBJECT_STRING = 
    "SELECT " + ALL_RESOURCE_STRING + " FROM Resource r " +
        "WHERE r.object_fk = ?";

    private const string CHILDREN_COUNT_STRING =
    "SELECT COUNT(upnp_id) FROM Object WHERE Object.parent = ?";

    private const string OBJECT_EXISTS_STRING =
    "SELECT COUNT(1), timestamp, r.size FROM Object " +
        "JOIN Resource r ON r.object_fk = upnp_id " +
        "WHERE Object.uri = ?";

    private const string GET_CHILD_ID_STRING =
    "SELECT upnp_id FROM OBJECT WHERE parent = ?";

    private const string GET_RESOURCE_COLUMN_STRING =
    "SELECT DISTINCT %s AS _column FROM Resource AS r " +
        "WHERE _column IS NOT NULL %s ORDER BY _column COLLATE CASEFOLD " +
    "LIMIT ?,?";

    internal const string SCHEMA_VERSION = "2";
    internal const string CREATE_RESOURCE_TABLE_STRING =
    "CREATE TABLE resource (size INTEGER, " +
                            "protocol_info TEXT, " +
                            "cleartext_size INTEGER, " +
                            "duration INTEGER, " +
                            "width INTEGER, " +
                            "height INTEGER, " +
                            "author TEXT, " +
                            "album TEXT, " +
                            "genre TEXT, " +
                            "bitrate INTEGER, " +
                            "sample_freq INTEGER, " +
                            "bits_per_sample INTEGER, " +
                            "channels INTEGER, " +
                            "track INTEGER, " +
                            "disc INTEGER, " +
                            "external_uri TEXT, " +
                            "name TEXT NOT NULL, " +
                            "extension TEXT, " +
                            "color_depth INTEGER, " +
                            "object_fk TEXT CONSTRAINT " +
                                "object_fk_id REFERENCES Object(upnp_id) " +
                                    "ON DELETE CASCADE,  " +
                             "PRIMARY KEY (name, object_fk));";

    private const string SCHEMA_STRING =
    "CREATE TABLE schema_info (version TEXT NOT NULL, " +
                              "reset_token TEXT); " +
    CREATE_RESOURCE_TABLE_STRING +
    "CREATE TABLE object (parent TEXT CONSTRAINT parent_fk_id " +
                                "REFERENCES Object(upnp_id), " +
                          "upnp_id TEXT PRIMARY KEY, " +
                          "type_fk INTEGER, " +
                          "title TEXT NOT NULL, " +
                          "class TEXT NOT NULL, " +
                          "date TEXT, " +
                          "creator TEXT, " +
                          "timestamp INTEGER NOT NULL, " +
                          "uri TEXT, " +
                          "object_update_id INTEGER, " +
                          "deleted_child_count INTEGER, " +
                          "container_update_id INTEGER, " +
                          "is_guarded INTEGER, " +
                          "reference_id TEXT DEFAULT NULL);" +
    "INSERT INTO schema_info (version) VALUES ('" +
    SQLFactory.SCHEMA_VERSION + "'); ";

    private const string CREATE_CLOSURE_TABLE =
    "CREATE TABLE closure (ancestor TEXT, descendant TEXT, depth INTEGER)";

    private const string CREATE_CLOSURE_TRIGGER_STRING =
    "CREATE TRIGGER trgr_update_closure " +
    "AFTER INSERT ON Object " +
    "FOR EACH ROW BEGIN " +
        "SELECT RAISE(IGNORE) WHERE (SELECT COUNT(*) FROM Closure " +
            "WHERE ancestor = NEW.upnp_id " +
                  "AND descendant = NEW.upnp_id " +
                  "AND depth = 0) != 0;" +
        "INSERT INTO Closure (ancestor, descendant, depth) " +
            "VALUES (NEW.upnp_id, NEW.upnp_id, 0); " +
        "INSERT INTO Closure (ancestor, descendant, depth) " +
            "SELECT ancestor, NEW.upnp_id, depth + 1 FROM Closure " +
                "WHERE descendant = NEW.parent;" +
    "END;" +

    "CREATE TRIGGER trgr_delete_closure " +
    "AFTER DELETE ON Object " +
    "FOR EACH ROW BEGIN " +
        "DELETE FROM Closure WHERE descendant = OLD.upnp_id;" +
    "END;";

    // these triggers emulate ON DELETE CASCADE
    private const string CREATE_TRIGGER_STRING =
    "CREATE TRIGGER trgr_delete_resource " +
    "BEFORE DELETE ON Object " +
    "FOR EACH ROW BEGIN " +
        "DELETE FROM Resource WHERE Resource.object_fk = OLD.upnp_id; "+
    "END;";

    private const string DELETE_REFERENCE_TRIGGER_STRING =
    "CREATE TRIGGER trgr_delete_references " +
    "BEFORE DELETE ON Object " +
    "FOR EACH ROW BEGIN " +
        "DELETE FROM Object WHERE OLD.upnp_id = Object.reference_id; " +
    "END;";

    private const string CREATE_INDICES_STRING =
    "CREATE INDEX IF NOT EXISTS idx_parent on Object(parent);" +
    "CREATE INDEX IF NOT EXISTS idx_object_upnp_id on Object(upnp_id);" +
    "CREATE INDEX IF NOT EXISTS idx_resource_fk on Resource(object_fk);" +
    "CREATE INDEX IF NOT EXISTS idx_closure on Closure(descendant,depth);" +
    "CREATE INDEX IF NOT EXISTS idx_closure_descendant on Closure(descendant);" +
    "CREATE INDEX IF NOT EXISTS idx_closure_ancestor on Closure(ancestor);" +
    "CREATE INDEX IF NOT EXISTS idx_uri on Object(uri);" +
    "CREATE INDEX IF NOT EXISTS idx_object_date on Object(date);" +
    "CREATE INDEX IF NOT EXISTS idx_resource_genre on Resource(genre);" +
    "CREATE INDEX IF NOT EXISTS idx_resource_album on Resource(album);" +
    "CREATE INDEX IF NOT EXISTS idx_resource_artist_album on " +
                                "Resource(author, album);";

    private const string EXISTS_CACHE_STRING =
    "SELECT DISTINCT r.size, o.timestamp, o.uri FROM Object o " +
        "JOIN Resource r ON o.upnp_id = r.object_fk";

    private const string STATISTICS_STRING =
    "SELECT class, count(1) FROM object GROUP BY class";

    private const string RESET_TOKEN_STRING =
    "SELECT reset_token FROM schema_info";

    private const string MAX_UPDATE_ID_STRING =
    "SELECT MAX(MAX(object_update_id), MAX(container_update_id)) FROM Object";

    private const string MAKE_GUARDED_STRING =
    "UPDATE Object SET is_guarded = ? WHERE Object.upnp_id = ?";

    private const string IS_GUARDED_STRING =
    "SELECT is_guarded FROM Object WHERE Object.upnp_id = ?";

    public unowned string make (SQLString query) {
        switch (query) {
            case SQLString.SAVE_RESOURCE:
                return SAVE_RESOURCE_STRING;
            case SQLString.DELETE_RESOURCES:
                return DELETE_RESOURCES_BY_ID_STRING;
            case SQLString.INSERT:
                return INSERT_OBJECT_STRING;
            case SQLString.DELETE:
                return DELETE_BY_ID_STRING;
            case SQLString.GET_OBJECT:
                return GET_OBJECT_WITH_PATH;
            case SQLString.GET_CHILDREN:
                return GET_CHILDREN_STRING;
            case SQLString.GET_OBJECTS_BY_FILTER:
                return GET_OBJECTS_BY_FILTER_STRING;
            case SQLString.GET_OBJECTS_BY_FILTER_WITH_ANCESTOR:
                return GET_OBJECTS_BY_FILTER_STRING_WITH_ANCESTOR;
            case SQLString.GET_OBJECT_COUNT_BY_FILTER:
                return GET_OBJECT_COUNT_BY_FILTER_STRING;
            case SQLString.GET_OBJECT_COUNT_BY_FILTER_WITH_ANCESTOR:
                return GET_OBJECT_COUNT_BY_FILTER_STRING_WITH_ANCESTOR;
            case SQLString.GET_RESOURCES_BY_OBJECT:
                return GET_RESOURCES_BY_OBJECT_STRING;
            case SQLString.GET_RESOURCE_COLUMN:
                return GET_RESOURCE_COLUMN_STRING;
            case SQLString.CHILD_COUNT:
                return CHILDREN_COUNT_STRING;
            case SQLString.EXISTS:
                return OBJECT_EXISTS_STRING;
            case SQLString.CHILD_IDS:
                return GET_CHILD_ID_STRING;
            case SQLString.TABLE_RESOURCE:
                return CREATE_RESOURCE_TABLE_STRING;
            case SQLString.TRIGGER_COMMON:
                return CREATE_TRIGGER_STRING;
            case SQLString.TRIGGER_CLOSURE:
                return CREATE_CLOSURE_TRIGGER_STRING;
            case SQLString.INDEX_COMMON:
                return CREATE_INDICES_STRING;
            case SQLString.SCHEMA:
                return SCHEMA_STRING;
            case SQLString.EXISTS_CACHE:
                return EXISTS_CACHE_STRING;
            case SQLString.TABLE_CLOSURE:
                return CREATE_CLOSURE_TABLE;
            case SQLString.STATISTICS:
                return STATISTICS_STRING;
            case SQLString.RESET_TOKEN:
                return RESET_TOKEN_STRING;
            case SQLString.MAX_UPDATE_ID:
                return MAX_UPDATE_ID_STRING;
            case SQLString.MAKE_GUARDED:
                return MAKE_GUARDED_STRING;
            case SQLString.IS_GUARDED:
                return IS_GUARDED_STRING;
            case SQLString.UPDATE_GUARDED_OBJECT:
                return UPDATE_GUARDED_OBJECT_STRING;
            case SQLString.TRIGGER_REFERENCE:
                return DELETE_REFERENCE_TRIGGER_STRING;
            default:
                assert_not_reached ();
        }
    }
}

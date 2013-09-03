/*
 * Copyright (C) 2010 Jens Georg <mail@jensge.org>.
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
using Gee;

internal class Rygel.ODID.MediaCacheUpgrader {
    private unowned Database database;
    private unowned SQLFactory sql;

    public MediaCacheUpgrader (Database database, SQLFactory sql) {
        this.database = database;
        this.sql = sql;
    }

    public bool needs_upgrade (out int current_version) throws Error {
        current_version = this.database.query_value (
                                        "SELECT version FROM schema_info");

        return current_version < int.parse (SQLFactory.SCHEMA_VERSION);
    }

    public void fix_schema () throws Error {
        var matching_schema_count = this.database.query_value (
                                        "SELECT count(*) FROM " +
                                        "sqlite_master WHERE sql " +
                                        "LIKE 'CREATE TABLE Meta_Data" +
                                        "%object_fk TEXT UNIQUE%'");
        if (matching_schema_count == 0) {
            try {
                message ("Found faulty schema, forcing full reindex");
                database.begin ();
                database.exec ("DELETE FROM Object WHERE upnp_id IN (" +
                               "SELECT DISTINCT object_fk FROM meta_data)");
                database.exec ("DROP TABLE Meta_Data");
                database.exec (this.sql.make (SQLString.TABLE_METADATA));
                database.commit ();
            } catch (Error error) {
                database.rollback ();
                warning ("Failed to force reindex to fix database: " +
                        error.message);
            }
        }
    }

    public void ensure_indices () {
        try {
            this.database.exec (this.sql.make (SQLString.INDEX_COMMON));
            this.database.analyze ();
        } catch (Error error) {
            warning ("Failed to create indices: " +
                     error.message);
        }
    }

    public void upgrade (int old_version) {
        debug ("Older schema detected. Upgrading...");
        int current_version = int.parse (SQLFactory.SCHEMA_VERSION);
        while (old_version < current_version) {
            if (this.database == null) {
                break;
            }

            switch (old_version) {
                default:
                    warning ("Cannot upgrade");
                    database = null;
                    break;
            }
            old_version++;
        }
    }

    public void force_reindex () throws DatabaseError {
        database.exec ("UPDATE Object SET timestamp = 0");
    }
}

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
                case 1:
                    update_v1_v2 ();
                    break;
                default:
                    warning ("Cannot upgrade");
                    database = null;
                    break;
            }
            old_version++;
        }
    }

    private void update_v1_v2 () {
        try {
            database.begin ();
            database.exec ("ALTER TABLE resource ADD COLUMN external_uri TEXT");
            database.exec ("UPDATE schema_info SET version = '2'");
            database.commit ();
        } catch (DatabaseError error) {
            database.rollback ();
            warning ("Database upgrade failed: %s", error.message);
            database = null;
        }
    }

    public void force_reindex () throws DatabaseError {
        database.exec ("UPDATE Object SET timestamp = 0");
    }
}

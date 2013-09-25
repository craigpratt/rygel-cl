/*
 * Copyright (C) 2011 Jens Georg <mail@jensge.org>.
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

using Sqlite;

internal class Rygel.ODID.SqliteWrapper : Object {
    private Sqlite.Database database = null;
    private Sqlite.Database *reference = null;

    /**
     * Property to access the wrapped database
     */
    protected unowned Sqlite.Database db {
        get { return reference; }
    }

    /**
     * Wrap an existing SQLite Database object.
     *
     * The SqliteWrapper doesn't take ownership of the passed db
     */
    public SqliteWrapper.wrap (Sqlite.Database db) {
        this.reference = db;
    }

    /**
     * Create or open a new SQLite database in path.
     *
     * @note: Path may also be ":memory:" for temporary databases
     */
    public SqliteWrapper (string path) throws DatabaseError {
        Sqlite.Database.open (path, out this.database);
        this.reference = this.database;
        this.throw_if_db_has_error ();
    }

    /**
     * Convert a SQLite return code to a DatabaseError
     */
    protected void throw_if_code_is_error (int sqlite_error)
                                           throws DatabaseError {
        switch (sqlite_error) {
            case Sqlite.OK:
            case Sqlite.DONE:
            case Sqlite.ROW:
                return;
            default:
                throw new DatabaseError.SQLITE_ERROR
                                        ("SQLite error %d: %s",
                                         sqlite_error,
                                         this.reference->errmsg ());
        }
    }

    /**
     * Check if the last operation on the database was an error
     */
    protected void throw_if_db_has_error () throws DatabaseError {
        this.throw_if_code_is_error (this.reference->errcode ());
    }
}

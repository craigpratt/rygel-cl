/*
 * Copyright (C) 2013 Intel Corporation.
 *
 * Author: Krzesimir Nowak <krnowak@openismus.com>
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
 * Author: Doug Galligan <doug@sentosatech.com>>
 */

public interface Rygel.ODID.UpdatableObject : Rygel.MediaObject {
    public async void non_overriding_commit () throws Error {
        yield this.commit_custom (false);
    }

    public abstract async void commit_custom (bool override_guarded)
                                              throws Error;
}

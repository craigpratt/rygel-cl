/*
 * Copyright (C) 2008 Zeeshan Ali <zeenix@gmail.com>.
 * Copyright (C) 2010 Nokia Corporation.
 *
 * Author: Zeeshan Ali (Khattak) <zeeshanak@gnome.org>
 *                               <zeeshan.ali@nokia.com>
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

/**
 * Interface to be implemented by 'writable' container: ones that allow
 * creation, removal and editing of items directly under them. Currently, only
 * addition is supported.
 *
 * In addition to implementing this interface, a writable container must also
 * provide one URI that points to a writable folder on a GIO supported
 * filesystem.
 */
public interface Rygel.WritableContainer : MediaContainer {
    // List of classes that an object in this container could be created of
    public abstract ArrayList<string> create_classes { get; set; }

    /**
     * Add a new item directly under this container.
     *
     * @param item The item to add to this container
     * @param cancellable optional cancellable for this operation
     *
     * return nothing.
     *
     */
    public async abstract void add_item (MediaItem    item,
                                         Cancellable? cancellable) throws Error;
}
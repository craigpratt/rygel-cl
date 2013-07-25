/*
 * Copyright (C) 2012 Openismus GmbH.
 * Copyright (C) 2012 Intel Corporation.
 * Copyright (C) 2013 Cablelabs.
 *
 * Author: Jens Georg <jensg@openismus.com>
 *         Cablelabs
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
 * Demo application for librygel-ruih.
 *
 * Creates a stand-alone UPnP ruih server
 *
 * Usage:
 *   standalone-ruih
 *
 * The server listens on wlan0 and eth0 by default.
 */

#include <gio/gio.h>
#include <rygel-ruih.h>
#include <rygel-core.h>

int main (int argc, char *argv[])
{
    RygelRuihServer *server;
    int i;
    GMainLoop *loop;
    GError *error = NULL;

    g_type_init ();

    g_set_application_name ("Standalone-Ruih");

    server = rygel_ruih_server_new ("RUIH sample server",
                                     RYGEL_PLUGIN_CAPABILITIES_NONE);
    rygel_media_device_add_interface (RYGEL_MEDIA_DEVICE (server), "eth0");
    rygel_media_device_add_interface (RYGEL_MEDIA_DEVICE (server), "wlan0");

    loop = g_main_loop_new (NULL, FALSE);
    g_main_loop_run (loop);
}

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

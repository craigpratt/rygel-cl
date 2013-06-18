/*
 * Copyright (C) 2013 cablelabs 
 *
 * Author: Cablelabs 
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

using GUPnP;
using Gee;

/**
 * Errors used by RemoteUIService and deriving classes.
 */
internal errordomain Rygel.RuihServiceError {
    NO_SUCH_OBJECT = 701,
    INVALID_CURRENT_TAG_VALUE = 702,
    INVALID_NEW_TAG_VALUE = 703,
    REQUIRED_TAG = 704,
    READ_ONLY_TAG = 705,
    PARAMETER_MISMATCH = 706,
    INVALID_SORT_CRITERIA = 709,
    RESTRICTED_OBJECT = 711,
    BAD_METADATA = 712,
    RESTRICTED_PARENT = 713,
    NO_SUCH_DESTINATION_RESOURCE = 718,
    CANT_PROCESS = 720,
    OUTDATED_OBJECT_METADATA = 728,
    INVALID_ARGS = 402
}

/**
 * Basic implementation of UPnP RemoteUIServer service version 1.
 */
internal class Rygel.RuihService: Service {
    public const string UPNP_ID = "urn:upnp-org:serviceId:RemoteUIServer";
    public const string UPNP_TYPE =
                    "urn:schemas-upnp-org:service:RemoteUIServer:1";
    public const string DESCRIPTION_PATH = "xml/RemoteUIServerService.xml";
    public const string UIISTING_PATH = BuildConfig.DATA_DIR + "/xml/UIList.xml";

    internal Cancellable cancellable;

    private UIListingManager uiMan; 

    public override void constructed () {
        base.constructed ();

        this.cancellable = new Cancellable ();

        this.uiMan = new UIListingManager(this, UIISTING_PATH);

        new Thread<int> ("UIListingManager thread", uiMan.run);

        this.root_device.resource_factory as RuihServerPlugin;

        this.query_variable["UIListingUpdate"].connect (
                                        this.query_uilisting);

        this.action_invoked["GetCompatibleUIs"].connect (this.getcompatibleuis_cb);

    }

    ~RuihService() {
        // Cancel all state machines
        this.cancellable.cancel ();
    }

    /* Browse action implementation */
    private void getcompatibleuis_cb (Service       content_dir,
                            ServiceAction action) {

    }

    private void query_uilisting(Service   ruih_service,
                                 string    variable,
                                 ref GLib.Value   value) {
        value.init (typeof (string));
        value.set_string ("");
    }


}

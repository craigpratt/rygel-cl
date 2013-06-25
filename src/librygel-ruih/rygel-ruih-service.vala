/*
 * Copyright (C) 2013 Cablelabs
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
    public const string DEVICEPROFILE_PATH = BuildConfig.DATA_DIR + "/xml/DeviceProfile.xml";

    internal Cancellable cancellable;

    private UIListingManager uiMan; 
    private RuihServiceManager ruiManager;

    public override void constructed () {
        base.constructed ();

        this.cancellable = new Cancellable ();

        this.uiMan = new UIListingManager(this, UIISTING_PATH);
        this.ruiManager = new RuihServiceManager();

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

        string xmlstr;
        xmlstr = this.uiMan.getUIListing (UIISTING_PATH);
        //No InputDeviceProfile or UIFilter entered, Return all possible UI's
        
        if (action.get_argument_count () == 0) {
            action.set ("UIListing", typeof (string), xmlstr);
            action.return ();
            return;
        }

        string inputDeviceProfile, inputUIFilter;
        action.get ("InputDeviceProfile", typeof (string), out inputDeviceProfile);
        action.get ("UIFilter", typeof (string), out inputUIFilter);
        
        try
        {
            var file = File.new_for_path (DEVICEPROFILE_PATH);
            // Create a new file with this name
            var file_stream = file.create (FileCreateFlags.NONE);

            // Write text data to file
            var data_stream = new DataOutputStream (file_stream);
            data_stream.put_string (inputDeviceProfile);
            ruiManager.setUIList(UIISTING_PATH);
            string compatUI = ruiManager.getCompatibleUIs(xmlstr, DEVICEPROFILE_PATH, inputUIFilter);

            // Bad Filter Argument provided
            if (compatUI.contains("Error"))
            {
                if (compatUI == "Error702")
                {
                    action.return_error(702, _("Invalid Filter Argument"));
                }

                // Bad Input Device Profile XML provided
                if (compatUI == "Error703")
                {
                    action.return_error(703, _("Bad InputDeviceProfile XML"));
                }
            }
            else
            {
                action.set ("UIListing", typeof (string), compatUI);
                file.trash();
                action.return ();
            }
        }
        catch (GLib.Error e)
        {
            debug("setUIList() threw an error %s, EXIT\n", e.message);
            return;
        }
    }

    private void query_uilisting(Service   ruih_service,
                                 string    variable,
                                 ref GLib.Value   value) {
        value.init (typeof (string));
        value.set_string ("");
    }

}

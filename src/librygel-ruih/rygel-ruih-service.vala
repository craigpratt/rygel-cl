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
 *
 * Author: Neha Shanbhag <N.Shanbhag@cablelabs.com>
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

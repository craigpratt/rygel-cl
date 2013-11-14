/*
 * Copyright (C) 2008 OpenedHand Ltd.
 * Copyright (C) 2009,2010,2011,2012 Nokia Corporation.
 * Copyright (C) 2012 Openismus GmbH
 * Copyright (C) 2012,2013 Intel Corporation.
 * Copyright (C) 2013  Cable Television Laboratories, Inc.
 *
 * Author: Jorn Baayen <jorn@openedhand.com>
 *         Zeeshan Ali (Khattak) <zeeshanak@gnome.org>
 *                               <zeeshan.ali@nokia.com>
 *         Jens Georg <jensg@openismus.com>
 *         Neha Shanbhag <N.Shanbhag@cablelabs.com>
 *         Sivakumar Mani <siva@orexel.com>
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

using Gst;
using GUPnP;
using Rygel.Renderer;
using Xml;

/**
 * Implementation of RygelMediaPlayer for GStreamer.
 *
 * This class is useful only when implementing Rygel plugins.
 */
public class Rygel.Playbin.Player : GLib.Object, Rygel.MediaPlayer {
    private const string TRANSFER_MODE_STREAMING = "Streaming";
    private const string TRANSFER_MODE_INTERACTIVE = "Interactive";
    private const string PROTOCOL_INFO_TEMPLATE = "http-get:%s:*:%s";

    private const string protocol_xpath  = "/supported-profiles/protocols";
    private const string media_collection_xpath  = "/supported-profiles/media-collection";
    private const string mimetype_xpath  = "/supported-profiles/mime-type";

    protected static string MIME_TYPE_NAME_PROPERTY   = "name";
    protected static const string DLNA_ORG_PN         = "DLNA.ORG_PN";
    protected static const string DLNA_ORG_OP         = "DLNA.ORG_OP";
    protected static const string DLNA_ORG_FLAGS      = "DLNA.ORG_FLAGS";
    protected static const string SUPPORT_PROFILE_LIST_PATH = BuildConfig.DATA_DIR + "/xml/profiles.xml";
    private string[] protocols = null;
    private string[] mime_types = null;

    private static Player player;

    private bool is_live;
    private bool foreign;
    private bool buffering;


    public dynamic Gst.Element playbin { get; private set; }

    protected void print_array(string[] arr)    {
        foreach(unowned string str in arr)
        {
            debug (" %s\n", str);
        }
    }

    protected void print_supported_profiles(GLib.List<DLNAProfile> supported_profs) {
        supported_profs.foreach ((entry) => {
                debug ("Mime: %s ", entry.mime);
                debug ("Name: %s ", entry.name);
                debug ("Operations: %s ", entry.operations);
                debug ("Flags: %s\n", entry.flags);
            });
    }

    private string _playback_state = "NO_MEDIA_PRESENT";
    public string playback_state {
        owned get {
            return this._playback_state;
        }

        set {
            Gst.State state, pending;

            this.playbin.get_state (out state, out pending, Gst.MSECOND);

            debug ("Changing playback state to %s.", value);

            switch (value) {
                case "STOPPED":
                    if (state != State.NULL || pending != State.VOID_PENDING) {
                        this._playback_state = "TRANSITIONING";
                        this.playbin.set_state (State.NULL);
                    } else {
                        this._playback_state = value;
                    }
                break;
                case "PAUSED_PLAYBACK":
                    if (state != State.PAUSED || pending != State.VOID_PENDING) {
                        this._playback_state = "TRANSITIONING";
                        this.playbin.set_state (State.PAUSED);
                    } else {
                        this._playback_state = value;
                    }
                break;
                case "PLAYING":
                    if (this._new_playback_speed != this._playback_speed &&
                        (state == State.PLAYING || state == State.PAUSED) &&
                        pending == State.VOID_PENDING) {
                        /* already playing, but play speed has changed */
                        this._playback_state = "TRANSITIONING";
                        this.seek (this.position);
                    } else if (state != State.PLAYING ||
                               pending != State.VOID_PENDING) {
                        // This needs a check if GStreamer and DLNA agree on
                        // the "liveness" of the source (s0/sn increase in
                        // protocol info)
                        this._playback_state = "TRANSITIONING";
                        this.is_live = this.playbin.set_state (State.PLAYING)
                                        == StateChangeReturn.NO_PREROLL;
                    } else {
                        this._playback_state = value;
                    }
                break;
                case "EOS":
                    this._playback_state = value;
                break;
                default:
                break;
            }
        }
    }

    private string[] _allowed_playback_speeds = {
        "1/16", "1/8", "1/4", "1/2", "1", "2", "4", "8", "16", "32", "64"
    };
    public string[] allowed_playback_speeds {
        owned get {
            return this._allowed_playback_speeds;
        }
    }

    /**
     * Actual _playback_speed is updated when playbin seek succeeds.
     * Until that point, the playback speed set via api is stored in
     * _new_playback_speed.
     **/
    private string _new_playback_speed = "1";

    private string _playback_speed = "1";
    public string playback_speed {
        owned get {
            return this._playback_speed;
        }

        set {
            this._new_playback_speed = value;
            /* theoretically we should trigger a seek here if we were
             * playing already, but playback state does get changed
             * after this when "Play" is invoked... */
        }
    }

    private string transfer_mode = null;

    private bool uri_update_hint = false;
    private string? _uri = null;
    public string? uri {
        owned get {
            return _uri;
        }

        set {
            this._uri = value;
            this.playbin.set_state (State.READY);
            this.playbin.uri = value;
            if (value != "") {
                switch (this._playback_state) {
                    case "NO_MEDIA_PRESENT":
                        this._playback_state = "STOPPED";
                        this.notify_property ("playback-state");
                        break;
                    case "STOPPED":
                        break;
                    case "PAUSED_PLAYBACK":
                        this.is_live = this.playbin.set_state (State.PAUSED)
                                        == StateChangeReturn.NO_PREROLL;
                        break;
                    case "EOS":
                    case "PLAYING":
                        // This needs a check if GStreamer and DLNA agree on
                        // the "liveness" of the source (s0/sn increase in
                        // protocol info)
                        this.is_live = this.playbin.set_state (State.PLAYING)
                                        == StateChangeReturn.NO_PREROLL;
                        break;
                    default:
                        break;
                }
            } else {
                this._playback_state = "NO_MEDIA_PRESENT";
                this.notify_property ("playback-state");
            }
            debug ("URI set to %s.", value);
        }
    }

    private string _mime_type = "";
    public string? mime_type {
        owned get {
            return this._mime_type;
        }

        set {
            this._mime_type = value;
        }
    }

    private string _metadata = "";
    public string? metadata {
        owned get {
            return this._metadata;
        }

        set {
            this._metadata = value;
        }
    }

    public bool can_seek {
        get {
            return this.transfer_mode != TRANSFER_MODE_INTERACTIVE &&
                   ! this.mime_type.has_prefix ("image/");
        }
    }

    public bool can_seek_bytes {
        get {
            return this.transfer_mode != TRANSFER_MODE_INTERACTIVE &&
                   ! this.mime_type.has_prefix ("image/");
        }
    }

    private string _content_features = "";
    private ProtocolInfo protocol_info;
    public string? content_features {
        owned get {
            return this._content_features;
        }

        set {
            var pi_string = PROTOCOL_INFO_TEMPLATE.printf (this.mime_type,
                                                           value);
            try {
                this.protocol_info = new ProtocolInfo.from_string (pi_string);
                var flags = this.protocol_info.dlna_flags;
                if (DLNAFlags.INTERACTIVE_TRANSFER_MODE in flags) {
                    this.transfer_mode = TRANSFER_MODE_INTERACTIVE;
                } else if (DLNAFlags.STREAMING_TRANSFER_MODE in flags) {
                    this.transfer_mode = TRANSFER_MODE_STREAMING;
                } else {
                    this.transfer_mode = null;
                }
            } catch (GLib.Error error) {
                this.protocol_info = null;
                this.transfer_mode = null;
            }
            this._content_features = value;
        }
    }

    public double volume {
        get {
            return this.playbin.volume;
        }

        set {
            this.playbin.volume = value;
            debug ("volume set to %f.", value);
        }
    }

    public int64 duration {
        get {
            int64 dur;

            if (this.playbin.query_duration (Format.TIME, out dur)) {
                return dur / Gst.USECOND;
            } else {
                return 0;
            }
        }
    }

    public int64 size {
        get {
            int64 dur;

            if (this.playbin.source.query_duration (Format.BYTES, out dur)) {
                return dur;
            } else {
                return 0;
            }
        }
    }

    public int64 position {
        get {
            int64 pos;

            if (this.playbin.query_position (Format.TIME, out pos)) {
                return pos / Gst.USECOND;
            } else {
                return 0;
            }
        }
    }

    public int64 byte_position {
       get {
            int64 pos;

            if (this.playbin.source.query_position (Format.BYTES, out pos)) {
                return pos;
            } else {
                return 0;
            }
        }
    }


    private void read_elements(Xml.XPath.Object* res, ref string[] read_elements)    {
        assert (res != null);
        assert (res->type == Xml.XPath.ObjectType.NODESET);
        assert (res->nodesetval != null);
        if (res->nodesetval->length () > 0)
        {
            read_elements = new string[res->nodesetval->length()];
            for (int i = 0; i < res->nodesetval->length (); i++) {
                Xml.Node* node = res->nodesetval->item (i);
                read_elements[i] = node->get_content ();
            }
        }
    }

    private void get_mime_attributes(Xml.XPath.Object* res, ref string[] mime_types_param, bool media_collection_flag)    {
        int num_of_mimes = res->nodesetval->length ();
        assert (res != null);
        assert (res->type == Xml.XPath.ObjectType.NODESET);
        assert (res->nodesetval != null);

        num_of_mimes = media_collection_flag == true ? res->nodesetval->length () + 1:num_of_mimes;

        if (num_of_mimes > 0)
        {
            int index = 0;
            mime_types_param = new string[num_of_mimes];
            if (media_collection_flag == true)
            {
                // add elements
                mime_types_param[0] = "text/xml";
                _supported_profiles.prepend (new DLNAProfile.extended
                                             ("DIDL_S",
                                              "text/xml",
                                              "",
                                              ""));
                index = 1;
            }

            for (int i = index; i < num_of_mimes; i++) {
                Xml.Node* node = null;
                if ( res->nodesetval != null && res->nodesetval->item(i) != null ) {
                    node = res->nodesetval->item(i);
                    string prop_value = node->get_prop(MIME_TYPE_NAME_PROPERTY);
                    if (prop_value == null)
                        break;

                    mime_types_param[i] = prop_value;

                    // Get the children for this node
                    for (Xml.Node* iter = node->children; iter != null; iter = iter->next) {
                        // Spaces between tags are also nodes, discard them
                        if (iter->type != ElementType.ELEMENT_NODE) {
                            continue;
                        }

                        string dlna_profile = iter->get_content();
                        if (dlna_profile != null)
                        {
                            string[] temp_str = dlna_profile.split (";", 0);
                            string dlna_org_pn = "", dlna_org_op = "", dlna_org_flags = "";

                            foreach (unowned string str in temp_str)
                            {
                                string[] key_value = str.split("=", 0);

                                switch (key_value[0])
                                {
                                case DLNA_ORG_PN:
                                    dlna_org_pn = key_value[1];
                                    break;
                                case DLNA_ORG_OP:
                                    dlna_org_op = key_value[1];
                                    break;
                                case DLNA_ORG_FLAGS:
                                    dlna_org_flags = key_value[1];
                                    break;
                                }
                            }

                            if (dlna_org_pn != null)
                            {
                                _supported_profiles.prepend (new DLNAProfile.extended
                                                             (dlna_org_pn,
                                                              prop_value ?? "",
                                                              dlna_org_op ?? "",
                                                              dlna_org_flags ?? ""));
                            }
                        }
                    }
                } else {
                    message ("failed to find the expected node");
                }
            }
        }
    }

    private void parse_file () {
        // Parse the document from path
        Xml.Doc* doc = Xml.Parser.parse_file (SUPPORT_PROFILE_LIST_PATH);
        if (doc == null) {
            error ("File %s not found or permissions missing\n", SUPPORT_PROFILE_LIST_PATH);
        }

        Xml.XPath.Context cntx = new Xml.XPath.Context (doc);
        if (cntx==null)
        {
            error ("failed to create the xpath context\n");
        }

        // Extract the protocol values
        Xml.XPath.Object* protocols_node = cntx.eval_expression (protocol_xpath);

        string[] temp_protocols = null;
        read_elements(protocols_node, ref temp_protocols);
		if (temp_protocols.length == 0)
		{
			error("No Protocols specified. Please add the info to the %s xml file\n", SUPPORT_PROFILE_LIST_PATH);
		}
	
        protocols = temp_protocols[0].split(",", 0);

        // Extract media-collection value
        Xml.XPath.Object* media_collection_node = cntx.eval_expression (media_collection_xpath);
        string[] media_collection_flagstr = null;
        bool media_collection_flag = false;

        read_elements(media_collection_node, ref media_collection_flagstr);
        media_collection_flag = bool.parse(media_collection_flagstr[0]);

        Xml.XPath.Object* mime_type_node = cntx.eval_expression (mimetype_xpath);
        string[] temp_mime_types = null;

        if (mime_type_node == null)
        {
            warning ("failed to evaluate xpath\n");
        }
        else
        {
            get_mime_attributes(mime_type_node, ref temp_mime_types, media_collection_flag);
            mime_types = temp_mime_types;
        }

        delete protocols_node;
        delete media_collection_node;
        delete mime_type_node;
        delete doc;

        // Do the parser cleanup to free the used memory
        Parser.cleanup ();
    }

    private Player () {
        this.playbin = ElementFactory.make ("playbin", null);
        this.foreign = false;
        this.setup_playbin ();
        this.parse_file();
    }

    public Player.wrap (Gst.Element playbin) {

        return_if_fail (playbin != null);
        return_if_fail (playbin.get_type ().name() == "GstPlayBin");

        this.playbin = playbin;
        this.foreign = true;
        this.setup_playbin ();
    }

    public static Player get_default () {
        if (player == null) {
            player = new Player ();
        }

        return player;
    }

    private bool seek_with_format (Format format, int64 target) {
        bool seeked;

        var speed = this.play_speed_to_double (this._new_playback_speed);
        if (speed > 0) {
            seeked = this.playbin.seek (speed,
                                        format,
                                        SeekFlags.FLUSH | SeekFlags.SKIP | SeekFlags.ACCURATE,
                                        Gst.SeekType.SET,
                                        target,
                                        Gst.SeekType.NONE,
                                        -1);
        } else {
            seeked = this.playbin.seek (speed,
                                        format,
                                        SeekFlags.FLUSH | SeekFlags.SKIP | SeekFlags.ACCURATE,
                                        Gst.SeekType.SET,
                                        0,
                                        Gst.SeekType.SET,
                                        target);
        }
        if (seeked) {
            this._playback_speed = this._new_playback_speed;
        }

        return seeked;
    }

    public bool seek (int64 time) {
        debug ("Seeking %lld usec, play speed %s", time, this._new_playback_speed);

        // Playbin doesn't return false when seeking beyond the end of the
        // file
        if (time > this.duration) {
            return false;
        }

        return this.seek_with_format (Format.TIME, time * Gst.USECOND);
    }

    public bool seek_bytes (int64 bytes) {
        debug ("Seeking %lld bytes, play speed %s", bytes, this._new_playback_speed);

        int64 size = this.size;
        if (size > 0 && bytes > size) {
            return false;
        }

        return this.seek_with_format (Format.BYTES, bytes);
    }

    public string[] get_protocols () {
        return protocols;
    }

    public string[] get_mime_types () {
        return mime_types;
    }

    private GLib.List<DLNAProfile> _supported_profiles;
    public unowned GLib.List<DLNAProfile> supported_profiles {
        get {
            this.print_supported_profiles (_supported_profiles);
            return _supported_profiles;
        }
    }

    private bool is_rendering_image () {
        dynamic Gst.Element typefind;

        typefind = (this.playbin as Gst.Bin).get_by_name ("typefind");
        Caps caps = typefind.caps;
        unowned Structure structure = caps.get_structure (0);

        return structure.get_name () == "image/jpeg" ||
               structure.get_name () == "image/png";
    }

    private void bus_handler (Gst.Bus bus,
                              Message message) {
        switch (message.type) {
        case MessageType.DURATION_CHANGED:
            if (this.playbin.query_duration (Format.TIME, null)) {
                this.notify_property ("duration");
            }
        break;
        case MessageType.STATE_CHANGED:
            if (message.src == this.playbin) {
                State old_state, new_state, pending;

                message.parse_state_changed (out old_state,
                                             out new_state,
                                             out pending);
                if (old_state == State.READY && new_state == State.PAUSED) {
                    if (this.uri_update_hint) {
                        this.uri_update_hint = false;
                        string uri = this.playbin.current_uri;
                        if (this._uri != uri && uri != "") {
                            // uri changed externally
                            this._uri = this.playbin.uri;
                            this.notify_property ("uri");
                            this.metadata = this.generate_basic_didl ();
                        }
                    }
                }

                if (pending == State.VOID_PENDING && !this.buffering) {
                    switch (new_state) {
                        case State.PAUSED:
                            this.playback_state = "PAUSED_PLAYBACK";
                            break;
                        case State.NULL:
                            this.playback_state = "STOPPED";
                            break;
                        case State.PLAYING:
                            this.playback_state = "PLAYING";
                            break;
                        default:
                            break;
                    }
                }

                if (old_state == State.PAUSED && new_state == State.PLAYING) {
                    this.buffering = false;
                    this.playback_state = "PLAYING";
                }
            }
            break;
        case MessageType.BUFFERING:
            // Assume the original application takes care of this.
            if (!(this.is_live || this.foreign)) {
                int percent;

                message.parse_buffering (out percent);

                if (percent < 100) {
                    this.buffering = true;
                    this.playbin.set_state (State.PAUSED);
                } else {
                    this.playbin.set_state (State.PLAYING);
                }
            }
            break;
        case MessageType.CLOCK_LOST:
            // Assume the original application takes care of this.
            if (!this.foreign) {
                this.playbin.set_state (State.PAUSED);
                this.playbin.set_state (State.PLAYING);
            }
            break;
        case MessageType.EOS:
            if (!this.is_rendering_image ()) {
                debug ("EOS");
                this.playback_state = "EOS";
            } else {
                debug ("Content is image, ignoring EOS");
            }

            break;
        case MessageType.ERROR:
            GLib.Error error;
            string debug_message;

            message.parse_error (out error, out debug_message);

            warning ("Error from GStreamer element %s: %s (%s)",
                     this.playbin.name,
                     error.message,
                     debug_message);
            warning ("Going to STOPPED state");

            this.playback_state = "STOPPED";

            break;
        }
    }

    private void on_source_setup (Gst.Element pipeline, dynamic Gst.Element source) {
        if (source.get_type ().name () == "GstSoupHTTPSrc" &&
            this.transfer_mode != null) {
            debug ("Setting transfer mode to %s", this.transfer_mode);

            var structure = new Structure.empty ("HTTPHeaders");
            structure.set_value ("transferMode.dlna.org", this.transfer_mode);

            source.extra_headers = structure;
        }
    }

    private void on_uri_notify (ParamSpec pspec) {
        this.uri_update_hint = true;
    }

    /**
     * Generate basic DIDLLite information.
     *
     * This is used when the URI gets changed externally. DLNA requires that a
     * minimum DIDLLite is always present if the URI is not empty.
     */
    private string generate_basic_didl () {
        var writer = new DIDLLiteWriter (null);
        var item = writer.add_item ();
        item.id = "1";
        item.parent_id = "-1";
        item.upnp_class = "object.item";
        var resource = item.add_resource ();
        resource.uri = this._uri;
        var file = File.new_for_uri (this.uri);
        item.title = file.get_basename ();

        return writer.get_string ();
    }

    private void setup_playbin () {
        // Needed to get "Stop" events from the playbin.
        // We can do this because we have a bus watch
        this.is_live = false;

        this.playbin.auto_flush_bus = false;
        assert (this.playbin != null);

        this.playbin.source_setup.connect (this.on_source_setup);
        this.playbin.notify["uri"].connect (this.on_uri_notify);

        // Bus handler
        var bus = this.playbin.get_bus ();
        bus.add_signal_watch ();
        bus.message.connect (this.bus_handler);
    }
}

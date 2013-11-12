/*
 * Copyright (C) 2008 OpenedHand Ltd.
 * Copyright (C) 2009,2010,2011,2012 Nokia Corporation.
 * Copyright (C) 2012 Openismus GmbH
 * Copyright (C) 2012,2013 Intel Corporation.
 *
 * Author: Jorn Baayen <jorn@openedhand.com>
 *         Zeeshan Ali (Khattak) <zeeshanak@gnome.org>
 *                               <zeeshan.ali@nokia.com>
 *         Jens Georg <jensg@openismus.com>
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
 *
 * Author: Neha Shanbhag <N.Shanbhag@cablelabs.com>
 * Author: Sivakumar Mani <siva@orexel.com>
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

	protected static string SUPPORTED_PROFILES        = "supported-profiles";
	protected static string PROTOCOLS                 = "protocols";
	protected static string MEDIA_COLLECTION          = "media-collection";
	protected static string MIME_TYPE                 = "mime-type";
	protected static string MIME_TYPE_NAME_PROPERTY   = "name";
//	protected static string DLNA_PROTOCOL_INFO        = "dlna-protocol-info";
	protected static const string DLNA_ORG_PN               = "DLNA.ORG_PN";
	protected static const string DLNA_ORG_OP               = "DLNA.ORG_OP";
	protected static const string DLNA_ORG_FLAGS            = "DLNA.ORG_FLAGS";
    protected static const string SUPPORT_PROFILE_LIST_PATH = BuildConfig.DATA_DIR + "/xml/profiles.xml";
	private string[] protocols;
	private string[] mime_types;

#if 0	
    private const string[] protocols = { "http-get", "rtsp" };
    private const string[] mime_types = {
                                        "audio/mpeg",
                                        "application/ogg",
                                        "audio/x-vorbis",
                                        "audio/x-vorbis+ogg",
                                        "audio/ogg",
                                        "audio/x-ms-wma",
                                        "audio/x-ms-asf",
                                        "audio/x-flac",
                                        "audio/x-flac+ogg",
                                        "audio/flac",
                                        "audio/mp4",
                                        "audio/3gpp",
                                        "audio/vnd.dlna.adts",
                                        "audio/x-mod",
                                        "audio/x-wav",
                                        "audio/x-ac3",
                                        "audio/x-m4a",
                                        "audio/l16;rate=44100;channels=2",
                                        "audio/l16;rate=44100;channels=1",
                                        "audio/l16;channels=2;rate=44100",
                                        "audio/l16;channels=1;rate=44100",
                                        "audio/l16;rate=44100",
                                        "image/jpeg",
                                        "image/png",
                                        "video/x-theora",
                                        "video/x-theora+ogg",
                                        "video/x-oggm",
                                        "video/ogg",
                                        "video/x-dirac",
                                        "video/x-wmv",
                                        "video/x-wma",
                                        "video/x-msvideo",
                                        "video/x-3ivx",
                                        "video/x-3ivx",
                                        "video/x-matroska",
                                        "video/x-mkv",
                                        "video/mpeg",
                                        "video/mp4",
                                        "application/x-shockwave-flash",
                                        "video/x-ms-asf",
                                        "video/x-xvid",
                                        "video/x-ms-wmv",
                                        "video/vnd.dlna.mpeg-tts",
                                        "application/x-dtcp1",

					 };
#endif
    private static Player player;
	
    private bool is_live;
    private bool foreign;
    private bool buffering;


    public dynamic Gst.Element playbin { get; private set; }

	protected void print_array(string[] arr)	{
		foreach(unowned string str in arr)
		{
			stdout.printf(" %s\n", str);
		}
	}

	protected void print_supported_profiles(GLib.List<DLNAProfile> supported_profs) {
		supported_profs.foreach ((entry) => {
				stdout.printf ("Mime: %s ", entry.mime);
				stdout.printf ("Name: %s ", entry.name);
				stdout.printf ("Operations: %s ", entry.operations);
				stdout.printf ("Flags: %s\n", entry.flags);
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
                    if (state != State.PLAYING ||
                        pending != State.VOID_PENDING) {
                        this._playback_state = "TRANSITIONING";
                        // This needs a check if GStreamer and DLNA agree on
                        // the "liveness" of the source (s0/sn increase in
                        // protocol info)
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

    private string[] _allowed_playback_speeds = {"-64", "-32", "-16", "-8", "-4", "-2", "-1", "1/2", "1", "2", "4", "8", "10", "16", "32", "64"};
    public string[] allowed_playback_speeds {
        owned get {
            return this._allowed_playback_speeds;
        }
    }

    private string _playback_speed = "1";
    public string playback_speed {
        owned get {
            return this._playback_speed;
        }

        set {
            this._playback_speed = value;
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

    public int64 position_byte {
       get {
            int64 pos;

            if (this.playbin.query_position (Format.BYTES, out pos)) {
                return pos;
            } else {
                return 0;
            }
        }
    }


	private void read_elements(Xml.XPath.Object* res, out string[] read_elements)	{
		assert (res != null);
		assert (res->type == Xml.XPath.ObjectType.NODESET);
		assert (res->nodesetval != null);
		read_elements = null;
		stdout.printf ("%d\n", res->nodesetval->length ());
		if (res->nodesetval->length () > 0)
		{
			read_elements = new string[res->nodesetval->length()];			
			for (int i = 0; i < res->nodesetval->length (); i++) {
				Xml.Node* node = res->nodesetval->item (i);
				read_elements[i] = node->get_content ();
				stdout.printf ("i:%d %s\n", i, read_elements[i]);
			}
		}
	}

	private void get_mime_attributes(Xml.XPath.Object* res, out string[] mime_types_param, bool media_collection_flag)	{
		int num_of_mimes = res->nodesetval->length ();
		assert (res != null);
		assert (res->type == Xml.XPath.ObjectType.NODESET);
		assert (res->nodesetval != null);

		mime_types_param = null;
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
											  "",
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

					print("Found the node we want with property:%s\n", mime_types_param[i]);
					
					// Get the children for this node
					for (Xml.Node* iter = node->children; iter != null; iter = iter->next) {
						// Spaces between tags are also nodes, discard them
						if (iter->type != ElementType.ELEMENT_NODE) {
							continue;
						}
						
//					print("Found the node we want with %s\n", iter->get_content());
						string dlna_profile = iter->get_content();
						if (dlna_profile != null)
						{
							string[] temp_str = dlna_profile.split (";", 0);
							string dlna_org_pn = "", dlna_org_op = "", dlna_org_flags = "";
							
							foreach (unowned string str in temp_str)
							{
								stdout.printf("%s\n", str);
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
					print("failed to find the expected node");
				}
			}
		}
	}

    private void parse_file () {
        // Parse the document from path
        Xml.Doc* doc = Xml.Parser.parse_file (SUPPORT_PROFILE_LIST_PATH);
        if (doc == null) {
            stderr.printf ("File %s not found or permissions missing\n", SUPPORT_PROFILE_LIST_PATH);
            return;
        }

		Xml.XPath.Context cntx = new Xml.XPath.Context (doc);	
		if (cntx==null) 
		{	
			print("failed to create the xpath context\n");
			return;
		}

		Xml.XPath.Object* protocols_node = cntx.eval_expression ("/" + SUPPORTED_PROFILES + "/" + PROTOCOLS);
		stdout.printf("\nPrinting Protocols\n");
		protocols = null;

		string[] temp_protocols = null; 
		read_elements(protocols_node, out temp_protocols);
		stdout.printf("Length: %s\n", temp_protocols[0]);
		protocols = temp_protocols[0].split(",", 0);
		foreach (unowned string str in protocols)
		{
			stdout.printf("%s\n", str);
		}

		Xml.XPath.Object* media_collection_node = cntx.eval_expression ("/" + SUPPORTED_PROFILES + "/" + MEDIA_COLLECTION);
		string[] media_collection_flagstr = null;
		bool media_collection_flag = false;

		stdout.printf("\nMediaCollection Flag\n");
		
		read_elements(media_collection_node, out media_collection_flagstr);
		stdout.printf("%s\n", media_collection_flagstr[0]);
		media_collection_flag = bool.parse(media_collection_flagstr[0]);

		if (media_collection_flag == true)
		{
			bool found_http_proto = false;
			// check if httpget is part of the protocols
			foreach(unowned string str in protocols) {
				if (str == "http-get") {
					found_http_proto = true;
				}
			}

			if (found_http_proto == false)
			{
				// we need to add http proto
				int index = 0;
				string[] temp_protos = new string[protocols.length + 1];
				foreach(unowned string str in protocols) {
					temp_protos[index++] = str;
				}
				temp_protos[index] = "http-get";
				protocols = temp_protos;
			}

		}
					

		Xml.XPath.Object* mime_type_node = cntx.eval_expression("/" + SUPPORTED_PROFILES + "/" + MIME_TYPE);
		string[] temp_mime_types = null; 
		mime_types = null;
		if (mime_type_node == null)
		{
			print("failed to evaluate xpath\n");
		}
		else
		{
			this.get_mime_attributes(mime_type_node, out temp_mime_types, media_collection_flag);
			mime_types = temp_mime_types;
			foreach(unowned string str in mime_types)
			{
				stdout.printf("STR %s\n", str);
			}
		}

		
		delete protocols_node;
		delete media_collection_node;
		delete mime_type_node;
		delete doc;

		// Do the parser cleanup to free the used memory
		Parser.cleanup ();

		// Parse the file listed in the first passed argument
		stdout.printf("\nProtocols\n");
		print_array(this.get_protocols());
		
		stdout.printf("\nMime_Types\n");
		this.print_array(this.get_mime_types());
		
		
		stdout.printf("\nDLNA Profiles\n");
		this.print_supported_profiles(this.supported_profiles);

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

    public bool seek (int64 time) {
        // Playbin doesn't return false when seeking beyond the end of the
        // file
        if (time > this.duration) {
            return false;
        }

        return this.playbin.seek (1.0,
                                  Format.TIME,
                                  SeekFlags.FLUSH,
                                  Gst.SeekType.SET,
                                  time * Gst.USECOND,
                                  Gst.SeekType.NONE,
                                  -1);
    }

    public bool seek_dlna (int64 target, string unit, double rate) {
   
	if(unit == "ABS_TIME" || unit == "REL_TIME"){
	debug("seek2() ABS_TIME or REL_TIME %lld", target);
		return this.playbin.seek (rate,
                                  Format.TIME,
                                  SeekFlags.FLUSH,
                                  Gst.SeekType.SET,
                                  target * Gst.USECOND, 
                                  Gst.SeekType.NONE,
                                  -1);

	}else if( unit == "ABS_COUNT" || unit == "REL_COUNT"){
	debug("seek2() ABS_COUNT or REL_COUNT %lld", target);
    		return this.playbin.seek (rate,
                                  Format.BYTES,
                                  SeekFlags.FLUSH,
                                  Gst.SeekType.SET,
                                  target,
                                  Gst.SeekType.NONE,
                                  -1);
	}else{
		warning("seek_dlna() wrong unit!!");
		return false;
	}

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
            if (_supported_profiles == null) {
                // FIXME: Check available decoders in registry and register
                // profiles after that
                _supported_profiles = new GLib.List<DLNAProfile> ();

                // Image
                _supported_profiles.prepend (new DLNAProfile ("JPEG_SM",
                                                              "image/jpeg"));
                _supported_profiles.prepend (new DLNAProfile ("JPEG_MED",
                                                              "image/jpeg"));
                _supported_profiles.prepend (new DLNAProfile ("JPEG_LRG",
                                                              "image/jpeg"));
                _supported_profiles.prepend (new DLNAProfile ("PNG_LRG",
                                                              "image/png"));
                 
                // Audio
                
                _supported_profiles.prepend (new DLNAProfile ("MP3",
                                                              "audio/mpeg"));
                _supported_profiles.prepend (new DLNAProfile ("MP3X",
                                                              "audio/mpeg"));
                _supported_profiles.prepend (new DLNAProfile
                                        ("AAC_ADTS_320",
                                         "audio/vnd.dlna.adts"));
                _supported_profiles.prepend (new DLNAProfile ("AAC_ISO_320",
                                                              "audio/mp4"));
                _supported_profiles.prepend (new DLNAProfile ("AAC_ISO_320",
                                                              "audio/3gpp"));
                _supported_profiles.prepend (new DLNAProfile
                                        ("LPCM",
                                         "audio/l16;rate=44100;channels=2"));
                _supported_profiles.prepend (new DLNAProfile
                                        ("LPCM",
                                         "audio/l16;rate=44100;channels=1"));
                _supported_profiles.prepend (new DLNAProfile ("WMABASE",
                                                              "audio/x-ms-wma"));
                _supported_profiles.prepend (new DLNAProfile ("WMAFULL",
                                                              "audio/x-ms-wma"));
                _supported_profiles.prepend (new DLNAProfile ("WMAPRO",
                                                              "audio/x-ms-wma"));
                 
                // Video
                
                _supported_profiles.prepend (new DLNAProfile
                                        ("MPEG_TS_SD_EU_ISO",
                                         "video/mpeg"));
                _supported_profiles.prepend (new DLNAProfile
                                        ("MPEG_TS_SD_NA_ISO",
                                         "video/mpeg"));
                _supported_profiles.prepend (new DLNAProfile
                                        ("MPEG_TS_HD_NA_ISO",
                                         "video/mpeg"));
                _supported_profiles.prepend (new DLNAProfile
                                        ("AVC_MP4_BL_CIF15_AAC_520",
                                         "video/mp4")); 

                _supported_profiles.prepend (new DLNAProfile.extended
                                        ("MPEG_TS_SD_EU_ISO",
                                         "video/mpeg",
                                         "01",
                                         "017000000000000000000000000000000000000"));
            }
			print("\nDLNA Profiles2\n");
			this.print_supported_profiles(_supported_profiles);

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

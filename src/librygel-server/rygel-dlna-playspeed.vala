/*
 * Copyright (C) 2013 CableLabs
 *
 * Author: Craig Pratt <craig@ecaspia.com>
 *
 * This file is part of Rygel.
 */

public errordomain Rygel.DLNAPlaySpeedError {
    INVALID_SPEED_FORMAT,
    SPEED_NOT_PRESENT
}

/**
 * PlaySpeed represents a DLNA PlaySpeed (PlaySpeed.dlna.org)
 *
 * A Playspeed can be positive or negative whole numbers or fractions.
 * e.g. "2". "1/2", "-1/4"
 */
public class Rygel.DLNAPlaySpeed : GLib.Object {
    public int numerator; // Sign of the speed will be attached to the numerator
    public uint denominator;
    public static const string PLAYSPEED_HEADER = "PlaySpeed.dlna.org";
    public static const string FRAMERATE_HEADER = "FrameRateInTrickMode.dlna.org";
    public static const int UNSPECIFIED_FRAMERATE = -1;
    /**
     * The framerate supported for the given rate, in frames per second
     */
    public int framerate;


    public DLNAPlaySpeed (int numerator, uint denominator) {
        this.numerator = numerator;
        this.denominator = denominator;
        this.framerate = UNSPECIFIED_FRAMERATE;
    }

    public DLNAPlaySpeed.from_string (string speed) throws DLNAPlaySpeedError {
        parse(speed);
        this.framerate = UNSPECIFIED_FRAMERATE;
    }

    internal DLNAPlaySpeed.from_request (Rygel.HTTPGet request) throws DLNAPlaySpeedError {
        // Format: PlaySpeed.dlna.org: speed=<rate>
        string speed_string = request.msg.request_headers.get_one (PLAYSPEED_HEADER);

        if (speed_string == null) {
            throw new DLNAPlaySpeedError.SPEED_NOT_PRESENT("Could not find header " + PLAYSPEED_HEADER);
        }
        
        var elements = speed_string.split("=");

        if ((elements.length != 2) || (elements[0] != "speed")) {
            throw new DLNAPlaySpeedError.INVALID_SPEED_FORMAT( "ill-formed value for "
                                                               + PLAYSPEED_HEADER + ": "
                                                               + speed_string );
        }
        
        parse(elements[1]);

        // Validate if playspeed is listed in the protocolInfo
        if (request.handler is HTTPMediaResourceHandler) {
            MediaResource resource = (request.handler as HTTPMediaResourceHandler)
                                              .media_resource;
            string[] speeds = resource.protocol_info.get_play_speeds();
            bool found_speed = false;
            foreach (var speed in speeds) {
                if (int.parse(speed) == numerator/denominator) {
                    found_speed = true;
                    break;
                }
            }

            if (!found_speed) {
                throw new DLNAPlaySpeedError.SPEED_NOT_PRESENT("Unknown playspeed requested.");
            }
        }
        this.framerate = UNSPECIFIED_FRAMERATE;
    }

    public bool equals(DLNAPlaySpeed that) {
        if (that == null) return false;

        return ( (this.numerator == that.numerator)
                 && (this.denominator == that.denominator) );
    }

    public bool is_positive() {
        return (this.denominator > 0);
    }

    public bool is_negative() {
        return (this.denominator < 0);
    }

    public string to_string() {
        if (this.denominator == 1) {
            return numerator.to_string();
        } else {
            return this.numerator.to_string() + "/" + this.denominator.to_string();
        }
    }

    public float to_float() {
        return (float)numerator/denominator;
    }

    public void parse(string speed) throws DLNAPlaySpeedError {
        if (! ("/" in speed)) {
            this.numerator = int.parse(speed);
            this.denominator = 1;
        } else {
            var elements = speed.split("/");
            if (elements.length != 2) {
                throw new DLNAPlaySpeedError.INVALID_SPEED_FORMAT("Missing/extra numerator/denominator");
            }
            this.numerator = int.parse(elements[0]);
            // Luckily, "0" isn't a valid numerator or denominator, as int.try_parse() is MIA
            if (this.numerator == 0) {
                throw new DLNAPlaySpeedError.INVALID_SPEED_FORMAT("Invalid numerator: " + elements[0]);
            }
            this.denominator = int.parse(elements[1]);

            if (this.denominator <= 0) {
                throw new DLNAPlaySpeedError.INVALID_SPEED_FORMAT("Invalid denominator: " + elements[1]);
            }
        }
    }

    /**
     * Set the framerate for the playspeed response.
     *
     * If the the framerate is set, a FrameRateInTrickMode response header will
     * be generated when add_response_headers() is called with the "rate=" field
     * set to the framerate.
     * 
     * @param framerate Framerate in frames per second
     */
    public void set_framerate(int framerate) {
        this.framerate = framerate;
    }

    /**
     * Unset the framerate for the playspeed response.
     *
     * If the the framerate is unset, a FrameRateInTrickMode response header will
     * not be generated when add_response_headers() is called.
     */
    public void unset_framerate() {
        this.framerate = UNSPECIFIED_FRAMERATE;
    }

    /**
     * Return true if the framerate is set.
     *
     * When true, a FrameRateInTrickMode response will be generated when add_response_headers()
     * is called with the "rate=" field set to the framerate.
     *
     * When false, a FrameRateInTrickMode response header will not be generated when
     * add_response_headers() is called..
     */
    public bool framerate_set() {
        return (this.framerate != UNSPECIFIED_FRAMERATE);
    }

    internal static bool requested (HTTPGet request) {
        return request.msg.request_headers.get_one (PLAYSPEED_HEADER) != null;
    }
    
    internal void add_response_headers (Rygel.HTTPRequest request) {
        // Format: PlaySpeed.dlna.org: speed=<rate>
        request.msg.response_headers.append (PLAYSPEED_HEADER, "speed=" + this.to_string());
        if (framerate_set()) {
            // Format: FrameRateInTrickMode.dlna.org: rate=<framerate>
            request.msg.response_headers.append ( FRAMERATE_HEADER,
                                                  "rate=" + this.framerate.to_string() );
        }
    }
}

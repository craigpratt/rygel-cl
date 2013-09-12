/*
 * Copyright (C) 2013 CableLabs
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
    public static const string HTTP_HEADER = "PlaySpeed.dlna.org";

    public DLNAPlaySpeed (int numerator, uint denominator) {
        this.numerator = numerator;
        this.denominator = denominator;
    }

    public DLNAPlaySpeed.from_string (string speed) throws DLNAPlaySpeedError {
        parse(speed);
    }

    internal DLNAPlaySpeed.from_request (Rygel.HTTPRequest request) throws DLNAPlaySpeedError {
        // Format: PlaySpeed.dlna.org: speed=<rate>
        string speed_string = request.msg.request_headers.get_one (HTTP_HEADER);

        if (speed_string == null) {
            throw new DLNAPlaySpeedError.SPEED_NOT_PRESENT("Could not find header " + HTTP_HEADER);
        }
        
        var elements = speed_string.split("=");

        if ((elements.length != 2) || (elements[0] != "speed")) {
            throw new DLNAPlaySpeedError.INVALID_SPEED_FORMAT( "ill-formed value for "
                                                               + HTTP_HEADER + ": "
                                                               + speed_string );
        }
        
        parse(elements[1]);
    }

    public bool equals(DLNAPlaySpeed that) {
        if (that == null) return false;

        return ( (this.numerator == that.numerator)
                 && (this.denominator == that.denominator) );
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

    internal static bool requested (HTTPGet request) {
        return request.msg.request_headers.get_one (HTTP_HEADER) != null;
    }
    
    internal void add_response_headers (Rygel.HTTPRequest request) {
        // Format: PlaySpeed.dlna.org: speed=<rate>
        request.msg.response_headers.append (HTTP_HEADER, "speed=" + this.to_string());
    }
}

/* 
 * Copyright (C) 2013  Cable Television Laboratories, Inc.
 * Contact: http://www.cablelabs.com/
 *
 * Rygel is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
 * IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL CABLE TELEVISION LABORATORIES
 * INC. OR ITS CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 * TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * Author: Craig Pratt <craig@ecaspia.com>
 *
 * This file is part of Rygel.
 */

public errordomain Rygel.DLNAPlaySpeedError {
    INVALID_SPEED_FORMAT,
    SPEED_NOT_PRESENT
}

public static const string PLAYSPEED_HEADER = "PlaySpeed.dlna.org";
public static const string FRAMERATE_HEADER = "FrameRateInTrickMode.dlna.org";

/**
 * This class represents a DLNA PlaySpeed request (PlaySpeed.dlna.org)
 *
 */
public class Rygel.DLNAPlaySpeedRequest : GLib.Object {
    public DLNAPlaySpeed speed { get; private set; }
    
    internal static bool requested (HTTPGet request) {
        return request.msg.request_headers.get_one (PLAYSPEED_HEADER) != null;
    }
    
    public DLNAPlaySpeedRequest (int numerator, uint denominator) {
        base();
        this.speed = new DLNAPlaySpeed(numerator, denominator);
    }

    public DLNAPlaySpeedRequest.from_string (string speed) throws DLNAPlaySpeedError {
        base();
        this.speed = new DLNAPlaySpeed.from_string(speed);
    }

    internal DLNAPlaySpeedRequest.from_request (Rygel.HTTPGet request) throws DLNAPlaySpeedError {
        base();
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

        speed = new DLNAPlaySpeed.from_string(elements[1]);

        // Normal rate is always valid. Just check for valid scaled rate
        if (!speed.is_normal_rate()) {
            // Validate if playspeed is listed in the protocolInfo
            if (request.handler is HTTPMediaResourceHandler) {
                MediaResource resource = (request.handler as HTTPMediaResourceHandler)
                                                  .media_resource;
                var speeds = resource.play_speeds;
                bool found_speed = false;
                foreach (var speed in speeds) {
                    var cur_speed = new DLNAPlaySpeedRequest.from_string (speed);
                    if (this.equals(cur_speed)) {
                        found_speed = true;
                        break;
                    }
                }
                if (!found_speed) {
                    throw new DLNAPlaySpeedError
                              .SPEED_NOT_PRESENT("Unknown playspeed requested (%s)", speed_string );
                }
            }
        }
    }

    public bool equals(DLNAPlaySpeedRequest that) {
        if (that == null) return false;

        return (this.speed.equals(that.speed));
    }
}

/**
 * This class represents a DLNA PlaySpeed response (PlaySpeed.dlna.org)
 */
public class Rygel.DLNAPlaySpeedResponse : Rygel.HTTPResponseElement {
    DLNAPlaySpeed speed;
    public static const int NO_FRAMERATE = -1;

    /**
     * The framerate supported for the given rate, in frames per second
     */
    public int framerate;

    public DLNAPlaySpeedResponse (int numerator, uint denominator, int framerate) {
        base();
        this.speed = new DLNAPlaySpeed(numerator, denominator);
        this.framerate = NO_FRAMERATE;
    }

    public DLNAPlaySpeedResponse.from_speed (DLNAPlaySpeed speed, int framerate)
       throws DLNAPlaySpeedError {
        base();
        this.speed = speed;
        this.framerate = framerate;
    }

    public DLNAPlaySpeedResponse.from_string (string speed, int framerate)
       throws DLNAPlaySpeedError {
        base();
        this.speed = new DLNAPlaySpeed.from_string(speed);
        this.framerate = NO_FRAMERATE;
    }

    public bool equals(DLNAPlaySpeedRequest that) {
        if (that == null) return false;

        return (this.speed.equals(that.speed));
    }

    public override void add_response_headers (Rygel.HTTPRequest request) {
        // Format: PlaySpeed.dlna.org: speed=<rate>
        request.msg.response_headers.append (PLAYSPEED_HEADER, "speed=" + speed.to_string());
        if (this.framerate > 0) {
            // Format: FrameRateInTrickMode.dlna.org: rate=<framerate>
            request.msg.response_headers.append ( FRAMERATE_HEADER,
                                                  "rate=" + this.framerate.to_string() );
        }
    }
}

/**
 * This is a container for a PlaySpeed value.
 * 
 * A Playspeed can be positive or negative whole numbers or fractions.
 * e.g. "2". "1/2", "-1/4"
 */
public class Rygel.DLNAPlaySpeed {
    public int numerator; // Sign of the speed will be attached to the numerator
    public uint denominator;
    
    public DLNAPlaySpeed (int numerator, uint denominator) {
        this.numerator = numerator;
        this.denominator = denominator;
    }

    public DLNAPlaySpeed.from_string (string speed) throws DLNAPlaySpeedError {
        parse(speed);
    }

    public bool equals(DLNAPlaySpeed that) {
        if (that == null) return false;

        return ( (this.numerator == that.numerator)
                 && (this.denominator == that.denominator) );
    }

    public bool is_positive() {
        return (this.numerator > 0);
    }

    public bool is_negative() {
        return (this.numerator < 0);
    }

    public bool is_normal_rate() {
        return (this.numerator == 1) && (this.denominator == 1);
    }

    public bool is_trick_rate() {
        return !is_normal_rate();
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

    private void parse(string speed) throws DLNAPlaySpeedError {
        if (! ("/" in speed)) {
            this.numerator = int.parse(speed);
            this.denominator = 1;
        } else {
            var elements = speed.split("/");
            if (elements.length != 2) {
                throw new DLNAPlaySpeedError.INVALID_SPEED_FORMAT("Missing/extra numerator/denominator");
            }
            this.numerator = int.parse(elements[0]);
            this.denominator = int.parse(elements[1]);
        }
        // "0" isn't a valid numerator or denominator (and parse returns "0" on parse error)
        if (this.numerator == 0) {
            throw new DLNAPlaySpeedError.INVALID_SPEED_FORMAT("Invalid numerator in speed: " + speed);
        }
        if (this.denominator <= 0) {
            throw new DLNAPlaySpeedError.INVALID_SPEED_FORMAT("Invalid denominator in speed: " + speed);
        }
    }
}


/* 
 * Copyright (C) 2013  Cable Television Laboratories, Inc.
 *
 * Author: Craig Pratt <craig@ecaspia.com>
 *
 * This file is part of Rygel.
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
 */

public static const string FRAMERATE_HEADER = "FrameRateInTrickMode.dlna.org";

/**
 * This class represents a DLNA PlaySpeed response (PlaySpeed.dlna.org)
 */
public class Rygel.PlaySpeedResponse : Rygel.HTTPResponseElement {
    PlaySpeed speed;
    public static const int NO_FRAMERATE = -1;

    /**
     * The framerate supported for the given rate, in frames per second
     */
    public int framerate;

    public PlaySpeedResponse (int numerator, uint denominator, int framerate) {
        base ();
        this.speed = new PlaySpeed (numerator, denominator);
        this.framerate = NO_FRAMERATE;
    }

    public PlaySpeedResponse.from_speed (PlaySpeed speed, int framerate)
       throws PlaySpeedError {
        base ();
        this.speed = speed;
        this.framerate = framerate;
    }

    public PlaySpeedResponse.from_string (string speed, int framerate)
       throws PlaySpeedError {
        base ();
        this.speed = new PlaySpeed.from_string (speed);
        this.framerate = NO_FRAMERATE;
    }

    public bool equals (PlaySpeedRequest that) {
        if (that == null) return false;

        return (this.speed.equals (that.speed));
    }

    public override void add_response_headers (Rygel.HTTPRequest request) {
        // Format: PlaySpeed.dlna.org: speed=<rate>
        request.msg.response_headers.append (PLAYSPEED_HEADER, "speed=" + this.speed.to_string ());
        if (this.framerate > 0) {
            // Format: FrameRateInTrickMode.dlna.org: rate=<framerate>
            request.msg.response_headers.append ( FRAMERATE_HEADER,
                                                  "rate=" + this.framerate.to_string () );
        }
    }

    public override string to_string () {
        return ("PlaySpeedResponse(speed=%s, framerate=%d)"
                .printf (this.speed.to_string (), this.framerate));
    }
}

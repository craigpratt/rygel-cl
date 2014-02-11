/*
 * Copyright (C) 2014  Cable Television Laboratories, Inc.
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

/**
 * This class models the live elements of a MediaResource.
 */
using GUPnP;

public errordomain Rygel.ODIDLiveSimulatorError {
    INVALID_STATE_ERROR
}

public class Rygel.ODIDLiveSimulator : Object {
    public string name;
    public string item_info_uri;
    public string resource_uri;
    public int64 live_start_time_us; // System time when "live" started (in microseconds)
    public int64 live_stop_time_us; // System time when "live" ended (in microseconds)
    public uint64 live_start_offset_us; // Start time offset (in microseconds)
    public bool started = false;
    public bool stopped = false;
    public int64 tsb_duration_us = -1; // -1: Unlimited, 0: None, >0: TSB duration (in microseconds)
    public int64 autostop_at_us = 0;
    public signal void started_signal ();
    public signal void stopped_signal ();
    public signal void reset_signal ();

    private uint report_timer_id = 0;
    private bool only_report_when_active = false;
    private uint autostop_timer_id = 0;
    private uint autoreset_timer_id = 0;
    private uint autoreset_timeout_ms = 0;
    private uint report_interval_ms = 0;
    private ODIDControlChannel control_channel;

    /**
     * Create a simulator with the given name, item info uri, resource uri, and (optional)
     * tsb duration. If the tsb duration is not given or <0, buffering is considered unlimited
     * (e.g. simulating an in-progress recording). If 0, the content will be considered
     * "strictly live" (no buffering). If >0, tsb_duration_s indicates the amount of buffered
     * content to be considered available.
     */
    public ODIDLiveSimulator (string name, string item_info_uri, string resource_uri)
         throws Error {
        this.name = name;
        this.item_info_uri = item_info_uri;
        this.resource_uri = resource_uri;
    }

    ~ODIDLiveSimulator () {
        this.stop_live ();
    }

    /**
     * Report the current content range for the live simulator (via message-level logging).
     *
     * The interval controls how often the range is queried/reported (in milliseconds)
     * If 0, reporting is disabled.
     *
     * If a control_channel is provided, reporting will be performed to the channel as
     * well as the log (if/when connected).
     */
    public void report_range (uint interval_ms, ODIDControlChannel ? control_channel = null) {
        if (this.report_timer_id != 0
           // Only cancel the timer if params are changed
             && ((interval_ms != this.report_interval_ms)
                 || (control_channel != this.control_channel))) {
            if (this.report_timer_id != 0) {
                debug ("sim %s: Canceling report timer", name);
                Source.remove (this.report_timer_id);
                this.report_timer_id = 0;
            }
        }
        if (interval_ms > 0) {
            debug ("sim %s: Scheduled report timer for %ums", name, interval_ms);
            this.report_timer_id = Timeout.add (interval_ms, on_report_range);
        }
        this.report_interval_ms = interval_ms;
        this.control_channel = control_channel;
        this.only_report_when_active = false;
    }

    /**
     * Report the current content range for the live simulator (via message-level logging)
     * when the simulator is "active" (started but not stopped).
     *
     * The interval controls how often the range is queried/reported (in milliseconds)
     * If 0, reporting is disabled.
     *
     * If a control_channel is provided, reporting will be performed to the channel as
     * well as the log (if/when connected).
     */
    public void report_range_when_active (uint interval_ms,
                                          ODIDControlChannel ? control_channel = null) {
        if (this.started && !this.stopped) {
            report_range (interval_ms, control_channel);
        } else { // Enable reporting when live is started
            this.report_interval_ms = interval_ms;
            this.control_channel = control_channel;
        }
        this.only_report_when_active = (interval_ms != 0);
    }

    // Called when the report timer expires
    private bool on_report_range () {
        int64 range_start, range_end;
        this.get_available_time_range (out range_start, out range_end);
        string report = "sim %s (%s): available time range: %0.3fs-%0.3fs"
                        .printf (name, get_state_string(),
                                 ODIDUtil.usec_to_secs (range_start),
                                 ODIDUtil.usec_to_secs (range_end));
        message (report); // Log it
        var cc = this.control_channel;
        if (cc != null) {
            cc.send_message (report);
        }

        bool do_repeat = (this.report_timer_id != 0)
                         && (!this.only_report_when_active
                             || (this.started && !this.stopped));
        return do_repeat;
    }

    /**
     * Start live
     *
     * The live_start_offset_us (in microseconds) allows simulation of the stream having
     * started before now (or being that amount of time into the live stream)
     *
     * autostop_at_us allows the live source to be stopped automatically at the given
     * media time (via stop_live()). If -1 or not provided, no automatic stop is enabled.
     * Note: autostop_at_us is not relative to live_time_offset_us. It's relative to the
     * live timeline ("0" representing the effective live start)
     *
     * start_live will throw an exception if the sim has already been started (and
     * hasn't been reset)
     */
    public void start_live ()
         throws Error {
        debug ("sim %s: start_live(live_offset %0.3f, stop_after %0.3f)",
               this.name, ODIDUtil.usec_to_secs (this.live_start_offset_us),
               ODIDUtil.usec_to_secs (this.autostop_at_us));
        if (this.started) {
            throw new ODIDLiveSimulatorError.INVALID_STATE_ERROR ("Already started %s (at %s)",
                                  this.name,
                                  ODIDUtil.system_time_to_string (this.live_start_time_us) );
        }
        if (this.stopped) {
            throw new ODIDLiveSimulatorError.INVALID_STATE_ERROR ("Already stopped %s (at %s)",
                                  this.name,
                                  ODIDUtil.system_time_to_string (this.live_stop_time_us) );
        }
        this.live_start_time_us = get_current_time_us () - (int64)this.live_start_offset_us;        
        // Essentially treat the stream as having started in the past (if/when
        //  a non-zero offset is provided)
        debug ("sim %s: start_live: started at %s (%lld)",
               this.name, ODIDUtil.system_time_to_string (this.live_start_time_us),
               this.live_start_time_us);
        debug ("sim %s: available time range: %0.3fs-%0.3fs", this.name,
               ODIDUtil.usec_to_secs (live_start_time_us),
               ODIDUtil.usec_to_secs (get_elapsed_live_time ()));
        if (this.autostop_at_us > 0) {
            // Schedule to stop automatically at the given media time
            uint timeout = (uint)(this.autostop_at_us - this.live_start_offset_us)/1000 - 1;
            debug ("sim %s: Setting an autostop timer to expire in %ums", this.name, timeout);
            autostop_timer_id = Timeout.add (timeout, on_autostop);
        }
        this.started = true;
        if (this.only_report_when_active) {
            report_range_when_active (this.report_interval_ms, this.control_channel);
        }
        started_signal ();
    }

    // Called when the stop timer expires
    private bool on_autostop () {
        debug ("sim %s: on_autostop()", this.name);
        stop_live ();
        return false; // Don't repeat - this is a one-shot
    }

    /**
     * Stop the live content
     *
     * Data can still be considered to exist. It's just no longer populating.
     *
     * The sim cannot be started without a reset ()
     */
    public void stop_live () {
        if (this.started && !this.stopped) {
            this.stopped = true;
            this.live_stop_time_us = get_current_time_us ();
            if (this.autostop_timer_id != 0) {
                Source.remove (this.autostop_timer_id);
                this.autostop_timer_id = 0;
            }
            if (this.autoreset_timeout_ms != 0) {
                set_autoreset ();
            }
            debug ("sim %s: stop_live: Stopped at %s (%lldus)",
                   this.name,
                   ODIDUtil.system_time_to_string (this.live_stop_time_us),
                   this.live_stop_time_us);
            stopped_signal ();
        }
    }

    /**
     * Reset the sim to pre-start state.
     *
     * Note: this will stop the sim if it's started
     */
    public void reset () {
        debug ("sim %s: Resetting", this.name);
        cancel_autoreset ();
        stop_live ();
        this.started = false;
        this.stopped = false;
        var cur_time = get_current_time_us ();
        debug ("sim %s: stop_live: Reset at %s (%lldus)",
               this.name, ODIDUtil.system_time_to_string (cur_time), cur_time);
        reset_signal ();
    }

    /**
     * Reset the sim after timeout_ms. This will restart the countdown on any pending autoreset.
     * If timeout_ms is 0, this call has the same effect as calling cancel_autoreset().
     * If timeout_ms is not specified, the last value passed to enable_autoreset() will be
     * used.
     */
    public void enable_autoreset (uint timeout_ms = uint.MAX) {
        if (timeout_ms != uint.MAX) {
            this.autoreset_timeout_ms = timeout_ms;
        }
        if (this.autoreset_timer_id != 0) {
            unset_autoreset ();
        }
        if (timeout_ms != 0) {
            if (this.started && this.stopped) {
                set_autoreset (); 
            } else { // Otherwise we'll set the autoreset on stop
                debug ("sim %s: Deferring autoreset timer until stopped", this.name);
            }
        }
    }

    /**
     * Cancel any scheduled autoreset
     */
    public void cancel_autoreset () {
        if (this.autoreset_timer_id != 0) {
            unset_autoreset ();
        }
    }

    private void set_autoreset () {
        if (this.autoreset_timeout_ms == 0) {
            warning ("sim %s: Not setting an autoreset timer (timeout==0)", this.name);
            return;
        }
        if (this.autoreset_timer_id != 0) {
            warning ("sim %s: Autoreset timer %u already set!", this.name, this.autoreset_timer_id);
            return;
        }
        this.autoreset_timer_id = Timeout.add (this.autoreset_timeout_ms, this.on_autoreset);
        debug ("sim %s: Set autoreset timer %u (%ums)", this.name, this.autoreset_timer_id,
                                                        this.autoreset_timeout_ms);
    }

    private void unset_autoreset () {
        if (this.autoreset_timer_id == 0) {
            warning ("sim %s: unset_autoreset: No autoreset timer to reset", this.name);
            return;
        }
        Source.remove (this.autoreset_timer_id);
        debug ("sim %s: Cancelled autoreset timer %u", this.name, this.autoreset_timer_id);
        this.autoreset_timer_id = 0;
    }

    // Called when the reset timer expires
    private bool on_autoreset () {
        debug ("sim %s: on_autoreset()", this.name);
        if (this.autoreset_timer_id != 0) {
            unset_autoreset ();
        }
        reset ();
        return false; // Don't repeat - this is a one-shot
    }

    /**
     * Get the start time for the available content range (in microseconds)
     */
    public int64 get_time_range_start () {
        if (this.tsb_duration_us >= 0) {
            return int64.max (0, get_elapsed_live_time () - this.tsb_duration_us);
        } else {
            return 0;
        }
    }

    /**
     * Get the end time for the available content range (in microseconds)
     */
    public int64 get_time_range_end () {
        return get_elapsed_live_time ();
    }

    /**
     * Get the available content range relative to the start of live (in microseconds)
     *
     * Note: this is functionally equivalent to get_time_range_start/end(), but is
     * slightly more accurate and efficient
     */
    public void get_available_time_range (out int64 range_start_us, out int64 range_end_us) {
        range_start_us = get_time_range_start ();
        range_end_us = get_elapsed_live_time ();
    }

    /**
     * Get the amount of content in the available range (in microseconds)
     */
    public int64 get_duration () {
        int64 range_start, range_end;
        this.get_available_time_range (out range_start, out range_end);
        return (range_end - range_start);
    }
      
    /**
     * Get the amount of time since live started (in microseconds)
     */
    public int64 get_elapsed_live_time () {
        if (this.stopped) {
            return (this.live_stop_time_us - this.live_start_time_us);
        } else if (this.started) {
            return (get_current_time_us () - this.live_start_time_us);
        } else {
            return (int64)this.live_start_offset_us;
        }
    }

    public enum State {INVALID=0, UNSTARTED, ACTIVE, STOPPED}

    public State get_state () {
        if (this.stopped) {
            return State.STOPPED;
        } else if (this.started) {
            return State.ACTIVE;
        } else {
            return State.UNSTARTED;
        }
    }

    public enum Mode {INVALID=0, S0_FIXED, S0_INCREASING, S0_EQUALS_SN}

    public Mode get_mode () {
        if (this.tsb_duration_us < 0) {
            return Mode.S0_FIXED;
        }
        if (this.tsb_duration_us == 0) {
            return Mode.S0_EQUALS_SN;
        }
        return Mode.S0_INCREASING;
    }

    public string get_state_string () {
        if (this.stopped) {
            return "stopped";
        } else if (this.started) {
            return "active";
        } else {
            return "unstarted";
        }
    }

    public string get_mode_string () {
        if (this.tsb_duration_us < 0) {
            return "S0_FIXED";
        }
        if (this.tsb_duration_us == 0) {
            return "S0==SN";
        }
        return "S0_INCREASING";
    }

    /**
     * Returns true of the sim mode/state implies a moving/movable S0 boundary
     */
    public bool is_s0_increasing () {
        return (!this.stopped && this.tsb_duration_us >= 0);
    }

    /**
     * Returns true of the sim mode/state implies a moving/movable Sn boundary
     */
    public bool is_sn_increasing () {
        return (!this.stopped);
    }

    /**
     * Returns true of the sim mode/state implies limited random access
     */
    public bool is_limited_random_access () {
        return (!this.stopped && (this.tsb_duration_us > 0));
    }

    /**
     * Returns true of the sim mode/state implies full random access
     */
    public bool is_full_random_access () {
        return ((this.tsb_duration_us < 0) // S0 fixed
                || ((this.tsb_duration_us > 0) && this.stopped) );
    }

    /**
     * Get the current system time (in microseconds)
     */
    public static int64 get_current_time_us () {
        // Note: Using get_real_time() for now for ease of debugging. But should
        //       switch to using get_monotonic_time() if/when we want to get serious
        //       about dealing with system clock changes
        return GLib.get_real_time ();
    }
}

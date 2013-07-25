/*
 * Copyright (C) 2013 CableLabs
 */
 
/*
 * Based on Rygel SimpleDataSource
 * Copyright (C) 2012 Intel Corporation.
 *
 */
 
/**
 * A simple data source for use with the CableLabs DLNA media engine.
 */
internal class Rygel.CableLabsDLNADataSource : DataSource, Object {
    private string uri;
    private Thread<void*> thread;
    private Mutex mutex = Mutex ();
    private Cond cond = Cond ();
    private uint64 first_byte = 0;
    private uint64 last_byte = 0;
    private bool frozen = false;
    private bool stop_thread = false;
    private HTTPSeek offsets = null;

    public CableLabsDLNADataSource(string uri) {
        message ("Creating a data source for URI %s", uri);
        this.uri = uri;
    }

    ~CableLabsDLNADataSource() {
        this.stop ();
        message ("Stopped data source");
    }

    public void start (HTTPSeek? offsets) throws Error {
        if (offsets != null) {
            if (offsets.seek_type == HTTPSeekType.TIME) {
                throw new DataSourceError.SEEK_FAILED
                                        (_("Time-based seek not supported"));

            }
        }

        this.offsets = offsets;

        message ("Starting data source for uri %s", this.uri);

        this.thread = new Thread<void*>("CableLabsDLNADataSource Serving thread",
                                         this.thread_func);
    }

    public void freeze () {
        if (this.frozen) {
            return;
        }

        this.mutex.lock();
        this.frozen = true;
        this.mutex.unlock ();
    }

    public void thaw() {
        if (!this.frozen) {
            return;
        }

        this.mutex.lock();
        this.frozen = false;
        this.cond.broadcast();
        this.mutex.unlock();
    }

    public void stop() 
    {
        if (this.stop_thread) 
        {
            return;
        }

        this.mutex.lock();
        this.frozen = false;
        this.stop_thread = true;
        this.cond.broadcast();
        this.mutex.unlock();
    }

    private void* thread_func() {
        var file = File.new_for_commandline_arg (this.uri);
        message ("Spawned new thread for streaming file %s", this.uri );
        try {
            var mapped = new MappedFile(file.get_path (), false);
            if (this.offsets != null) {
                this.first_byte = this.offsets.start;
                this.last_byte = this.offsets.stop + 1;
            } else {
                this.last_byte = mapped.get_length ();
            }

            while (true) {
                bool exit;
                this.mutex.lock ();
                while (this.frozen) {
                    this.cond.wait (this.mutex);
                }

                exit = this.stop_thread;
                this.mutex.unlock ();

                if (exit || this.first_byte == this.last_byte) {
                    message ("Done streaming!");
                    break;
                }

                var start = this.first_byte;
                var stop = start + uint16.MAX;
                if (stop > this.last_byte) {
                    stop = this.last_byte;
                }

                unowned uint8[] data = (uint8[]) mapped.get_contents ();
                data.length = (int) mapped.get_length ();
                uint8[] slice = data[start:stop];
                this.first_byte = stop;
                
                // message ( "Sending range %lld-%lld (%ld bytes of %ld)",
                //           start, stop, slice.length, data.length );

                // There's a potential race condition here.
                Idle.add ( () => {
                    if (!this.stop_thread) {
                        this.data_available (slice);
                    }

                    return false;
                });
            }
        } catch (Error error) {
            warning ("Failed to map file: %s", error.message);
        }

        // Signal that we're done streaming
        Idle.add ( () => { this.done (); return false; });

        return null;
    }
}

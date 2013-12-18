/*
 * Copyright (C) 2009 Jens Georg <mail@jensge.org>.
 * Copyright (C) 2013 Cable Television Laboratories, Inc.
 * 
 * Author: Jens Georg <mail@jensge.org>
 *         Doug Galligan <doug@sentosatech.com>
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

using GLib;
using Gee;

internal class FileQueueEntry {
    public File file;
    public bool known;
    public string content_type;

    public FileQueueEntry (File file, bool known, string content_type) {
        this.file = file;
        this.known = known;
        this.content_type = content_type;
    }
}

public class Rygel.ODID.HarvestingTask : Rygel.StateMachine,
                                                GLib.Object {
    public File origin;
    private MediaCache cache;
    private GLib.Queue<MediaContainer> containers;
    private Gee.Queue<FileQueueEntry> files;
    private RecursiveFileMonitor monitor;
    private MediaContainer parent;
    private const int BATCH_SIZE = 256;

    public Cancellable cancellable { get; set; }

    private const string HARVESTER_ATTRIBUTES =
                                        FileAttribute.STANDARD_NAME + "," +
                                        FileAttribute.STANDARD_TYPE + "," +
                                        FileAttribute.TIME_MODIFIED + "," +
                                        FileAttribute.STANDARD_CONTENT_TYPE + "," +
                                        FileAttribute.STANDARD_SIZE + "," +
                                        FileAttribute.STANDARD_IS_HIDDEN;

    public HarvestingTask (RecursiveFileMonitor monitor,
                           File                 file,
                           MediaContainer       parent) {
        this.origin = file;
        this.parent = parent;
        this.cache = MediaCache.get_default ();

        this.files = new LinkedList<FileQueueEntry> ();
        this.containers = new GLib.Queue<MediaContainer> ();
        this.monitor = monitor;
    }

    public void cancel () {
        // detach from common cancellable; otherwise everything would be
        // cancelled like file monitoring, other harvesters etc.
        this.cancellable = new Cancellable ();
        this.cancellable.cancel ();
    }

    /**
     * Extract all metainformation from a given file.
     *
     * What action will be taken depends on the arguments
     * * file is a simple file. Then only information of this
     *   file will be extracted
     * * file is a directory and recursive is false. The children
     *   of the directory (if not directories themselves) will be
     *   enqueued for extraction
     * * file is a directory and recursive is true. ++ All ++ children
     *   of the directory will be enqueued for extraction, even directories
     *
     * No matter how many children are contained within file's hierarchy,
     * only one event is sent when all the children are done.
     */
    public async void run () {
        try {
            var info = yield this.origin.query_info_async
                                        (HARVESTER_ATTRIBUTES,
                                         FileQueryInfoFlags.NONE,
                                         Priority.DEFAULT,
                                         this.cancellable);

            if (this.process_file (this.origin, info, this.parent)) {
                if (info.get_file_type () != FileType.DIRECTORY) {
                    this.containers.push_tail (this.parent);
                }
                this.on_idle ();
            } else {
                this.completed ();
            }
        } catch (Error error) {
            if (!(error is IOError.CANCELLED)) {
                warning (_("Failed to harvest file %s: %s"),
                         this.origin.get_uri (),
                         error.message);
            } else {
                debug ("Harvesting of uri %s was cancelled",
                       this.origin.get_uri ());
            }
            this.completed ();
        }
    }

    /**
     * Add a file to the meta-data extraction queue.
     *
     * The file will only be added to the queue if one of the following
     * conditions is met:
     *   - The file is not in the cache
     *   - The current mtime of the file is larger than the cached
     *   - The size has changed
     * @param file to check
     * @param info FileInfo of the file to check
     * @return true, if the file has been queued, false otherwise.
     */
    private bool push_if_changed_or_unknown (File       file,
                                             FileInfo   info) {
        int64 timestamp;
        int64 size;
        try {
            if (this.cache.exists (file, out timestamp, out size)) {
                int64 mtime = (int64) info.get_attribute_uint64
                                        (FileAttribute.TIME_MODIFIED);

                if (mtime > timestamp ||
                    info.get_size () != size) {
                    var entry = new FileQueueEntry (file,
                                                    true,
                                                    info.get_content_type ());
                    this.files.offer (entry);

                    return true;
                }
            } else {
                var entry = new FileQueueEntry (file,
                                                false,
                                                info.get_content_type ());
                this.files.offer (entry);

                return true;
            }
        } catch (Error error) {
            warning (_("Failed to query database: %s"), error.message);
        }

        return false;
    }

    private bool process_file (File           file,
                               FileInfo       info,
                               MediaContainer parent) {
        if (info.get_is_hidden ()) {
            return false;
        }

        if (info.get_file_type () == FileType.DIRECTORY) {
            // queue directory for processing later
            this.monitor.add.begin (file);

            var container = new DummyContainer (file, parent);
            this.containers.push_tail (container);

            // Only add new containers. There's not much about a container so
            // we skip the updated signal
            var dummy_parent = parent as DummyContainer;
            if (dummy_parent == null ||
                !dummy_parent.children.contains (MediaCache.get_id (file.get_uri ()))) {
                (parent as TrackableContainer).add_child_tracked.begin (container);
            }

            return true;
        } else {
            // Check if the file needs to be harvested at all either because
            // it is denied by filter or it hasn't updated
            if (Harvester.is_eligible (info)) {
                return this.push_if_changed_or_unknown (file, info);
            }

            return false;
        }
    }

    private bool process_children (GLib.List<FileInfo>? list) {
        if (list == null || this.cancellable.is_cancelled ()) {
            return false;
        }

        int count = 0;
        // Discover if this is an ODID directory, single .item file.
        foreach (var info in list) {
            if (info.get_name ().has_suffix (".item")) {
                count++;
            }
        }

        bool isOdidDirectory = count == 1 ? true : false;

        var container = this.containers.peek_head () as DummyContainer;

        foreach (var info in list) {
            var file = container.file.get_child (info.get_name ());
            // Skip processing ODID resource directories.
            if (!(isOdidDirectory && info.get_file_type () == FileType.DIRECTORY)   ) {
                this.process_file (file, info, container);
                container.seen (file);
            }
        }

        return true;
    }

    private async void enumerate_directory () {
        var directory = (this.containers.peek_head () as DummyContainer).file;
        try {
            var enumerator = yield directory.enumerate_children_async
                                        (HARVESTER_ATTRIBUTES,
                                         FileQueryInfoFlags.NONE,
                                         Priority.DEFAULT,
                                         this.cancellable);

            GLib.List<FileInfo> list = null;
            do {
                list = yield enumerator.next_files_async (BATCH_SIZE,
                                                          Priority.DEFAULT,
                                                          this.cancellable);
            } while (this.process_children (list));

            yield enumerator.close_async (Priority.DEFAULT, this.cancellable);
        } catch (Error err) {
            warning (_("failed to enumerate folder: %s"), err.message);
        }

        this.cleanup_database ();
        this.do_update ();
    }

    private void cleanup_database () {
        var container = this.containers.peek_head () as DummyContainer;

        // delete all children which are not in filesystem anymore
        try {
            foreach (var child in container.children) {
                this.cache.remove_by_id (child);
            }
        } catch (DatabaseError error) {
            warning (_("Failed to get children of container %s: %s"),
                     container.id,
                     error.message);
        }
    }

    private bool on_idle () {
        if (this.cancellable.is_cancelled ()) {
            this.completed ();

            return false;
        }

        if (!this.files.is_empty) {
            debug ("Scheduling file %s for meta-data extraction…",
                   this.files.peek ().file.get_uri ());

			if (this.files.peek ().file.get_basename ().has_suffix (".item")) {
				this.read_odid (this.files.peek ().file);
			}
			
        } else if (!this.containers.is_empty ()) {
            this.enumerate_directory.begin ();
        } else {
            // nothing to do
            this.completed ();
        }

        return false;
    }

    private void read_odid (File file) {
        if (this.cancellable.is_cancelled ()) {
            this.completed ();
        }

        KeyFile keyFile = new KeyFile ();
        try {
            keyFile.load_from_file (file.get_path (),
                                   KeyFileFlags.KEEP_COMMENTS |
                                   KeyFileFlags.KEEP_TRANSLATIONS);

            string id = MediaCache.get_id (file.get_uri ());

            MediaItem item = new Rygel.ODID.MediaItem
                                     (id, this.containers.peek_head (),
                                      keyFile.get_string ("item", "title"));

            if (keyFile.has_key ("item", "date"))    {
                item.date = keyFile.get_string ("item", "date");
            }

            if (keyFile.has_key ("item", "creator"))    {
                item.creator = keyFile.get_string ("item", "creator");
            }

            var media_engine = MediaEngine.get_default ( );

            // Note: Call async, since it can block for some time

            item.add_uri (file.get_uri ());

            media_engine.get_resources_for_item.begin ( item,
                                                        (obj, res) => {
                var engine_resources = media_engine.get_resources_for_item.end (res);
                debug ( "Received %s resources for %s",
                        ((engine_resources == null)
                         ? "NO" : engine_resources.size.to_string () ),
                        file.get_uri ().to_string () );
                item.get_resource_list ().add_all (engine_resources);

                if (item != null) {
                    item.parent_ref = this.containers.peek_head ();
                    // This is only necessary to generate the proper <objAdd LastChange entry
                    if (this.files.peek ().known) {
                        (item as UpdatableObject).non_overriding_commit.begin ();
                    } else {
                        var container = item.parent as TrackableContainer;
                        container.add_child_tracked.begin (item) ;
                    }
                }

                this.files.poll ();
                this.do_update ();
            }); 
        } catch (Error error) {
            warning ("Unable to read item file %s, Message: %s",
                     file.get_path (), error.message);
        }
    }

    /**
     * If all files of a container were processed, notify the container
     * about this and set the updating signal.
     * Reschedule the iteration and extraction
     */
    private void do_update () {
        if (this.files.is_empty &&
            !this.containers.is_empty ()) {
            this.containers.pop_head ();
        }

        this.on_idle ();
    }
}

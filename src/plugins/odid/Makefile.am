include $(top_srcdir)/common.am

plugin_LTLIBRARIES = librygel-odid.la
plugin_DATA = odid.plugin

librygel_odid_la_SOURCES = \
	rygel-odid-plugin.vala \
	rygel-odid-database.vala \
	rygel-odid-database-cursor.vala \
	rygel-odid-sqlite-wrapper.vala \
	rygel-odid-db-container.vala \
	rygel-odid-sql-factory.vala \
	rygel-odid-media-cache.vala \
	rygel-odid-sql-operator.vala \
	rygel-odid-sql-function.vala \
	rygel-odid-media-cache-upgrader.vala \
	rygel-odid-null-container.vala \
	rygel-odid-dummy-container.vala \
	rygel-odid-root-container.vala \
	rygel-odid-query-container.vala \
	rygel-odid-query-container-factory.vala \
	rygel-odid-node-query-container.vala \
	rygel-odid-leaf-query-container.vala \
	rygel-odid-recursive-file-monitor.vala \
	rygel-odid-harvester.vala \
	rygel-odid-harvesting-task.vala \
	rygel-odid-object-factory.vala \
	rygel-odid-writable-db-container.vala \
	rygel-odid-media-item.vala \
	rygel-odid-trackable-db-container.vala \
	rygel-odid-updatable-object.vala \
	rygel-odid-collate.c

librygel_odid_la_VALAFLAGS = \
	--enable-experimental \
	--internal-vapi rygel-odid.vapi \
	--internal-header rygel-odid-internal.h \
	--header rygel-odid.h \
	$(RYGEL_PLUGIN_ODID_DEPS_VALAFLAGS) \
	$(RYGEL_COMMON_LIBRYGEL_SERVER_VALAFLAGS) \
	$(RYGEL_COMMON_VALAFLAGS)

librygel_odid_la_CFLAGS = \
	$(RYGEL_PLUGIN_ODID_DEPS_CFLAGS) \
	$(RYGEL_COMMON_LIBRYGEL_SERVER_CFLAGS) \
	-DG_LOG_DOMAIN='"ODID"'
librygel_odid_la_LIBADD = \
	$(RYGEL_PLUGIN_ODID_DEPS_LIBS) \
	$(RYGEL_COMMON_LIBRYGEL_SERVER_LIBS)

librygel_odid_la_LDFLAGS = \
	$(RYGEL_PLUGIN_LINKER_FLAGS)

EXTRA_DIST = odid.plugin.in

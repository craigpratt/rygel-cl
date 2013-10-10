include $(top_srcdir)/common.am

engine_LTLIBRARIES = librygel-media-engine-odid.la
engine_DATA = media-engine-odid.plugin

librygel_media_engine_odid_la_SOURCES = \
	odid-media-engine.vala \
	odid-util.vala \
	odid-data-source.vala 

librygel_media_engine_odid_la_VALAFLAGS = \
	$(RYGEL_COMMON_LIBRYGEL_SERVER_VALAFLAGS) \
	$(RYGEL_COMMON_VALAFLAGS) \
	--pkg dtcpip

librygel_media_engine_odid_la_CFLAGS = \
	$(LIBRYGEL_SERVER_DEPS_CFLAGS) \
	$(RYGEL_COMMON_LIBRYGEL_SERVER_CFLAGS) \
	-DG_LOG_DOMAIN='"MediaEngine-ODID"'
librygel_media_engine_odid_la_LIBADD = \
	$(LIBRYGEL_SERVER_DEPS_LIBS) \
	$(RYGEL_COMMON_LIBRYGEL_SERVER_LIBS)
librygel_media_engine_odid_la_LDFLAGS = \
	$(RYGEL_PLUGIN_LINKER_FLAGS)

EXTRA_DIST = media-engine-odid.plugin.in


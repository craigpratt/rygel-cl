include $(top_srcdir)/common.am

engine_LTLIBRARIES = librygel-media-engine-cl-dlna.la
engine_DATA = media-engine-cl-dlna.plugin

librygel_media_engine_cl_dlna_la_SOURCES = \
	cl-dlna-media-engine.vala \
	cl-dlna-fake-transcoder.vala \
	cl-dlna-data-source.vala

librygel_media_engine_cl_dlna_la_VALAFLAGS = \
	$(RYGEL_COMMON_LIBRYGEL_SERVER_VALAFLAGS) \
	$(RYGEL_COMMON_VALAFLAGS)

librygel_media_engine_cl_dlna_la_CFLAGS = \
	$(LIBRYGEL_SERVER_DEPS_CFLAGS) \
	$(RYGEL_COMMON_LIBRYGEL_SERVER_CFLAGS) \
	-DG_LOG_DOMAIN='"MediaEngine-CL-DLNA"'
librygel_media_engine_cl_dlna_la_LIBADD = \
	$(LIBRYGEL_SERVER_DEPS_LIBS) \
	$(RYGEL_COMMON_LIBRYGEL_SERVER_LIBS)
librygel_media_engine_cl_dlna_la_LDFLAGS = \
	$(RYGEL_PLUGIN_LINKER_FLAGS)

EXTRA_DIST = media-engine-cl-dlna.plugin.in


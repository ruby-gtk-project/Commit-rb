# frozen_string_literal: true

require "gtk4"
require "adwaita"
require "gobject-introspection"

# GtkSourceView and libspelling have no Ruby gems, so their namespaces are
# loaded straight from the typelibs the dev shell puts on GI_TYPELIB_PATH.
module GtkSource; end
module Spelling; end

GObjectIntrospection::Loader.new(GtkSource).load("GtkSource")
GObjectIntrospection::Loader.new(Spelling).load("Spelling")

Adwaita.init
GtkSource.init

# What the desktop shows for the process, and what GLib puts in log messages.
GLib.application_name = "Commit"

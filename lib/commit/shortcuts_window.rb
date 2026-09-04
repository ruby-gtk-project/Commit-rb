# frozen_string_literal: true

require_relative "i18n"
require_relative "paths"

module Commit
  # The keyboard shortcuts window.
  #
  # Upstream builds this from a Blueprint file, and so does this — see
  # `data/shortcuts-window.ui`. It has to: the Ruby bindings cannot construct
  # a GtkShortcutsWindow directly. The generated constructor resolves to
  # GtkWindow's and raises, and the raw GObject one leaves the floating
  # references unsunk, which finalizes the children while they are still
  # parented. GtkBuilder gets it right.
  class ShortcutsWindow
    def initialize(application)
      @application = application
    end

    attr_reader :application

    def build
      window.tap do |win|
        win.transient_for = application.active_window
        win.application = application
      end
    end

    def present
      window.present
    end

    def builder
      @builder ||= Gtk::Builder.new.tap do |b|
        b.translation_domain = APPLICATION_ID
        b.add_from_file(Paths.shortcuts_window_ui)
      end
    end

    def window = @window ||= builder.get_object("window")
  end
end

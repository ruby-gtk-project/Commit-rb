# frozen_string_literal: true

require_relative "paths"

module Commit
  # The GtkSourceView the message is edited in, with the syntax definitions,
  # the Adwaita-matching colour scheme and the spell checker attached.
  class CommitEditor
    # The language definitions for git and mercurial comment blocks ship with
    # the app rather than with GtkSourceView, so the manager needs telling
    # where to look — once, for the whole process.
    def self.language_manager
      @language_manager ||= GtkSource::LanguageManager.new.tap do |manager|
        manager.search_path = manager.search_path + [Paths.language_specs_dir]
      end
    end

    def initialize(language:)
      @language = language
      @wrap_width_request = 0
    end

    attr_reader :language, :wrap_width_request

    def build
      scrolled_window.tap do |sw|
        sw.child = view

        view.tap do |v|
          v.buffer = buffer
          v.extra_menu = spelling_adapter.menu_model
          v.insert_action_group("spelling", spelling_adapter)
        end

        spelling_adapter.enabled = true

        # GtkSourceView flips wrapping in size_allocate, which the Ruby
        # bindings do not expose. The scrolled window's hadjustment tracks the
        # view's width just as closely, and notifies on every resize.
        sw.hadjustment.signal_connect("notify::page-size") { update_wrap_mode }

        style_manager.signal_connect("notify::dark") { update_style }
        update_style
      end
    end

    def wrap_width_request=(value)
      @wrap_width_request = value
      view.right_margin_position = value
      update_wrap_mode
    end

    # Once the window is wide enough to show a full line, wrapping stops
    # helping and starts hiding where the ruler actually falls.
    def wider_than_wrap_width_request?
      view.width >= ruler_position
    end

    def show_right_margin=(value)
      view.show_right_margin = value
    end

    def update_wrap_mode
      if wider_than_wrap_width_request?
        view.wrap_mode = :none
      else
        view.wrap_mode = :word
      end
    end

    def update_style
      if style_manager.dark?
        buffer.style_scheme = scheme_manager.get_scheme("Adwaita-dark")
      else
        buffer.style_scheme = scheme_manager.get_scheme("Adwaita")
      end
    end

    # https://gitlab.gnome.org/GNOME/gtksourceview/-/blob/main/gtksourceview/gtksourceview.c
    def ruler_position
      (character_width * wrap_width_request) + view.left_margin
    end

    def character_width = view.create_pango_layout("_").pixel_size.first

    def style_manager = Adwaita::StyleManager.default
    def scheme_manager = GtkSource::StyleSchemeManager.default
    def spelling_checker = Spelling::Checker.default

    def spelling_adapter
      @spelling_adapter ||= Spelling::TextBufferAdapter.new(buffer, spelling_checker)
    end

    def scrolled_window
      @scrolled_window ||= Gtk::ScrolledWindow.new.tap do |sw|
        sw.vexpand = true
      end
    end

    def view
      @view ||= GtkSource::View.new.tap do |v|
        v.monospace = true
        v.show_right_margin = true
        v.wrap_mode = :word
        v.tab_width = 2
        v.insert_spaces_instead_of_tabs = true
        v.top_margin = 12
        v.left_margin = 12
        v.right_margin = 12
        v.bottom_margin = 12
        v.input_hints = Gtk::InputHints::SPELLCHECK |
                        Gtk::InputHints::WORD_COMPLETION |
                        Gtk::InputHints::EMOJI |
                        Gtk::InputHints::UPPERCASE_SENTENCES
      end
    end

    def buffer
      @buffer ||= GtkSource::Buffer.new(nil).tap do |b|
        b.enable_undo = true
        b.language = self.class.language_manager.get_language(language)
      end
    end
  end
end

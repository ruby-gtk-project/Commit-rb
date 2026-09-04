# frozen_string_literal: true

require_relative "about"
require_relative "dev"
require_relative "paths"
require_relative "settings"
require_relative "shortcuts_window"
require_relative "welcome"
require_relative "window"

module Commit
  # Commit is launched twice over: by git, with the message file as its only
  # argument, and by the user, with none — which is what the welcome window
  # is for. Both can be open at once, hence NON_UNIQUE.
  class Application
    def initialize
      @readonly = false
    end

    # Kept so tests (and anything else outside) have a handle on the windows
    # this opened; the app itself never needs them again.
    attr_reader :readonly, :editor_window, :welcome_window, :shortcuts_window

    def build
      application.tap do |app|
        app.add_main_option(
          "readonly",
          0,
          GLib::OptionFlags::NONE,
          GLib::OptionArg::NONE,
          "Prevent Commit from making changes - useful for testing",
          nil,
        )

        app.signal_connect("handle-local-options") { |_app, options| on_handle_local_options(options) }
        app.signal_connect("startup") { on_startup }
        app.signal_connect("activate") { open_welcome }
        app.signal_connect("open") { |_app, files, _hint| on_open(files) }

        app.add_action(about_action)
        app.add_action(shortcuts_action)
        app.add_action(color_scheme_action)

        about_action.signal_connect("activate") { open_about }
        shortcuts_action.signal_connect("activate") { open_shortcuts }

        app.set_accels_for_action("app.shortcuts", ["<Control>question"])
        app.set_accels_for_action("win.cancel", ["Escape"])
        app.set_accels_for_action("win.save", ["<Control>Return", "<Control>KP_Enter"])

        Settings.settings.signal_connect("changed::color-scheme") { apply_color_scheme }

        if Dev.enabled?
          app.add_action(restart_action)
          restart_action.signal_connect("activate") { restart }
          app.set_accels_for_action("app.restart", ["<Control><Shift>Q"])
        end
      end
    end

    def run(argv)
      @argv = argv
      application.run(argv)
    end

    # Quit and come straight back, so a code change can be picked up without
    # leaving the window behind.
    def restart
      application.quit
      Process.spawn(*@argv)
    end

    def application
      @application ||= Gtk::Application.new(
        APPLICATION_ID,
        Gio::ApplicationFlags::HANDLES_OPEN | Gio::ApplicationFlags::NON_UNIQUE,
      )
    end

    # -1 keeps the command line going; anything else would be an exit code.
    def on_handle_local_options(options)
      if options.contains?("readonly")
        @readonly = true
      end

      -1
    end

    def on_startup
      # Both windows read the gitconfig-backed preferences as they build, so
      # they have to be loaded before either one exists.
      Settings.load
      apply_color_scheme
      load_style
      register_icons
    end

    # git hands us exactly one file. Anything else is a person running the
    # app by hand.
    def on_open(files)
      if files.length == 1
        open_editor(files.first.path)
      else
        open_welcome
      end
    end

    def open_editor(path)
      read(path).then do |text|
        if text
          Window.new(
            application: application,
            path:        path,
            text:        text,
            type:        Scm.type_for(path),
            readonly:    readonly,
          ).tap do |window|
            @editor_window = window
            window.build
            window.present
          end
        end
      end
    end

    def read(path)
      File.read(path)
    rescue SystemCallError => e
      warn("Could not read #{path}: #{e.message}")
      application.quit
      nil
    end

    def open_welcome
      # Quit only makes sense on the welcome window: closing the editor
      # without answering would leave git waiting.
      application.add_action(quit_action)
      quit_action.signal_connect("activate") { application.quit }
      application.set_accels_for_action("app.quit", ["<Control>Q"])

      Welcome.new(application).tap do |welcome|
        @welcome_window = welcome
        welcome.build
        welcome.present
      end
    end

    def open_about
      About.new.tap do |about|
        about.build
        about.present(application.active_window)
      end
    end

    def open_shortcuts
      ShortcutsWindow.new(application).tap do |shortcuts|
        @shortcuts_window = shortcuts
        shortcuts.build
        shortcuts.present
      end
    end

    def apply_color_scheme
      Adwaita::StyleManager.default.color_scheme = Settings.settings.get_int("color-scheme")
    end

    def load_style
      Gtk::CssProvider.new.tap do |provider|
        provider.load_from_path(Paths.style_css)
        Gtk::StyleContext.add_provider_for_display(
          Gdk::Display.default,
          provider,
          Gtk::StyleProvider::PRIORITY_APPLICATION,
        )
      end
    end

    # Running from a checkout there is no installed icon, so point the theme
    # at the one in data/.
    def register_icons
      Gtk::IconTheme.get_for_display(Gdk::Display.default).add_search_path(Paths.icons_dir)
    end

    def about_action = @about_action ||= Gio::SimpleAction.new("about")
    def shortcuts_action = @shortcuts_action ||= Gio::SimpleAction.new("shortcuts")
    def quit_action = @quit_action ||= Gio::SimpleAction.new("quit")
    def restart_action = @restart_action ||= Gio::SimpleAction.new("restart")
    def color_scheme_action = @color_scheme_action ||= Settings.settings.create_action("color-scheme")
  end
end

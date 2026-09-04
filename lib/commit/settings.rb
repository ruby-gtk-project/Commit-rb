# frozen_string_literal: true

require_relative "paths"

module Commit
  TITLE_LENGTH_HINT = "title-length-hint"
  BODY_LENGTH_WRAP = "body-length-wrap"
  AUTO_CAPITALIZE_TITLE = "auto-capitalize-title"

  MIN_TITLE_LENGTH_HINT = 50
  MIN_BODY_LENGTH_WRAP = 50
  MAX_TITLE_LENGTH_HINT = 2_147_483_647
  MAX_BODY_LENGTH_WRAP = 2_147_483_647

  DEFAULT_TITLE_LENGTH_HINT = 50
  DEFAULT_BODY_LENGTH_WRAP = 72
  DEFAULT_AUTO_CAPITALIZE_TITLE = true

  # Commit keeps its per-repository preferences in the repository's own
  # .gitconfig and its global ones in the user's, both under a
  # `[re.sonny.Commit]` section — so they travel with the checkout and can be
  # committed like any other project setting.
  class Config
    GROUP = "re.sonny.Commit"

    attr_accessor :title_length_hint, :body_length_wrap, :auto_capitalize_title
    attr_reader :path

    def initialize(path)
      @path = path
      @key_file = GLib::KeyFile.new
    end

    # `fallback` is what a key that is not in this file resolves to: the
    # global config for the local one, and the GSettings defaults for the
    # global one.
    def load(fallback)
      read

      @title_length_hint = integer(TITLE_LENGTH_HINT) || fallback[:title_length_hint]
      @body_length_wrap = integer(BODY_LENGTH_WRAP) || fallback[:body_length_wrap]
      @auto_capitalize_title = boolean(AUTO_CAPITALIZE_TITLE)
      if @auto_capitalize_title.nil?
        @auto_capitalize_title = fallback[:auto_capitalize_title]
      end
    end

    def save
      # Re-read first: the file may have changed under us, and everything in
      # it that is not ours has to survive the write.
      read

      @key_file.set_integer(GROUP, TITLE_LENGTH_HINT, title_length_hint)
      @key_file.set_integer(GROUP, BODY_LENGTH_WRAP, body_length_wrap)
      @key_file.set_boolean(GROUP, AUTO_CAPITALIZE_TITLE, auto_capitalize_title)

      File.write(path, @key_file.to_data)
    end

    def to_h
      {
        title_length_hint:     title_length_hint,
        body_length_wrap:      body_length_wrap,
        auto_capitalize_title: auto_capitalize_title,
      }
    end

      private

        def read
          @key_file.load_from_file(path, GLib::KeyFile::KEEP_COMMENTS | GLib::KeyFile::KEEP_TRANSLATIONS)
        rescue GLib::FileError
          # No config file yet — every key falls back.
          nil
        rescue GLib::KeyFileError
          # A .gitconfig git accepts but GKeyFile does not. Leave it alone.
          nil
        end

        def integer(key)
          @key_file.get_integer(GROUP, key)
        rescue GLib::KeyFileError
          nil
        end

        def boolean(key)
          @key_file.get_boolean(GROUP, key)
        rescue GLib::KeyFileError
          nil
        end
  end

  # The GSettings the app itself owns: the two lengths (as the last-resort
  # defaults behind the gitconfig ones) and the theme choice.
  module Settings
    module_function

    def settings
      @settings ||= Gio::Settings.new(APPLICATION_ID, path: "#{RESOURCE_PATH}/")
    end

    def defaults
      {
        title_length_hint:     settings.get_int(TITLE_LENGTH_HINT),
        body_length_wrap:      settings.get_int(BODY_LENGTH_WRAP),
        auto_capitalize_title: DEFAULT_AUTO_CAPITALIZE_TITLE,
      }
    end

    # https://git-scm.com/docs/git-config#FILES
    def global_gitconfig_path
      File.join(host_config_home, "git", "config").then do |xdg_path|
        if File.file?(xdg_path)
          xdg_path
        else
          File.join(Dir.home, ".gitconfig")
        end
      end
    end

    def local_gitconfig_path = File.join(Dir.pwd, ".gitconfig")

    # Under Flatpak, XDG_CONFIG_HOME points inside the sandbox, but the
    # gitconfig we want to read is the host's.
    def host_config_home
      if sandboxed?
        ENV["HOST_XDG_CONFIG_HOME"] || File.join(Dir.home, ".config")
      else
        ENV["XDG_CONFIG_HOME"] || File.join(Dir.home, ".config")
      end
    end

    def sandboxed? = File.exist?("/.flatpak-info")

    def global = @global ||= Config.new(global_gitconfig_path)

    def local = @local ||= Config.new(local_gitconfig_path)

    # The local config's fallback is the global one, so the global has to be
    # loaded first and reloaded whenever the local is.
    def load
      global.load(defaults)
      local.load(global.to_h)
    end
  end
end

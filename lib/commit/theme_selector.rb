# frozen_string_literal: true

require_relative "i18n"
require_relative "paths"

module Commit
  # The light / dark / follow-system control at the top of the main menu.
  #
  # The three check buttons are a radio group wired to the app.color-scheme
  # action; their targets are Adwaita::ColorScheme values, which is what the
  # GSettings key stores. The widgets come from `data/theme-selector.ui`
  # because that is the only way to give them accessible labels — the Ruby
  # bindings raise NotImplementedError on gtk_accessible_update_property.
  class ThemeSelector
    DEFAULT = 0
    FORCE_LIGHT = 1
    FORCE_DARK = 4

    def build
      bin.tap do |b|
        style_manager.tap do |manager|
          manager.signal_connect("notify::system-supports-color-schemes") { update_follow_visibility }
          manager.signal_connect("notify::dark") { update_dark_class }
        end

        update_follow_visibility
        update_dark_class
      end
    end

    # Following the system is not an option on a desktop that has no
    # preference to follow.
    def update_follow_visibility
      follow_button.visible = style_manager.system_supports_color_schemes?
    end

    # The swatches are drawn against the popover's background, which changes
    # with the theme.
    def update_dark_class
      if style_manager.dark?
        bin.add_css_class("dark")
      else
        bin.remove_css_class("dark")
      end
    end

    def style_manager = Adwaita::StyleManager.default

    def builder
      @builder ||= Gtk::Builder.new.tap do |b|
        # AdwBin has to be registered before the builder can resolve it.
        Adwaita::Bin.gtype
        b.translation_domain = APPLICATION_ID
        b.add_from_file(Paths.theme_selector_ui)
      end
    end

    def bin
      @bin ||= builder.get_object("theme_selector").tap do |b|
        b.add_css_class("themeselector")
      end
    end

    def follow_button = @follow_button ||= builder.get_object("follow")
    def light_button = @light_button ||= builder.get_object("light")
    def dark_button = @dark_button ||= builder.get_object("dark")
  end
end

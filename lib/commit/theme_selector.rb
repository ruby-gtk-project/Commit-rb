# frozen_string_literal: true

require_relative "i18n"

module Commit
  # The light / dark / follow-system control at the top of the main menu.
  #
  # The three check buttons are a radio group wired to the app.color-scheme
  # action; their targets are Adwaita::ColorScheme values, which is what the
  # GSettings key stores.
  class ThemeSelector
    include Translations

    DEFAULT = 0
    FORCE_LIGHT = 1
    FORCE_DARK = 4

    def build
      bin.tap do |b|
        b.child = box

        box.tap do |bx|
          bx.append(follow_button)
          bx.append(light_button)
          bx.append(dark_button)

          light_button.set_group(follow_button)
          dark_button.set_group(follow_button)
        end

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

    def bin
      @bin ||= Adwaita::Bin.new.tap do |b|
        b.hexpand = true
        b.add_css_class("themeselector")
      end
    end

    def box
      @box ||= Gtk::Box.new(:horizontal, 12).tap do |b|
        b.hexpand = true
      end
    end

    def follow_button = @follow_button ||= swatch("follow", DEFAULT, _("Follow system style"))
    def light_button = @light_button ||= swatch("light", FORCE_LIGHT, _("Light style"))
    def dark_button = @dark_button ||= swatch("dark", FORCE_DARK, _("Dark style"))

    def swatch(name, color_scheme, tooltip)
      Gtk::CheckButton.new.tap do |button|
        button.add_css_class("theme-selector")
        button.add_css_class(name)
        button.hexpand = true
        button.halign = :center
        button.focus_on_click = false
        button.tooltip_text = tooltip
        button.action_name = "app.color-scheme"
        # An unwrapped Ruby value would be dropped here without a warning.
        button.action_target = GLib::Variant.new(color_scheme, "i")
      end
    end
  end
end

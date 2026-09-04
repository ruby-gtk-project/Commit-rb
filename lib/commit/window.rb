# frozen_string_literal: true

require_relative "editor"
require_relative "i18n"
require_relative "preferences"
require_relative "scm"
require_relative "settings"
require_relative "theme_selector"

module Commit
  # The editor window git and mercurial actually launch: the message, an
  # Abort and a confirm button, and the menu in the bottom right.
  class Window
    include Translations

    def initialize(application:, path:, text:, type:, readonly:)
      @application = application
      @path = path
      @text = text
      @type = type
      @readonly = readonly
      @has_changes = false
    end

    attr_reader :application, :path, :type, :readonly
    # Kept only so the dialog can be reached from outside once it is open.
    attr_reader :preferences

    def parsed
      @parsed ||= Scm.parse(@text, type)
    rescue StandardError
      # A message shape we do not recognise is still editable as plain text.
      Scm.parse("", type)
    end

    def build
      window.tap do |win|
        win.content = toolbar_view
        win.title = title

        toolbar_view.tap do |tv|
          tv.add_top_bar(header_bar)
          tv.content = overlay

          header_bar.pack_start(abort_button)
          header_bar.pack_end(save_button)
        end

        overlay.tap do |o|
          o.add_overlay(menu_button)

          menu_button.popover.add_child(theme_selector.build, "themeswitcher")
          # The floating button needs room to breathe over the text.
          menu_button.first_child.first_child.tap do |margin_box|
            margin_box.margin_top = 10
            margin_box.margin_bottom = 10
            margin_box.margin_start = 10
            margin_box.margin_end = 10
          end
        end

        save_button.label = _(parsed[:action])

        editor.build
        buffer.signal_connect("changed") { @has_changes = true }

        win.add_action(cancel_action)
        win.add_action(save_action)
        application.add_action(preferences_action)

        cancel_action.signal_connect("activate") { on_cancel }
        save_action.signal_connect("activate") { on_save }
        preferences_action.signal_connect("activate") { open_preferences }

        # https://github.com/sonnyp/Commit/issues/33
        win.set_focus(view)
      end
    end

    def present
      window.present
    end

    def title
      File.basename(Dir.pwd).then do |basename|
        if parsed[:detail]
          "#{basename} (#{parsed[:detail]})"
        else
          basename
        end
      end
    end

    def buffer = editor.buffer
    def view = editor.view

    def open_preferences
      Preferences.new(on_close: -> { editor.update }).tap do |preferences|
        @preferences = preferences
        preferences.build
        preferences.present(window)
      end
    end

    # Confirming writes the message back to the file git handed us and quits;
    # git takes it from there.
    def on_save
      buffer.text.then do |text|
        if !Scm.empty_commit_message?(text, parsed[:comment_prefix])
          Settings.load
          write(formatted(text))
          application.quit
        end
      end
    end

    # Reflowing a message the user is reading at full width would move text
    # around under them, so it only happens when the ruler is off screen.
    def formatted(text)
      if parsed[:is_message] && !editor.wider_than_wrap_width_request?
        Scm.format(text, Settings.local.body_length_wrap, parsed[:comment_prefix])
      else
        text
      end
    end

    # Aborting means handing git back an empty file, which it treats as
    # "cancel". A config file is not a message, so there is nothing to empty.
    def on_cancel
      if save_on_abort?
        confirm_discard { write("") && application.quit }
      else
        application.quit
      end
    end

    def save_on_abort? = !type.nil? && type != "config"

    def confirm_discard
      if confirm_on_discard?
        discard_dialog.tap do |dialog|
          dialog.choose(window, nil) do |_source, result|
            if dialog.choose_finish(result) == "discard"
              yield
            end
          end
        end
      else
        yield
      end
    end

    # Only worth asking about a commit message the user has actually typed
    # something into.
    def confirm_on_discard?
      @has_changes && type == "commit" && !buffer.text.strip.empty?
    end

    def write(value)
      if readonly
        true
      else
        File.write(path, value)
        true
      end
    rescue SystemCallError => e
      warn("Could not write #{path}: #{e.message}")
      true
    end

    def editor
      @editor ||= Editor.new(overlay: overlay, save_button: save_button, parsed: parsed)
    end

    def theme_selector = @theme_selector ||= ThemeSelector.new

    def window
      @window ||= Adwaita::ApplicationWindow.new(application).tap do |win|
        win.set_default_size(654, 272)
      end
    end

    def toolbar_view
      @toolbar_view ||= Adwaita::ToolbarView.new.tap do |tv|
        # Because of the right margin.
        tv.top_bar_style = Adwaita::ToolbarStyle::RAISED
      end
    end

    def header_bar
      @header_bar ||= Adwaita::HeaderBar.new.tap do |bar|
        bar.show_start_title_buttons = false
        bar.show_end_title_buttons = false
      end
    end

    def abort_button
      @abort_button ||= Gtk::Button.new.tap do |button|
        button.label = _("_Abort")
        button.use_underline = true
        button.action_name = "win.cancel"
        button.tooltip_text = _("Cancel and Dismiss")
      end
    end

    def save_button
      @save_button ||= Gtk::Button.new.tap do |button|
        button.use_underline = true
        button.sensitive = false
        button.action_name = "win.save"
        button.tooltip_text = _("Save and Confirm")
        button.add_css_class("suggested-action")
      end
    end

    def overlay = @overlay ||= Gtk::Overlay.new

    def menu_button
      @menu_button ||= Gtk::MenuButton.new.tap do |button|
        button.primary = true
        button.icon_name = "open-menu-symbolic"
        button.menu_model = menu_model
        button.tooltip_text = _("Main Menu")
        button.halign = :end
        button.valign = :end
        button.margin_end = 12
        button.margin_bottom = 12
        button.add_css_class("circular")
      end
    end

    def menu_model
      @menu_model ||= Gio::Menu.new.tap do |menu|
        menu.append_section(nil, primary_section)
        menu.append_section(nil, secondary_section)
      end
    end

    def primary_section
      @primary_section ||= Gio::Menu.new.tap do |section|
        section.append_item(theme_selector_item)
        section.append(_("Preferences"), "app.preferences")
      end
    end

    def secondary_section
      @secondary_section ||= Gio::Menu.new.tap do |section|
        section.append(_("Keyboard Shortcuts"), "app.shortcuts")
        section.append(_("About Commit"), "app.about")
      end
    end

    # A menu item whose content is a widget the popover is told about by name.
    def theme_selector_item
      @theme_selector_item ||= Gio::MenuItem.new.tap do |item|
        item.set_attribute_value("custom", GLib::Variant.new("themeswitcher"))
      end
    end

    def discard_dialog
      @discard_dialog ||= Adwaita::AlertDialog.new.tap do |dialog|
        dialog.heading = _("Discard changes?")
        dialog.close_response = "cancel"
        dialog.add_response("cancel", _("Cancel"))
        dialog.add_response("discard", _("Discard"))
        dialog.set_response_appearance("discard", Adwaita::ResponseAppearance::DESTRUCTIVE)
        dialog.default_response = "discard"
      end
    end

    def cancel_action = @cancel_action ||= Gio::SimpleAction.new("cancel")
    def save_action = @save_action ||= Gio::SimpleAction.new("save")
    def preferences_action = @preferences_action ||= Gio::SimpleAction.new("preferences")
  end
end

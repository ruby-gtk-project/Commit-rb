# frozen_string_literal: true

require_relative "i18n"
require_relative "preference_rows"

module Commit
  # What you get when Commit is launched on its own rather than by git: the
  # global preferences, and the two commands that make it your editor.
  class Welcome
    include Translations

    GIT_DOCUMENTATION =
      "https://git-scm.com/book/en/v2/Customizing-Git-Git-Configuration#_core_editor"
    MERCURIAL_DOCUMENTATION = "https://www.mercurial-scm.org/wiki/editor"

    def initialize(application)
      @application = application
    end

    attr_reader :application

    def build
      window.tap do |win|
        win.content = toolbar_view

        toolbar_view.tap do |tv|
          tv.add_top_bar(header_bar)
          tv.content = page

          header_bar.pack_start(about_button)
        end

        page.tap do |p|
          p.add(preferences_group)
          p.add(git_group)
          p.add(mercurial_group)

          rows.add_to(preferences_group)

          git_group.add(git_box)
          git_box.tap do |box|
            box.append(git_label)
            box.append(git_buttons)

            git_buttons.tap do |buttons|
              buttons.append(git_copy_button)
              buttons.append(git_documentation_button)
            end
          end

          mercurial_group.add(mercurial_box)
          mercurial_box.tap do |box|
            box.append(mercurial_label)
            box.append(mercurial_buttons)

            mercurial_buttons.tap do |buttons|
              buttons.append(mercurial_copy_button)
              buttons.append(mercurial_documentation_button)
            end
          end
        end

        rows.load
        fill_commands

        git_copy_button.signal_connect("clicked") { copy(git_label) }
        mercurial_copy_button.signal_connect("clicked") { copy(mercurial_label) }

        # There is no explicit save: the rows are written back when the app
        # goes away, exactly as upstream does it.
        application.signal_connect("shutdown") { rows.save }
      end
    end

    def present
      window.present
    end

    def fill_commands
      command.then do |cmd|
        git_label.label = %(<tt>git config --global core.editor "#{cmd}"</tt>)
        mercurial_label.label = "<tt>[ui]\neditor=#{cmd}</tt>"
      end
    end

    def copy(label)
      label.clipboard.set(label.text)
    end

    # What the user has to put in their config to reach this very binary.
    def command
      ENV["FLATPAK_ID"].then do |flatpak_id|
        if flatpak_id
          "flatpak run #{flatpak_id}"
        else
          invocation_command
        end
      end
    end

    def invocation_command
      if $PROGRAM_NAME == File.basename($PROGRAM_NAME)
        # On PATH already.
        $PROGRAM_NAME
      else
        File.expand_path($PROGRAM_NAME, Dir.pwd)
      end
    end

    def rows = @rows ||= PreferenceRows.new(Settings.global)

    def window
      @window ||= Adwaita::ApplicationWindow.new(application).tap do |win|
        win.title = "Commit"
        win.set_default_size(560, 640)
      end
    end

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new
    def header_bar = @header_bar ||= Adwaita::HeaderBar.new

    def about_button
      @about_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = "help-about-symbolic"
        button.tooltip_text = _("About Commit")
        button.action_name = "app.about"
      end
    end

    def page
      @page ||= Adwaita::PreferencesPage.new.tap do |p|
        p.vexpand = true
      end
    end

    def preferences_group
      @preferences_group ||= Adwaita::PreferencesGroup.new.tap do |group|
        group.title = _("Global Preferences")
      end
    end

    def git_group
      @git_group ||= Adwaita::PreferencesGroup.new.tap do |group|
        group.title = _("Git")
        group.description = _("To set Commit as default editor for Git run the following command")
      end
    end

    def mercurial_group
      @mercurial_group ||= Adwaita::PreferencesGroup.new.tap do |group|
        group.title = _("Mercurial")
        group.description =
          _("To set Commit as default editor for Mercurial, set the following in your <tt>hgrc</tt>")
      end
    end

    def git_box = @git_box ||= Gtk::Box.new(:vertical, 12)
    def mercurial_box = @mercurial_box ||= Gtk::Box.new(:vertical, 12)
    def git_buttons = @git_buttons ||= Gtk::Box.new(:horizontal, 6)
    def mercurial_buttons = @mercurial_buttons ||= Gtk::Box.new(:horizontal, 6)

    def git_label = @git_label ||= command_label
    def mercurial_label = @mercurial_label ||= command_label

    def command_label
      Gtk::Label.new.tap do |label|
        label.use_markup = true
        label.wrap = true
        label.selectable = true
        label.xalign = 0
        label.add_css_class("code")
        label.add_css_class("view")
        label.add_css_class("frame")
      end
    end

    def git_copy_button = @git_copy_button ||= Gtk::Button.new(label: _("Copy to Clipboard"))

    def mercurial_copy_button
      @mercurial_copy_button ||= Gtk::Button.new(label: _("Copy to Clipboard"))
    end

    def git_documentation_button
      @git_documentation_button ||= documentation_button(_(GIT_DOCUMENTATION))
    end

    def mercurial_documentation_button
      @mercurial_documentation_button ||= documentation_button(_(MERCURIAL_DOCUMENTATION))
    end

    def documentation_button(uri)
      Gtk::LinkButton.new(uri).tap do |button|
        button.label = _("Documentation")
      end
    end
  end
end

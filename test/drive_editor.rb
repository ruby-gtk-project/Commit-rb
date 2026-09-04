# frozen_string_literal: true

# Drives the editor window: opens a real COMMIT_EDITMSG, pokes the buffer and
# the actions, and screenshots what comes out.
#
#   env -u DISPLAY -u WAYLAND_DISPLAY bundle exec ruby test/drive_editor.rb

require "tmpdir"
require "fileutils"

require_relative "gtk_driver"

FIXTURES = File.expand_path("fixtures", __dir__)
SHOTS = File.expand_path("../tmp/shots", __dir__)

# Commit writes its preferences into the repository's .gitconfig and the
# user's, so a test run has to be given a home and a working directory of its
# own or it edits the real ones.
HOME = Dir.mktmpdir("commit-home")
REPOSITORY = Dir.mktmpdir("commit-repo")
ENV["HOME"] = HOME
ENV["XDG_CONFIG_HOME"] = File.join(HOME, ".config")
Dir.chdir(REPOSITORY)

MESSAGE_PATH = File.join(REPOSITORY, "COMMIT_EDITMSG")
FileUtils.cp(File.join(FIXTURES, "with-body/COMMIT_EDITMSG"), MESSAGE_PATH)

require_relative "../lib/commit"

ThemeSelectorDark = Commit::ThemeSelector::FORCE_DARK

app_object = Commit::Application.new

GtkDriver.drive(app_object, shots: SHOTS) do |d, app|
  d.window { app.editor_window&.window }

  d.step("the welcome window opens on activate") do
    d.check("welcome window is there") { app.welcome_window }
  end

  d.step("open a commit message") do
    # Open the editor before closing the welcome window: losing the last
    # window would take the application down with it.
    app.open_editor(MESSAGE_PATH)
    app.welcome_window.window.close
  end

  d.step("the message is loaded") do
    app.editor_window.then do |window|
      d.check("title shows the branch") { window.window.title.end_with?("(main)") }
      d.check("confirm button says Commit") { window.save_button.label == "_Commit" }
      d.check("confirm button is sensitive") { window.save_button.sensitive? }
      d.check("body is in the buffer") do
        window.buffer.text.start_with?("Do something great with this commit message")
      end
      d.check("comment block is in the buffer") { window.buffer.text.include?("# On branch main") }
      d.shot("01-editor")
    end
  end

  d.step("the comment block is read-only") do
    app.editor_window.buffer.then do |buffer|
      comment_offset = buffer.text.index("# Please enter")
      d.check("comment is not editable") do
        !buffer.get_iter_at(offset: comment_offset + 2).editable(true)
      end
      d.check("body is editable") { buffer.get_iter_at(offset: 2).editable(true) }
    end
  end

  d.step("select all stops at the comment") do
    app.editor_window.then do |window|
      window.view.signal_emit("select-all", true)
      window.buffer.selection_bounds.then do |bounds|
        d.check("selection stops before the comment") do
          !window.buffer.get_text(bounds.first, bounds.last, false).include?("# On branch main")
        end
      end
    end
  end

  d.step("an over-long title is highlighted") do
    app.editor_window.then do |window|
      window.buffer.text = "#{'x' * 60}\n\nbody"
      d.check("the overflow carries the tag") do
        window.buffer.get_iter_at(offset: 55).tags.any? { |tag| tag.foreground_rgba.to_s.include?("224") }
      end
      d.check("under the limit is untagged") { window.buffer.get_iter_at(offset: 10).tags.empty? }
    end
  end

  d.step("look at the highlighted title") do
    d.shot("02-title-too-long")
  end

  d.step("an empty message cannot be confirmed") do
    app.editor_window.then do |window|
      window.buffer.text = "# only a comment\n"
      d.check("confirm is insensitive") { !window.save_button.sensitive? }
      window.buffer.text = "Back to something"
      d.check("confirm is sensitive again") { window.save_button.sensitive? }
    end
  end

  d.step("Ctrl+/ comments the current line") do
    app.editor_window.then do |window|
      window.buffer.text = "hello"
      window.buffer.place_cursor(window.buffer.get_iter_at(offset: 0))
      window.editor.toggle_line_comment
      d.check("line is commented") { window.buffer.text == "# hello" }
      window.editor.toggle_line_comment
      d.check("line is uncommented again") { window.buffer.text == "hello" }
    end
  end

  d.step("the main menu opens") do
    app.editor_window.menu_button.popup
  end

  # The popover animates open; give it a turn before looking at it.
  d.step("let the popover settle") {}

  d.step("it has the theme switcher in it") do
    app.editor_window.then do |window|
      d.check("the popover is up") { window.menu_button.popover.visible? }
      d.check("the theme selector is in the popover") { window.theme_selector.bin.realized? }
      d.check("all three swatches are there") do
        [window.theme_selector.follow_button,
         window.theme_selector.light_button,
         window.theme_selector.dark_button
].all? { |swatch| swatch.is_a?(Gtk::CheckButton) }
      end
      d.check("they are wired to the colour scheme action") do
        window.theme_selector.dark_button.action_name == "app.color-scheme"
      end
      d.shot("08-menu", window.menu_button.popover)
      window.menu_button.popdown
    end
  end

  d.step("the theme selector drives the colour scheme") do
    app.application.lookup_action("color-scheme").tap do |action|
      action.activate(GLib::Variant.new(ThemeSelectorDark, "i"))
      d.check("action state followed") { action.state == ThemeSelectorDark }
      d.check("the style manager followed") do
        Adwaita::StyleManager.default.color_scheme == Adwaita::ColorScheme::FORCE_DARK
      end
      d.check("the dark swatch is checked") { app.editor_window.theme_selector.dark_button.active? }
      d.check("the follow swatch is not") { !app.editor_window.theme_selector.follow_button.active? }
    end
  end

  d.step("and back to following the system") do
    app.application.lookup_action("color-scheme").tap do |action|
      action.activate(GLib::Variant.new(0, "i"))
      d.check("the follow swatch is checked") { app.editor_window.theme_selector.follow_button.active? }
    end
  end

  d.step("preferences open, change and apply") do
    app.editor_window.then do |window|
      window.window.lookup_action("cancel") # touch the action map
      app.application.lookup_action("preferences").activate(nil)
    end
  end

  d.step("let the dialog finish opening") {}

  d.step("the preferences dialog is showing") do
    app.editor_window.then do |window|
      d.check("dialog is open") { window.window.visible_dialog }
      d.check("title length row shows the current value") do
        window.preferences.rows.title_length_row.value.to_i == Commit::Settings.local.title_length_hint
      end
      d.check("body length row shows the current value") do
        window.preferences.rows.body_length_row.value.to_i == Commit::Settings.local.body_length_wrap
      end
      d.check("body length defaults to 72") { window.preferences.rows.body_length_row.value.to_i == 72 }
      d.check("auto capitalize defaults to on") { window.preferences.rows.capitalize_row.active? }
      d.shot("03-preferences", window.window.visible_dialog)
    end
  end

  d.step("changing a preference writes it to the repository config") do
    app.editor_window.preferences.tap do |preferences|
      preferences.rows.body_length_row.value = 60
      preferences.dialog.close
    end
  end

  d.step("the new value came back through the config") do
    d.check("config was written") { File.exist?(File.join(REPOSITORY, ".gitconfig")) }
    d.check("body length is 60 now") { Commit::Settings.local.body_length_wrap == 60 }
    d.check("the editor picked it up") do
      app.editor_window.editor.commit_editor.wrap_width_request == 60
    end
  end

  d.step("the shortcuts window opens") do
    app.application.lookup_action("shortcuts").activate(nil)
  end

  d.step("let it settle") {}

  d.step("the shortcuts window is showing") do
    app.shortcuts_window.then do |shortcuts|
      d.check("it is a real GtkShortcutsWindow") { shortcuts.window.is_a?(Gtk::ShortcutsWindow) }
      d.check("it is visible") { shortcuts.window.visible? }
      d.check("it is transient for the editor") do
        shortcuts.window.transient_for == app.editor_window.window
      end
      d.check("the editing group is titled") do
        shortcuts.builder.get_object("group_editing").title == "Editing"
      end
      d.check("the save shortcut is titled") do
        shortcuts.builder.get_object("shortcut_save").title == "Save and Confirm"
      end
      d.check("and carries its accelerator") do
        shortcuts.builder.get_object("shortcut_save").accelerator == "<Control>Return"
      end
      d.shot("04-shortcuts", shortcuts.window)
      shortcuts.window.close
    end
  end

  d.step("the about dialog opens") do
    app.application.lookup_action("about").activate(nil)
  end

  # The about dialog animates in and loads its icon, so it wants two.
  d.step("let it settle too") {}

  d.step("and once more") {}

  d.step("the about dialog is showing") do
    app.editor_window.window.then do |win|
      d.check("about dialog is open") { win.visible_dialog }
      d.shot("05-about", win.visible_dialog)
      win.visible_dialog&.close
    end
  end

  d.step("aborting an edited message asks first") do
    app.editor_window.then do |window|
      window.buffer.text = "Something worth keeping"
      window.window.lookup_action("cancel").activate(nil)
    end
  end

  d.step("and settle again") {}

  d.step("the discard dialog is showing") do
    app.editor_window.window.then do |win|
      d.check("discard dialog is open") { win.visible_dialog }
      d.shot("06-discard", win.visible_dialog)
      win.visible_dialog&.close
    end
  end

  d.step("a window wider than the ruler leaves the text alone") do
    app.editor_window.then do |window|
      window.buffer.text = "Add the thing\n\n#{'word ' * 40}\n"
      d.check("the ruler is on screen") { window.editor.wider_than_wrap_width_request? }
      d.check("nothing is reflowed") { window.formatted(window.buffer.text) == window.buffer.text }
      window.write(window.formatted(window.buffer.text))
    end
  end

  d.step("the file on disk holds what was typed") do
    d.check("written verbatim") { File.read(MESSAGE_PATH) == app.editor_window.buffer.text }
    # Push the ruler past the right edge of the view. Resizing the window
    # would do it too, but this does not depend on the window manager
    # honouring the new size within a tick.
    app.editor_window.editor.commit_editor.wrap_width_request = 200
  end

  d.step("a window narrower than the ruler reflows on save") do
    app.editor_window.then do |window|
      d.check("the ruler is off screen") { !window.editor.wider_than_wrap_width_request? }
      window.formatted(window.buffer.text).then do |formatted|
        d.check("body was wrapped") { formatted.lines.all? { |line| line.chomp.length <= 72 } }
        d.check("title was left alone") { formatted.start_with?("Add the thing\n\n") }
        window.write(formatted)
      end
      d.shot("07-narrow")
    end
  end

  d.step("the wrapped message reached the file") do
    d.check("file is wrapped") { File.read(MESSAGE_PATH).lines.all? { |line| line.chomp.length <= 72 } }
  end

  d.step("--readonly is read off the command line") do
    GLib::VariantDict.new(nil).tap { |options| options.insert("readonly", GLib::Variant.new(true)) }
                              .then do |options|
      d.check("handling the option lets the command line continue") do
        app.on_handle_local_options(options) == -1
      end
      d.check("and sets the flag") { app.readonly }
    end
  end

  d.step("a readonly window writes nothing") do
    File.join(REPOSITORY, "readonly-COMMIT_EDITMSG").then do |path|
      FileUtils.cp(File.join(FIXTURES, "with-body/COMMIT_EDITMSG"), path)
      File.read(path).then do |before|
        Commit::Window.new(
          application: app.application,
          path:        path,
          text:        before,
          type:        "commit",
          readonly:    true,
        ).tap do |window|
          window.build
          window.write("clobbered")
          d.check("the file is untouched") { File.read(path) == before }
          window.window.close
        end
      end
    end
  end
end

# frozen_string_literal: true

# Drives the welcome window — what you get running Commit by hand rather than
# from git.
#
#   env -u DISPLAY -u WAYLAND_DISPLAY bundle exec ruby test/drive_welcome.rb

require "tmpdir"

require_relative "gtk_driver"

SHOTS = File.expand_path("../tmp/shots", __dir__)

# The welcome window edits the user's global gitconfig, so give the run a home
# of its own rather than the real one.
HOME = Dir.mktmpdir("commit-home")
REPOSITORY = Dir.mktmpdir("commit-repo")
ENV["HOME"] = HOME
ENV["XDG_CONFIG_HOME"] = File.join(HOME, ".config")
Dir.chdir(REPOSITORY)

require_relative "../lib/commit"

app_object = Commit::Application.new

GtkDriver.drive(app_object, shots: SHOTS) do |d, app|
  d.window { app.welcome_window&.window }

  d.step("the welcome window opens") do
    app.welcome_window.then do |welcome|
      d.check("it is there") { welcome }
      d.check("titled Commit") { welcome.window.title == "Commit" }
      d.shot("10-welcome")
    end
  end

  d.step("it shows the commands that make Commit the editor") do
    app.welcome_window.then do |welcome|
      d.check("git command mentions core.editor") do
        welcome.git_label.label.include?("git config --global core.editor")
      end
      d.check("git command names this binary") { welcome.git_label.label.include?(welcome.command) }
      d.check("mercurial command sets ui.editor") { welcome.mercurial_label.label.include?("[ui]") }
      d.check("mercurial command names this binary") do
        welcome.mercurial_label.label.include?(welcome.command)
      end
    end
  end

  d.step("copying puts the command on the clipboard") do
    app.welcome_window.then do |welcome|
      welcome.git_copy_button.signal_emit("clicked")
      # Reading the text back is a headless-clipboard dead end — the offscreen
      # backend reports no compatible transfer format — so check that the
      # button put a local provider on the clipboard instead.
      d.check("the clipboard holds something") { welcome.git_label.clipboard.content }
      d.check("and it came from us") { welcome.git_label.clipboard.local? }
      d.check("the label text is the bare command") do
        welcome.git_label.text == %(git config --global core.editor "#{welcome.command}")
      end
    end
  end

  d.step("the rows show the global preferences") do
    app.welcome_window.rows.then do |rows|
      d.check("title length") { rows.title_length_row.value.to_i == Commit::Settings.global.title_length_hint }
      d.check("body length") { rows.body_length_row.value.to_i == Commit::Settings.global.body_length_wrap }
      d.check("body length defaults to 72") { rows.body_length_row.value.to_i == 72 }
      d.check("auto capitalize defaults to on") { rows.capitalize_row.active? }
    end
  end

  d.step("the about dialog opens from the header bar") do
    app.welcome_window.about_button.activate
  end

  d.step("let it settle") {}

  d.step("the about dialog is showing") do
    app.welcome_window.window.then do |win|
      d.check("about dialog is open") { win.visible_dialog }
      d.shot("11-welcome-about", win.visible_dialog)
      win.visible_dialog&.close
    end
  end

  d.step("changing a row and shutting down writes the global config") do
    app.welcome_window.rows.body_length_row.value = 80
    # The welcome window saves on the application's shutdown, so that is what
    # has to fire — not the save method directly.
    app.application.signal_emit("shutdown")
  end

  d.step("the global gitconfig has the new value") do
    File.join(HOME, ".gitconfig").then do |path|
      d.check("written to the home gitconfig") { File.exist?(path) }
      d.check("holds the new body length") { File.read(path).include?("body-length-wrap=80") }
      d.check("left the repository config alone") do
        !File.exist?(File.join(REPOSITORY, ".gitconfig"))
      end
    end
  end
end

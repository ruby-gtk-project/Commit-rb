# frozen_string_literal: true

# Drives the app the way bin/commit-dev does — as a development build.
#
#   env -u DISPLAY -u WAYLAND_DISPLAY bundle exec ruby test/drive_dev.rb

require "tmpdir"
require "fileutils"

require_relative "gtk_driver"

FIXTURES = File.expand_path("fixtures", __dir__)
SHOTS = File.expand_path("../tmp/shots", __dir__)

HOME = Dir.mktmpdir("commit-home")
REPOSITORY = Dir.mktmpdir("commit-repo")
ENV["HOME"] = HOME
ENV["XDG_CONFIG_HOME"] = File.join(HOME, ".config")
Dir.chdir(REPOSITORY)

MESSAGE_PATH = File.join(REPOSITORY, "COMMIT_EDITMSG")
FileUtils.cp(File.join(FIXTURES, "with-body/COMMIT_EDITMSG"), MESSAGE_PATH)

require_relative "../lib/commit"

Commit::Dev.enable!

app_object = Commit::Application.new

GtkDriver.drive(app_object, shots: SHOTS) do |d, app|
  d.window { app.editor_window&.window }

  d.step("the welcome window is marked as a development build") do
    d.check("welcome carries the devel class") do
      app.welcome_window.window.css_classes.include?("devel")
    end
    d.shot("20-dev-welcome", app.welcome_window.window)
  end

  d.step("open a commit message") do
    app.open_editor(MESSAGE_PATH)
    app.welcome_window.window.close
  end

  d.step("the editor is marked too, and can restart itself") do
    d.check("editor carries the devel class") { app.editor_window.window.css_classes.include?("devel") }
    d.check("the restart action exists") { app.application.lookup_action("restart") }
    d.check("and has its accelerator") do
      # GTK normalises <Control><Shift>Q on the way in.
      app.application.get_accels_for_action("app.restart") == ["<Shift><Control>q"]
    end
    d.shot("21-dev-editor")
  end
end

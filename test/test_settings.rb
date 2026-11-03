# frozen_string_literal: true

# Parity checks for where Commit looks for its two gitconfigs, ported from
# the upstream test/helpers.test.js. Upstream splits this across
# src/helpers.js (getHostConfigHomePath, isFile) and src/git.js
# (getGlobalGitconfig); the port keeps all three in Commit::Settings, so the
# upstream isFile cases show up here as the branch they exist to drive — the
# choice between $XDG_CONFIG_HOME/git/config and ~/.gitconfig.
#
#   bundle exec ruby test/test_settings.rb

require "fileutils"
require "tmpdir"

require_relative "../lib/commit/settings"

$failures = []
$checks = 0

def check(description, actual, expected)
  $checks += 1
  if actual == expected
    puts "  ok   #{description}"
  else
    puts "  FAIL #{description}"
    puts "       expected: #{expected.inspect}"
    puts "       actual:   #{actual.inspect}"
    $failures << description
  end
end

# Runs the block with the named variables set — nil unsets one — and puts
# every one of them back afterwards, set or unset as it found them.
def with_env(**variables)
  variables.to_h { |name, _| [name, ENV.fetch(name.to_s, nil)] }.then do |saved|
    variables.each { |name, value| ENV[name.to_s] = value }
    begin
      yield
    ensure
      saved.each { |name, value| ENV[name.to_s] = value }
    end
  end
end

DEFAULT_CONFIG_HOME = File.join(Dir.home, ".config")

puts "host_config_home — outside a sandbox"
with_env(XDG_CONFIG_HOME: "/foo/bar") do
  check("honours XDG_CONFIG_HOME", Commit::Settings.host_config_home(false), "/foo/bar")
end
with_env(XDG_CONFIG_HOME: nil) do
  check("falls back to ~/.config", Commit::Settings.host_config_home(false), DEFAULT_CONFIG_HOME)
end
with_env(XDG_CONFIG_HOME: "") do
  check(
    "treats an empty XDG_CONFIG_HOME as unset",
    Commit::Settings.host_config_home(false),
    DEFAULT_CONFIG_HOME,
  )
end

puts "host_config_home — inside a sandbox"
with_env(HOST_XDG_CONFIG_HOME: "/foo/bar", XDG_CONFIG_HOME: "/sandbox/config") do
  check(
    "honours HOST_XDG_CONFIG_HOME over the sandbox's own XDG_CONFIG_HOME",
    Commit::Settings.host_config_home(true),
    "/foo/bar",
  )
end
with_env(HOST_XDG_CONFIG_HOME: nil) do
  check("falls back to ~/.config", Commit::Settings.host_config_home(true), DEFAULT_CONFIG_HOME)
end
with_env(HOST_XDG_CONFIG_HOME: "") do
  check(
    "treats an empty HOST_XDG_CONFIG_HOME as unset",
    Commit::Settings.host_config_home(true),
    DEFAULT_CONFIG_HOME,
  )
end

# The upstream isFile cases — a real file, a directory, and a path that is not
# there at all — as the branch they decide in getGlobalGitconfig.
puts "global_gitconfig_path"
Dir.mktmpdir("commit-rb-settings") do |config_home|
  check(
    "a missing XDG git/config falls back to ~/.gitconfig",
    Commit::Settings.global_gitconfig_path(config_home),
    File.join(Dir.home, ".gitconfig"),
  )

  FileUtils.mkdir_p(File.join(config_home, "git", "config"))
  check(
    "a directory where git/config should be falls back to ~/.gitconfig",
    Commit::Settings.global_gitconfig_path(config_home),
    File.join(Dir.home, ".gitconfig"),
  )

  FileUtils.rm_rf(File.join(config_home, "git", "config"))
  File.write(File.join(config_home, "git", "config"), "[user]\n\tname = x\n")
  check(
    "an XDG git/config that is a file wins",
    Commit::Settings.global_gitconfig_path(config_home),
    File.join(config_home, "git", "config"),
  )
end

puts "local_gitconfig_path"
check(
  "is the .gitconfig in the working directory",
  Commit::Settings.local_gitconfig_path,
  File.join(Dir.pwd, ".gitconfig"),
)

puts
puts "#{$checks - $failures.length} of #{$checks} checks passed"
$failures.each { |failure| puts "  failed: #{failure}" }
exit($failures.empty? ? 0 : 1)

# frozen_string_literal: true

# Regenerates re.sonny.Commit.json.
#
# Flatpak builds have no network, so every gem has to be declared as a source
# with its checksum for flatpak-builder to fetch up front. The list and the
# checksums come from vendor/cache, which `bundle cache` fills from the
# resolved Gemfile.lock; the manifest itself points at rubygems.org, so a
# build needs nothing but this file.
#
#   bundle cache --no-install
#   bundle exec ruby tools/generate-flatpak-manifest.rb
#
# The rest of the manifest is the fixed part below.

require "digest"
require "json"

ROOT = File.expand_path("..", __dir__)
CACHE = File.join(ROOT, "vendor", "cache")
MANIFEST = File.join(ROOT, "re.sonny.Commit.json")

RUBY_VERSION_BUILT = "3.4.9"
RUBY_SHA256 = "7bb4d4f5e807cc27251d14d9d6086d182c5b25875191e44ab15b709cd7a7dd9c"

def gem_sources
  Dir.glob(File.join(CACHE, "*.gem")).sort.map do |path|
    {
      "type"   => "file",
      "url"    => "https://rubygems.org/downloads/#{File.basename(path)}",
      "sha256" => Digest::SHA256.file(path).hexdigest,
      "dest"   => "gems",
    }
  end
end

manifest = {
  "id"           => "re.sonny.Commit",
  "runtime"      => "org.gnome.Platform",
  "runtime-version" => "50",
  "sdk"          => "org.gnome.Sdk",
  "command"      => "commit",
  "finish-args"  => [
    "--share=ipc",
    "--socket=fallback-x11",
    "--socket=wayland",
    "--device=dri",
    "--filesystem=host",
  ],
  "cleanup" => [
    "/include",
    "/lib/pkgconfig",
    "/man",
    "/share/doc",
    "/share/gtk-doc",
    "/share/man",
    "/share/pkgconfig",
    "/share/installed-tests",
    "*.la",
    "*.a",
  ],
  "modules" => [
    {
      "name"        => "libspelling",
      "buildsystem" => "meson",
      "config-opts" => ["-Ddocs=false", "-Dvapi=false"],
      "sources"     => [
        {
          "type"   => "archive",
          "url"    => "https://download.gnome.org/sources/libspelling/0.4/libspelling-0.4.10.tar.xz",
          "sha256" => "56e3f01a3a18b575beea4c34349f99cdaba316e1f7c271b1231f7bcf5d9af73b",
        },
      ],
    },
    {
      "name"        => "ruby",
      "buildsystem" => "autotools",
      "config-opts" => [
        "--disable-install-doc",
        "--disable-install-rdoc",
        "--enable-shared",
      ],
      "sources"     => [
        {
          "type"   => "archive",
          "url"    => "https://cache.ruby-lang.org/pub/ruby/3.4/ruby-#{RUBY_VERSION_BUILT}.tar.gz",
          "sha256" => RUBY_SHA256,
        },
      ],
    },
    {
      "name"          => "ruby-gems",
      "buildsystem"   => "simple",
      "build-commands" => [
        "gem install --local --no-document --bindir /app/bin gems/*.gem",
      ],
      "sources"       => gem_sources,
    },
    {
      "name"           => "Commit",
      "buildsystem"    => "simple",
      "build-commands" => ["make install PREFIX=/app"],
      "sources"        => [{ "type" => "dir", "path" => "." }],
    },
  ],
}

File.write(MANIFEST, "#{JSON.pretty_generate(manifest)}\n")
puts "wrote #{MANIFEST} with #{gem_sources.length} gem sources"

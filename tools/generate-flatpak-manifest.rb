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

require "bundler"
require "digest"
require "json"

ROOT = File.expand_path("..", __dir__)
CACHE = File.join(ROOT, "vendor", "cache")
MANIFEST = File.join(ROOT, "re.sonny.Commit.json")

RUBY_VERSION_BUILT = "3.4.9"
RUBY_SHA256 = "7bb4d4f5e807cc27251d14d9d6086d182c5b25875191e44ab15b709cd7a7dd9c"

# Only what the app itself needs — rubocop and its dependencies stay out of
# the runtime.
def runtime_specs
  Bundler.definition.specs_for([:default]).reject { |spec| spec.name == "bundler" }
end

# The ruby-gnome extensions build against each other in an order their
# gemspecs do not fully describe — atk, for one, needs gobject-introspection
# without declaring it — so that chain is spelled out rather than derived.
BUILD_ORDER = %w[
  rake
  native-package-installer
  pkg-config
  red-colors
  glib2
  gobject-introspection
  gio2
  atk
  cairo
  cairo-gobject
  pango
  gdk_pixbuf2
  graphene1
  gdk4
  gsk4
  gtk4
  adwaita
].freeze

# `gem install --local` will not resolve between the files it is handed, so
# they go in one at a time, the named chain first and everything else after it
# in dependency order.
def ordered_specs
  runtime_specs.then do |specs|
    BUILD_ORDER.filter_map { |name| specs.find { |spec| spec.name == name } }.dup.then do |ordered|
      specs.each { |spec| append_with_dependencies(spec, specs, ordered) }
      ordered
    end
  end
end

# `ordered` starts as the named chain and grows; anything already in it is
# left where it is.
def append_with_dependencies(spec, specs, ordered)
  if !ordered.include?(spec)
    spec.dependencies.select { |dependency| dependency.type == :runtime }.each do |dependency|
      specs.find { |candidate| candidate.name == dependency.name }.then do |needed|
        if needed
          append_with_dependencies(needed, specs, ordered)
        end
      end
    end

    ordered << spec
  end
end

def gem_file(spec) = File.join(CACHE, "#{spec.name}-#{spec.version}.gem")

def gem_sources(specs)
  specs.map do |spec|
    {
      "type"   => "file",
      "url"    => "https://rubygems.org/downloads/#{File.basename(gem_file(spec))}",
      "sha256" => Digest::SHA256.file(gem_file(spec)).hexdigest,
      "dest"   => "gems",
    }
  end
end

def install_commands(specs)
  specs.map do |spec|
    "gem install --local --no-document --ignore-dependencies " \
      "--bindir /app/bin gems/#{File.basename(gem_file(spec))}"
  end
end

SPECS = ordered_specs

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
    # A GEM_HOME set on the host follows the process into the sandbox and
    # shadows the gems in /app, so the app comes up unable to require gtk4.
    "--unset-env=GEM_HOME",
    "--unset-env=GEM_PATH",
    "--unset-env=RUBYOPT",
    "--unset-env=BUNDLE_GEMFILE",
    "--unset-env=BUNDLE_PATH",
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
      "build-commands" => install_commands(SPECS),
      "sources"       => gem_sources(SPECS),
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
puts "wrote #{MANIFEST} with #{SPECS.length} gems, in dependency order"

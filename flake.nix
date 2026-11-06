{
  description = "Ruby GTK4 development shell";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, utils }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [ pkg-config wrapGAppsHook4 ];
          buildInputs = with pkgs; [
            ruby_3_4
            bundler
            bundix
            atk
            gtk4
            libadwaita
            # No ruby gems exist for these two; they are loaded straight from
            # their typelibs by GObjectIntrospection::Loader.
            gtksourceview5
            libspelling
            gobject-introspection
            glib
            cairo
            pango
            gdk-pixbuf
            harfbuzz
            libyaml
            # `make test` validates the appstream and desktop metadata.
            appstream
            desktop-file-utils
            gettext
            openssl

            # The ruby-gnome extconfs resolve Requires.private out of the .pc
            # files, so every private dependency of glib/cairo/pango/gtk needs
            # its own .pc here or the gem fails to configure.
            expat
            freetype
            fontconfig
            fribidi
            graphene
            lerc
            libdatrie
            libdeflate
            libepoxy
            libpng
            libpthread-stubs
            libselinux
            libsepol
            libsysprof-capture
            libthai
            libwebp
            libxkbcommon
            libX11
            libXau
            libxcb
            libXdmcp
            libXext
            libXrender
            pcre2
            pixman
            util-linux
            xz
            zstd

            # This machine has no display server at all, so the shell carries
            # one it can start itself: `xvfb-run -a ruby ...` is how the app
            # and the test/drive_*.rb scripts are run. GTK4 here has no
            # offscreen backend — gtk_init fails outright with no display —
            # so xvfb-run is not optional.
            xvfb-run
            # The spec runner the test suite under spec/ needs.
            rubyPackages_3_4.rspec
          ];

          shellHook = ''
            # Both of these are pinned to the checkout on purpose. BUNDLE_PATH
            # keeps the gems out of the user's home, and BUNDLE_GEMFILE keeps
            # an ambient one — this tree sits beside sibling checkouts whose
            # direnv exports their own — from pointing bundler at the wrong
            # Gemfile, which resolves a bundle with no gtk4 in it.
            export BUNDLE_GEMFILE="$PWD/Gemfile"
            export BUNDLE_PATH="$PWD/vendor/bundle"
            export BUNDLE_BUILD__GTK4="--use-system-libraries"
            export GI_TYPELIB_PATH="${pkgs.gtk4}/lib/girepository-1.0:${pkgs.libadwaita}/lib/girepository-1.0:${pkgs.gtksourceview5}/lib/girepository-1.0:${pkgs.libspelling}/lib/girepository-1.0''${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}"
            export LD_LIBRARY_PATH="${pkgs.gtksourceview5}/lib:${pkgs.libspelling}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
            export RUBYLIB="$PWD/lib''${RUBYLIB:+:$RUBYLIB}"
          '';
        };
      }
    );
}

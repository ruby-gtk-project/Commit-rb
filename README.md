# Commit — Ruby port

A Ruby GTK4 / Libadwaita port of [Commit](https://commit.sonny.re), the editor
that pops up when you run `git commit`.

The original is written in GJS and lives on this fork's `main` branch. This
branch is the port: same windows, same dialogs, same shortcuts, same
preferences, same twenty translations.

## What it does

- Highlights the part of the commit title that runs past the length hint
- Reflows the body at the wrap width — but only while the ruler is off screen,
  so widening the window turns the reflow off
- Keeps the comment block read-only, and out of Select All
- Inserts the blank line between title and body for you
- Capitalizes the title once, after the `fix:`-style prefix if there is one
- Shows the project folder and the branch, tag or rebase range in the header
- Syntax highlighting for git, mercurial and diffs, and inline spell checking
- Understands `git commit`, `merge`, `tag --annotate`, `add --patch`,
  `rebase --interactive`, `hg commit`, and plain gitconfig/hgrc files

## Running it

```sh
direnv allow          # or: nix develop
bundle install
bundle exec ruby bin/commit path/to/COMMIT_EDITMSG
```

`bin/commit-dev` is the same app run as a development build — the windows get
libadwaita's `devel` striping and `<Control><Shift>Q` restarts it in place,
which is what upstream's `src/local.js` does. `make run` is that.

With no arguments you get the welcome window, which has the global preferences
and the command that makes Commit your editor:

```sh
git config --global core.editor "$PWD/bin/commit"
```

`--readonly` runs the app without letting it write anything back, which is
useful for poking at a real message without committing it.

## Preferences

Commit stores its preferences in gitconfig, under `[re.sonny.Commit]` — the
repository's `.gitconfig` for the per-repository ones, yours for the global
ones. The theme choice is a GSetting.

## Tests

```sh
bundle exec ruby test/test_scm.rb          # message parsing, against the upstream fixtures
bundle exec ruby test/test_translations.rb # the compiled catalogues
env -u DISPLAY -u WAYLAND_DISPLAY bundle exec ruby test/drive_editor.rb
env -u DISPLAY -u WAYLAND_DISPLAY bundle exec ruby test/drive_welcome.rb
env -u DISPLAY -u WAYLAND_DISPLAY bundle exec ruby test/drive_dev.rb
```

`make test` runs all of that plus the appstream, desktop-file, msgfmt and
flatpak-manifest validation.

## Packaging

```sh
make install PREFIX=/usr/local   # lib/ and data/ under share/re.sonny.Commit
make flatpak                     # build and install the flatpak
make bundle                      # a single-file Commit.flatpak
make manifest                    # regenerate re.sonny.Commit.json from Gemfile.lock
```

The `drive_` scripts run the app headlessly, click through it and write
screenshots to `tmp/shots/`. They give themselves a temporary `HOME` and
working directory, because Commit writes to real gitconfig files.

Roughly one screenshot in six runs comes back empty — the offscreen backend
occasionally has no render node for a widget that was reconfigured a moment
earlier. The harness retries, reports the ones it gave up on, and carries on;
the checks are what a run is judged on.

## Differences from upstream

The app itself is the same. What differs is underneath it:

- **The shortcuts window and the theme switcher are built from `.ui` files**
  (`data/shortcuts-window.ui`, `data/theme-selector.ui`), the way upstream
  builds them from Blueprint. They have to be: `GtkShortcutsWindow` cannot be
  constructed from the Ruby bindings — the generated constructor resolves to
  `GtkWindow`'s and raises, and the raw GObject one leaves the floating
  references unsunk — and `gtk_accessible_update_property` is not implemented,
  so `<accessibility>` in the XML is the only way to label the three theme
  swatches. GtkBuilder translates both files against the C gettext domain,
  which `lib/commit/i18n.rb` binds to the same catalogues the Ruby side uses.
- **Wrap toggling on resize.** Upstream overrides `size_allocate`. The Ruby
  bindings do not expose that vfunc, so the port watches the scrolled window's
  hadjustment instead — it changes with the view's width on every resize.
- **`make` instead of `meson`.** `make install` puts `lib/` and `data/` side by
  side under `$PREFIX/share/re.sonny.Commit` and drops a launcher in
  `$PREFIX/bin`. `make test` runs rubocop, the four test scripts, and the same
  appstream, desktop-file and msgfmt validation upstream's `make test` does.
- **The flatpak manifest carries a Ruby.** Upstream's `re.sonny.Commit.json`
  builds one meson module against the GNOME SDK. This one builds Ruby, then
  every gem — pinned by name and checksum, because a flatpak build has no
  network — then the app. `make manifest` regenerates it from `Gemfile.lock`,
  so adding a gem is one command rather than an editing job.

## Licence

GPL-3.0, as upstream. See `COPYING`.

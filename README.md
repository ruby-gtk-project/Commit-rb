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
bin/commit path/to/COMMIT_EDITMSG
```

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
```

The two `drive_` scripts run the app headlessly, click through it and write
screenshots to `tmp/shots/`. They give themselves a temporary `HOME` and
working directory, because Commit writes to real gitconfig files.

## Differences from upstream

- **Keyboard shortcuts window.** GTK deprecated `GtkShortcutsWindow` and its
  Ruby constructor is broken; the port uses `AdwShortcutsDialog`, which shows
  the same list.
- **Wrap toggling on resize.** Upstream overrides `size_allocate`. The Ruby
  bindings do not expose that vfunc, so the port watches the scrolled window's
  hadjustment instead — it changes with the view's width on every resize.
- **Accessibility labels on the theme switcher.** `gtk_accessible_update_property`
  is not implemented in the Ruby bindings (it raises `NotImplementedError`), so
  the three swatches carry their tooltips but not an explicit accessible label.
- **No dev mode.** Upstream's `src/local.js` — the `.devel` styling and the
  `<Control><Shift>Q` restart action — is build tooling, not an app feature.

## Licence

GPL-3.0, as upstream. See `COPYING`.

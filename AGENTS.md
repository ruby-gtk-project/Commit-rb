# Commit — Ruby port

This branch is the Ruby GTK4 / Libadwaita port of Commit. The original GJS
implementation lives on this fork's `main` branch and is the spec — read it,
don't copy it. `README.md` covers what the app does and how to run it.

## Skills — use them

Two skills are installed in `.claude/skills/`. They are not optional reading.

- **ruby-gtk** — the house style for Ruby GTK4/Libadwaita: the declarative
  memoized-widget pattern, Adwaita binding quirks, worked examples. Load it
  before writing or reviewing ANY Ruby GTK code, including single widgets, and
  before planning a port. The bindings are quirky enough that code written from
  memory is unreliable.
- **ruby-gtk-testing** — run the app headlessly and drive its UI: click through
  dialogs, assert widget state, capture screenshots. Use it before claiming any
  GTK change works. `ruby -c` and a successful `require` prove nothing about a
  UI.

## Setup

`direnv allow` (or `nix develop`) gets Ruby, GTK4, Libadwaita, GtkSourceView,
libspelling and the introspection typelibs. Then `bundle install`.

GtkSourceView and libspelling have no Ruby gems; they are loaded from their
typelibs in `lib/commit/gi.rb`, which is why the dev shell puts them on
`GI_TYPELIB_PATH` and `LD_LIBRARY_PATH`.

Everything is run through the dev shell:

```sh
nix develop --command bundle exec rubocop
nix develop --command bundle exec ruby test/test_scm.rb
nix develop --command env -u DISPLAY -u WAYLAND_DISPLAY bundle exec ruby test/drive_editor.rb
```

## Style

`.rubocop.yml` plus the custom cops in `cops/` are enforced: no `return`, no
modifier `if`, no conditional assignment, `tap` where it applies, and fixed
multi-line argument/hash layout. Run `bundle exec rubocop` before committing.

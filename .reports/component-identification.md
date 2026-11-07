# Commit — component identification (verification pass)

Upstream ref recorded for this audit: `origin/main` @ `b97eead` ("GNOME 51").
Port: `ruby` branch, HEAD `04419b7` at the first audit; **re-confirmed at
`e5a1062`** this round. The only change between the two is the translation
fix tracked in `component-parity.md`/`translation-parity.md`
(`lib/commit/preference_rows.rb` + `po/`); nothing that bears on component
identification (file mapping, unit count) changed, so the 16-row map below
still holds and was spot-checked again rather than assumed.

`.reports/component-inventory.md` (written by an earlier pass) is the
identification document for this port and its 16-row unit map was re-walked
file by file for this audit rather than trusted on sight. It holds up: every
upstream `.blp`/`.ui` template root and every upstream named top-level object
is accounted for, and the file mapping is correct side to side, including the
two cases that are easy to get wrong:

- `troll/src/widgets/ThemeSelector.{blp,js,css}` is a **submodule** path, not
  a `src/` path, so a scan of `src/` alone finds zero rows for it. It is still
  a real upstream unit (`gitlink` `37b53b29d…` in `.gitmodules`) and the port's
  `lib/commit/theme_selector.rb` + `data/theme-selector.ui` is its counterpart.
- `src/local.js`, `src/bin.js`, `src/main.js` are the GJS bundler/entry point,
  not UI; the port's `exe/`, `lib/commit/paths.rb`, `lib/commit/gi.rb`,
  `lib/commit/dev.rb`, `lib/commit/i18n.rb` are the correspondence, correctly
  carrying no upstream file-to-file mapping of their own.

One correction to the existing inventory: the "troll's ThemeSelector" table's
CSS-class column lists only `follow`, `light`, `dark` and drops the shared
`theme-selector` class that all three check buttons also carry (confirmed in
both `troll/src/widgets/ThemeSelector.blp` and the port's
`data/theme-selector.ui`, where the class is actually present on all three
`<object class="GtkCheckButton">` elements). The port's code is correct; the
table describing it is incomplete. Fixed here, not worth a second full
document.

No additional unported upstream unit, window, dialog, menu, or declarative
file was found. See `component-parity.md` for the axis-by-axis check and the
one real gap this audit found (which is a translation-marker gap, not a
missing component).

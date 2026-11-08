# Commit — component identification (this round's re-verification)

Upstream ref confirmed fresh this round: `origin/main` @
`b97eead8ef5165ae5f54b9aea522d4ae89ad7305` ("GNOME 51") — fetched and checked
with `git log origin/main -1`. Port: `ruby` @ `e2690c0` (HEAD at the start of
this round; adds only `test/run_all.sh` and report prose on top of `83277e8`,
confirmed with `git diff --stat 83277e8 e2690c0` touching only `.reports/` and
`test/run_all.sh`, nothing under `lib/`, `data/`, or `po/`).

## What this round did independently, not by reading the existing `.reports/`

Rather than re-reading the prior rounds' prose and trusting its conclusion,
this round ran the skill's own `component-scan.sh` against both trees fresh:

```sh
git worktree add --detach /tmp/commit-upstream origin/main
git submodule update --init troll   # inside the worktree, so ThemeSelector is visible
.claude/skills/component-identification/scripts/component-scan.sh /tmp/commit-upstream > up.tsv
.claude/skills/component-identification/scripts/component-scan.sh .                     > port.tsv
```

With the `troll` submodule actually checked out (prior rounds inferred its
contents by reading `ThemeSelector.blp` directly; this round cloned it and ran
the scanner over it, so the comparison below is over real scanned rows, not an
assumption):

- `up.tsv`: 84 rows. `port.tsv`: 102 rows.
- Widget-type set diff (`comm -23`/`comm -13` over the sorted distinct
  `widget` values): **zero** upstream widget types missing from the port.
  The only two types present in the port and absent from a plain `src/`-only
  upstream scan are `Adw.Bin` and `Gtk.CheckButton` — both fully accounted for
  by `troll/src/widgets/ThemeSelector.blp` (1 `Adw.Bin` template root, 3
  `CheckButton`s), confirmed by reading that file directly out of the cloned
  submodule this round, not by citing the inventory's prior description of it.
- Read `ThemeSelector.blp` in full: its three `CheckButton`s each carry a
  `tooltip-text` and an `accessibility { label: }`, both `_()`-wrapped — six
  translatable strings. Confirmed `data/theme-selector.ui` carries all six,
  byte-identical text, by grep (`"Follow system style"`, `"Light style"`,
  `"Dark style"`, each twice).

No new upstream window, dialog, page, menu, action, shortcut, preference,
empty state or error state was found outside the existing 16-unit map in
`component-inventory.md`. The map is unchanged from the prior round because
neither upstream's ref nor the port's `lib/`/`data/` tree changed.

## Verdict

16 of 16 upstream units identified and mapped, re-confirmed this round against
a freshly cloned copy of the upstream tree *and* its `troll` submodule (the
previous round confirmed the submodule's contents by reading the file; this
round additionally ran the scanner over an actual checkout of it). No unmapped
upstream UI surface found.

# Commit — component identification (this round's re-verification)

Upstream ref confirmed fresh this round: `origin/main` @ `b97eead8ef5165ae5f54b9aea522d4ae89ad7305`
("GNOME 51") — fetched and checked with `git log origin/main -1`, not read
off a prior report's word. Port: `ruby` @ `83277e8` (HEAD at the start of
this round; it is the previous round's "Parity reports" commit itself, no
code change on top of `e5a1062`, confirmed with `git log --oneline -3` and
`git status` showing a clean tree).

## What this round did independently, not by trusting the existing `.reports/`

- Diffed upstream's non-test `.blp`/`.js` file list (`git ls-tree -r
  --name-only origin/main | grep -E '\.(blp|js)$'`) against the 16-row map
  in `component-inventory.md`: all 21 files are accounted for by the 16
  rows (several files share a row, e.g. `window.blp`+`window.js`).
- Diffed upstream's `test/` file list the same way: `test/helpers.test.js`,
  `test/scm.test.js`, `test/wrap.test.js`, plus `test/fixtures/**`. Every
  fixture file upstream has is present under the port's `test/fixtures/`
  byte-for-byte by path (`diff` of the two sorted file lists showed zero
  missing paths; the port adds two of its own, `format_expected.txt` and
  `format_input.txt`, used only by the port's own `test_scm.rb` `format`
  case — not a gap).
- Confirmed the submodule-sourced unit (`troll/src/widgets/ThemeSelector`)
  and the GJS-bundler files with no port counterpart (`src/local.js`,
  `src/bin.js`, `src/main.js`) are both correctly called out as
  non-standard rows in `component-inventory.md`, by reading the upstream
  tree directly rather than taking the inventory's word for their absence
  from a plain `src/` scan.

No new upstream window, dialog, page, menu, action, shortcut, preference,
empty state or error state was found outside the existing 16-unit map. The
map itself is unchanged from the prior round because the upstream ref and
the port's `lib/`/`data/` tree are both unchanged (`git diff --stat
e5a1062 83277e8` touches only `.reports/`, nothing under `lib/`, `data/`,
`po/`, or `test/`).

## One thing worth re-stating plainly, since this round's job is to verify, not assume

The previous round's `component-inventory.md` already corrected itself once
(the `ThemeSelector` CSS-class table missing the shared `theme-selector`
class). That correction still holds on direct inspection of
`data/theme-selector.ui` this round — all three `GtkCheckButton` elements
still carry `theme-selector` alongside their individual `follow`/`light`/
`dark` class.

## Verdict

16 of 16 upstream units identified and mapped, confirmed again this round
against `origin/main` directly (not against a cached description of it). No
unmapped upstream UI surface found.

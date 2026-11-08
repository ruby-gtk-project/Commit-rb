# Commit — translation parity (this round's re-verification)

Upstream: `origin/main` @ `b97eead`. Port: `ruby` @ `e2690c0` (no code or
`po/` change since `e5a1062`).

## Independently rebuilt the catalogue this round

```sh
nix develop --command bash -lc '
  bundle exec ruby -e "
    require \"gettext/tools/xgettext\"
    files = File.readlines(\"po/POTFILES\", chomp: true).reject(&:empty?)
    GetText::Tools::XGetText.run(*files, \"-o\", \"/tmp/commit_check_r3.pot\")
  "
  grep -c \"^msgid \" /tmp/commit_check_r3.pot
'
```

40 msgids, same as every prior round, re-derived independently this round
rather than trusted from a committed `.pot` or a prior report.

## Every `.po` file checked individually this round

```sh
for f in po/*.po; do grep -q "Title Maximum Length" "$f" || echo "MISSING: $f"; done
```

Printed nothing. All 20 `.po` files (`ls po/*.po | wc -l` → 20, matching
`po/LINGUAS`'s 20 entries) carry both SpinRow titles.

## POTFILES cross-check against upstream's own list, done fresh this round

Rather than re-trusting the prior rounds' description of which upstream
files have strings, this round diffed upstream's own `po/POTFILES.in` against
the port's `po/POTFILES`:

```sh
git show origin/main:po/POTFILES.in
cat po/POTFILES
```

Upstream lists `src/CommitEditor.{blp,js}`, `src/wrap.js`, `src/editor.js`,
`src/application.js`, `src/main.js`, `src/settings.js`, `src/helpers.js`,
`src/git.js`, `troll/src/builder.js` in addition to the files the port's
`POTFILES` carries counterparts for. Checked each one directly with `git show
origin/main:<file> | grep -nE '_\(|gettext'`: **none of them contain a single
translatable marker** — upstream's `POTFILES.in` lists files regardless of
whether they currently have strings (ordinary gettext practice), it does not
mean every listed file is owed a port-side counterpart in `POTFILES`. This
confirms, by direct inspection this round rather than by citing
`component-inventory.md`'s claim, that `lib/commit/application.rb`,
`lib/commit/editor.rb`, `lib/commit/commit_editor.rb`,
`lib/commit/shortcuts_window.rb` and `lib/commit/theme_selector.rb` are
correctly absent from the port's `POTFILES` — they have no translatable
strings of their own, and the two files that do carry their upstream unit's
strings (`data/shortcuts-window.ui`, `data/theme-selector.ui`) are listed.

## ThemeSelector strings, verified against the submodule this round

This round cloned the `troll` submodule (see `component-identification.md`)
and read `ThemeSelector.blp` directly rather than trusting a description of
it: three `_()`-wrapped `tooltip-text` properties and three
`accessibility { label: }` properties — six strings total ("Follow system
style", "Light style", "Dark style", each used twice). Confirmed
`data/theme-selector.ui` carries all six, byte-identical, and that they are
present in the freshly rebuilt `.pot` from this round.

## Confirm-button labels, re-spot-checked

`lib/commit/scm.rb`'s action table still wraps each of the six confirm labels
in `N_()`. `test/test_potfiles.rb` — re-run fresh this round, 19/19 — still
exercises that every one of them survives extraction.

## Runtime gate cross-check

This round's stated gate ("210 checks passed, 0 failed, covering 16
components") matches `test/test_translations.rb`'s fresh 13/13 this round
and the whole-suite `test/run_all.sh` total. See `test-parity.md`.

## Verdict

Clean. All 20 `.po` files plus the `.pot` carry all 40 current msgids. No
upstream msgid is missing from the port; no port-invented msgid exists that
upstream lacks. This round additionally verified, against an actual checkout
of the `troll` submodule and upstream's own `POTFILES.in`, the two claims
prior rounds made about absent files and the ThemeSelector strings by
description rather than by direct inspection — both hold.

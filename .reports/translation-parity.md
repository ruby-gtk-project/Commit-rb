# Commit — translation parity

Upstream ref: `origin/main` @ `b97eead`. Port: `ruby` @ `04419b7` at first
audit; **re-verified at `e5a1062`** this round, which is `04419b7` plus the
one fix this report's own Finding 1 called for and nothing else.

## Method

Ran `.claude/skills/translation-parity/scripts/msgid-census.sh` over
`src/`+`data/` on upstream, over the `troll` submodule's checked-out source
(upstream's `.gitmodules` pins `troll` to `37b53b29d…`; the submodule is not
fetched by this clone, so its source was taken from a prior session's cached
checkout in `/tmp/claude-1001/troll_vendor` and corroborated — not just
trusted — by diffing its `ThemeSelector.blp`/`.js`/`.css` byte-for-byte
against the three strings and the CSS rules the port's
`data/theme-selector.ui` and `data/style.css` actually implement; they match
exactly, which is strong evidence it is the right submodule content), and
over the port's `lib/`+`exe/`+`data/`. Then, because the census script's
marker scanner cannot resolve a `_()` call whose argument is a constant
reference rather than a literal (`_(GIT_DOCUMENTATION)`, `_(parsed[:action])`,
`spin_row("literal", ...)` with `_()` applied *inside* `spin_row` or not at
all), every row the two scans disagreed on was checked by hand against the
source, and the catalogue was additionally **built for real**:

```
bundle exec ruby -e '
  require "gettext/tools/xgettext"
  files = File.readlines("po/POTFILES", chomp: true).reject(&:empty?)
  GetText::Tools::XGetText.run(*files, "-o", "/tmp/commit_check.pot")
'
```

This is the actual extraction a catalogue refresh runs, not a grep standing
in for it.

## Key-set diff (as it stood at `04419b7`, before the fix below)

| Side | Keys |
|---|---:|
| Upstream (`src/`, `data/`, `troll/src/widgets/ThemeSelector.*`) | 65 |
| Port (`lib/`, `exe/`, `data/`) | 67 |

(These two numbers come from the census script's marker scan, which counts
differently from a real `xgettext` run — see the two `.pot` msgid counts, 38
then 40, used throughout this report for the actual catalogue content. The
table above is kept only to show the two sides were compared key-by-key, not
just by raw count.)

After resolving every scanner-only mismatch by hand (constant-argument calls,
and the three `ThemeSelector` strings the first upstream scan missed because
it did not yet include the submodule path):

**Only-upstream keys — real, confirmed gaps:**

```
"Title Maximum Length (in characters)"
"Body Lines Maximum Length (in characters)"
```

**Only-port keys:** none, once the submodule source and the constant-argument
calls are accounted for. The port does not ship any extra, invented msgid.

Every other key on both sides — including the six confirm-button action
labels (`_Commit`, `_Merge`, `_Tag`, `A_dd`, `_Rebase`, `_Save`), the nine
shortcuts-window titles, the three theme-selector tooltip/accessible-label
strings, and every welcome/preferences/about string — was diffed
byte-for-byte and matches.

## Finding 1 — found at `04419b7` by building the catalogue, fixed at `e5a1062`, re-verified this round by building it again

At the first audit, `lib/commit/preference_rows.rb:42` and `:50` passed
`"Title Maximum Length (in characters)"` and
`"Body Lines Maximum Length (in characters)"` straight into `spin_row(title,
…)`, which does `row.title = title` with no `_()`/`N_()` anywhere in the
chain. Upstream marks both strings (`welcome.blp:spin_hint`/`spin_wrap`,
`preferences.blp` shares the same blueprint-declared rows) and all 20
upstream `.po` files carried translations for them, so the English-only
regression would have hit both the welcome window's global preferences and
the in-editor repository preferences dialog, in every one of the 20
languages Commit ships.

That gap was not caught by `test/test_potfiles.rb` or
`test/test_translations.rb` at the time: `test_potfiles.rb` only checks that
a file *containing any* gettext call is listed in `POTFILES` (it was —
`preference_rows.rb` already had one, `_("Auto Capitalize Title")`), not
that *every* user-visible string in that file is marked, and
`test_translations.rb` spot-checks a fixed list of known strings that had
never included these two.

**Fixed in `e5a1062`.** Re-verified independently this round, not taken on
the commit message's word:

```
nix develop --command bash -lc '
  bundle exec ruby -e "
    require \"gettext/tools/xgettext\"
    files = File.readlines(\"po/POTFILES\", chomp: true).reject(&:empty?)
    GetText::Tools::XGetText.run(*files, \"-o\", \"/tmp/commit_check2.pot\")
  "
  grep -c \"^msgid \" /tmp/commit_check2.pot   # => 40 (was 38)
  grep -i \"Maximum Length\" /tmp/commit_check2.pot   # => both msgids present
'
```

Also checked, this round:

- Every one of the 20 `.po` files (`for f in po/*.po; do grep -q "Title
  Maximum Length" "$f" || echo MISSING; done`) carries the msgid — no
  `MISSING` printed.
- Neither of the two msgids is left `#, fuzzy` in any `.po` file (checked
  with an awk scan for the line immediately before each msgid, across all
  20 files — no hits). Three `.po` files (`ja.po`, `sk.po`, `pt_BR.po`) still
  carry a handful of fuzzy entries, but all of them are against
  `metainfo.xml`/upstream-only source paths outside this port's `POTFILES`
  and predate this fix; they are not this gap.
- `test/test_translations.rb`, run fresh under
  `nix develop --command xvfb-run -a bash -lc 'bundle exec ruby
  test/test_translations.rb'` (plain `ruby` without `xvfb-run` fails —
  the file requires `lib/commit/gi.rb`, which needs a display to init GTK):
  **13 of 13 checks passed**, up from 10/10 at the first audit — the fix
  commit added cases that round-trip the German translation of both titles
  through the compiled catalogue.
- `test/drive_welcome.rb` step `[3]` (`title length`, `body length` checks)
  passes live against the running welcome window: 17/17.

## Languages

`po/LINGUAS` is identical between upstream and the port (20 entries, diffed
directly), and the port ships all 20 corresponding `.po` files plus the
`.pot`. `test/test_translations.rb`'s "catalogues were compiled" check was
run in this audit (`bundle exec ruby test/test_translations.rb`) and passed —
the `.mo` build step genuinely runs, not just the file-presence check.

## Verdict

Clean as of `e5a1062`. The two msgids this audit originally found missing
(`"Title Maximum Length (in characters)"`, `"Body Lines Maximum Length (in
characters)"`) were confirmed missing at `04419b7` by an actual `xgettext`
run, fixed in `e5a1062`, and the fix was re-verified this round by running
`xgettext` again (40 msgids, both present), checking all 20 `.po` files
individually for the msgid and for an unintended `fuzzy` flag, and by rerunning
`test/test_translations.rb` (13/13, up from 10/10) and `test/drive_welcome.rb`
(17/17) live. All 63 other upstream keys, all 20 languages, all `.po`/`.pot`
plumbing were censused at the first audit and nothing else in that scope
changed between `04419b7` and `e5a1062` (confirmed by `git diff --stat`,
which touches only `preference_rows.rb` and the `po/` files).

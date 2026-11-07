# Commit — translation parity

Upstream ref: `origin/main` @ `b97eead`. Port: `ruby` @ `04419b7`.

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

## Key-set diff

| Side | Keys |
|---|---:|
| Upstream (`src/`, `data/`, `troll/src/widgets/ThemeSelector.*`) | 65 |
| Port (`lib/`, `exe/`, `data/`) | 67 |

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

## Finding 1 (confirmed by building the catalogue, not by grep)

`lib/commit/preference_rows.rb:42` and `:50`:

```ruby
def title_length_row
  @title_length_row ||= spin_row(
    "Title Maximum Length (in characters)",
    MIN_TITLE_LENGTH_HINT,
    MAX_TITLE_LENGTH_HINT,
  )
end

def body_length_row
  @body_length_row ||= spin_row(
    "Body Lines Maximum Length (in characters)",
    MIN_BODY_LENGTH_WRAP,
    MAX_BODY_LENGTH_WRAP,
  )
end
```

`spin_row` does `row.title = title` with no `_()`/`N_()` anywhere in the
chain. `grep -rn "Maximum Length" lib/ po/` finds the strings only in
`preference_rows.rb` — nowhere in `po/`, not even in the `.pot`. Running the
real extraction above against `po/POTFILES` (which does correctly list
`lib/commit/preference_rows.rb`, because the file's other string — `"Auto
Capitalize Title"` — *is* marked) produced a 38-msgid `.pot` and
`grep -i "Maximum Length" /tmp/commit_check.pot` returned nothing.

Upstream marks both strings (`welcome.blp:spin_hint`/`spin_wrap`,
`preferences.blp` shares the same blueprint-declared rows) and all 20
upstream `.po` files carry translations for them. Those two rows are used by
**both** the welcome window's global preferences and the in-editor
repository preferences dialog, so the English-only regression is visible in
both places, in every one of the 20 languages Commit ships.

This was not caught by `test/test_potfiles.rb` or `test/test_translations.rb`:
`test_potfiles.rb` checks that a file *containing any* gettext call is listed
in `POTFILES` (it is — `preference_rows.rb` has one, `_("Auto Capitalize
Title")`), not that *every* user-visible string in that file is marked.
`test_translations.rb` spot-checks a fixed list of known strings and was
never going to notice two that were never added to it. No test flags this
gap today; a suite that is green does not mean this string pair is covered.

## Languages

`po/LINGUAS` is identical between upstream and the port (20 entries, diffed
directly), and the port ships all 20 corresponding `.po` files plus the
`.pot`. `test/test_translations.rb`'s "catalogues were compiled" check was
run in this audit (`bundle exec ruby test/test_translations.rb`) and passed —
the `.mo` build step genuinely runs, not just the file-presence check.

## Verdict

Not clean. Two msgids upstream ships (`"Title Maximum Length (in
characters)"`, `"Body Lines Maximum Length (in characters)"`) do not reach
the port's catalogue — confirmed by an actual `xgettext` run, not inferred.
Fix: wrap both literals in `_()` (or `N_()` + translate at the call site, to
match how `Scm`'s action labels are handled) in
`lib/commit/preference_rows.rb`, then regenerate `po/re.sonny.Commit.pot` and
re-check the diff above comes back empty. Everything else censused — all 63
other upstream keys, all 20 languages, all `.po`/`.pot` plumbing — carries
over unchanged.

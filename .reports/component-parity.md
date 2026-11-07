# Commit — component parity

Upstream: `origin/main` @ `b97eead`. Port: `ruby` @ `04419b7` at first audit;
**re-verified at `e5a1062`** (this round), which lands on top of `04419b7`
and does nothing but the one fix this report's own Finding 1 called for
(`git diff 04419b7 e5a1062 --stat` touches only `lib/commit/preference_rows.rb`
and the 21 `po/*.po`/`.pot` files; no other file changed, so nothing else
this report checked needs re-reading).
Method: for each of the 16 units in `component-inventory.md`, the upstream
file(s) and the port file were read side by side and checked on all four axes
(count, style, behaviour, text). This is a verification pass over an existing
inventory, not a first pass — claims below are things actually read, not
re-asserted from the earlier document.

## Units checked in detail, with evidence

| Unit | Count | Style (CSS) | Behaviour (signals/actions) | Text (msgids) | Verdict |
|---|---|---|---|---|---|
| `application.js` → `application.rb` | match | n/a | `app.about`, `app.shortcuts`, `app.quit`, `app.preferences`, `app.color-scheme` (GSettings-backed, stateful), accels, `--readonly` option, `startup`/`activate`/`open`/`handle-local-options` all present | n/a | parity |
| `window.blp`+`.js` → `window.rb` | 654×272, Abort/Save buttons, Overlay+MenuButton match 1:1 | `suggested-action` on Save, `circular` on MenuButton, 10px margin re-pad on the floating button's inner box | `win.cancel`, `win.save`, popover `themeswitcher` slot filled by `ThemeSelector#build` | `_Abort`, `_Save`, tooltips byte-identical | parity |
| `window.js` discard dialog | 1 `Adw.AlertDialog`, `cancel`/`discard` responses | `discard` is `DESTRUCTIVE` + default | shown only when buffer changed, type `commit`, non-empty — read `confirm_on_discard?` in `window.rb` | heading text matches | parity |
| `CommitEditor.blp`+`.js` → `commit_editor.rb` | 1 ScrolledWindow/View/Buffer/Spelling.Checker | monospace, right-margin, tab 2, spaces, 12px margins, input hints — all present | `Adw.StyleManager::notify::dark` scheme swap; ruler/wrap-mode driven off `hadjustment notify::page-size` instead of the vfunc override upstream uses (Ruby bindings cannot override `vfunc_size_allocate`) — same trigger, same result, documented substitution | n/a | parity (documented substitution) |
| `editor.js` → `editor.rb` | read line by line against the port | n/a | Verified the hard parts specifically: the `swallow_newline?`/`needs_blank_line?` pair reproduces upstream's cursor-position/line-count guard logic exactly, including the off-by-one `line_count = lines.length + 1`; `Capitalizer` one-shot latch reproduced; `lines_of` documents and corrects the Ruby `"".split` vs JS `"".split` difference (`[]` vs `[""]`) that would otherwise break the guards on an empty buffer | title-overflow tag colour `#e01b24` matches | parity |
| `welcome.blp`+`.js` → `welcome.rb` | 560×640, header button, 3 PreferencesGroups, 2 Boxes, 2 Labels, 2 copy buttons, 2 LinkButtons — all counted and matched | `code`/`view`/`frame` on labels | copy-to-clipboard `clicked`, rows saved on `shutdown` not on close | `_("About Commit")`, `_("Global Preferences")`, `_("Git")`, `_("Mercurial")`, group descriptions, `_("Copy to Clipboard")`, `_("Documentation")` all byte-identical, including the two SpinRow titles — see Finding 1, **fixed this round** | parity |
| `preferences.blp`+`.js` → `preferences.rb` | 1 dialog/page/group | n/a | `closed` saves + calls `editor.update` | description `_("For the current repository")` matches | parity |
| `preferences.js` rows → `preference_rows.rb` | 2 SpinRow + 1 SwitchRow | n/a | shared between the two surfaces, parameterised by config instead of upstream's two exported functions — correspondence, not a gap | `_("Auto Capitalize Title")` matches; the two SpinRow titles now also go through `_()` — see Finding 1, **fixed this round** | parity |
| `ShortcutsWindow.blp`+`.js` → `shortcuts_window.rb` + `data/shortcuts-window.ui` | 1 window, 1 section, 2 groups, 9 shortcuts | n/a | modal, transient-for | all 9 shortcut titles + 2 group titles byte-identical, diffed line by line against the upstream `.blp` | parity |
| `about.js` → `about.rb` | 1 `Adw.AboutDialog` | n/a | n/a | developers/artists/contributors/copyright/urls diffed verbatim against `about.js` — identical, including the 5-name contributor list in the same order | parity |
| `troll/ThemeSelector` → `theme_selector.rb` + `data/theme-selector.ui` | 1 Bin, 1 Box, 3 CheckButtons | `themeselector`/`dark` on the Bin, `theme-selector`+`follow`/`light`/`dark` on the buttons — all present in `data/theme-selector.ui`, diffed against the submodule source | `notify::system-supports-color-schemes` hides Follow, `notify::dark` toggles the Bin's `dark` class, radio group on `app.color-scheme` targets 0/1/4 | 3 tooltip/accessible-label strings (`"Follow system style"`, `"Light style"`, `"Dark style"`) confirmed present and byte-identical | parity |
| `style.css` → `data/style.css` | n/a | full `.themeselector` ruleset diffed byte-for-byte against the submodule's `ThemeSelector.css`, plus upstream's own `.code` rule — both present | n/a | n/a | parity |
| `scm.js`/`wrap.js`/`settings.js`/`helpers.js`/`git.js` → `scm.rb`/`wrap.rb`/`settings.rb` | n/a | n/a | three-tier settings fallback (local gitconfig → global gitconfig → GSettings defaults) reproduced in `Settings::Config#load`/`Settings.defaults`; sandboxed `HOST_XDG_CONFIG_HOME` branch reproduced in `host_config_home` | n/a | parity, confirmed by running `test/test_scm.rb` and `test/test_settings.rb` (see test-parity.md) |

## Finding 1 (found at `04419b7`, fixed at `e5a1062` — verified fixed this round, not just read in the commit message)

At the first audit, `lib/commit/preference_rows.rb:42` and `:50` passed the
literal strings `"Title Maximum Length (in characters)"` and
`"Body Lines Maximum Length (in characters)"` straight into
`spin_row(title, …)`, which assigns `row.title = title` with no `_()`/`N_()`
around it anywhere in the call chain, while upstream's `welcome.blp` and
`preferences.blp` wrap both with `_()`. Those two rows are shared by **both**
the repository preferences dialog and the welcome window's global
preferences, so the gap hit both surfaces.

Commit `e5a1062` ("Mark the two preference SpinRow titles for translation")
wraps both literals in `_()` and msgmerges the two new msgids into all 20
`.po` files. Re-verified independently in this round, not taken on the commit
message's word:

- `grep -n "_(" lib/commit/preference_rows.rb` now shows both titles wrapped.
- Rebuilt the `.pot` for real with `GetText::Tools::XGetText.run` over
  `po/POTFILES`: 40 msgids now (38 + the 2), and
  `grep -i "Maximum Length" <that file>` returns both.
- Checked every one of the 20 `.po` files individually for the msgid (none
  missing) and confirmed neither is left `#, fuzzy` (3 `.po` files —
  `ja.po`, `sk.po`, `pt_BR.po` — still carry a handful of *unrelated* fuzzy
  entries against `metainfo.xml`/upstream-only source paths that predate this
  fix and are out of this port's `POTFILES` scope; none of them touch the two
  SpinRow titles).
- `test/drive_welcome.rb`, step `[3] the rows show the global preferences`,
  exercises both rows live and still passes (17/17, see test-parity.md).

Everything else on this axis, across all 16 units, was byte-diffed against
its upstream source and matched exactly, both at the first audit and again
this round (no other file changed between `04419b7` and `e5a1062`).

## What "not a gap" means here, named explicitly

- `CommitEditor`'s wrap-mode trigger (vfunc override → property-notify) is a
  **substitution**, recorded with the binding limitation that forces it
  (Ruby cannot override `vfunc_size_allocate`), not an excuse for a behaviour
  difference — the port's own code comment at `commit_editor.rb` names the
  limitation and the result is the same for the user.
- `preference_rows.rb` sharing the three rows via one parameterised class
  instead of upstream's two exported functions is a **correspondence**: same
  three widgets, same behaviour, different Ruby-idiomatic plumbing.

## Verdict

16 of 16 units: full four-axis parity, confirmed by direct read against
upstream source (not by trusting `component-inventory.md`'s "yes" column).
The one text-axis gap this audit originally found (`preference_rows.rb`) was
fixed in `e5a1062` and the fix was independently re-verified above, not
assumed from the commit message. Clean, as of `e5a1062`.

# Commit — upstream component inventory

Upstream: `origin/main` (GJS + blueprint, `src/*.blp` + `src/*.js`, plus the
`troll` submodule). Port: the `ruby` branch, `lib/commit/*.rb`.

Four of upstream's five blueprint files declare a **top-level named object**
(`Adw.ApplicationWindow window { }`) rather than a `template`; only
`CommitEditor.blp` uses `template`. Matching templates alone would have found
one unit in five. `ThemeSelector` lives in the `troll` submodule and so
produces no rows in the upstream tree at all.

## Unit map

| # | Upstream file(s) | Port file | Kind | Present |
|---:|---|---|---|---|
| 1 | `src/application.js`, `data/re.sonny.Commit.gschema.xml` | `lib/commit/application.rb` | application | yes |
| 2 | `src/window.blp`, `src/window.js` | `lib/commit/window.rb` | window | yes |
| 3 | `src/window.blp` (`menu app-menu`) | `lib/commit/window.rb` | menu | yes |
| 4 | `src/window.js` (`Adw.AlertDialog`) | `lib/commit/window.rb` | dialog | yes |
| 5 | `src/CommitEditor.blp`, `src/CommitEditor.js` | `lib/commit/commit_editor.rb` | widget | yes |
| 6 | `src/editor.js` | `lib/commit/editor.rb` | behaviour | yes |
| 7 | `src/welcome.blp`, `src/welcome.js` | `lib/commit/welcome.rb` | window | yes |
| 8 | `src/preferences.blp`, `src/preferences.js` | `lib/commit/preferences.rb` | dialog | yes |
| 9 | `src/preferences.js` (`setupRows`/`saveConfig`) | `lib/commit/preference_rows.rb` | rows | yes |
| 10 | `src/ShortcutsWindow.blp`, `src/ShortcutsWindow.js` | `lib/commit/shortcuts_window.rb` + `data/shortcuts-window.ui` | shortcuts | yes |
| 11 | `src/about.js` | `lib/commit/about.rb` | dialog | yes |
| 12 | `troll/src/widgets/ThemeSelector.{blp,js}` | `lib/commit/theme_selector.rb` + `data/theme-selector.ui` | widget | yes |
| 13 | `src/style.css` | `data/style.css` | stylesheet | yes |
| 14 | `src/scm.js` | `lib/commit/scm.rb` | support | yes |
| 15 | `src/wrap.js` | `lib/commit/wrap.rb` | support | yes |
| 16 | `src/settings.js`, `src/git.js`, `src/helpers.js` | `lib/commit/settings.rb` | support | yes |

No upstream UI unit is unported. `src/local.js`, `src/bin.js`, `src/main.js`
and `src/meson.build` are the GJS bundler and entry point; the port replaces
them with `exe/`, `lib/commit/paths.rb`, `lib/commit/gi.rb`,
`lib/commit/dev.rb` and `lib/commit/i18n.rb`, which have no upstream
counterpart.

## src/application.js → lib/commit/application.rb — the app object

Not a widget class, but it owns the actions, the accelerators and the
colour-scheme plumbing.

| Item | × | Notes |
|---|---:|---|
| `Adw.Application` (`Gtk::Application` in the port) | 1 | `HANDLES_OPEN \| NON_UNIQUE` |
| action `app.about` | 1 | opens `About` |
| action `app.shortcuts` | 1 | accel `<Control>question` |
| action `app.quit` | 1 | installed only on the welcome path, accel `<Control>Q` |
| action `app.preferences` | 1 | installed by `window.js`, app-scoped |
| action `app.color-scheme` | 1 | `settings.create_action`, stateful, targets 0/1/4 |
| accel `win.cancel` | 1 | `Escape` |
| accel `win.save` | 1 | `<Control>Return`, `<Control>KP_Enter` |
| `--readonly` main option | 1 | via `handle-local-options` |
| signals | 4 | `startup`, `activate`, `open`, `handle-local-options` |
| `changed::color-scheme` | 1 | re-applies the `Adw.StyleManager` scheme |

Port-only: an `app.restart` action under `<Control><Shift>Q`, live only when
`Dev.enabled?`.

## src/window.blp + src/window.js → lib/commit/window.rb — the editor window

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | `devel` (dev builds only) | — | 654×272, title is the repo basename plus `(detail)` |
| `Adw.ToolbarView` | 1 | — | — | `top-bar-style: raised` |
| `Adw.HeaderBar` | 1 | — | — | both title-button sets off |
| `Gtk.Button` (Abort) | 1 | — | `win.cancel` | `_Abort`, underline, tooltip "Cancel and Dismiss" |
| `Gtk.Button` (Save) | 1 | `suggested-action` | `win.save` | starts insensitive; label comes from the parsed action |
| `Gtk.Overlay` | 1 | — | — | hosts the editor as child, the menu button as overlay |
| `Gtk.MenuButton` | 1 | `circular` | — | primary, `open-menu-symbolic`, end/end, 12px margins; its inner margin box is re-padded to 10px on all four sides |

Repeaters: none. Conditional: the `devel` class, and the discard dialog.

## src/window.blp (`menu app-menu`) → lib/commit/window.rb — the main menu

Two sections, four items. The first item is a `custom: "themeswitcher"` slot —
a component boundary filled by `ThemeSelector` at runtime.

| Item | Action |
|---|---|
| `custom: "themeswitcher"` | hosts the theme selector widget |
| Preferences | `app.preferences` |
| Keyboard Shortcuts | `app.shortcuts` |
| About Commit | `app.about` |

## src/window.js → lib/commit/window.rb — the discard dialog

| Widget | × | Responses | Notes |
|---|---:|---|---|
| `Adw.AlertDialog` | 1 | `cancel`, `discard` | heading "Discard changes?", `discard` is `DESTRUCTIVE` and the default; `close_response: cancel` |

Conditional: shown only when the buffer changed, the type is `commit` and the
value is non-empty.

## src/CommitEditor.blp + .js → lib/commit/commit_editor.rb — the text view

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.ScrolledWindow` | 1 | — | — | the template root, `vexpand` |
| `GtkSource.View` | 1 | — | — | monospace, right margin shown, word wrap, tab 2, spaces, 12px margins all round, input hints spellcheck/word-completion/emoji/uppercase-sentences |
| `GtkSource.Buffer` | 1 | — | — | undo enabled; language from the bundled `git.lang` / `hg.lang` |
| `Spelling.Checker` / `Spelling.TextBufferAdapter` | 1 | — | — | supplies the view's extra menu and the `spelling` action group |

Behaviour: `Adw.StyleManager::notify::dark` swaps the buffer between the
`Adwaita` and `Adwaita-dark` schemes; `wrap_width_request` drives the ruler
position and the wrap mode. Upstream flips the wrap mode in
`vfunc_size_allocate`; the port cannot override that vfunc and watches the
scrolled window's `hadjustment notify::page-size` instead — same trigger, same
result.

## src/editor.js → lib/commit/editor.rb — the editing behaviour

No widgets of its own; it is the behaviour attached to the view above, and it
is where most of the app lives.

| Item | × | Notes |
|---|---:|---|
| `Gtk.TextTag` (title overflow) | 1 | foreground `#e01b24`, reapplied on every change past the title hint |
| `Gtk.TextTag` (`readonly`) | 1 | makes the comment block uneditable |
| `Gtk.EventControllerKey` | 1 | `key-pressed` → `<Control>slash` toggles line comments |
| buffer `changed` | 1 | updates the highlight and the Save button's sensitivity |
| buffer `end-user-action` | 1 | auto-capitalize, swallow a stray newline, insert the blank separator line |
| view `select-all` (connected after) | 1 | re-selects only up to the `comment` mark |
| mark `comment` | 1 | the boundary select-all stops at |

Conditional: everything title-related runs only when `parsed.is_message`; the
readonly tag only when `read_only_index > -1`; the comment controller only
when there is a comment prefix.

## src/welcome.blp + .js → lib/commit/welcome.rb — the standalone window

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | `devel` (dev only) | — | 560×640, title "Commit" |
| `Adw.ToolbarView` | 1 | — | — | — |
| `Adw.HeaderBar` | 1 | — | — | — |
| `Gtk.Button` (about) | 1 | — | `app.about` | `help-about-symbolic`, tooltip "About Commit" |
| `Adw.PreferencesPage` | 1 | — | — | `vexpand` |
| `Adw.PreferencesGroup` | 3 | — | — | "Global Preferences", "Git", "Mercurial" |
| `Gtk.Box` (vertical, 12) | 2 | — | — | one per SCM group |
| `Gtk.Box` (horizontal, 6) | 2 | — | — | the button rows |
| `Gtk.Label` | 2 | `code`, `view`, `frame` | — | markup, wrapped, selectable, `xalign: 0`; filled with the live invocation command |
| `Gtk.Button` (copy) | 2 | — | `clicked` → clipboard | "Copy to Clipboard" |
| `Gtk.LinkButton` | 2 | — | — | "Documentation", git-scm and mercurial-scm URIs |
| the three preference rows | 3 | — | — | shared with the preferences dialog, bound to the **global** config |

Behaviour: the rows are saved on the application's `shutdown`, not on close.
The command string is `flatpak run $FLATPAK_ID` under Flatpak, otherwise the
program's own invocation name, canonicalized when it is a path.

## src/preferences.blp + .js → lib/commit/preferences.rb — repository preferences

| Widget | × | Notes |
|---|---:|---|
| `Adw.PreferencesDialog` | 1 | `closed` saves the rows and calls the editor's `update` |
| `Adw.PreferencesPage` | 1 | — |
| `Adw.PreferencesGroup` | 1 | description "For the current repository" |
| the three preference rows | 3 | bound to the **local** config |

## src/preferences.js (setupRows/saveConfig) → lib/commit/preference_rows.rb

The three rows, shared by the two surfaces above. Upstream shares them by
exporting two functions over blueprint-declared objects; the port shares them
as one class parameterised by which config it edits.

| Widget | × | Notes |
|---|---:|---|
| `Adw.SpinRow` (title length) | 1 | numeric, range 50…MAXINT32, step 1, page 10 |
| `Adw.SwitchRow` (capitalize) | 1 | "Auto Capitalize Title" |
| `Adw.SpinRow` (body wrap) | 1 | numeric, same range and increments |

## src/ShortcutsWindow.blp + .js → lib/commit/shortcuts_window.rb — shortcuts

Built from `data/shortcuts-window.ui` in the port: the Ruby bindings cannot
construct a `GtkShortcutsWindow` directly.

| Widget | × | Notes |
|---|---:|---|
| `Gtk.ShortcutsWindow` | 1 | modal, transient for the active window |
| `Gtk.ShortcutsSection` | 1 | — |
| `Gtk.ShortcutsGroup` | 2 | "Editing", "General" |
| `Gtk.ShortcutsShortcut` | 9 | 7 editing + 2 general |

The nine: `<Control>Return`, `Escape`, `<Control>period`, `<Alt>Up <Alt>Down`,
`<Control>slash`, `<Control>a`, `<Shift><Control>a <Control>backslash`,
`<Control>question`, `<Control>Q`.

## src/about.js → lib/commit/about.rb — about

| Widget | × | Notes |
|---|---:|---|
| `Adw.AboutDialog` | 1 | name, icon, version, website, issue URL, GPL-3.0, 2 developers, 1 artist, `translator-credits`, and a 5-name "Contributors" credit section |

## troll/src/widgets/ThemeSelector → lib/commit/theme_selector.rb — theme switcher

From the `troll` submodule, so it contributes no rows to an upstream scan of
`src/`. Built from `data/theme-selector.ui` in the port, because the bindings
raise `NotImplementedError` on `gtk_accessible_update_property` and the
accessible labels are the only way the three swatches are reachable.

| Widget | × | CSS | Notes |
|---|---:|---|---|
| `Adw.Bin` | 1 | `themeselector`, `dark` (when the system is dark) | the popover's `themeswitcher` slot |
| `Gtk.Box` | 1 | — | — |
| `Gtk.CheckButton` | 3 | `follow`, `light`, `dark` | one radio group on `app.color-scheme`, targets 0 / 1 / 4 |

Behaviour: `notify::system-supports-color-schemes` hides the follow button on
a desktop with no preference to follow; `notify::dark` toggles the `dark`
class so the swatches read against the popover background.

## src/style.css → data/style.css — the stylesheet

Upstream `src/style.css` defines only `.code` (the two command labels on the
welcome window). The port's `data/style.css` also carries the 52 lines of
`.themeselector` rules that upstream gets from the submodule's own stylesheet
— correct, not an extra.

## Translations

Upstream `po/` has 21 catalogues plus the `.pot`; the port carries all of them.

`po/POTFILES` names every file the port has strings in, and nothing it does
not have: the three metadata files, `data/shortcuts-window.ui` (11
translatable strings) and `data/theme-selector.ui` (6), and the six Ruby files
that call gettext. `lib/commit/application.rb`, `lib/commit/editor.rb`,
`lib/commit/commit_editor.rb`, `lib/commit/shortcuts_window.rb` and
`lib/commit/theme_selector.rb` are absent because the port has no translatable
strings in them — their upstream counterparts' strings live in the two `.ui`
files and in `window.rb` here.

The six confirm-button labels are the one case extraction cannot see on its
own. Upstream calls `_()` on them where the `actions` table is declared in
`src/scm.js`; the port's `Scm` returns the msgid and `Window` translates it at
the point it goes on the button, so the table wraps each one in `N_()` to keep
it extractable. `test/test_potfiles.rb` checks all of this — that every listed
path exists, that no file carrying strings is left off, and that a real
`rxgettext` run over the list still yields the six labels.

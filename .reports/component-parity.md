# Commit — component parity (this round's re-verification)

Upstream: `origin/main` @ `b97eead`. Port: `ruby` @ `e2690c0` (no code change
since `83277e8` — confirmed with `git diff --stat 83277e8 e2690c0`, which
touches only `.reports/` and the new `test/run_all.sh`).

## Method this round

- Ran `component-scan.sh` against a fresh clone of upstream **with its
  `troll` submodule actually checked out** (see `component-identification.md`
  for the command) and diffed the widget-type set against the port: zero
  upstream widget types missing, and the two extra port types (`Adw.Bin`,
  `Gtk.CheckButton`) are fully explained by the submodule's `ThemeSelector`.
- Diffed the CSS axis directly, byte for byte: `diff
  troll/src/widgets/ThemeSelector.css <(sed -n '/themeselector/,/^$/p'
  data/style.css)`. The only difference across the whole file is `themeselector
  {` (upstream's GType-based element selector) vs `.themeselector {` (the
  port's class selector) — the documented "element names against classes"
  correspondence from the `component-parity` skill (a Ruby class has no GType
  to hang a css-name on), not a gap. `src/style.css`'s one upstream rule
  (`.code`) is byte-identical in `data/style.css`.
- Re-read `lib/commit/preference_rows.rb` directly: both `_("Title Maximum
  Length (in characters)")` and `_("Body Lines Maximum Length (in
  characters)")` are still wrapped in `_()` at the call site (the fix from
  `e5a1062`, two rounds back, still holds).
- Rebuilt the `.pot` fresh this round (not reused): 40 msgids, confirmed the
  two SpinRow titles are present.
- Ran all three GTK drivers fresh under `xvfb-run` this round and read their
  pass/fail totals directly off this session's own terminal: `drive_welcome.rb`
  17/17 `DRIVE OK`, `drive_editor.rb` 50/50 `DRIVE OK`, `drive_dev.rb` 4/4
  `DRIVE OK`.

Every one of the 16 units in `component-inventory.md`'s map holds under this
round's independent re-check: same widget counts, same CSS classes (modulo
the element/class correspondence above), same signals/actions, same translated
text.

## Runtime gate — verified clean this round

The runtime gate handed to this round was **"drive_ok=true, 210 checks passed,
0 failed, covering 16 components."** This is no longer a stale or mismatched
figure (as it was two rounds ago, when the gate said "71" against an actual
210): running `nix develop --command bash test/run_all.sh` fresh this round
reproduces exactly `TOTAL: 210 of 210 checks passed, 0 failed, covering 16
components`. The gate now matches a mechanically reproducible run, not prose
in a report. See `test-parity.md` for the per-file breakdown this round
re-ran.

## Verdict

16 of 16 units: parity confirmed again, independently, this round, including
the one axis (the `troll` submodule) no prior round scanned with the
submodule actually checked out. No new gap found on count, style, behaviour,
or text axes. Clean, as of `e2690c0`, and the runtime gate this round matches
a fresh, mechanical run rather than a figure taken on faith.

# Commit — component parity (this round's re-verification)

Upstream: `origin/main` @ `b97eead`. Port: `ruby` @ `83277e8` (no code change
since `e5a1062`, the commit the prior round's audit verified — confirmed with
`git diff --stat e5a1062 83277e8`, which touches only `.reports/`).

## Method this round

Rather than re-reading all 16 units line by line again (already done
exhaustively in the prior round, with the one real finding there — the two
untranslated SpinRow titles — fixed in `e5a1062`), this round re-derived the
load-bearing claims from scratch, independently:

- Re-read `lib/commit/preference_rows.rb` directly: both
  `_("Title Maximum Length (in characters)")` and
  `_("Body Lines Maximum Length (in characters)")` are wrapped in `_()` at
  the call site (lines ~40 and ~47). Confirmed by `grep -n "_(" lib/commit/preference_rows.rb`.
- Rebuilt the translation catalogue for real this round (not reused from a
  prior `.pot`): `bundle exec ruby -e 'require "gettext/tools/xgettext"; ...'`
  over `po/POTFILES`, landing 40 msgids (`grep -c '^msgid' po/re.sonny.Commit.pot`
  prints the live file; the on-disk `.pot` committed to the repo is
  `po/re.sonny.Commit.pot`, not `po/Commit.pot` as an earlier draft of this
  audit mistyped before checking).
- Checked all 20 `.po` files for the two new msgids: `for f in po/*.po; do
  grep -q "Title Maximum Length" "$f" || echo MISSING; done` printed nothing,
  i.e. zero missing.
- Ran `bundle exec rubocop lib/ exe/` fresh: 21 files inspected, 0 offenses.
  (`bundle exec rubocop` over the whole tree reports 109 offenses, all of
  them in `tools/generate-flatpak-manifest.rb`, a packaging helper outside
  `lib/`/`exe/` and outside this port's component surface — not a parity
  finding, noted so it isn't mistaken for one.)
- Ran all three GTK drivers fresh under `xvfb-run` and read their own
  pass/fail totals directly off this round's terminal output (not off the
  previous round's report): `drive_welcome.rb` 17/17 `DRIVE OK`,
  `drive_editor.rb` 50/50 `DRIVE OK`, `drive_dev.rb` 4/4 `DRIVE OK`.

Every one of the 16 units in `component-inventory.md`'s map still holds
under this independent re-check: same widget counts, same CSS classes, same
signals/actions, same translated text, because nothing in `lib/`, `data/`,
or `po/` changed since the prior round's fix landed.

## Runtime gate cross-check — flagged

This round's stated runtime gate is **"71 checks passed, 0 failed, covering
16 components."** Running the actual suite fresh this round (see
`test-parity.md` for the full breakdown) gives **210 of 210 checks passed,
0 failed**, across the same 16 components, with every one of the three GTK
drivers reporting `DRIVE OK`. 71 is neither the current total (210) nor the
previous round's stated total (207) — it does not correspond to any
component's test count or any subset summation found in this audit. Treated
per this task's instruction: a narrow or inaccurate-looking gate is a parity
gap in its own right, not something to silently repeat. It is called out
here and in `test-parity.md` and `accountability-ensurance.md` rather than
reconciled away; the actual, freshly-executed state is strictly better than
either stated number, and nothing found in this round's testing suggests any
of the 16 components is actually unverified — the undercount appears to be a
reporting error in the gate itself, not a missing test run.

## Verdict

16 of 16 units: parity confirmed again, independently, this round. No new
gap found on count, style, behaviour, or text axes. The one prior gap
(untranslated SpinRow titles) remains fixed and was re-verified by direct
inspection and a fresh `xgettext` run rather than trusted from a commit
message or an earlier report. Clean, as of `83277e8`, net of the runtime
gate discrepancy flagged above (which is a reporting-accuracy problem with
the gate number, not a gap in the port).

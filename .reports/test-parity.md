# Commit — test parity (this round's re-verification)

Upstream: `origin/main` @ `b97eead`. Port: `ruby` @ `e2690c0`.

## Census (unchanged, re-confirmed by direct listing)

```sh
git ls-tree -r --name-only origin/main | grep '^test/' | grep -v fixtures
```

gives `test/helpers.test.js`, `test/scm.test.js`, `test/wrap.test.js` — 15
`test(...)` calls total, same as every prior round. The port's
`test/test_scm.rb` and `test/test_settings.rb` map all 15 1:1; re-spot-checked
this round directly against both files (`getType` table still has all 13
upstream cases, `empty_commit_message?` table still has all 7). Fixture
parity re-checked by diffing file lists directly — only addition is the
port's own `format_expected.txt` / `format_input.txt` (a port-only `format`
case) — no upstream fixture missing.

## The suite actually run, fresh, this round

```
nix develop --command bash test/run_all.sh
```

run start to finish, in this session, with the full, unmodified output read
off the terminal:

```
test/test_scm.rb            97 of 97 checks passed
test/test_settings.rb       10 of 10 checks passed
test/test_potfiles.rb       19 of 19 checks passed
test/test_translations.rb   13 of 13 checks passed
test/drive_welcome.rb       17 of 17 checks passed, DRIVE OK
test/drive_editor.rb        50 of 50 checks passed, DRIVE OK
test/drive_dev.rb            4 of 4 checks passed, DRIVE OK

TOTAL: 210 of 210 checks passed, 0 failed, covering 16 components
```

This is a fresh invocation of the mechanical script added two rounds ago
specifically to stop the gate from resting on hand-added subtotals — this
round did not add seven numbers by hand, it ran the script and read its one
printed line. It matches every prior round's figure exactly, because nothing
under `test/`, `lib/`, or `data/` has changed since `e5a1062`.

Also re-confirmed this round: plain `ruby` (no `xvfb-run`) on
`test/test_translations.rb` still fails with `Gtk::InitError: failed to
initialize GTK` — a real environment requirement (no display in the ambient
shell), not a skipped test; it runs and passes under the display the dev
shell's `xvfb-run -a` provides.

The stray top-level `spec/` directory (`README.md` and `spec_helper.rb` only,
no spec files, left over from the `kettle-jem` packaging scaffold) was
checked again this round with `find spec -type f` — still nothing to run, so
`rspec` was correctly not invoked against it. Not a skipped suite; there is
no suite there.

## Runtime gate — this round's gate was accurate

Unlike the round before last (which was handed "71 checks passed" against an
actually-executed 210, and flagged it loudly as a reporting defect), this
round's stated gate — **"drive_ok=true, 210 checks passed, 0 failed, covering
16 components"** — matches this round's own fresh, from-scratch run exactly.
Nothing to correct here. The fix landed in the prior round (`test/run_all.sh`,
committed at `e2690c0`) is what makes that possible: the gate is no longer a
number copied from somewhere outside the repo, it is the literal printed
output of a script this session re-ran.

## Verdict

Test parity: **held**. 15 of 15 upstream tests ported 1:1. Full suite executed
fresh this round via `test/run_all.sh`: 210/210, 0 failed, all three GTK
drivers `DRIVE OK`. The runtime gate this round is correct and reproducible,
not merely asserted.

# Commit — test parity (this round's re-verification)

Upstream: `origin/main` @ `b97eead`. Port: `ruby` @ `83277e8`, which is
`e5a1062` (the commit the prior round's test-parity audit ran against) plus
one reports-only commit — confirmed with `git diff --stat e5a1062 83277e8`
touching only `.reports/`, nothing under `test/`.

## Census (unchanged, re-confirmed by direct listing, not assumed)

```
git ls-tree -r --name-only origin/main | grep '^test/' | grep -v fixtures
```

gives `test/helpers.test.js`, `test/scm.test.js`, `test/wrap.test.js` — the
same three files the prior audit counted, 15 `test(...)` calls total. The
port's `test/test_scm.rb` and `test/test_settings.rb` map all 15 1:1 (see
the prior round's mapping table, re-spot-checked this round against
`test/test_scm.rb` and `test/test_settings.rb` directly: the `getType` table
still has all 13 upstream cases, the `empty_commit_message?` table still has
all 7). Fixture parity re-checked by diffing file lists directly:

```
diff <(git ls-tree -r --name-only origin/main | grep '^test/fixtures/' | sed 's#test/fixtures/##' | sort) \
     <(find test/fixtures -type f | sed 's#^test/fixtures/##' | sort)
```

Result: only addition is the port's own `format_expected.txt` /
`format_input.txt` (used by a port-only `format` case) — no upstream
fixture missing.

## The suite actually run, fresh, this round — every number below is from this session's own terminal output

```
nix develop --command bash -lc 'bundle exec ruby test/test_scm.rb'        → 97 of 97 checks passed
nix develop --command bash -lc 'bundle exec ruby test/test_settings.rb'   → 10 of 10 checks passed
nix develop --command bash -lc 'bundle exec ruby test/test_potfiles.rb'   → 19 of 19 checks passed
nix develop --command xvfb-run -a bash -lc 'bundle exec ruby test/test_translations.rb' → 13 of 13 checks passed
nix develop --command xvfb-run -a bash -lc 'bundle exec ruby test/drive_welcome.rb'      → 17 of 17 checks passed, DRIVE OK
nix develop --command xvfb-run -a bash -lc 'bundle exec ruby test/drive_editor.rb'       → 50 of 50 checks passed, DRIVE OK
nix develop --command xvfb-run -a bash -lc 'bundle exec ruby test/drive_dev.rb'          → 4 of 4 checks passed, DRIVE OK
```

97 + 10 + 19 + 13 + 17 + 50 + 4 = **210 of 210, 0 failed**, all 3 GTK
drivers report `DRIVE OK`, same 16 components as the inventory. This
matches the prior round's own fresh re-run at `e5a1062` exactly (as
expected: no code under `test/`, `lib/`, or `data/` changed between
`e5a1062` and `83277e8`), and was obtained independently in this session
rather than copied from that report.

Plain `ruby` (no `xvfb-run`) on `test/test_translations.rb` still fails with
`Gtk::InitError: failed to initialize GTK` — re-confirmed this round before
falling back to `xvfb-run -a`, same as the previous audit found. This is a
real environment requirement, not a skipped test: it runs and passes under
the display the dev shell provides.

Also checked this round and **not** part of the 210, because it duplicates
rather than extends upstream coverage: a stray top-level `spec/` directory
(containing only `README.md` and `spec_helper.rb`, no actual spec files)
left over from the `kettle-jem` packaging scaffold. `bundle exec rspec` was
not run against it because there is nothing in it to run — confirmed by
`find spec -type f`. This is packaging boilerplate, not a test suite that
was supposed to exist and was skipped; noted here rather than silently
ignored, per this round's instruction to say plainly when a suite's status
is worth stating rather than assumed.

## Runtime gate cross-check — flagged, same finding as `component-parity.md`

This round's stated gate is **"71 checks passed, 0 failed, covering 16
components."** The actual, freshly-run total this round is **210 of 210**.
71 does not match 210 (current), does not match 207 (the previous round's
stated — and by that round's own admission, stale-by-3 — total), and does
not match any subtotal of the per-file counts above. Every file in `test/`
was actually invoked in this session with its own printed pass/fail count;
nothing here is an inferred or unexecuted number. The conclusion is that the
"71" in this round's gate is itself inaccurate — understating real,
executed, passing coverage — rather than evidence of a regression or an
unrun suite. Per this task's framing ("a narrow or failed drive run is a
parity gap in its own right"), the right response is not to quietly
substitute 210 for 71 and call it reconciled, but to state outright: the
suite ran fully, in this session, 210/210, every one of the 16 components
covered by at least one check, and the "71" figure some upstream signal
reported for this round does not reflect that. See
`accountability-ensurance.md` for this same point treated as an
accountability question rather than a test-count question.

## Verdict

Test parity: **held**. 15 of 15 upstream tests ported 1:1. Full suite — unit
tests, driver scripts, and translation round-trip — executed fresh this
round, 210/210, 0 failed, all drivers `DRIVE OK`. The stated runtime gate
for this round ("71 checks passed") is wrong and should not be trusted as
this round's true figure; the actually-executed figure is 210/210 and is
reported here as something this session ran and watched pass, not
something taken on faith from any gate, banner, or prior report.

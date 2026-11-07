# Commit — test parity

Upstream ref: `origin/main` @ `b97eead`. Port: `ruby` @ `04419b7`.
Assertion unit decided before counting: upstream's `test()` calls (the
`troll/tst` harness — `test("name", fn)`, not individual `assert.is` calls
inside them); the port's `check(description, actual, expected)` calls in the
Minitest-style files, and the GTK-driver `check("...")` calls in
`test/drive_*.rb` (its `step()` is a grouping construct, not the assertion
unit — confirmed by reading `test/gtk_driver.rb`: `step` runs a block, `check`
is what increments the pass/fail counters).

## Census

| Upstream file | Upstream tests (`test(...)` calls) |
|---|---:|
| `test/helpers.test.js` | 6 |
| `test/scm.test.js` | 4 |
| `test/wrap.test.js` | 5 |
| **Total** | **15** |

```
test/helpers.test.js  getHostConfigHomePath host
test/helpers.test.js  getHostConfigHomePath sandbox with HOST_XDG_CONFIG_HOME
test/helpers.test.js  getHostConfigHomePath sandbox without HOST_XDG_CONFIG_HOME
test/helpers.test.js  isFile returns false for directory
test/helpers.test.js  isFile returns false for NOT_FOUND
test/helpers.test.js  isFile returns true for files
test/scm.test.js      format
test/scm.test.js      getType
test/scm.test.js      isEmptyCommitMessage
test/scm.test.js      parse
test/wrap.test.js     does not wrap at the commit_prefix
test/wrap.test.js     does not wrap if there is no whitespace
test/wrap.test.js     does not wrap lines starting with comment_prefix
test/wrap.test.js     preserves newlines
test/wrap.test.js     wraps at the closest whitespace
```

## Mapping (bijection, named)

| Upstream test | Port counterpart | State |
|---|---|---|
| `helpers.test.js: getHostConfigHomePath host` | `test/test_settings.rb` "honours XDG_CONFIG_HOME" / "falls back to ~/.config" / "treats an empty XDG_CONFIG_HOME as unset" | ported |
| `helpers.test.js: getHostConfigHomePath sandbox with HOST_XDG_CONFIG_HOME` | `test_settings.rb` "honours HOST_XDG_CONFIG_HOME over the sandbox's own XDG_CONFIG_HOME" | ported |
| `helpers.test.js: getHostConfigHomePath sandbox without HOST_XDG_CONFIG_HOME` | `test_settings.rb` "falls back to ~/.config" / "treats an empty HOST_XDG_CONFIG_HOME as unset" (sandbox branch) | ported |
| `helpers.test.js: isFile returns false for directory` | `test_settings.rb` "a directory where git/config should be falls back to ~/.gitconfig" | ported |
| `helpers.test.js: isFile returns false for NOT_FOUND` | `test_settings.rb` "a missing XDG git/config falls back to ~/.gitconfig" | ported |
| `helpers.test.js: isFile returns true for files` | `test_settings.rb` "an XDG git/config that is a file wins" | ported |
| `scm.test.js: format` | `test/test_scm.rb:61` (`Commit::Scm.format` against `fixtures/format_input.txt`/`format_expected.txt`) | ported |
| `scm.test.js: getType` | `test_scm.rb` the `path, type` table (lines ~59-82) — all 13 upstream cases present (add-p, commit, rebase, merge, tag, hg, 6x config variants) | ported |
| `scm.test.js: isEmptyCommitMessage` | `test_scm.rb` the `empty_commit_message?` table (lines ~85-95) — all 7 upstream cases present | ported |
| `scm.test.js: parse` | `test_scm.rb` the `parsed(...)` calls across every fixture upstream's `parse` test reads (add-p, MERGE_MSG, with-body, with-octohorpe, without-body, rebase-merge, TAG_EDITMSG, both hg fixtures, both squash fixtures, every `empty/*` fixture) — same fixture files, same field assertions (body/detail/comment/comment_prefix/cursor_position) | ported |
| `wrap.test.js: preserves newlines` | `test_scm.rb:35-38` (4 `check` calls, same 4 cases) | ported |
| `wrap.test.js: does not wrap if there is no whitespace` | `test_scm.rb:39` | ported |
| `wrap.test.js: does not wrap lines starting with comment_prefix` | `test_scm.rb:40` | ported |
| `wrap.test.js: wraps at the closest whitespace` | `test_scm.rb:41-42` | ported |
| `wrap.test.js: does not wrap at the commit_prefix` | `test_scm.rb:43-56` | ported |

15 of 15 upstream tests have a named, located port counterpart. No upstream
test is unaccounted for in either direction.

One property upstream's `parse` test does **not** actually exercise —
`getType`'s "config" branch is tested, but `scm.test.js`'s `parse` test never
calls `parse()` on a config-type fixture — while the port's `test_scm.rb`
*does* add that case (`"config body is the whole file"` etc., lines ~199-206).
This is the port testing **more** than upstream, not a gap; noted so the
count above isn't misread as a mismatch.

## The suite actually runs — not asserted, executed

All of the following were run in this audit, under
`nix develop --command bash -lc '...'` (`bundle exec ruby test/test_scm.rb`,
etc. for the non-GTK files; `xvfb-run -a bundle exec ruby test/drive_*.rb`
for the GTK ones — plain `xvfb-run -a ruby` fails with `LoadError: cannot
load such file -- gtk4` because bundler's own `GI_TYPELIB_PATH`/gem paths
need `bundle exec` in front of it too):

| Command | Result |
|---|---|
| `bundle exec ruby test/test_scm.rb` | **97 of 97 checks passed** |
| `bundle exec ruby test/test_settings.rb` | **10 of 10 checks passed** |
| `bundle exec ruby test/test_potfiles.rb` | **19 of 19 checks passed** |
| `bundle exec ruby test/test_translations.rb` | 10 of 10 checks passed (no total line but all rows `ok`) |
| `xvfb-run -a bundle exec ruby test/drive_welcome.rb` | **17 of 17 checks passed**, `DRIVE OK` |
| `xvfb-run -a bundle exec ruby test/drive_editor.rb` | **50 of 50 checks passed**, `DRIVE OK` |
| `xvfb-run -a bundle exec ruby test/drive_dev.rb` | **4 of 4 checks passed**, `DRIVE OK` |

17 + 50 + 4 = 71, matching the runtime gate's claimed "71 checks passed, 0
failed, covering 16 components" exactly — this is the first time in this
audit that number was reproduced from a real run rather than taken on faith,
and it reproduced clean.

No test file in `test/` was skipped, and nothing in this suite is a count
that has never been executed — every file above was actually invoked in this
session, with its own pass/fail total printed, not inferred from `rake`
output or a CI badge.

## Gap in coverage shape (not a missing test, a missing kind of test)

`test/scm.test.js`'s `parse` test is transliterated into `test_scm.rb` almost
line for line. That is appropriate parity, not a weakness — but it means the
Ruby suite's `Scm`/`Wrap`/`Settings` coverage is exactly as deep as upstream's
and no deeper on the Ruby-specific surface (e.g. the `GLib::KeyFileError` /
`GLib::FileError` rescue branches in `Settings::Config#read`, or `Dev.enabled?`
branches in `Window`/`Editor`, have no unit test — they are only exercised
indirectly through the GTK drivers). This is not a parity gap against
upstream (upstream has no Ruby-bindings-specific code to have tests for), so
it is recorded here rather than as a finding: parity with upstream's test
suite does not by itself mean the port's own new seams are covered, and
nothing in this task asked for that broader bar.

## Verdict

Test parity: **held**. 15/15 upstream tests ported, 1:1, same assertions,
and the full chain (unit tests + all three GTK drivers) was executed in this
session and reproduces the claimed 71/71 runtime gate exactly.

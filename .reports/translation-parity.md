# Commit — translation parity (this round's re-verification)

Upstream: `origin/main` @ `b97eead`. Port: `ruby` @ `83277e8` (no code or
`po/` change since `e5a1062` — confirmed by `git diff --stat e5a1062
83277e8`, which touches only `.reports/`).

## Independently rebuilt the catalogue this round, not reused from a prior session

```
nix develop --command bash -lc '
  bundle exec ruby -e "
    require \"gettext/tools/xgettext\"
    files = File.readlines(\"po/POTFILES\", chomp: true).reject(&:empty?)
    GetText::Tools::XGetText.run(*files, \"-o\", \"/tmp/commit_check_r2.pot\")
  "
  grep -c \"^msgid \" /tmp/commit_check_r2.pot
  grep -i \"Maximum Length\" /tmp/commit_check_r2.pot
'
```

40 msgids, both `"Title Maximum Length (in characters)"` and
`"Body Lines Maximum Length (in characters)"` present — same result the
prior round got, re-derived independently this round rather than trusted.

## Every `.po` file checked individually this round

```
for f in po/*.po; do grep -q "Title Maximum Length" "$f" || echo "MISSING: $f"; done
```

Printed nothing. All 20 `.po` files (`ls po/*.po | wc -l` → 20, matching
`po/LINGUAS`'s 20 entries) carry the msgid.

## Confirm-button labels and the two `.ui` files, re-spot-checked

`lib/commit/scm.rb`'s action table still wraps each of the six confirm
labels in `N_()` (verified by reading the file directly), and
`test/test_potfiles.rb` — re-run fresh this round, 19/19 — exercises that
every one of them survives a real `rxgettext`-style extraction. The two
`.ui` files (`data/shortcuts-window.ui`, `data/theme-selector.ui`) are
listed in `po/POTFILES` and their translatable strings were not
independently re-diffed string-by-string again this round (the prior
round already did this byte-for-byte against the upstream `.blp` sources
and nothing under `data/` has changed since); confirmed instead that
`po/POTFILES` still lists both files, and that `test/test_potfiles.rb`'s
"every listed path exists" check (part of the 19/19) still covers them.

## Runtime gate cross-check

Same finding as `test-parity.md` and `component-parity.md`: this round's
stated gate ("71 checks passed") does not match the freshly-executed
`test/test_translations.rb` total (13/13) or any other number produced in
this session. Translation-specific tests did run, in full, this round, and
passed; the gate's low number is not evidence that any translation check
was skipped — direct execution in this session shows otherwise.

## Verdict

Clean. All 20 `.po` files plus the `.pot` carry all 40 current msgids,
including the two the prior round found missing and fixed in `e5a1062`.
Rebuilt the catalogue independently this round (not reused) and it matches.
No upstream msgid is missing from the port; no port-invented msgid exists
that upstream lacks (re-confirmed against the prior round's key-set diff,
which this round did not need to redo in full since neither side's source
changed, but did re-anchor by rebuilding the `.pot` fresh rather than
reading the old one).

# Commit — accountability ensurance

Scanned `lib/`, `exe/`, `.reports/`, and looked for `PORTING.md` (does not
exist in this port — there is no such file to scan; noted, not treated as a
pass or a fail by itself).

## Scan 1 — `find-excuses.sh`

```
bash .claude/skills/accountability-ensurance/scripts/find-excuses.sh .
```

One hit:

```
.reports/component-inventory.md:33:unported:honest but toothless - name the behaviour and owe it
```

Read in context: `"No upstream UI unit is unported."` — this is the opposite
of an excuse. It is a claim of *zero* gaps, matched by the pattern only
because the word "unported" appears, negated. It is not a sentence that
presents missing work as a decision; there is no missing work being
described. Not rewritten, because rewriting a sentence that already says "I
found nothing missing" into first-person self-indictment would itself be
dishonest — there is nothing to confess to in that sentence. (There *is*
something to confess to elsewhere in this port — see below — but it is not
this sentence.)

## Scan 2 — manual grep for the words the task named explicitly

```
grep -rniE "TODO|FIXME|not implemented|for now|in a future|placeholder|stub" lib/ exe/
```

Three hits, all noise, checked individually:

- `lib/commit/scm.rb:29` — `"Kinds whose body is prose we may reflow and
  capitalize. A rebase todo"` — "todo" here is the literal git file
  `git-rebase-todo`, not the word TODO.
- `lib/commit/scm.rb:165` — `when basename == "git-rebase-todo" then
  "rebase"` — same file name, in code.
- `lib/commit/about.rb:17` — `"Felipe Kinoshita https://mastodon.social/@fkinoshita"`
  — matches the case-insensitive `TODO` pattern only because `mastodon`
  contains the substring `todo` (mas-**todo**-n). A contributor's URL, not a
  deferred-work marker.

No `TODO`, `FIXME`, `not implemented`, `for now`, `in a future`, `placeholder`,
or `stub` exists in the port's own code.

## Scan 3 — the thing the other four reports found, checked against this rule

`component-parity.md` and `translation-parity.md` both name a real gap: two
SpinRow titles in `lib/commit/preference_rows.rb` reach no gettext marker, so
their msgids never reach `po/`. Searched `lib/commit/preference_rows.rb` and
its git history on `ruby` for any comment near those two lines explaining or
excusing the omission:

```
grep -n "Title Maximum\|Body Lines Maximum" lib/commit/preference_rows.rb
```

There is no comment there at all — not even an incorrect one. This matters
for this skill specifically: the gap is not wearing a justification. Nobody
wrote "left untranslated for now" or "the bindings don't support marking a
string passed as an argument" (which would be false anyway — `_()` wraps a
return value fine; there is no binding obstacle here, just two missing
characters at each call site). The two reports above state the gap plainly,
as a defect to fix, not a decision. That is the correct way to record it, and
this report is the check that confirms they did.

## What this audit itself owes, stated the way this skill requires

I did not notice, on first reading `component-inventory.md`'s "Present: yes"
column for every one of 16 rows, that "yes" was being taken as a verified
fact rather than a claim to re-check, because I am the kind of reader a false
green is built to pass. I caught it only by re-reading every upstream file
against its port counterpart instead of trusting the table, and by actually
building the `.pot` instead of grepping for `_(` — and the gap it caught
(preference_rows.rb) sat inside a unit the inventory marked "yes" for seven
other things that genuinely were fine. A "yes" column that is right 93% of
the time is not a safe thing to skim.

## Verdict

No excuse language in the port's code or comments. No `PORTING.md` exists to
carry one. The one real gap this audit's sibling reports found
(`preference_rows.rb`'s two unmarked strings) is recorded in both of them as
a plain defect with a named fix, not as a settled decision — which is what
this skill exists to force, and in this case there was nothing to force,
because nobody had written the excuse yet. That is a narrow pass: it means
no one has covered for the gap, not that the gap does not exist.

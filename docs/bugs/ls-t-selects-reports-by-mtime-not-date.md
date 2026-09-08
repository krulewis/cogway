# `ls -t` selects the "most recent" signal/improvement report by mtime, not by the date in its name

**Status:** open — spike only, not fixed. Reproduced against the real router; no code, test,
or fixture changed by this document.
**Severity:** low mechanically (two `ls -t` call sites), high behaviourally — the wrong
outcome is not a no-op, it dispatches a whole phase.
**Found:** 2026-09-08. Flagged during PR review pass 3 as a real routing bug and filed here
per the commit that fixed the fixture it was hiding in (`improve-stable-gate-absent-with-signal`,
commit `3860e6f`'s parent). This document is that filing.
**Affects:** `ops/route-initiative.sh`'s two "most recent report" selections — the signal
report lookup (~line 145) and the improvement report lookup (~line 156).

## The problem

Every signal and improvement report is named by date: `YYYY-MM-DD-signal.md`,
`YYYY-MM-DD-improve.md`. That naming convention is documented (see the schema headers in
`ops/schemas/signal-report-schema.md` and `ops/schemas/improvement-report-schema.md`) and is
what a reader — human or agent — uses to tell reports apart.

The router does not use it. Both "most recent report" lookups call `ls -t DIR/*.md | head -1`,
which sorts by **modification time**, not filename. Filename date and mtime are two
independent orderings. They agree only when nothing has touched the filesystem metadata since
the files were written in date order — which is not guaranteed, and in this repo's own history
was already the source of a fixture that "passed by accident" (see commit `3860e6f`'s message).

## Reproduction

Built in a scratch directory, never in the repo:

```bash
WORK=/tmp/cogway-ls-t-repro
mkdir -p "$WORK/03-feature/signal-reports"

cat > "$WORK/03-feature/feature-record.md" <<'EOF'
---
build_status: complete
---

## Baseline Metrics

| Metric | Value | Captured at |
|---|---|---|
| p95 latency | 120ms | 2026-04-01 |

## Monitoring Thresholds

| Metric | Healthy min | Degraded min | Critical min |
|---|---|---|---|
| p95 latency | <200ms | <500ms | <1000ms |
EOF

cat > "$WORK/03-feature/signal-reports/2026-01-01-signal.md" <<'EOF'
---
recommendation: trigger_improve
---
EOF

cat > "$WORK/03-feature/signal-reports/2026-06-01-signal.md" <<'EOF'
---
recommendation: stable
---
EOF

SIG="$WORK/03-feature/signal-reports"

# Case 1 — mtimes agree with filename order
touch -d "2026-01-01 00:00:00" "$SIG/2026-01-01-signal.md"
touch -d "2026-06-01 00:00:00" "$SIG/2026-06-01-signal.md"
bash ops/route-initiative.sh "$WORK" /dev/null

# Case 2 — mtimes tied
touch -d "2026-07-01 00:00:00" "$SIG/2026-01-01-signal.md"
touch -d "2026-07-01 00:00:00" "$SIG/2026-06-01-signal.md"
bash ops/route-initiative.sh "$WORK" /dev/null

# Case 3 — mtimes inverted (older-dated file touched most recently)
touch -d "2026-08-01 00:00:00" "$SIG/2026-01-01-signal.md"
touch -d "2026-07-01 00:00:00" "$SIG/2026-06-01-signal.md"
bash ops/route-initiative.sh "$WORK" /dev/null
```

Run from the repo root against the real, unmodified `ops/route-initiative.sh` at `3860e6f`.
The intended answer, in all three cases, is `MON3|no-op|` — `2026-06-01-signal.md` is the
newer report and it says `stable`.

| Case | mtime relationship | Result | Correct? |
|---|---|---|---|
| 1 | mtimes agree with filename order | `MON3\|no-op\|` | Yes |
| 2 | mtimes tied | `MON2\|dispatch\|improve` | **No** — `ls -t` tie-breaks name-ascending, picks `2026-01-01` |
| 3 | mtimes inverted (old file touched most recently) | `MON2\|dispatch\|improve` | **No** — obeys mtime, ignores the filename date |

All three confirmed by direct execution of `ops/route-initiative.sh`, not inferred.

## Why it matters

`MON2` dispatches an entire improve phase that should not run. `MON3` is the no-op, so the
wrong direction here is not silence — it is a live dispatch triggered by filesystem metadata
that isn't part of the repository's tracked state. The mirror case is just as real: a stale
`trigger_improve` report shadowing a newer `stable` one would wrongly keep an initiative
churning in improve; a stale `stable` shadowing a newer `trigger_improve_urgent` would strand
an initiative that needs `MON1`'s urgent path and silently downgrade it to a no-op instead.

The triggers are routine, not exotic:

- `git clone` / `git checkout` set mtimes to checkout time, not commit time — the whole
  directory lands with mtimes clustered within the same second or two, which is exactly
  Case 2 (the tie case already caught by accident in `improve-stable-gate-absent-with-signal`).
- `tar`, `rsync`, and CI cache restores commonly flatten or reorder mtimes depending on flags.
- Editing an old report — e.g. fixing a typo in a `2026-01-01-signal.md` — bumps its mtime
  past every report written after it. That is Case 3, and it is the single most plausible way
  this fires in real use: nobody edits report content expecting it to change routing.

It also contradicts the repo's own pitch. `README.md` describes routing as "bash conditions
... checked by a real fixture suite," explicitly positioned against "a prompt an agent might
misread." A same-repository-state-routes-two-ways bug driven by untracked filesystem metadata
is the same failure mode the whole project exists to rule out, just moved from the prompt
layer into the shell layer.

## Options considered

### 1. Sort by filename instead of mtime

Replace `ls -t DIR/*.md | head -1` with a filename-sort, e.g.
`printf '%s\n' "$DIR"/*.md | sort | tail -1` (ISO 8601 dates sort correctly as plain strings).

- **Correctness:** Exact, as long as every file in the directory is named
  `YYYY-MM-DD-{signal,improve}.md`. That premise is already the documented convention and is
  what a human reader relies on today — this option makes the router agree with the reader.
- **Migration cost for reports in the wild:** None. No file content or filename changes;
  only the selection logic changes. (This repo has no real signal/improvement reports of its
  own to check — see Open Questions — so "in the wild" here means CampBuddy/Stashtrend/
  tokencast initiative folders, which I did not have access to inspect.)
- **What happens to a misnamed file:** Silently wrong, and wrong in a way that's easy to miss.
  A file named `final-signal.md` or `2026-1-1-signal.md` (unpadded) sorts lexicographically
  wherever its string happens to land — not necessarily last, not flagged, no error. Nothing
  in `ops/check-deliverable-fields.sh` currently validates filenames, only frontmatter field
  values (`*-signal.md) specs=("recommendation=...")`, matched by suffix glob, not full
  pattern). Making the naming convention load-bearing for routing without also linting it
  trades one silent-failure mode for another, narrower one.
- **Lint / `field-map-consistency-test.sh` impact:** `field-map-consistency-test.sh`'s
  `EXPECTED_TABLE` only tracks `key: value` field pairs per file, not filenames, so this
  option needs a new check (in the lint or a new test) asserting each file under
  `signal-reports/`/`improvement-reports/` matches the date-prefixed pattern — otherwise the
  misnamed-file failure mode above ships unguarded.
- **Fixtures needed:** The three cases already reproduced above, committed as real fixtures
  (tied mtime, inverted mtime) — these are *cheap to write correctly* under this option
  because the fix doesn't depend on mtime, so fixture mtimes are irrelevant and tests need no
  special setup, unlike today. Plus one misnamed-file fixture to characterize (or, if a lint
  is added, to prove caught) the failure mode above.
- **Effort:** Small. Two call sites, no schema change, no new required field.

### 2. Read a date field from frontmatter

Both schemas already carry a body-level date field by convention —
`**evaluated_at:** YYYY-MM-DD` in `ops/schemas/signal-report-schema.md`,
`**date:** YYYY-MM-DD` in `ops/schemas/improvement-report-schema.md` — but neither is in
frontmatter, neither is required by `check-deliverable-fields.sh` (only `recommendation` is
required for `*-signal.md`; the improvement-reports branch requires `recommendation` and
`live_data_validation`, not a date), and neither is read by `route-initiative.sh` at all today.
This option promotes one of them into frontmatter as a required field and sorts on it using
the existing `field()` helper (which already parses frontmatter first, then falls back to
whole-file bold `**key:**` scan for legacy files).

- **Correctness:** Authoritative and self-describing — matches the router's own stated
  philosophy. `AGENTS.md` states plainly: "Deliverable frontmatter fields ... are the ONLY
  source of truth — never act on verbal instructions." An mtime comparison is neither a
  frontmatter field nor a verbal instruction, but it is exactly the kind of untracked,
  out-of-band signal that line is written to rule out. This option is the one that actually
  closes that gap; sorting by filename (Option 1) narrows it but still leaves the filename —
  not a schema-validated field — as the load-bearing value.
- **Migration cost for reports in the wild:** Real cost, and larger than it first looks. This
  repo's own `ops/tests/fixtures-lint/improvement-reports/2026-01-01-report.md` — a legacy-bold
  fixture already in the suite — has no date field at all (checked directly: it carries
  `recommendation`, `mini_design_sprint_triggered`, `mini_sprint_status`,
  `live_data_validation`, and nothing else). Since the field is optional today, existing
  reports may have it absent, or present as the unfilled schema placeholder text
  (`**evaluated_at:** YYYY-MM-DD` verbatim) rather than a real date — either of which breaks a
  naive sort. A migration pass would need to backfill from the filename anyway (the one
  signal that's reliably present), which raises the question of why not stop there (Option 1).
  Note: `ops/tests/schema-migration-test.sh` references a `migrate-field-to-frontmatter.sh`
  script in a comment, but no such script exists in this repo — there is no existing migration
  tool to build on.
- **Lint / `field-map-consistency-test.sh` impact:** New required field in
  `check-deliverable-fields.sh`'s specs for both `*-signal.md` and the
  `improvement-reports` branch; a new row in `field-map-consistency-test.sh`'s
  `EXPECTED_TABLE`; a schema-version consideration for both schema files (mirrors the open
  question already on record in `docs/bugs/build-status-complete-written-before-live-data-gate.md`
  about whether field-meaning changes warrant a version bump).
- **Fixtures needed:** Same three adversarial-mtime fixtures as Option 1 (again mtime-
  independent once fixed), plus fixtures for missing-field and placeholder-value reports to
  prove the lint/migration path, plus at least one legacy-bold fixture proving the
  fallback-parse path still resolves ordering correctly.
- **Effort:** Medium. Touches two schemas, the lint, the consistency test, and needs a
  documented migration story for whatever already exists outside this repo.

### 3. Keep `ls -t`, but pin mtime in the deliverable's own write path

Have whatever writes a signal/improvement report (the `monitor-technical`/`monitor-product`/
`improve-analyst` agents, or an orchestrator wrapper) explicitly `touch` the file to a
canonical time derived from its own filename immediately after writing it, so mtime and
filename are forced to agree at write time and stay that way barring the exact events this
bug is about (edits, tar/rsync, cache restores).

- **Correctness:** Only as strong as the weakest write path. Any tool that touches the file
  afterward (editor, formatter, `git checkout` on a fresh clone of history where the write-time
  touch isn't replayed) reintroduces the bug. This doesn't fix the router; it tries to keep the
  environment from tripping it, which is the same category of fragility the bug already lives
  in. Weakest of the three options and arguably not a fix at all — it's a mitigation with the
  same failure mode as the status quo, just less frequently triggered.
- **Migration cost:** None for existing reports, but it also does nothing for them — an
  already-checked-out repo's mtimes are exactly the case this doesn't help.
- **Lint impact:** None — nothing about frontmatter or filenames changes, so no lint or
  consistency-test change.
- **Fixtures needed:** None new; can't be fixture-tested at all, since the "fix" lives outside
  `route-initiative.sh` in agent-side behavior the test suite doesn't exercise.
- **Effort:** Small per write path, but there are multiple write paths (`monitor-technical`,
  `monitor-product`, `improve-analyst`, plus whatever `mini-design-sprint` writes), and every
  future one has to remember to do it. Rejected on inspection but included because it's the
  cheapest option to implement and its rejection reason (weakest correctness guarantee, no
  test coverage possible) is worth recording alongside the two real candidates.

## How would the fix be tested deterministically?

The current suite cannot catch this class of bug: fixtures get their mtimes from `git
checkout`, so a fixture with two report files always exercises whatever `ls -t` happens to do
with checkout-time mtimes on that machine, at that moment — that's exactly how
`improve-stable-gate-absent-with-signal` shipped green for a false reason (see commit
`3860e6f`'s message).

Two different answers apply depending on what's being tested:

- **A regression fixture proving the bug is gone** still has to manipulate mtime on purpose,
  the way the reproduction above does (`touch -d`), because the whole point is to construct
  the adversarial case (tied, inverted) that checkout-time mtimes won't reliably produce. This
  is what the current fixture suite already does for the tied case, per commit `3860e6f`
  ("every fixture mtime forcibly tied").
- **The fix itself**, under either Option 1 or Option 2, does not depend on mtime once
  implemented — filename-sort and frontmatter-date-sort both order purely on file content/name,
  not filesystem metadata. So new fixtures added *because of* the fix need no special mtime
  handling at all; only the fixtures that specifically regression-test the old bug do. Option 3
  is the odd one out here — it can't be fixture-tested deterministically at all, since its
  effect lives in agent write behavior outside `route-initiative.sh`.

## Recommendation

Option 1 (sort by filename), paired with a filename-pattern lint addition so a misnamed file
fails loudly instead of sorting silently wrong. It is the smallest change that fixes the actual
router bug, requires no migration of anything already written, and is fully testable today with
no environment dependency. Option 2 is the philosophically cleaner answer — it's the one that
actually satisfies AGENTS.md's "frontmatter is the only source of truth" line rather than
substituting one out-of-band signal (mtime) for another in-band-but-still-not-frontmatter one
(filename) — and is worth doing later as a deliberate schema change with its own migration plan,
not bundled into a routing bugfix. Option 3 is not a real fix and is recorded only to close it
off.

This recommendation is advisory; it has not been through the architecture step.

## Not yet decided

- Whether Option 1's filename-pattern lint lives in `check-deliverable-fields.sh` (write-side,
  catches it when the report is authored) or as a new check inside `route-initiative.sh`
  itself (catches it at read-time, covers files written before the lint existed).
- Whether Option 2 is worth doing at all once Option 1 ships, or whether the correctness gap
  it closes (misnamed-but-lint-passing files) is narrow enough not to justify the schema
  migration cost.
- Whether any real initiative outside this repo (CampBuddy, Stashtrend, tokencast) currently
  has signal/improvement reports whose mtime order disagrees with filename order — not
  checked, since those live in separate repos this spike did not have access to.

## Referenced from

- Commit `3860e6f`'s message (the fix to `improve-stable-gate-absent-with-signal`), which
  first identified this as a real routing bug and deferred it here.
- `README.md`'s "Open items" list.

# Bug: EXP extension counter misses `## Extensions` heading (only matches `**Extensions:**` bold)

**Status:** open · **Severity:** medium (silent — corrupts the experiment lifecycle progression) · **Filed:** 2026-08-08
**Component:** `ops/route-initiative.sh` (EXP3/EXP4 rules) · **Loop:** `cogway-exp-extensions-count`

## Summary

The router counts extension rows in an experiment report with an `awk` block keyed on a **bold** marker:

```awk
# ops/route-initiative.sh:97-101
exp_extensions_count=$(awk '/^\*\*Extensions:\*\*/{f=1;header=0;next} \
    f && /^\|[^-]/{if(header){c++}else{header=1}} \
    f && /^[^|]/{exit} \
    END{print c+0}' "$EXPERIMENT_REPORT" 2>/dev/null || echo 0)
```

If an experiment report writes its extensions under a standard markdown heading `## Extensions`
instead of the bold `**Extensions:**`, the `awk` never sets `f=1`, so `exp_extensions_count`
silently reads **0** no matter how many extensions have actually been recorded.

## Impact

The count drives the extend → escalate progression:

- `EXP3` (`extend`, `extensions < 2`) → `update|extend-experiment`
- `EXP4` (`extend`, `extensions >= 2`) → `escalate|gate-exp-inconclusive` (the human gate)

With the count stuck at 0, **`EXP4` can never fire.** An experiment whose verdict stays
`extend` is extended unboundedly and the human "inconclusive" gate is unreachable — the exact
class of silent lifecycle failure the router exists to prevent.

## Why the test suite is green anyway (the trap)

Cogway is internally consistent on the *bold* format:

- `ops/schemas/02-experiment-report-schema.md:28` documents `**Extensions:**`.
- The EXP fixtures (`ops/tests/fixtures/exp-extend-0|1|2/02-experiment/experiment-report.md`)
  all use `**Extensions:**`.
- The router greps for `**Extensions:**`.

So `route-initiative-test.sh` passes — but only because every fixture shares the router's own
format assumption. **No fixture exercises the `## Extensions` heading variant**, so the suite
cannot catch this. A test suite whose fixtures encode the code's assumption can be fully green
while the code is wrong for the other valid format.

## Reproduction

Run the router against an experiment report that (a) has `overall_verdict: extend` and
(b) records its extensions under a `## Extensions` heading with 2 data rows:

```bash
bash ops/route-initiative.sh <that-initiative-path> <roadmap-path>
# expected: EXP4|escalate|gate-exp-inconclusive
# actual:   EXP3|update|extend-experiment   (count read as 0)
```

Observed live on 2026-08-08 routing the personal `open-brain` roadmap: OB-009, OB-010, and
OB-011 all returned `EXP3` despite each having a recorded `## Extensions` row.

## Origin

Originally identified 2026-07-18 (personal-system session): the **personal** router
(`~/.claude/scripts/route-initiative.sh`) had the same defect and was fixed to recognize the
`## Extensions` heading — documented as open-brain `docs/gotchas.md` gotcha #45. A backlog task
was filed at the time to port that fix to Cogway's copy; this document is that port, now tracked
in-repo.

## Proposed fix (not yet applied)

Make the counter recognize **both** the `## Extensions` heading and the `**Extensions:**` bold
marker, e.g. anchor on `/^(##[[:space:]]+Extensions|\*\*Extensions:\*\*)/`.

Per Cogway's contract (*a change to `route-initiative.sh` isn't done until
`ops/tests/route-initiative-test.sh` and its fixture reflect it*), the fix is not complete until
a fixture using the `## Extensions` **heading** form exists and:

1. fails (returns `EXP3` at 2 extensions) against the current router, and
2. passes (returns `EXP4`) against the fixed router.

Also decide whether to standardize the schema/template/fixtures on the `## Extensions` heading
form for consistency with the upstream personal system, rather than supporting both indefinitely.

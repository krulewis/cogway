---
schema: experiment-report
version: 1
overall_verdict: Promote | Kill | Extend
---

# Experiment Report — {Initiative Slug}

**initiative_id:** INI-{NNN}
**experiment_id:** EXP-{NNN}
**date:** YYYY-MM-DD

---

## Hypothesis Tested

{The exact hypothesis this experiment was designed to test.}

## What Was Built

{Minimal implementation summary — what was built and what was instrumented.}

## Measurement

**window_start_date:** YYYY-MM-DD
**measurement_window:** {N days}

<!-- The router's extension counter (route-initiative.sh, EXP3/EXP4) accepts either
     this bold `**Extensions:**` marker or a plain `## Extensions` heading. Prefer the
     bold form shown here for consistency with the rest of this schema, but a report
     written with the heading form counts correctly and must keep doing so — both forms
     have fixtures in ops/tests/fixtures/. Any other marker reads as zero extensions,
     which strands the experiment on EXP3 and makes EXP4's human gate unreachable. -->
**Extensions:**
| Extended at | New window | Rationale |
|---|---|---|

## Metrics Observed

<!-- INSTRUMENTATION RULE: Every metric in this table must be captured automatically.
     Operators do not log during builds. Any metric requiring human annotation is invalid.
     Valid sources: git diffs, task list state, hook output, file change counts, CI results. -->

| Metric | Baseline | Target | Promote threshold | Kill threshold | Observed | Verdict |
|---|---|---|---|---|---|---|
| | | | | | | hit / missed / inconclusive |

## Security Findings

| Severity | Finding | Status |
|---|---|---|

## Verdict

**analyst_rationale:** {reasoning with data}

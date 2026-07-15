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

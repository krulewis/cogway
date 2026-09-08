---
schema: improvement-report
version: 1
recommendation: stable | continue_improve | flag_decommission
mini_design_sprint_triggered: true | false
mini_sprint_status: pending | complete
live_data_validation: validated | not_applicable | failed
---

# Improvement Report — {Feature ID} — {YYYY-MM-DD}

**feature_id:** FEA-{NNN}
**date:** YYYY-MM-DD
**triggered_by:** quality_signal | performance_signal | security_drift | scheduled

---

## Analysis

**mini_design_sprint_scope:** {description if triggered, else null}

## Improvements Made

| Axis | Description | Before metric | After metric |
|---|---|---|---|
| ux / visual / code_quality / performance / security | | | |

## Live Data Validation

<!-- Required for BOTH `validated` and `not_applicable` — a claim with zero rows below
     does not satisfy the gate (route-initiative.sh's IMP3 checks count > 0; see
     ops/rules/build-common.md's "Live-Data Validation Gate" for the full checklist this
     table transcribes). For `not_applicable`, use exactly this row shape, naming the
     scope you checked and the PR:
     | (none) | — | — | — | no cron, workflow_dispatch, scheduled job, capture script or export added in PR #NNN | -->

| Pipeline | Manual trigger | First live run | Write destination | Content read |
|---|---|---|---|---|

## Remaining Opportunities

- {Opportunity 1 — ranked by impact}
- {Opportunity 2}

---


---
schema: feature-record
version: 1
build_status: in_progress | complete
live_data_validation: validated | not_applicable | failed
---

# Feature Record — {Initiative Slug}

**initiative_id:** INI-{NNN}
**feature_id:** FEA-{NNN}
**experiment_id:** EXP-{NNN} | null
**mvp_validation_report:** path/to/mvp-experiment-report.md | null

---

## Repo

**name:** {repo-name}
**path:** {relative path or git URL}
**branch:** {feature branch or main}
**pr_url:** {URL}

## Architecture Summary

{2-3 sentences describing the technical approach.}

## Implementation Notes

{Key decisions, gotchas, non-obvious choices made during implementation.}

## Build Status

**build_completed_date:** YYYY-MM-DD

## Live Data Validation

<!-- Required for BOTH `validated` and `not_applicable` — a claim with zero rows below
     does not satisfy the gate (route-initiative.sh's BF1 checks count > 0; see
     ops/rules/build-common.md's "Live-Data Validation Gate" for the full checklist this
     table transcribes). For `not_applicable`, use exactly this row shape, naming the
     scope you checked and the PR:
     | (none) | — | — | — | no cron, workflow_dispatch, scheduled job, capture script or export added in PR #NNN | -->

| Pipeline | Manual trigger | First live run | Write destination | Content read |
|---|---|---|---|---|

## Baseline Metrics

| Metric | Value | Captured at |
|---|---|---|

## Monitoring Thresholds

| Metric | Healthy min | Degraded min (trigger_improve) | Critical min (trigger_improve_urgent) |
|---|---|---|---|

**monitor_cadence:** weekly

## Security

**security_audit_date:** YYYY-MM-DD
**security_findings:**
| Severity | Finding | Status (resolved / outstanding) |
|---|---|---|

## Performance

**performance_review_date:** YYYY-MM-DD
**performance_findings:**
| Finding | Status |
|---|---|

## Launch

**launch_date:** YYYY-MM-DD
**current_phase:** feature | improve | decommission-pending

## Improvement History

| Date | Report path | Triggered by | Outcome |
|---|---|---|---|

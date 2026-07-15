---
schema: feature-record
version: 1
build_status: in_progress | complete
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

---
schema: discovery-spec
version: 1
discovery_approved:
---

# Discovery Spec — Example Feature

**initiative_id:** EXAMPLE-001
**initiative_type:** iteration
**date:** 2026-01-01
**status:** draft

---

## Problem Statement

Users can't tell whether a long-running export finished successfully — the UI shows a spinner
that just disappears, with no success or failure state.

## Who Has It

**Segment:** Users exporting reports larger than ~500 rows
**Context:** Exports that take more than a few seconds to generate

## What They've Tried

Refreshing the page and re-triggering the export, which sometimes double-submits the job.

## Competitive Landscape

| Competitor | Approach | Differentiation opportunity |
|---|---|---|
| Tool A | Email notification on completion | In-app toast is faster feedback for users still on the page |

## Hypotheses

- [ ] Showing an explicit success/failure state after export completion will reduce duplicate export submissions
- [ ] A visible progress indicator will reduce premature page navigation during export

## UX Research

**User journeys:** User clicks "Export" → spinner shows → spinner vanishes with no confirmation → user is unsure whether it worked

**Mental models:** Users expect a persistent, unambiguous end state (success or error), not a state that silently disappears

**Failure points:** The moment the spinner disappears with no visible outcome

## Success Metrics

| Metric | Baseline | Target | Threshold (promote) | Threshold (kill) | Window |
|---|---|---|---|---|---|
| duplicate_export_rate | 0.11 | 0.03 | 0.05 | 0.10 | 14 days |

## Value Estimate

**Effort:** S
**Opportunity:** Fewer duplicate export jobs, less support volume from "did my export work?" tickets
**Confidence:** high

## Reviewer Verdict

**Verdict:** Go
**Rationale:** Small, well-scoped fix with a clear, measurable success signal.

---

## Human Gate 1

**decision_date:**
**decision_rationale:**

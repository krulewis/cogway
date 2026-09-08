---
build_status: complete
live_data_validation: validated
---

## Live Data Validation

| Pipeline | Manual trigger | First live run | Write destination | Content read |
|---|---|---|---|---|
| daily-digest workflow | `gh workflow run digest.yml` | 2026-09-06 14:02 — 37 items processed | `out/` bucket, write confirmed 2026-09-06 | opened `out/2026-09-06.md`; header + 3 entries read, encoding correct |

## Baseline Metrics

| Metric | Value | Captured at |
|---|---|---|

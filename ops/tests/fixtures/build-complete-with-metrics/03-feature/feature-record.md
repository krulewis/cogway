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
| p95 latency | 120ms | 2026-04-01 |
| error rate | 0.2% | 2026-04-01 |

## Monitoring Thresholds

| Metric | Healthy min | Degraded min | Critical min |
|---|---|---|---|
| p95 latency | <200ms | <500ms | <1000ms |
| error rate | <1% | <3% | <10% |

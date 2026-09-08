---
build_status: complete
live_data_validation: failed
---

## Live Data Validation

| Pipeline | Manual trigger | First live run | Write destination | Content read |
|---|---|---|---|---|
| daily-digest workflow | `gh workflow run digest.yml` | 2026-09-06 14:02 — ran, wrote no output file | `out/` bucket — write NOT confirmed, bucket empty after run | opened `out/`; directory listing empty, digest.yml logs show a silent early exit |

## Baseline Metrics

| Metric | Value | Captured at |
|---|---|---|
| p95 latency | 120ms | 2026-04-01 |

## Monitoring Thresholds

| Metric | Healthy min | Degraded min | Critical min |
|---|---|---|---|
| p95 latency | <200ms | <500ms | <1000ms |

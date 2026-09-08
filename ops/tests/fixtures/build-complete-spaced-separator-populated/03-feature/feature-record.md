---
build_status: complete
live_data_validation: validated
---

## Live Data Validation

| Pipeline | Manual trigger | First live run | Write destination | Content read |
| --- | --- | --- | --- | --- |
| nightly-digest | `gh workflow run digest.yml` | 2026-09-02 03:14 — 41 items | `out/` bucket, write confirmed | opened `out/2026-09-02.md`; 3 entries read, encoding correct |

## Baseline Metrics

| Metric | Value | Captured at |
| --- | --- | --- |
| p95 latency | 240ms | 2026-09-01 |

## Monitoring Thresholds

| Metric | Healthy min | Degraded min | Critical min |
| --- | --- | --- | --- |
| p95 latency | 300ms | 500ms | 900ms |

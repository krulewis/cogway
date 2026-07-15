---
description: Monitor phase compositions — technical (daily health check) and product (weekly metrics) task lists
globs: ["**/signal-reports/**"]
alwaysApply: false
---

# Monitor Phase — loads as: ops/rules/monitor.md
# Root index pointer: monitor → this file

### Monitor — Technical (`{ini-id}-monitor-{YYYY-MM-DD}`)

| # | Task | Owner |
|---|---|---|
| 1 | Daily technical health check | `monitor-technical` |

*Dispatched by `monitor_run` trigger, not by routing rule.*

---

### Monitor — Product (`{ini-id}-monitor-product-{YYYY-MM-DD}`)

| # | Task | Owner |
|---|---|---|
| 1 | Weekly product metrics check | `monitor-product` |

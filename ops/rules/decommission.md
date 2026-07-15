---
description: Decommission phase compositions — analyst (kill case) and executor (cleanup plan) task lists and spawn order
globs: ["**/04-decommission-report.md"]
alwaysApply: false
---

# Decommission Phase — loads as: ops/rules/decommission.md
# Root index pointer: decommission → this file

### Decommission — Analyst (`{ini-id}-decommission-analyst`)

| # | Task | Owner |
|---|---|---|
| 1 | Evidence-based kill case and recommendation | `decommission-analyst` |

---

### Decommission — Executor (`{ini-id}-decommission-executor`)

| # | Task | Owner |
|---|---|---|
| 1 | Cleanup plan (files, data, comms) | `decommission-executor` |

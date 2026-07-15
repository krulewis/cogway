---
description: Discovery phase composition — 4-task list, spawn order (discovery-pm → discovery-researcher + ux-researcher → discovery-reviewer)
globs: ["**/00-discovery-spec.md"]
alwaysApply: false
---

# Discovery Phase — loads as: ops/rules/discovery.md
# Root index pointer: discovery → this file

### Discovery (`{ini-id}-discovery`)

| # | Task | Owner | Blocked by |
|---|---|---|---|
| 1 | Problem statement, hypotheses, success metrics | `discovery-pm` | — |
| 2 | Competitive landscape and market sizing | `discovery-researcher` | [1] |
| 3 | User journeys and mental models | `ux-researcher` | [1] |
| 4 | Discovery Spec adversarial review + verdict | `discovery-reviewer` | [2, 3] |

**Spawn:** `discovery-pm` → `discovery-researcher` + `ux-researcher` in parallel → `discovery-reviewer`

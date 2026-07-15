---
description: Design Sprint phase composition — 3-task list, spawn order (ux-designer + visual-designer → design-reviewer), field carry-forward requirement
globs: ["**/01-design-sprint.md"]
alwaysApply: false
---

# Design Sprint Phase — loads as: ops/rules/design-sprint.md
# Root index pointer: design-sprint → this file

### Design Sprint (`{ini-id}-design-sprint`)

| # | Task | Owner | Blocked by |
|---|---|---|---|
| 1 | UX flows and interaction specs | `ux-designer` | — |
| 2 | Visual direction and design tokens | `visual-designer` | — |
| 3 | Design Sprint adversarial review + verdict | `design-reviewer` | [1, 2] |

**Spawn:** `ux-designer` + `visual-designer` in parallel → `design-reviewer`

> Field carry-forward: When dispatching design-sprint, schema template must include **initiative_type:** copied from the discovery spec. See orchestrator.md for full dispatch rules.

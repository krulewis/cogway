---
description: Build:Feature phase composition — 17-task list (largest), spawn order, PR review loop, functional-review-writer, human-asset gate
globs: ["**/03-feature/**"]
alwaysApply: false
---

# Build:Feature Phase — loads as: ops/rules/build-feature.md
# Root index pointer: build-feature → this file

### Build:Feature (`{ini-id}-build-feature`)

| # | Task | Owner | Blocked by |
|---|---|---|---|
| 1 | Feature requirements | `pm` | — |
| 2 | Research approaches and patterns | `researcher` | [1] |
| 3 | Performance review of planned architecture | `performance-reviewer` | [1] |
| 4 | Architecture decision | `architect` | [2, 3] |
| 5 | UX design | `ux-designer` | [4] |
| 6 | Visual design | `visual-designer` | [4] |
| 7 | Initial implementation plan | `engineer` | [5, 6] |
| 8a | Plan review — staff | `staff-reviewer` | [7] |
| 8b | Plan review — Codex adversarial | `/codex:adversarial-review --wait` | [7] |
| 8c | Synthesize plan review findings | orchestrator (inline) | [8a, 8b] |
| 9 | Revised implementation plan | `engineer` | [8c] |
| 10 | Write failing tests | `qa` | [9] |
| 11 | Frontend component design | `frontend-designer` | [9] |
| 12 | Implement feature | `implementer` | [10, 11] |
| 13 | Security review | `security-reviewer` | [12] |
| 14 | Conformity review | `staff-reviewer` | [13] |
| 15 | Staff engineer PR review | `staff-reviewer` | [14] |
| 16 | Visual QA | `playwright-qa` | [15] |
| 17 | Update documentation | `docs-updater` | [15] |
| 18 | Functional review document | `functional-review-writer` | [16, 17] |

**Spawn:** `pm` → `researcher` + `performance-reviewer` in parallel → `architect` → `ux-designer` + `visual-designer` in parallel → `engineer` (initial plan) → `staff-reviewer` + `/codex:adversarial-review --wait` in parallel (plan review) → orchestrator synthesizes findings → `engineer` (revised plan) → **run `estimate_cost` MCP tool inline** → **human-asset gate** → `qa` (failing tests) + `frontend-designer` in parallel → `implementer` → `security-reviewer` → **conformity review** (`staff-reviewer`: check out-of-scope code, missing plan items, incorrect implementations) → **PR review loop** → `playwright-qa` + `docs-updater` in parallel → `functional-review-writer`

**PR review loop (after task 14):** Pass 1 — dispatch fresh `staff-reviewer` (Opus) AND run `/codex:adversarial-review --base main --wait` in parallel with PR diff. Synthesize inline (dedup, highest severity wins, disagreements flagged). If findings → `implementer`/`debugger` fixes → commit → new pass. Pass 2+ — tiered (`staff-reviewer` Opus → `code-reviewer` Sonnet if ≤2 findings and no Critical/High), no Codex. Repeat until "no remaining comments."

*`security-reviewer` waits for `implementer` (which waits for `frontend-designer`) because component designs affect security decisions.*

---

## Human-in-the-Loop Blockers (Build:Feature)

**Any asset, credential, or resource that requires human action to obtain must be surfaced immediately — not discovered mid-build.**

### Engineer Dispatch Requirement

When dispatching the `engineer` agent for any implementation plan (initial or revised), always include this instruction in the prompt:

> **Required section:** End your plan with an `## External Dependencies` section listing every asset, credential, or resource the build needs that cannot be downloaded or generated autonomously (sprites, audio, fonts, API keys, license-gated content, hardware, external service credentials). If there are none, write `None`. This section must be present even if empty.
>
> **Deploy steps rule:** Every step described as "at deploy time", "before deploy", or "run this manually" must be one of: (a) a script or CI job the agent can execute autonomously — write it into the plan; (b) an explicit human gate surfaced as a blocking `AskUserQuestion` — not a markdown note; or (c) flagged as a design smell requiring the approach to be redesigned. Plans that contain unexecutable manual steps produce deploy guides that get skipped.

### Human-Asset Gate (orchestrator inline step)

After receiving the revised plan and **before dispatching `qa`**, the orchestrator executes this gate:

1. Read the `## External Dependencies` section of the revised plan.
2. **If `None` or empty** → proceed normally to `qa`.
3. **If blockers listed:**
   **Always (blocking and non-blocking):**
   1. Add a **Human Action Required** table to `roadmap.md` with exact filenames, placement paths, and suggested sources for each item.
   2. Use `AskUserQuestion` to surface the full blocker list to the user.

   **Blocking (no fallback in code):**
   3. Set initiative RAG to 🔴 and `Pending` to `human-assets (0d)`. Do NOT dispatch `qa` or `implementer`.
   4. Resume only after user confirms assets are in place — re-run the gate.

   **Non-blocking (code has a working fallback):**
   3. Set initiative RAG to 🟡 and `Pending` to `human-assets (0d)`.
   4. Proceed to `qa` after raising to the user — do not wait for confirmation.

**This gate runs in every build phase:** Build:MVP, Build:Experiment, Build:Feature, Improve.

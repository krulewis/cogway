# Improve Phase — loads as: ops/rules/improve.md
# Root index pointer: improve → this file

### Improve (`{ini-id}-improve-{N}`)

**When TARGET is `improve-urgent`:** Include `priority: urgent` in the `improve-analyst` prompt. The improve-analyst agent must prioritize security vulnerabilities and critical regressions. It may skip lower-priority improvements (UX polish, minor performance gains) entirely. Set RAG to 🔴 Red on the roadmap before dispatching.

| # | Task | Owner | Blocked by |
|---|---|---|---|
| 1 | Audit and rank improvement opportunities | `improve-analyst` | — |
| 2 | Security drift audit | `security-reviewer` | [1] |
| 3 | Runtime performance analysis | `performance-reviewer` | [1] |
| 4 | Mini Design Sprint — UX | `ux-designer` | [1] |
| 5 | Mini Design Sprint — Visual | `visual-designer` | [1] |
| 6 | Implement improvements | `implementer` | [2, 3, 4, 5] |
| 7 | Frontend design for improvements | `frontend-designer` | [1] |
| 8 | Conformity review | `staff-reviewer` | [6, 7] |
| 9 | Staff review | `staff-reviewer` | [8] |

Create all 9 tasks upfront. After `improve-analyst` returns, check `mini_design_sprint_triggered`:
- **false:** mark tasks 4 + 5 `completed` (skipped), then spawn `security-reviewer` + `performance-reviewer` → **human-asset gate** → `implementer` + `frontend-designer` → **conformity review** (`staff-reviewer`: check out-of-scope code, missing plan items, incorrect implementations) → **PR review loop** → `staff-reviewer`
- **true:** spawn `security-reviewer` + `performance-reviewer` + `ux-designer` + `visual-designer` all in parallel → **human-asset gate** → `implementer` + `frontend-designer` → **conformity review** (`staff-reviewer`: check out-of-scope code, missing plan items, incorrect implementations) → **PR review loop** → `staff-reviewer`

**File conflict rule:** `implementer` and `frontend-designer` run in parallel only if their assigned file sets are non-overlapping per the engineer's plan. If both need to modify the same component files, serialize them: `implementer` first, then `frontend-designer`.

**PR review loop (after task 6):** Pass 1 — dispatch fresh `staff-reviewer` (Opus) AND run `/codex:adversarial-review --base main --wait` in parallel with PR diff. Synthesize inline (dedup, highest severity wins, disagreements flagged). If findings → `implementer`/`debugger` fixes → commit → new pass. Pass 2+ — tiered (`staff-reviewer` Opus → `code-reviewer` Sonnet if ≤2 findings and no Critical/High), no Codex. Repeat until "no remaining comments."

---

## Human-in-the-Loop Blockers (Improve)

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

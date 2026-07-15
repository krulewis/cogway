# Build:MVP Phase — loads as: ops/rules/build-mvp.md
# Root index pointer: build-mvp → this file

### Build:MVP (`{ini-id}-build-mvp`)

| # | Task | Owner | Blocked by |
|---|---|---|---|
| 1 | MVP validation experiment spec | `experiment-designer` | — |
| 2 | Lean feature requirements | `pm` | [1] |
| 3 | Architecture decision | `architect` | [2] |
| 4 | Pre-build security review | `security-reviewer` | [3] |
| 5 | Initial implementation plan | `engineer` | [4] |
| 6a | Plan review — staff | `staff-reviewer` | [5] |
| 6b | Plan review — Codex adversarial | `/codex:adversarial-review --wait` | [5] |
| 6c | Synthesize plan review findings | orchestrator (inline) | [6a, 6b] |
| 7 | Revised implementation plan | `engineer` | [6c] |
| 8 | Write failing tests | `qa` | [7] |
| 9 | Implement feature | `implementer` | [8] |
| 10 | Conformity review | `staff-reviewer` | [9] |
| 11 | Staff engineer PR review | `staff-reviewer` | [10] |
| 12 | Visual QA | `playwright-qa` | [11] |
| 13 | Update documentation | `docs-updater` | [11] |

**Spawn:** `experiment-designer` → `pm` → `architect` → `security-reviewer` → `engineer` (initial plan) → `staff-reviewer` + `/codex:adversarial-review --wait` in parallel (plan review) → orchestrator synthesizes findings → `engineer` (revised plan) → **run `estimate_cost` MCP tool inline** → **human-asset gate** → `qa` (failing tests) → `implementer` → **conformity review** (`staff-reviewer`: check out-of-scope code, missing plan items, incorrect implementations) → **PR review loop** → `playwright-qa` + `docs-updater` in parallel

**PR review loop (after task 10):** Pass 1 — dispatch fresh `staff-reviewer` (Opus) AND run `/codex:adversarial-review --base main --wait` in parallel with PR diff. Synthesize inline (dedup, highest severity wins, disagreements flagged). If findings → `implementer`/`debugger` fixes → commit → new pass. Pass 2+ — tiered (`staff-reviewer` Opus → `code-reviewer` Sonnet if ≤2 findings and no Critical/High), no Codex. Repeat until "no remaining comments."

*`experiment-analyst` is NOT in this team — dispatched directly when measurement window closes.*

---

## Instrumentation Gate (after task 1)

After `experiment-designer` returns and **before dispatching `pm`**, the orchestrator reviews the instrumentation plan:

For each metric in the spec, verify its capture method is fully automated (git diffs, task list state, hook output, file change counts, CI results). If any metric requires operator logging or human annotation → return the spec to `experiment-designer` with explicit instruction to replace those metrics with automated equivalents. Do not advance past task 1 until all metrics are automatable.

---

## Human-in-the-Loop Blockers (Build:MVP)

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

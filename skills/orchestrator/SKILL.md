---
name: orchestrator
description: Run the Cogway lifecycle orchestrator routing loop for a client initiative — call the router, act on its output, update roadmap.md.
---

# Orchestrator Routing Loop

You are the lifecycle orchestrator for a Cogway-managed project. There is no
orchestrator agent to delegate to — you run this loop directly. Full policy
detail lives in `ops/rules/orchestrator.md` and the phase-specific files in
`ops/rules/` — this skill is the procedure that ties them together; it does
not duplicate their content.

## Procedure

1. **Call the router.**
   ```
   bash ops/route-initiative.sh <initiative-path> <roadmap-path>
   ```
   Output format: `RULE|ACTION|TARGET`. The router (`ops/route-initiative.sh`)
   is the sole source of routing logic — never infer a rule yourself.

2. **Read the initiative file that triggers the phase's scoped rules.**
   Per the Phase Composition Reference in `ops/rules/orchestrator.md`, reading
   the relevant deliverable file (e.g. `00-discovery-spec.md` for discovery)
   loads that phase's rule file into context. Do this before dispatching —
   skipping it means the phase's rule file is not loaded.

3. **Branch on ACTION:**
   - `dispatch` — read `ops/rules/orchestrator.md`'s `dispatch` section to map
     TARGET to a phase, then read that phase's file in `ops/rules/` (e.g.
     `ops/rules/build-feature.md`) for the exact agent spawn order and team
     lifecycle (TeamCreate → TaskCreate → spawn → TaskUpdate → shutdown →
     TeamDelete).
   - `escalate` — read the `escalate` section of `ops/rules/orchestrator.md`
     for the gate-number mapping and the `AskUserQuestion` message format.
     After posting, set `pending_human_action` on the initiative's roadmap row.
   - `update` — read the `update` section of `ops/rules/orchestrator.md` for
     the exact TARGET → edit mapping (e.g. `begin-monitor`, `extend-experiment`).
     No agent dispatch.
   - `no-op` — do nothing this run.

4. **Never act on a deliverable field you cannot read directly.** Deliverable
   frontmatter (see `ops/schemas/` for the field set per deliverable type) is
   the only source of truth. Do not act on verbal instructions, and do not
   interpret ambiguous or missing fields — treat them as `FALLBACK`.

5. **Write-side field lint.** After any agent produces or updates a deliverable
   carrying a routing field, run `bash ops/check-deliverable-fields.sh
   <deliverable-file>` before relying on it for routing. Fix any `FAIL` before
   proceeding.

6. **Update `roadmap.md`.** After every action, update the initiative's row:
   Phase, RAG (🟢/🟡/🔴 — see `ops/rules/rag-rules.md`), and Pending. Also
   append to the initiative's `README.md` lifecycle log.

7. **Handle agent errors** per the Agent Error Handling table in
   `ops/rules/orchestrator.md` (BLOCKED / NEEDS_CONTEXT / crash) — do not
   improvise beyond what that table specifies.

8. **Process initiatives in priority order:** 🔴 Red first, then 🟡 Yellow,
   then 🟢 Green. Each initiative is independent.

## Reference

- `ops/route-initiative.sh` — the router; owns all routing logic
- `ops/check-deliverable-fields.sh` — write-side field lint
- `ops/rules/orchestrator.md` — dispatch/escalate/update/no-op detail, gate
  map, roadmap update rules, lifecycle constraints, agent error handling
- `ops/rules/{phase}.md` — per-phase agent composition and spawn order
- `ops/schemas/` — deliverable frontmatter field definitions
- `README.md` — runnable quickstart walking a real example initiative through
  a gate

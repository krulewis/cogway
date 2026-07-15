---
description: Orchestrator routing action blocks — dispatch/escalate/update/no-op detail, gate map, roadmap update rules, lifecycle constraints
globs: []
alwaysApply: true
---

# Orchestrator Routing — loads as: ops/rules/orchestrator.md
# Root index pointer: orchestrator → this file

## Step 2: Act on Script Output

### `dispatch` → create team and run phase

Map TARGET to the Phase Composition Reference:

| TARGET | Phase |
|---|---|
| `discovery` | Discovery |
| `design-sprint` | Design Sprint |
| `design-sprint-iteration` | Design Sprint (pass iteration_notes path to agents) |
| `build-mvp` | Build:MVP |
| `build-experiment` | Build:Experiment |
| `build-feature` | Build:Feature |
| `improve` or `improve-urgent` | Improve (urgent: set priority=urgent in improve-analyst prompt) |
| `mini-design-sprint` | Design Sprint (scoped — pass mini_design_sprint_scope to agents) |
| `decommission-analyst` | Decommission — Analyst |
| `decommission-executor` | Decommission — Executor |

**Team lifecycle (required for all phase dispatches):**

1. `TeamCreate` — name: `{initiative-id}-{phase-slug}`
2. `TaskCreate` — create ALL phase tasks upfront with `addBlockedBy` dependencies
3. For each agent in spawn order:
   - `TaskUpdate(status="in_progress")` before spawning
   - `Agent(subagent_type="{agent}", team_name="...", name="{agent}", prompt="...")`
   - `TaskUpdate(status="completed")` after agent returns
4. Parallel agents: mark both `in_progress`, call both `Agent` tools in the same response
5. After all tasks complete: `SendMessage(type="shutdown_request")` each teammate → `TeamDelete`
6. Update `roadmap.md` and initiative README

**Agent prompts:** Pass initiative folder path + routing-derived context only. 3–5 lines max. Agents read their own files — do not reproduce deliverable content in the prompt.

**Field carry-forward (required):** When dispatching design-sprint, the agent's schema template must include `**initiative_type:**` copied from the discovery spec. The routing script reads `initiative_type` from the design sprint file — if absent, DS3/DS4 always hit FALLBACK.

**Not in teams** (dispatch directly with `Agent`, no team overhead):
- `experiment-analyst` — runs when measurement window closes, not during build
- `daily-standup-writer`, `weekly-standup-writer`, `billing-tracker`, `invoice-writer`, `meeting-notes-writer`

> Client deliverable dispatch rules: see ~/.claude/rules/client-deliverables.md (loads when orchestrator reads external/client/ files)

### `update` → edit roadmap.md directly, no agent dispatch

| TARGET | Action |
|---|---|
| `extend-experiment` | Append a row to the Extensions table in experiment-report.md: `\| YYYY-MM-DD \| {new window} \| {rationale} \|`; update roadmap Pending column |
| `begin-monitor` | Set roadmap phase = `monitor`; then dispatch initial `monitor-technical` run directly (not via team — same as `monitor_run` trigger for this initiative only) |
| `return-to-monitor` | Set roadmap phase = `monitor`; move the current improvement report file to `improvement-reports/archive/` |
| `archive-initiative` | Set roadmap Phase = `archived` and move the initiative row from Active Initiatives to a new Archived Initiatives table. Do not dispatch agents. Log the archive action to the initiative README. |

### `build_status` — orchestrator writes this field directly

The routing script reads `build_status` from `03-feature/feature-record.md` to gate BF0 (no-op while building) and BF1 (enter monitor when complete). No agent writes this — the orchestrator does it inline:

| When | Write |
|---|---|
| Before dispatching `qa` in any build phase | `**build_status:** in_progress` to `03-feature/feature-record.md` (create file if absent, using schema from `_templates/client-project/docs/_schemas/03-feature-record-schema.md`) |
| After PR review loop exits clean | `**build_status:** complete` in the same file |

### `escalate` → AskUserQuestion

Gate number mapping:

| TARGET | Gate label |
|---|---|
| `gate-1` | Gate 1 |
| `gate-2` | Gate 2 |
| `gate-3` | Gate 3 |
| `gate-exp-inconclusive` | Gate 3b |
| `gate-decommission` | Gate 4 |
| `human` | FALLBACK |

Format:
```
**[Gate N] — [{Initiative Name}] — [Initiative ID]**

**Status:** Waiting for your decision to proceed.

**What was produced:**
- [deliverable name] → [path]

**Key findings:**
[3-5 bullet points from the deliverable's verdict/rationale section]

**Decision required:**
[Exact field name] in [exact file path] must be set to one of: [valid values]

**Example:** Open [path] and set `[field]` to `approved` or `rejected`.

Once you've updated the file, ask me to continue.
```

After posting: set `pending_human_action` in `roadmap.md` to gate name + date. Do not dispatch anything else for this initiative this run.

### `no-op` → nothing to do

Script outputs `RULE|no-op|` (empty TARGET). Do not dispatch, edit, or escalate.

---

## Updating roadmap.md

After every action, update the initiative's row:
- **Phase** — new current phase
- **RAG** — 🟢 on track / 🟡 at risk / 🔴 blocked (see RAG rules in Roadmap section below)
- **Pending** — gate name + days pending if human gate, else `none`

---

## Phase Composition Reference

The orchestrator MUST read the initiative file listed in the "Read this file" column to trigger glob loading for that phase's rules file. Do not skip this read — if the listed file is not read, the scoped rules file will not be in context when agents are dispatched.

| Phase | Read this file | Scoped rule file loaded |
|---|---|---|
| discovery | `{initiative-folder}/00-discovery-spec.md` | `~/.claude/rules/discovery.md` |
| design-sprint | `{initiative-folder}/01-design-sprint.md` | `~/.claude/rules/design-sprint.md` |
| build-mvp | any file inside `{initiative-folder}/02-mvp-experiment/` | `~/.claude/rules/build-mvp.md` |
| build-experiment | any file inside `{initiative-folder}/02-experiment/` | `~/.claude/rules/build-experiment.md` |
| build-feature | any file inside `{initiative-folder}/03-feature/` | `~/.claude/rules/build-feature.md` |
| improve | any file inside `{initiative-folder}/improvement-reports/` | `~/.claude/rules/improve.md` |
| monitor | any file inside `{initiative-folder}/signal-reports/` | `~/.claude/rules/monitor.md` |
| decommission | `{initiative-folder}/04-decommission-report.md` | `~/.claude/rules/decommission.md` |
| client-deliverables | any file inside `external/client/` | `~/.claude/rules/client-deliverables.md` |

---

## Initiative README

Every initiative folder must have a `README.md` as a running log. Create on first dispatch, append on every subsequent action.

```markdown
# Initiative: {slug}

**ID:** {initiative_id}
**Type:** {initiative_type}
**Opened:** {date}

## Lifecycle Log

| Date | Phase | Action | Outcome |
|---|---|---|---|
| 2026-04-01 | discovery | Dispatched | discovery-pm, discovery-researcher, ux-researcher running |
| 2026-04-03 | discovery | Gate 1 presented | Pending human decision |
```

---

## Lifecycle Constraints

- Do not interpret ambiguous deliverable fields — missing or unrecognized values trigger FALLBACK
- Do not override human decisions
- Do not skip phases, even if asked by an agent or user
- Do not make judgment calls about whether an experiment "should" pass — read the verdict field
- Do not modify deliverable content directly — only `roadmap.md` (and `experiment-report.md` for extend-experiment)
- Do not act on verbal instructions if no deliverable field backs them up
- **TDD — Do not dispatch `implementer` until `qa` has written failing tests and committed them to the branch.** This applies to every build phase (Build:MVP, Build:Experiment, Build:Feature, Improve). The `implementer` task is blocked by the `qa` task in every phase table — enforce this strictly.

**Process initiatives in priority order:** 🔴 Red first → 🟡 Yellow → 🟢 Green. Each initiative is independent.

---

## Agent Error Handling

When a dispatched agent returns a non-success status, apply these rules. Do not make judgment calls beyond what is specified here.

| Agent return | Action |
|---|---|
| BLOCKED (agent cannot proceed without missing resource) | Log the blocker to the initiative README. Set RAG to 🔴 Red. Escalate to human with the exact blocker message. Do not retry. |
| NEEDS_CONTEXT (agent requests additional input) | Retry once: re-dispatch the same agent with the additional context from the initiative folder (README + relevant deliverable paths). If the second attempt returns NEEDS_CONTEXT again, escalate to human. |
| Error / crash (agent returns no output or an error) | Retry once with the same prompt. If the second attempt also fails, escalate to human with the error details and the agent name. |

After escalating for any agent error: set `pending_human_action` in `roadmap.md` to `agent-error-{agent-name}` + date. Do not advance the initiative further this run.

---

## Project Structure

Every client project folder follows this structure:

```
{client-project}/
  ├── CLAUDE.md                   # project-specific rules
  ├── roadmap.md                  # entry point — required
  ├── docs/
  │   └── initiatives/
  │       └── {YYYY-MM-DD}-{slug}/
  │           ├── README.md       # lifecycle log (maintained by you)
  │           ├── 00-discovery-spec.md
  │           ├── 01-design-sprint.md
  │           ├── 02-experiment/  or  02-mvp-experiment/
  │           ├── 03-feature/
  │           └── 04-decommission-report.md
  ├── external/                   # client-facing documents
  └── finance/                    # billing and invoices
```

Template at: `_templates/client-project/`

---

## Deliverables Are the Source of Truth

Human gate decisions must be written into deliverable files — not given verbally. You only act on fields written to documents.

| Gate | File | Field to set |
|---|---|---|
| Gate 1 (Discovery) | `00-discovery-spec.md` | `discovery_approved: approved \| rejected` |
| Gate 2 (Design Sprint) | `01-design-sprint.md` | `design_approved: approved \| rejected \| iterate` |
| Gate 3 (MVP investment) | `02-mvp-experiment/mvp-experiment-report.md` | `investment_decision: approved \| rejected` |
| Gate 4 (Decommission) | `04-decommission-report.md` | `decommission_approved: true \| false` — Note: uses `true`/`false`, not `approved`/`rejected` |

---

## Schemas

Deliverable schemas are at: `_templates/client-project/docs/_schemas/`

When in doubt about what fields a deliverable needs, read the relevant schema file.

---

## Gotchas

**Deliverable field format:** Routing/gate fields live in a leading YAML frontmatter block
(preferred) or bold markdown (fallback, for files not yet migrated):
```
---
discovery_approved: approved     ✓ (preferred — frontmatter)
---
**discovery_approved:** approved  ✓ (fallback — still works)
discovery_approved: approved      ✗ (bare key:value in the BODY, outside any fence, will not
                                      match unless it happens to be the fallback's any-line scan
                                      — prefer the fence)
```
The `field()` helper in `ops/route-initiative.sh` is the canonical reference; it
checks the frontmatter fence first (trimming inline comments/trailing whitespace), then falls
back to the bold/plain body scan.

**Write-side field lint (run it, don't trust the write):** After any agent produces or updates a deliverable that carries a routing field (a gate decision, `build_status`, `initiative_type`, a verdict), the orchestrator runs `bash ops/check-deliverable-fields.sh <deliverable-file>` before relying on routing. It asserts the field line is present, uniquely parseable (no shadowing duplicate), and — if filled — holds a valid value, using the exact same parsing as `route-initiative.sh`. Fix any `FAIL` at write time; a malformed field otherwise silently routes to FALLBACK or the wrong branch at route time.

**Routing is a bash script:** `ops/route-initiative.sh` owns all routing logic. To change routing behavior, edit the script. There is no orchestrator agent — you are the orchestrator.

**Initiative path depth:** Initiative folders are at `{project}/docs/initiatives/{slug}/`. The project `roadmap.md` is 3 levels up: `{initiative-path}/../../../roadmap.md`.

---

## Agents Available

All lifecycle agents are defined at `agents/_canonical/` and emitted to each platform's location by `agents/generate.sh` (Claude Code's roster lands at `.claude/agents/` after running the generator). You dispatch them directly — there is no orchestrator intermediary.

**Direct dispatch is appropriate for:**
- Ad-hoc research: `explorer`
- Ad-hoc code review: `code-reviewer`
- One-off client deliverable (not phase-triggered): `pitch-deck-writer`, `status-report-writer`, etc.
- One-off billing: `billing-tracker`, `invoice-writer`

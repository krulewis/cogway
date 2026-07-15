---
description: Universal agent rules — tool use preference, codebase-memory-mcp first, agent delegation table, model selection, parallelism
globs: []
alwaysApply: true
---

# Agent Behavior Rules — loads as: ops/rules/agent-behavior.md
# Root index pointer: agent-behavior → this file

---

## MCP Tools in Sub-Agents (Universal Rule — updated 2026-07-14)

**MCP tools work in Agent-tool sub-agents and team teammates — but access is governed by the agent's `tools:` frontmatter, in two modes. Confirmed 2026-07-14 by four probes (two full-tools, two restricted). A "docs check" agent that could not reach live Anthropic docs wrongly parroted the old rule with false confidence — trust the empirical result, not the prose.**

**Mode A — full-tools agent (`tools: *`, i.e. has ToolSearch).** All ~30 connected `mcp__*` servers are *deferred* (names listed, schemas not preloaded). The agent calls `ToolSearch` to load a tool, then invokes it — reaching everything the main session can: codebase-memory, open-brain, and the already-authenticated claude.ai connectors (Google Calendar, Gmail, Drive, Sentry…), all returning live data.

**Mode B — restricted agent with explicit `mcp__X` grants** (e.g. `architect`, `staff-reviewer`, `engineer`, `implementer`, `qa`, `code-reviewer`, `debugger`, `docs-updater`, `explorer` all grant `mcp__codebase-memory-mcp__*`). Those specific tools are **pre-loaded and directly callable — no ToolSearch needed.** But the agent has **no ToolSearch and sees ONLY its granted tools**; a non-granted call returns "No such tool available." A restricted `explorer` called its granted `codebase-memory` tools live but could not see `open-brain` at all.

This **reverses** the prior rule (confirmed 2026-04-19, MS-004) that MCP was categorically blocked in sub-agents — that predated the deferred-tool/ToolSearch harness.

**Caveats & gotchas:**
- **OAuth-gated plugin servers** (`mcp__plugin_sentry_*`, `plugin_vercel`, `plugin_slack`, `plugin_supabase`, `circleback`, …) expose ONLY an `authenticate`/`complete_authentication` stub until an interactive handshake — which a sub-agent can't do. Their real tools are unreachable from a sub-agent until authed in the main session. The **already-authed `mcp__claude_ai_*` connectors DO work.**
- **Namespace drift bites frontmatter grants.** Servers often appear under two prefixes — bare (`mcp__open-brain__`) and connector/plugin (`mcp__claude_ai_open-brain__`, `mcp__plugin_tokencast_tokencast__`). A grant naming an unavailable variant silently won't resolve — grant the variant that actually works (the authed `mcp__claude_ai_*` connector, not an OAuth-gated `mcp__plugin_*` stub). *(Example caught + fixed 2026-07-14: `monitor-technical` had granted the gated `mcp__plugin_sentry_sentry__*`; switched to the authed `mcp__claude_ai_Sentry__*`.)*
- **Headless / cron / remote:** interactive-auth connectors may be absent outside an interactive session; a CronCreate agent firing in the main instance is the safe path.
- **If `ENABLE_TOOL_SEARCH` is not `auto`:** Mode A breaks (no ToolSearch); only Mode B frontmatter grants remain.

**Practical guidance:**
- Need arbitrary MCP in a dispatched agent → give it `tools: *` (ToolSearch included).
- Need a specific MCP in a focused agent → grant the exact **available** `mcp__*` names in frontmatter (they pre-load); verify the variant exists.
- OAuth-gated plugin server → authenticate it in the main session first; sub-agents can't complete the handshake.

---

## Agent Tool-Grant Policy — Least Privilege (Universal Rule)

Every custom agent lists **exactly** the file/exec tools and the specific `mcp__*` servers its single task needs — nothing more. As of 2026-07-14 no custom agent uses `tools: *`; keep it that way.

- **`tools: *` is reserved for deliberate catch-alls** (`general-purpose`, `claude`) used only when the required tools genuinely can't be enumerated. A `*` sub-agent under `bypassPermissions` can autonomously send email, delete calendar events, delete thoughts, hit Stripe, etc. — grant it consciously, never as a convenience.
- **Defined-role agents get scoped grants.** Code agents → file/bash + `mcp__codebase-memory-mcp__*`. Specialized agents → only the one or two services they touch (Playwright, PostHog, Sentry, Circleback).
- **Agents that ingest untrusted external content get the LEAST power.** `researcher`, `discovery-researcher`, `ux-researcher` (web) and `meeting-notes-writer` (transcripts) are the prompt-injection surface — a poisoned page or transcript could weaponize any tool they hold. Never give them `tools: *` or mutating/write-heavy MCP.
- **Grant the *available* MCP variant** (see the MCP sub-agent section): the authenticated `mcp__claude_ai_*` connectors, not the OAuth-gated `mcp__plugin_*` stubs a sub-agent can't authenticate.

---

## Monitoring Background Sub-Agents — Universal Rule

When you dispatch a background sub-agent (Agent tool) and need to judge whether it is alive vs. stuck:

- **Do NOT stat or watch `tasks/{id}.output` for liveness.** That file is a fixed ~152-byte stub — identical size for agents that completed AND agents that hung — and its mtime does not update during execution. Watching it is a blind timer with no progress signal and will false-positive-kill healthy agents.
- **The completion notification is the authoritative "done" signal.** The harness fires a `<task-notification>` when the agent finishes; rely on it for the normal case rather than polling.
- **The real, growing transcript is `subagents/agent-{id}.jsonl`.** If you must detect a genuine stall, watch THAT file's size/mtime, and treat the agent as stuck only if it stops growing for **≥ 10–15 minutes**. 240s is far too short — Opus reviewers and planning agents legitimately run many minutes with long gaps between tool calls.
- **Before killing + re-dispatching a seemingly-stuck agent, check for partial work** (working tree, commits). A killed agent may have already produced its deliverable (e.g. `qa`'s committed tests) — salvage that instead of re-running.
- Genuine hangs are almost always a sub-agent blocked on an unbounded `Bash` command (e.g. a full test suite that hangs on a down upstream). Agent definitions now require targeted test runs + `timeout` on test/build Bash calls; if one still hangs, suspect a blocking Bash call.

Confirmed 2026-07-08 (CampBuddy P0 grounding build): a 240s stub-watch false-positive-killed a healthy `staff-reviewer`, and two genuine hangs were blocking `Bash` calls. Post-mortem: `campbuddy-api/docs/postmortems/2026-07-08-stalled-subagents.md`.

---

## Data Migration Pattern — Universal Rule

**Any edit that replaces or modifies an existing data file must follow this order:**

1. **Back up** the existing file to a temp location before touching it
2. **Create/overwrite** with the new content
3. **Verify** the new file works (API call, JSON parse, smoke test — whatever is appropriate)
4. **Cleanup** — discard the backup only after verification passes
5. **Rollback** — if verification fails, restore from backup immediately

**Never delete a file before its replacement is confirmed working.** This applies to credential files, config files, JSON data files, and any file whose loss would break a running system. In-place overwrites still require a backup first.

```bash
# Pattern (bash):
cp existing.json /tmp/backup_existing.json          # 1. back up
generate_new > existing.json                         # 2. create/overwrite
verify_works && echo "ok" || {                       # 3. verify
    cp /tmp/backup_existing.json existing.json       # 4. rollback on failure
    echo "Migration failed — restored backup"
    exit 1
}
safe-delete.sh /tmp/backup_existing.json             # 5. cleanup on success
```

---

## Safe Delete — Universal Rule

Never use `rm` directly. The `rm` command is blocked by a PreToolUse hook and will not execute.

Always use `safe-delete.sh <path>` instead:
- **Safe targets** (node_modules, /tmp, *.log, build artifacts): deleted immediately, no backup needed
- **Protected targets** (credentials, config, data files): backup must exist, be non-empty, and be < 60 min old

Pattern for protected files — run safe-delete.sh first to get the exact backup path, then create the backup:

    safe-delete.sh important.json
    # Error: no backup found.
    # Run first: cp "important.json" "/tmp/backup_important.json_a1b2c3d4"

    cp important.json /tmp/backup_important.json_a1b2c3d4
    safe-delete.sh important.json   # now passes

For directories, touch the backup after cp -r (cp preserves original mtime otherwise):

    cp -r mydir /tmp/backup_mydir_e5f6a7b8 && touch /tmp/backup_mydir_e5f6a7b8
    safe-delete.sh mydir

---

## Capture Hook — pluggable, no-op by default

Cogway ships a no-op `hooks/capture.sh`. Wire your own persistence (a database, a note-taking tool, a file log) by editing that hook; the orchestrator calls it at the same trigger points Kelly's personal system used for Open Brain capture, documented in SKILL.md.

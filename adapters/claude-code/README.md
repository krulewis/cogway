# Claude Code adapter

Claude Code is Cogway's flagship platform: the orchestrator loop, agent roster, and
hook patterns below are all exercised on it first.

## Populating `.claude/agents/`

`.claude/agents/` is generated, not hand-maintained, and is gitignored (see
`.gitignore`). Populate it by running the generator from the repo root:

```
agents/generate.sh
```

This reads every `agents/_canonical/*.md` source and emits a near-identity
`.claude/agents/<name>.md` for each — frontmatter (`name`, `description`, `tools`,
`model`) plus the role body, unchanged. Concrete Claude Code model names
(`opus`/`sonnet`/`haiku`) come from the canonical `model_tier`; the mapping lives in
`agents/generate.sh` (see `model_for_tier()`).

Re-run `agents/generate.sh` any time a canonical agent source changes — it always
overwrites `.claude/agents/` in full, so there is nothing to merge by hand.

**Host-provided tools.** A few canonical agents (e.g. `frontend-designer`,
`monitor-technical`, `monitor-product`) list capabilities marked `host-provided:X` in
their canonical `tools:` line — these are MCP servers whose exact grant name is
account- or install-specific (a browser-automation MCP, a connector-flavored
observability MCP, etc.). The generator emits these as a commented placeholder line
(`# tools: <grant your own MCP for X here>`) rather than a broken grant. Uncomment and
fill in the real tool name for your own setup before those agents will have the
capability.

## PreToolUse hook patterns worth porting

Claude Code's `settings.json` supports `PreToolUse` hooks — shell commands that run
before a tool call and can block it. `settings.json.example` in this directory sketches
a minimal, illustrative starting point. It is **not** anyone's real configuration —
copying it verbatim gives you a working skeleton, not a finished setup.

The pattern *categories* below are broadly portable across projects and worth adapting
to your own repo, independent of Cogway's specific rules:

- **Destructive-command guards.** Block direct `rm` (or similar irreversible deletes)
  and route through a safe-delete script that requires a verified backup for
  protected paths, and allows immediate deletion for safe/scratch paths. See
  `ops/rules/agent-behavior.md`'s "Safe Delete" section for the policy this repo's own
  agents follow (backup-then-delete, never delete-then-verify).
- **Branch-protection-style guards.** Block `git commit` / `git push` when the current
  branch is a protected branch (e.g. `main`), and gate pushes on some project-defined
  "reviewed" marker before allowing them through. The exact marker mechanism is
  project-specific; the pattern (deny by default on the protected branch, require an
  explicit signal to unblock) is the portable part.
- **Read-guard patterns for sensitive files.** Block direct reads of credential-shaped
  files (`.env`, files matching `*credentials*`, etc.) so an agent can't accidentally
  echo secrets into its own transcript or a downstream tool call.

What is **not** portable, and should not be copied out of anyone's real
`settings.json`: personal file paths, project-specific script locations, account
identifiers, or any hook wired to infrastructure outside this repo (a specific CI
system, a specific ticket tracker, etc.). Treat a real `settings.json` as a config
file to imitate the *shape* of, never a file to transplant directly into a new project.

## Teams

Cogway's orchestrator dispatches agents as described in `AGENTS.md` and
`skills/orchestrator/SKILL.md`. On Claude Code, use the `Agent` tool (or Team
primitives, where available in your harness) to spawn the agents named in
`ops/rules/{phase}.md` for the current lifecycle phase. Cogway does not require any
team-coordination feature beyond what the router already prescribes — the router's
`RULE|ACTION|TARGET` output is the single source of dispatch instructions.

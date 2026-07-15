# Codex adapter

Codex is Cogway's second supported platform. It runs the same canonical agent roster
and the same `ops/route-initiative.sh` router as Claude Code — only the agent-file
format and the hook mechanism differ.

## Populating `.codex/agents/`

`.codex/agents/` is generated, not hand-maintained, and is gitignored (see
`.gitignore`). Populate it by running the same generator used for Claude Code, from
the repo root:

```
agents/generate.sh
```

For each `agents/_canonical/*.md` source, the generator emits a
`.codex/agents/<name>.toml` file: `name`, `description`, and `model` as TOML keys, and
the canonical role body wrapped in a `role = """…"""` multi-line string. The generator
refuses to emit a `.toml` file (non-zero exit) if a canonical body contains a literal
`"""` sequence, since that would break the TOML string delimiter — this is intentional
fail-closed behavior, not a bug.

**Verify-at-build-time markers.** Every emitted `.toml` file carries two comment lines
you should check against your installed Codex CLI before relying on an agent:

- `model = "..."  # VERIFY-AT-BUILD-TIME` — the concrete Codex model name for each
  `model_tier` (`critical`/`standard`/`mechanical`) is unconfirmed pending Codex CLI
  access (see architecture Open Question #4 in the Cogway planning docs). Confirm the
  mapping in `agents/generate.sh`'s `model_for_tier()` matches your Codex CLI's actual
  model identifiers before trusting agent dispatch.
- `# tools-grant-key = VERIFY-AT-BUILD-TIME` — the exact Codex frontmatter key for
  tool/capability grants is unconfirmed; the comment lists the canonical capability
  names so you can translate them into whatever your Codex CLI version expects.

Re-run `agents/generate.sh` any time a canonical agent source changes.

## `hooks.json` — documented, shipped off by default

`hooks.json.example` in this directory is **inert** — every entry is commented out.
This is deliberate, per architecture decision R4, not an oversight:

- Codex's `hooks.json` mechanism is **experimental** as of the version Cogway was
  designed against (v0.114, March 2026).
- It is **off by default** in Codex itself.
- It has **no Windows support**.

Because of that, **Cogway does not make any lifecycle gate depend on Codex hooks.**
The router (`ops/route-initiative.sh`) and the deliverable-field lint
(`ops/check-deliverable-fields.sh`) are the portable enforcement layer that works
identically on every platform — they are plain files and shell scripts, not
platform-specific hook infrastructure. Anything a Claude Code `PreToolUse` hook
enforces (see `adapters/claude-code/README.md`) that you also want on Codex must be
enforced by convention, by the router, or by CI — not by relying on `hooks.json`.

If you want to experiment with Codex hooks anyway, `hooks.json.example` shows the
shape of a config in commented form as a starting point. Treat it as unsupported and
subject to break on any Codex CLI upgrade until the upstream feature stabilizes.

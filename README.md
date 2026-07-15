# Cogway

Cogway is a lifecycle orchestrator for AI coding agents: a router script, a set of
phase rule files, and a canonical agent roster that turn "an agent decides what to
build next" into "a deterministic script decides, and a test suite proves the
decision logic is correct." The routing rules aren't a prompt an agent might
misread — they're bash conditions in `ops/route-initiative.sh`, checked by a real
fixture suite in `ops/tests/`. Don't take that on faith: run
`bash examples/demo-break-a-rule.sh` right now. It copies the router into a scratch
directory, breaks exactly one rule, reruns the full fixture suite against the broken
copy, and shows you the resulting `FAIL` lines — live, in your terminal, without
touching the real router. That's the whole pitch: the orchestrator's own test suite
catches a routing bug, on command.

## Quickstart

```bash
git clone <this-repo> cogway && cd cogway
```

**1. Run the test suite.** Five scripts cover the router, the deliverable-field
lint, a cross-file consistency check, the schema migration, and the agent-roster
generator, plus a self-test for the secret scanner:

```bash
bash ops/tests/route-initiative-test.sh          # 38 passed, 0 failed
bash ops/tests/check-deliverable-fields-test.sh  # 12 passed, 0 failed
bash ops/tests/field-map-consistency-test.sh     # 11 passed, 0 failed
bash ops/tests/schema-migration-test.sh          # 12 passed, 0 failed
bash agents/generate.sh && bash ops/tests/generate-test.sh
bash scripts/secret-scan-test.sh
```

**2. Run the demo.** Watch the suite catch an intentionally broken rule:

```bash
bash examples/demo-break-a-rule.sh
```

It comments out the D2 rule's action (discovery approved → dispatch design sprint)
in a scratch copy of the router, reruns the fixture suite against that copy, and
prints the `FAIL:` lines for every fixture that depended on D2 — then deletes the
scratch copy on exit. Your real `ops/route-initiative.sh` is never opened for
writing; the demo's own exit code is `0` because successfully showing a red test
*is* the demo working.

**3. Walk the example initiative through a gate.** `examples/walkthrough-initiative/`
is a real, runnable initiative — a discovery spec with an unfilled
`discovery_approved` field, plus a roadmap the router reads. Run it as-is:

```bash
bash ops/route-initiative.sh \
  examples/walkthrough-initiative/docs/initiatives/2026-01-01-example-feature \
  examples/walkthrough-initiative/roadmap.md
```

This prints `D1|escalate|gate-1` — no `discovery_approved` value is set, so the
router escalates to a human decision instead of guessing (see
`ops/rules/orchestrator.md`'s `escalate` section for what happens next).

To see the *next* rule fire (`D2|dispatch|design-sprint`, once discovery is
approved), you need a copy of just the discovery spec — the committed example
folder also has a `01-design-sprint.md` sitting next to it, and D2's condition is
specifically "approved, and no design sprint file exists yet," so editing the field
in place will land on `DS1` (design sprint pending), not `D2`:

```bash
mkdir -p /tmp/cogway-demo && \
  cp examples/walkthrough-initiative/docs/initiatives/2026-01-01-example-feature/00-discovery-spec.md \
     /tmp/cogway-demo/
sed 's/^discovery_approved:$/discovery_approved: approved/' \
  /tmp/cogway-demo/00-discovery-spec.md > /tmp/cogway-demo/tmp && \
  mv /tmp/cogway-demo/tmp /tmp/cogway-demo/00-discovery-spec.md
bash ops/route-initiative.sh /tmp/cogway-demo examples/walkthrough-initiative/roadmap.md
# -> D2|dispatch|design-sprint
rm -rf /tmp/cogway-demo
```

From there, the committed `01-design-sprint.md` (already present in the real
walkthrough folder, with its own unfilled `design_approved` field) shows the next
gate: `DS1|escalate|gate-2`.

## Lifecycle State Diagram

Built directly from the `assert_rule` pairs in `ops/tests/route-initiative-test.sh`
— rule name on the left, `ACTION|TARGET` on the right. `escalate` nodes are human
gates; `dispatch` nodes hand off to a phase's agent roster (see
`ops/rules/{phase}.md`); `update` nodes are orchestrator-only file edits; `no-op`
means nothing happens this run.

```mermaid
graph TD
    D0["D0: no discovery spec, no feature record"] -->|dispatch| DISCOVERY[discovery phase]
    D1["D1: discovery spec exists, unapproved"] -->|escalate| GATE1[gate-1]
    D1b["D1b: discovery rejected"] -->|update| ARCHIVE1[archive-initiative]
    D2["D2: discovery approved, no design sprint yet"] -->|dispatch| DESIGNSPRINT[design-sprint phase]
    DS1["DS1: design sprint exists, unapproved"] -->|escalate| GATE2[gate-2]
    DS2["DS2: design_approved = iterate"] -->|dispatch| DSITER[design-sprint-iteration]
    DS2b["DS2b: design rejected"] -->|update| ARCHIVE2[archive-initiative]
    DS3["DS3: design approved, new_product, no MVP dir yet"] -->|dispatch| BUILDMVP[build-mvp phase]
    DS4["DS4: design approved, iteration, no experiment report yet"] -->|dispatch| BUILDEXP[build-experiment phase]
    MVP1["MVP1: MVP verdict set, investment decision pending"] -->|escalate| GATE3[gate-3]
    MVP2["MVP2: investment approved, no feature record yet"] -->|dispatch| BUILDFEAT1[build-feature phase]
    MVP3["MVP3: investment rejected, no decommission report yet"] -->|dispatch| DECANALYST1[decommission-analyst]
    EXP0["EXP0: experiment report exists, verdict pending"] -->|no-op| NOOP1[stay in build-experiment]
    EXP1["EXP1: verdict = promote, no feature record yet"] -->|dispatch| BUILDFEAT2[build-feature phase]
    EXP2["EXP2: verdict = kill, no decommission report yet"] -->|dispatch| DECANALYST2[decommission-analyst]
    EXP3["EXP3: verdict = extend, extensions < 2"] -->|update| EXTENDEXP[extend-experiment]
    EXP4["EXP4: verdict = extend, extensions >= 2"] -->|escalate| GATE3B[gate-exp-inconclusive]
    BF0["BF0: feature record exists, build in_progress"] -->|no-op| NOOP2[stay in build-feature]
    BF1["BF1: build complete, baseline+thresholds set, no signals/improvements yet"] -->|update| MONITOR[begin-monitor]
    MON1["MON1: signal = trigger_improve_urgent"] -->|dispatch| IMPROVEURGENT[improve-urgent]
    MON2["MON2: signal = trigger_improve"] -->|dispatch| IMPROVE[improve phase]
    MON3["MON3: signal = stable"] -->|no-op| NOOP3[stay in monitor]
    IMP1["IMP1: mini_design_sprint_triggered, status pending"] -->|dispatch| MINISPRINT[mini-design-sprint]
    IMP2["IMP2: improvement recommends flag_decommission"] -->|dispatch| DECANALYST3[decommission-analyst]
    IMP3["IMP3: recommendation = stable or continue_improve"] -->|update| RETURNMONITOR[return-to-monitor]
    DEC1["DEC1: decommission report exists, unapproved"] -->|escalate| GATE4[gate-decommission]
    DEC2["DEC2: decommission approved"] -->|dispatch| DECEXEC[decommission-executor]
    DEC3["DEC3: decommission rejected"] -->|update| RETURNMONITOR2[return-to-monitor]
    FALLBACK["FALLBACK: no rule matched"] -->|escalate| HUMAN[human]
```

The test suite also runs 6 legacy bold-markdown fixtures (`*-legacy-bold`) proving
the router still parses the pre-frontmatter `**field:** value` format, plus one
`frontmatter-inline-comment` fixture exercising the comment-trim edge case
documented in `ops/rules/orchestrator.md` — 38 assertions total, all in
`ops/tests/route-initiative-test.sh`.

## Architecture

- **`AGENTS.md`** — the thin bootstrap adapter. Points any harness at the router
  and the skill; kept deliberately small (under a few hundred bytes) so it never
  approaches the 32768-byte size gate CI enforces.
- **`skills/orchestrator/SKILL.md`** — the step-by-step orchestrator procedure:
  call the router, branch on `ACTION`, read the matching `ops/rules/{phase}.md`
  file on demand, update `roadmap.md`.
- **`ops/`** — the enforcement layer. `route-initiative.sh` (the router),
  `check-deliverable-fields.sh` (write-side field lint), `rules/` (11 phase rule
  files ported from the personal system, minus the two that were entirely
  client/billing-facing), `schemas/` (8 deliverable frontmatter schemas),
  `templates/` (initiative folder skeletons), and `tests/` (the fixture suite
  covering all of the above).

Everything under `ops/` is plain bash and markdown — no Node, no Python, no
dependency to install before the router runs.

## Platform Support

| Platform | Status | Notes |
|---|---|---|
| **Claude Code** | Flagship | Agent roster generated to `.claude/agents/*.md`. Team primitives (roster dispatch, task tracking) and `PreToolUse` hook patterns are documented in `adapters/claude-code/README.md`; `settings.json.example` is an illustrative skeleton, not a real config. |
| **Codex** | Supported | Agent roster generated to `.codex/agents/*.toml`. Runs the same router and rule files. `hooks.json.example` ships **documented but off** — Codex's hook mechanism is experimental, off by default, and has no Windows support, so no lifecycle gate in Cogway depends on it (see `adapters/codex/README.md`). Model-name and tools-grant-key mappings in generated `.toml` files carry `VERIFY-AT-BUILD-TIME` comments pending confirmation against a real Codex CLI install. |

Other harnesses mentioned in earlier planning (Copilot, Cursor, Antigravity) are
**deferred, not silently unsupported** — Cogway does not claim to run identically
across every possible agent harness. Two platforms are built and tested; more may
follow.

Run `agents/generate.sh` from the repo root to populate both `.claude/agents/` and
`.codex/agents/` from the 36 canonical sources in `agents/_canonical/`. Both output
directories are gitignored — they're generated, not hand-maintained — so re-run the
generator any time a canonical source changes.

## Security

`scripts/secret-scan.sh` is the single source of truth for secret detection —
pattern-based (AWS keys, generic `key:`/`token:`/`password:`-shaped assignments,
PEM private-key headers), no external dependency. CI job 3 runs it on every
push/PR. It is also meant to be run by hand — `bash scripts/secret-scan.sh .` —
immediately before this repo's first `git push` to any remote, so a leaked secret
is caught before it's committed to public history rather than after; this local
run is a documented required step, not (yet) an installed git hook.

## Contributing

This is a young, single-maintainer project. The router and its test suite are the
contract — a change to `ops/route-initiative.sh` isn't done until
`ops/tests/route-initiative-test.sh` (and the fixture it needs) reflects it. Start
by reading `AGENTS.md` and `skills/orchestrator/SKILL.md`, then `ops/rules/` for
the phase you're touching.

Open items:
- `LICENSE` is a draft (MIT, placeholder copyright holder) pending confirmation
  before this repo goes public — see `LICENSE` itself for the current status.
- Codex model-name and tools-grant-key mappings need verification against a real
  Codex CLI install (see the `VERIFY-AT-BUILD-TIME` markers in generated
  `.codex/agents/*.toml`).
- Adapters beyond Claude Code and Codex are not yet built.

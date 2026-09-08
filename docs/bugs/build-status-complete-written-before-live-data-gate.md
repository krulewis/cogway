# `build_status: complete` is written before the Live-Data Validation Gate runs

**Status:** open — latent until the router-enforced gate ships, then live.
**Severity:** low mechanically, moderate behaviourally.
**Found:** 2026-09-08, during the architecture decision for the router-enforced gate.
**Affects:** `ops/rules/orchestrator.md`, `ops/rules/build-feature.md`, and rule `BF1b`
once the router-enforced gate lands.

## The problem

Two orderings disagree about what `build_status: complete` means.

`ops/rules/orchestrator.md` has the orchestrator write `build_status: complete` **after the
PR review loop closes**. `ops/rules/build-feature.md` runs the Live-Data Validation Gate
**after that** — after the PR loop, before `playwright-qa` / `docs-updater` /
`functional-review-writer`.

So there is a window in which a feature record is fully BF1-eligible — `build_status:
complete`, baseline metrics populated, thresholds populated — while the live-data gate has
not yet run. Any session that ends inside that window leaves the initiative in a state where
the next router call returns `BF1b|escalate|gate-live-data`.

That escalation is **correct** — the initiative genuinely must not advance to `monitor` with
an unvalidated pipeline. The problem is that it is also **routine**. It fires in normal
operation, not only on mistakes.

## Why it matters

A gate that cries wolf during ordinary work gets dismissed during ordinary work. The whole
value of `BF1b` is that a human or orchestrator treats it as a real blocker; a benign
escalation that shows up on well-run initiatives trains exactly the opposite reflex. This is
the most likely way the live-data gate degrades back into the prose gate it replaced.

The root cause is semantic: `build_status: complete` currently means "the PR merged," not
"the build is validated." Those were the same thing before the gate existed. They are not
anymore.

## Options

1. **Move the write.** Have the orchestrator write `build_status: complete` *after* the
   live-data gate closes rather than after the PR review loop. Eliminates the window
   entirely and makes `complete` mean "validated," which is arguably what a reader already
   assumes it means. Cost: it changes the meaning of an existing field mid-flight, and any
   initiative currently sitting between PR-merge and gate has its `build_status` semantics
   shift under it.
2. **Add an intermediate value.** e.g. `build_status: in_progress | merged | complete`, with
   BF1 requiring `complete` and the gate being what promotes `merged` -> `complete`. Most
   explicit, but it is a routing-field value change, so it touches the router, the lint,
   `field-map-consistency-test.sh`'s expected table, both schemas and every feature-record
   fixture.
3. **Leave it and document.** What was chosen for the gate initiative itself — the hazard is
   noted in `build-feature.md` and the escalation message states both resolutions, so an
   orchestrator resolves it inline before ending the run rather than deferring to a human.

## Decision so far

Option 3, deliberately and temporarily. Kelly Lewis's call on 2026-09-08 was to keep the
gate initiative's blast radius honest rather than change existing orchestrator behaviour in
the same change. Options 1 and 2 are a separate, small initiative.

## Not yet decided

Which of options 1 and 2 to take, and whether the semantic change to `build_status` warrants
a schema version bump (nothing in `route-initiative.sh` reads `version`, so a bump would be
for audit legibility only).

## Referenced from

- `ops/rules/orchestrator.md`'s `build_status` and `live_data_validation` section (states
  both the Build:Feature and Improve escalation windows, with task numbers, and links here
  for the full analysis)
- `ops/rules/build-feature.md`'s Live-Data Validation Gate section
- `ops/rules/improve.md`'s Live-Data Validation Gate section (added by the live-data-gate
  initiative; Improve's window — tasks 1 through 8 — is wider than Build:Feature's and is
  noted at the point of reference, not here, since this doc's Options/Decision-so-far
  sections were written against the Build:Feature case specifically)

# Example Project Roadmap

The orchestrator reads this file on every run. Keep `Phase`, `RAG`, and `Pending` current for
each initiative — see `ops/rules/orchestrator.md` ("Updating roadmap.md") for the update rules,
and `ops/rules/rag-rules.md` for how RAG is calculated.

This file is part of Cogway's runnable walkthrough example (see the repo README's Quickstart).
Try it yourself:

```
bash ops/route-initiative.sh examples/walkthrough-initiative/docs/initiatives/2026-01-01-example-feature examples/walkthrough-initiative/roadmap.md
```

That should print `D1|escalate|gate-1` — the discovery spec below has an unfilled `discovery_approved`
field, so the router escalates to a human decision instead of guessing. See the README's Quickstart
for how to edit the field and watch the routing decision change.

## Active Initiatives

| ID | Slug | Type | Phase | RAG | Pending | Path |
|---|---|---|---|---|---|---|
| EXAMPLE-001 | example-feature | iteration | discovery | 🟢 | gate_1 (0d) | docs/initiatives/2026-01-01-example-feature |

**Type values:** `new_product` \| `iteration`
**Phase values:** `discovery` \| `design_sprint` \| `build_mvp` \| `build_experiment` \| `build_feature` \| `monitor` \| `improve` \| `decommission`
**RAG values:** 🟢 \| 🟡 \| 🔴
**Pending values:** `none` \| `gate_1 ({N}d)` \| `gate_2 ({N}d)` \| `gate_3 ({N}d)` \| `gate_4 ({N}d)`

## Archived Initiatives

None yet — this is a fresh example.

## Adding an initiative

1. Create a folder: `docs/initiatives/YYYY-MM-DD-{slug}/`
2. Copy the relevant schema from `ops/schemas/` into that folder (e.g.
   `ops/schemas/00-discovery-spec-schema.md` → `docs/initiatives/YYYY-MM-DD-{slug}/00-discovery-spec.md`)
3. Add a row to Active Initiatives above
4. Run `ops/route-initiative.sh` against the new folder to confirm it routes to `D0|dispatch|discovery`
   or `D1|escalate|gate-1`, depending on whether a discovery spec already exists

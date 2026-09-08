# Improvement Reports

Named `YYYY-MM-DD-{N}-improvement.md` where N is the iteration count for that date.
Each Improve cycle produces one file. Do not overwrite previous reports.

Required frontmatter fields: `recommendation` (set by `improve-analyst`, task 1) and
`live_data_validation` (set by the orchestrator after the Live-Data Validation Gate closes
clean — see `ops/rules/build-common.md`'s "Recording the outcome" subsection and
`ops/rules/improve.md`'s Live-Data Validation Gate section). Both are read by
`ops/route-initiative.sh`; an absent `live_data_validation` routes to `IMP3b|escalate|gate-live-data` — unless a
`stable` signal report is present, in which case `MON3` matches first and the gate is
never reached.

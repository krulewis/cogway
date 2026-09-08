# Improvement Reports

Named `YYYY-MM-DD-{N}-improvement.md` where N is the iteration count for that date.
Each Improve cycle produces one file. Do not overwrite previous reports.

Required frontmatter fields: `recommendation` (set by `improve-analyst`, task 1) and
`live_data_validation` (also written by `improve-analyst` at task 1, left **blank** —
`check-deliverable-fields.sh` requires the field line to be present unconditionally,
and blank is a valid pre-gate state; the orchestrator fills in the value after the
Live-Data Validation Gate closes clean — see `ops/rules/build-common.md`'s "Recording
the outcome" subsection and `ops/rules/improve.md`'s Live-Data Validation Gate
section). Both are read by `ops/route-initiative.sh`; a blank/absent
`live_data_validation` routes to `IMP3b|escalate|gate-live-data` — unless the most
recent signal report recommends `stable`, in which case `MON3` matches first and the
gate is never reached.

# Build-phase shared rules — loads as: ops/rules/build-common.md
# Not a dispatch target. Referenced by build-mvp.md, build-experiment.md,
# build-feature.md and improve.md rather than duplicated in each, so a fix here
# fixes all four at once.

Applies to **Build:MVP, Build:Experiment, Build:Feature and Improve** — every phase that
dispatches `implementer` and runs a PR review loop.

Deliberately **not** applied to Discovery, Design Sprint, Monitor or Decommission: none of
those dispatch `implementer` or produce a new running pipeline. They produce documents, or
read from pipelines that were already validated when they were built. If a future phase
starts building or modifying live pipelines, add it here.

---

## Live-Data Validation Gate

"Automatable on paper" is not the same as "produces real, correct output." The recurring
failure shape this gate exists to catch:

- A metric's capture method passes spec review, then silently returns nothing — or the
  wrong thing — for its entire measurement window. Observed causes include a missing CI
  permission, a query filtering on a field the capture tool never actually populates, and
  an unset config variable. None surfaced until the window closed and a promote/kill
  decision was already due, by which point the window's data was unrecoverable. One of
  these nearly triggered a decommission review over a measurement artifact rather than a
  real defect.
- A scheduled job whose write destination had been created but never initialised, so its
  first real run failed immediately. The build's own verification had exercised only the
  *read* side; nothing had ever confirmed the write destination existed.
- The same job, after that fix, silently corrupting its payload on every run through an
  encoding bug. It exited 0, wrote a file of a plausible size, and recorded a real entry
  in its state file — every automatable check available passed. Nobody had opened the file
  and read it.

All of them are one shape: **verifying that a pipeline ran successfully is not the same as
verifying that what it produced is real and correct.** A green check, a non-zero file size
and a populated state entry are necessary but not sufficient.

### When this gate runs

- **Build:MVP / Build:Experiment** — after the PR review loop (and `security-reviewer`, for
  Experiment) closes clean, and **before** the orchestrator records a `window_start_date` or
  advances the initiative to `monitor`.
- **Build:Feature** — after the PR review loop closes clean, and **before** `playwright-qa` /
  `docs-updater` / `functional-review-writer` run.
- **Improve** — after the PR review loop closes clean, and **before** the final
  `staff-reviewer` sign-off and the return to `monitor`.

Each phase file names its own trigger point in task numbers; this file owns the checks.

### The checks

For every metric, capture script, export, transcript, digest, report, or any other artifact
the build produces on a schedule or a trigger:

1. **Run once on live data.** The pipeline has actually been executed at least once against
   real data — not a fixture or a mock — and produced a real, sane result, not an error,
   `N/A`, or an unexplained zero/empty result. A pipeline that returns nothing sane on its
   first live run is a build defect, not a valid baseline. Return it to
   `implementer`/`debugger` and re-verify before the gate closes.
2. **Manually triggerable.** The pipeline can be invoked on demand — by an agent or by a
   human — via a flag, a `workflow_dispatch` input, or a direct script call, not solely on a
   fixed cron schedule. This is what makes a mid-window "is this still working?" spot-check
   take minutes instead of a wait for the next scheduled run.
3. **Write destination exists and is writable, if the pipeline creates one.** If the plan has
   the pipeline write to a destination it has never written to before — a new repo, bucket,
   table or resource — confirm that destination exists and accepts a write before considering
   the pipeline validated. Confirming the read/query side returns real data is not the same
   check.
4. **Read the actual produced content — do not stop at exit code, existence, or file size.**
   For any pipeline whose deliverable is content a human will read (a transcript, digest,
   export, report — not just a numeric metric), open and read a real sample of what it
   actually produced. "The job succeeded and wrote a plausible-sized file" is proof the job
   did not crash, not proof the content is correct. This is the check that catches encoding
   and serialisation corruption, and it is the one most often skipped because it feels
   redundant after check 1 passes.

If any check fails, the gate does not close — fix and re-verify before proceeding.

### Forcing an unambiguous re-verification

A re-run after a fix can look like it passed without actually re-exercising the broken path.
An idempotent or watermarked pipeline may correctly do nothing on a re-run because the
affected item has already scrolled outside its processing window. Do not accept an ambiguous
"it ran and didn't error" as proof of a fix. If a straightforward re-run does not
unambiguously exercise the fixed code path:

- Read the run's own log output, not just its pass/fail status, to see what it actually did —
  how many items it processed, not merely that it succeeded.
- If needed, deliberately reset just enough state to force a clean re-test — for example
  rewinding a watermark or cursor file to before the affected item. Use a small, reversible,
  low-blast-radius edit to the pipeline's *own* state, never to production user data. Then
  re-run and confirm the state settles back to a correct value on its own afterwards.
- Only then read the actual output, per check 4.

Confirm the log shows real work happened, force a clean test if the first re-run was a no-op,
then read the real output.

### Recording the outcome

Write the result into the deliverable the gate protects — a claim with no evidence is
indistinguishable from a claim never made, and the router requires both:

- **Field:** `live_data_validation: validated | not_applicable | failed` (blank until the
  gate runs; blank is allowed pre-gate, same as every other gate field).
- **Table:** a `## Live Data Validation` heading with **at least one data row**, required
  for *both* `validated` and `not_applicable` — a claim with zero rows does not satisfy
  the gate, even if the scalar is set to a passing value.

| Column | Content |
|---|---|
| Pipeline | The scheduled job, capture script, export, digest, or report this row covers |
| Manual trigger | The exact command/flag/`workflow_dispatch` input used to invoke it on demand |
| First live run | Date/time and a concrete result (an item count, not just "ran") |
| Write destination | Where it wrote, and confirmation the write landed |
| Content read | What was opened and read, and whether it was correct |

**Vacuous-build row.** If the build added no scheduled or triggered pipeline, capture
script, export, digest, or report, write `not_applicable` and exactly one row of this
shape, naming the PR scanned:

| Pipeline | Manual trigger | First live run | Write destination | Content read |
|---|---|---|---|---|
| (none) | — | — | — | no cron, `workflow_dispatch`, scheduled job, capture script or export added in PR #NNN |

**What counts as "a pipeline" (resolves ambiguity toward `validated`, not
`not_applicable`):** a cron/schedule, a `workflow_dispatch` input, a scheduled job, a
capture script, an export, a digest, a transcript generator, or a report generator. **If
uncertain whether something counts, the default is to run it and record `validated` — not
to reach for `not_applicable`.** `not_applicable` is for builds that genuinely produced
none of the above, not for builds where checking felt like more effort than skipping.

**Target file per phase:**

| Phase | File | Routed? |
|---|---|---|
| Build:Feature | `03-feature/feature-record.md` | Yes — `route-initiative.sh` BF1/BF1b |
| Improve | `03-feature/improvement-reports/*.md` (current report) | Yes — `route-initiative.sh` IMP3/IMP3b |

**Build:MVP and Build:Experiment record the gate outcome in prose in their existing report
body and do not use the `live_data_validation` field or the `## Live Data Validation`
heading.** `window_start_date` is written by `experiment-designer` and read by no router
rule (`route-initiative.sh` never references it — it appears only in
`ops/schemas/02-experiment-report-schema.md` and agent prose), so there is no routed
"window opens" transition to hang a field check on. Inventing one is a separate
initiative — see `build-mvp.md` / `build-experiment.md` for the one-sentence pointer each
carries. **Do not infer symmetric enforcement across all four phases from this section**
— only Build:Feature and Improve are router-enforced today.

**The central limit, stated plainly — do not soften this anywhere:**

> This gate converts "silently skipped" into "explicitly claimed." An agent that FORGETS
> is blocked. An agent that LIES is not.

A router reads a string and counts table rows; it cannot execute the pipeline, inspect the
output, or verify that a timestamp corresponds to a real run. `validated` with a
fabricated evidence row routes identically to an honest one. The evidence table raises the
cost of lying (five independently falsifiable strings instead of one flipped enum) and
leaves an artifact a human or reviewer can check against the PR diff — it does not close
the gap.

### Escalation message (BF1b / IMP3b)

When `route-initiative.sh` returns `BF1b|escalate|gate-live-data` or
`IMP3b|escalate|gate-live-data`, the orchestrator's `AskUserQuestion` must state all three
resolutions explicitly, using the generic Format block in `ops/rules/orchestrator.md`'s
`escalate` section, with this **Decision required** text:

> `live_data_validation` in `<path>` must be set to `validated` or `not_applicable`,
> **and** the `## Live Data Validation` table must have at least one row. Those two values
> are the only ones that clear the gate. `failed` is a valid state to record — it says the
> checks ran and something did not pass — but it does **not** clear the gate and the router
> will keep returning this escalation until the underlying failure is fixed and the value
> changes. If the gate already ran and passed, record it. If this build adds no scheduled
> or triggered pipeline, write `not_applicable` and a `(none)` row naming the PR you
> checked. **If the phase has not yet reached the gate, this escalation is premature —
> resume the phase; do not write a value to clear it.**

`<path>` is `03-feature/feature-record.md` for `BF1b`; the current
`03-feature/improvement-reports/*.md` file for `IMP3b`. The rule name (`BF1b` vs `IMP3b`)
disambiguates which, so the message does not need to restate it.

The third resolution above closes a gap that would otherwise train people to pick
whichever answer is fastest: Improve's escalation window (tasks 1–8, see
`orchestrator.md`'s `build_status`/`live_data_validation` section) is wide enough that a
mid-phase router call is the common case, not the exception, and a two-resolution message
offers no honest answer for it — the path of least resistance would be to write a value
just to clear the escalation, which is the exact rubber-stamping this gate exists to
prevent.

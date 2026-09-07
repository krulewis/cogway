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

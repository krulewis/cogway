#!/usr/bin/env bash
# examples/demo-break-a-rule.sh — "watch the suite go red"
#
# Cogway's routing logic is enforced by a real, failing test suite, not
# vibes. This demo proves it live, without touching anything real:
#
#   1. Copies ops/route-initiative.sh into a scratch temp directory. The
#      REAL file at ops/route-initiative.sh is never opened for writing.
#   2. Uses sed to comment out ONE line in the SCRATCH COPY: the action
#      line of the D2 rule ("discovery approved, no design sprint yet ->
#      dispatch design-sprint"). That rule's bash condition and action are
#      joined across two physical lines with a backslash continuation;
#      bash splices continuation lines together before comment parsing
#      runs, so commenting out just the action line turns the whole
#      logical line into a condition test with no action — the rule goes
#      silent instead of throwing a syntax error. One clean, single-line
#      sed edit is enough to break it.
#   3. Runs the full fixture suite (ops/tests/route-initiative-test.sh)
#      against the BROKEN SCRATCH COPY — not the real router — by laying
#      out a copy of the test harness inside a sibling "tests/" directory
#      under the same scratch root. The harness resolves the script it
#      tests as "$(dirname <itself>)/../route-initiative.sh", so this
#      sibling layout is what points it at the broken copy instead of the
#      real one. Fixture DATA is symlinked from the real
#      ops/tests/fixtures/ — fixtures are not part of what's under test
#      here and are never modified.
#   4. Prints the suite's real output, including the resulting FAIL
#      line(s), so you can watch it happen.
#   5. Deletes the scratch directory on exit — success, failure, or
#      Ctrl-C — via `trap ... EXIT`. No manual cleanup step.
#
# Exit code contract (read this before you check `$?`):
#   This script's OWN exit code is 0 when it successfully DEMONSTRATES a
#   red test — i.e., the inner suite run it displays contains at least one
#   "FAIL:" line. The inner suite's own exit code is non-zero (a fixture
#   failed, as intended) and is reported in the output, but is
#   deliberately NOT propagated as this script's exit code: seeing "FAIL"
#   in the demo output is the demo working correctly, not the demo
#   failing. If the suite unexpectedly stays green (e.g. the D2 rule's
#   exact text no longer matches what this script expects to edit,
#   because route-initiative.sh has since changed), THAT is treated as
#   this demo failing, and this script exits non-zero instead.
#
# Verify nothing real was touched, any time, with:
#   git status ops/route-initiative.sh ops/tests/route-initiative-test.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REAL_ROUTER="$REPO_ROOT/ops/route-initiative.sh"
REAL_TEST="$REPO_ROOT/ops/tests/route-initiative-test.sh"
REAL_FIXTURES="$REPO_ROOT/ops/tests/fixtures"

TARGET_LINE_TEXT='    && echo "D2|dispatch|design-sprint" && exit 0'

SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/cogway-demo-break-a-rule.XXXXXX")"
cleanup() {
    rm -rf "$SCRATCH"
}
trap cleanup EXIT

echo "== Cogway demo: watch the suite go red =========================="
echo ""
echo "1. Copying ops/route-initiative.sh into a scratch directory (the real file is untouched)..."
cp "$REAL_ROUTER" "$SCRATCH/route-initiative.sh"
mkdir -p "$SCRATCH/tests"
cp "$REAL_TEST" "$SCRATCH/tests/route-initiative-test.sh"
ln -s "$REAL_FIXTURES" "$SCRATCH/tests/fixtures"

echo "2. Breaking the D2 rule (discovery approved -> dispatch design-sprint) in the SCRATCH COPY only..."
target_line_no="$(grep -nF "$TARGET_LINE_TEXT" "$SCRATCH/route-initiative.sh" | head -1 | cut -d: -f1)"
if [ -z "$target_line_no" ]; then
    echo "demo-break-a-rule.sh: expected D2 rule text not found — route-initiative.sh has drifted since this demo was written." >&2
    exit 1
fi
sed -i.bak "${target_line_no}s/^/# /" "$SCRATCH/route-initiative.sh"
rm -f "$SCRATCH/route-initiative.sh.bak"
echo "   (commented out line $target_line_no of the scratch copy — the D2 rule now falls through silently)"
echo ""

echo "3. Running the full fixture suite against the BROKEN scratch copy..."
echo "-------------------------------------------------------------------"
set +e
suite_output="$(bash "$SCRATCH/tests/route-initiative-test.sh" 2>&1)"
suite_exit=$?
set -e
echo "$suite_output"
echo "-------------------------------------------------------------------"
echo ""

if echo "$suite_output" | grep -q '^FAIL:'; then
    echo "Demo succeeded: broke one rule, the suite caught it (inner suite exit code: $suite_exit — non-zero is expected)."
    echo "Real files are untouched. Verify with: git status ops/route-initiative.sh ops/tests/route-initiative-test.sh"
    exit 0
else
    echo "Demo did not observe a FAIL line in the suite output — something is wrong with the demo itself, not with route-initiative.sh." >&2
    exit 1
fi

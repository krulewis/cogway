#!/usr/bin/env bash
# Test harness for ops/check-deliverable-fields.sh
# Usage: bash ops/tests/check-deliverable-fields-test.sh
#
# Exit-code-only assertions (assert_exit) are sufficient for cases where the
# expected exit code cannot be produced any other way. For the improvement-reports
# directory-dispatch cases, a script with no directory branch at all falls through
# to the basename case's "*)" no-op, which coincidentally ALSO exits 0 for every
# one of these fixtures — so an exit-code-only check would be vacuously green
# before the fix lands. Those cases use assert_exit_and_contains, which
# additionally requires a specific validated-field line in stdout, so they
# genuinely fail red until the directory-based dispatch is implemented.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SCRIPT_DIR/../check-deliverable-fields.sh"
FIXTURES="$SCRIPT_DIR/fixtures"
FIXTURES_LINT="$SCRIPT_DIR/fixtures-lint"
PASS=0
FAIL=0

assert_exit() {
    local file="$1" expected_exit="$2"
    local output actual_exit
    output=$(bash "$SCRIPT" "$file" 2>&1)
    actual_exit=$?
    if [ "$actual_exit" -eq "$expected_exit" ]; then
        echo "PASS: $file → exit $expected_exit"
        PASS=$((PASS + 1))
    else
        echo "FAIL: $file"
        echo "  expected exit: $expected_exit"
        echo "  actual exit:   $actual_exit"
        echo "  output:"
        echo "$output" | sed 's/^/    /'
        FAIL=$((FAIL + 1))
    fi
}

assert_exit_and_contains() {
    local file="$1" expected_exit="$2" must_contain="$3"
    local output actual_exit
    output=$(bash "$SCRIPT" "$file" 2>&1)
    actual_exit=$?
    if [ "$actual_exit" -eq "$expected_exit" ] && printf '%s\n' "$output" | grep -qF "$must_contain"; then
        echo "PASS: $file → exit $expected_exit, contains '$must_contain'"
        PASS=$((PASS + 1))
    else
        echo "FAIL: $file"
        echo "  expected exit: $expected_exit, output containing: '$must_contain'"
        echo "  actual exit:   $actual_exit"
        echo "  output:"
        echo "$output" | sed 's/^/    /'
        FAIL=$((FAIL + 1))
    fi
}

# ── Case matrix ────────────────────────────────────────────────────────────────
assert_exit "$FIXTURES/decommission-approved/04-decommission-report.md" 0
assert_exit "$FIXTURES/discovery-pending/00-discovery-spec.md" 0
assert_exit "$FIXTURES_LINT/invalid-value/00-discovery-spec.md" 1
assert_exit "$FIXTURES_LINT/missing-field/00-discovery-spec.md" 1
assert_exit "$FIXTURES_LINT/duplicate/00-discovery-spec.md" 1
assert_exit "$FIXTURES_LINT/duplicate-fm-body/00-discovery-spec.md" 1
assert_exit "$FIXTURES_LINT/not-gated/README.md" 0

# *-signal.md basename dispatch
assert_exit_and_contains "$FIXTURES_LINT/signal-valid/2026-01-01-signal.md" 0 "recommendation = stable"

# `failed` with an empty evidence table must LINT CLEAN. Only a passing claim
# (validated / not_applicable) needs evidence: `failed` escalates at BF1b/IMP3b
# whatever the table holds, so demanding rows for it would block a valid record
# for no routing benefit. Guards the narrowing of that check — without this, the
# condition could be widened back to "any non-empty value" and nothing would fail.
assert_exit "$FIXTURES_LINT/feature-record-failed-no-rows/feature-record.md" 0

# An improvement report missing `live_data_validation` entirely must FAIL. This is
# the only assertion that proves the field is REQUIRED on this deliverable: the
# positive fixtures pass their OK line from the evidence-table block, which is
# independent of `specs`, so without this the spec could be deleted from the
# improvement-reports branch and nothing would go red.
assert_exit_and_contains "$FIXTURES_LINT/improvement-reports/2026-06-02-missing-ldv.md" 1 "live_data_validation"

# CRLF feature record claiming `validated` over a header+separator-only table.
# The lint's count_entries() copy must strip \r before testing for a separator,
# exactly as the router's does — otherwise the separator counts as a data row and
# the lint says PASS while the router says BF1b. That split is the precise thing
# field-map-consistency-test.sh exists to prevent, and no CRLF file existed under
# fixtures-lint/ to catch it.
assert_exit "$FIXTURES_LINT/feature-record-crlf-no-rows/feature-record.md" 1
# Same guard the router suite carries. Without it, normalising this fixture AND
# stripping the lint's CR handling both pass — the fixture quietly becomes a
# duplicate of an LF one and the thing it guards goes untested.
if grep -q $'\r' "$FIXTURES_LINT/feature-record-crlf-no-rows/feature-record.md" 2>/dev/null; then
  echo "PASS: feature-record-crlf-no-rows still contains CR"; PASS=$((PASS + 1))
else
  echo "FAIL: feature-record-crlf-no-rows has NO CR — normalised, no longer tests CRLF handling"; FAIL=$((FAIL + 1))
fi

# improvement-reports directory-based dispatch (recommendation-gated, mini_* optional)
assert_exit_and_contains "$FIXTURES_LINT/improvement-reports/2026-01-01-report.md" 0 "recommendation = continue_improve"

# archived improvement report — must NOT be caught by the directory dispatch
# (parent dir is "archive", not "improvement-reports")
assert_exit "$FIXTURES_LINT/improvement-reports/archive/2026-01-01-report.md" 0

# contrast fixture: recommendation only, no mini_* fields — must still validate
# and PASS, proving the two mini_* fields are OPTIONAL not required
assert_exit_and_contains "$FIXTURES_LINT/improvement-reports/2026-05-07-architectural-audit.md" 0 "recommendation = continue_improve"

# contrast fixture: co-located non-gated file in the same directory — must NOT
# be treated as a gated report at all
assert_exit "$FIXTURES_LINT/improvement-reports/2026-05-07-requirements.md" 0

# feature-record.md lint fixture set (basename dispatch — new for the live-data gate)
assert_exit_and_contains "$FIXTURES_LINT/feature-record-missing/feature-record.md" 1 "live_data_validation — field line absent"
assert_exit "$FIXTURES_LINT/feature-record-blank/feature-record.md" 0
assert_exit_and_contains "$FIXTURES_LINT/feature-record-claim-no-rows/feature-record.md" 1 "no rows found under '## Live Data Validation'"
assert_exit "$FIXTURES_LINT/feature-record-invalid/feature-record.md" 1
assert_exit_and_contains "$FIXTURES_LINT/feature-record-validated/feature-record.md" 0 "live_data_validation = validated"
assert_exit "$FIXTURES_LINT/feature-record-spaced-separator/feature-record.md" 1

# improvement-reports directory-dispatch positive fixture (proves the evidence check on
# the OTHER dispatch branch, not just the feature-record.md basename branch)
assert_exit_and_contains "$FIXTURES_LINT/improvement-reports/2026-06-01-ldv-report.md" 0 "live_data_validation = not_applicable"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1

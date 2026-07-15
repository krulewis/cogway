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

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1

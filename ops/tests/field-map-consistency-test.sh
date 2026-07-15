#!/usr/bin/env bash
# field-map-consistency-test.sh
#
# Static consistency test: asserts, for each gated deliverable type, that
# check-deliverable-fields.sh's required-field list equals the field names
# route-initiative.sh actually calls field() with for that deliverable path.
# Guards the drift class where a lint validates one field name while the
# router reads a different one for the same gate decision.
#
# The expected table below is hardcoded (authoritative source-of-truth) — do
# not re-derive it dynamically.
#
# Portability note: macOS ships bash 3.2 (no associative arrays), matching
# route-initiative.sh/check-deliverable-fields.sh's own bash-3.2-safe style —
# the expected table below is a plain "pattern|keys" line list, not `declare -A`.
#
# Usage: bash ops/tests/field-map-consistency-test.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINT_SCRIPT="$SCRIPT_DIR/../check-deliverable-fields.sh"
ROUTE_SCRIPT="$SCRIPT_DIR/../route-initiative.sh"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

# ── Helper: extract key names from a basename/glob case entry's specs=() list ──
extract_keys_for_case() {
    local pattern="$1" file="$2"
    grep -E "  ${pattern}\)" "$file" \
        | grep -oE '"[a-zA-Z_]+=' \
        | sed -E 's/^"//; s/=$//' \
        | sort
}

# ── Expected table (basename/glob rows): "pattern|comma,separated,keys" ────────
EXPECTED_TABLE='00-discovery-spec\.md|discovery_approved
01-design-sprint\.md|design_approved,initiative_type
mvp-experiment-report\.md|investment_decision,overall_verdict
experiment-report\.md|overall_verdict
feature-record\.md|build_status
04-decommission-report\.md|decommission_approved
\*-signal\.md|recommendation'

while IFS='|' read -r pattern keys; do
    [ -z "$pattern" ] && continue
    expected_sorted=$(printf '%s\n' "$keys" | tr ',' '\n' | sort)
    actual_sorted=$(extract_keys_for_case "$pattern" "$LINT_SCRIPT")
    if [ "$actual_sorted" = "$expected_sorted" ]; then
        pass "case '$pattern' → required fields match ($(echo "$expected_sorted" | tr '\n' ',' | sed 's/,$//'))"
    else
        fail "case '$pattern' → required-field mismatch. expected: [$(echo "$expected_sorted" | tr '\n' ',')] actual: [$(echo "$actual_sorted" | tr '\n' ',')]"
    fi
done <<< "$EXPECTED_TABLE"

# ── <dir:improvement-reports> row — required/optional split ────────────────────

# 1. `recommendation` must be assigned unconditionally, immediately inside the
#    `if [ "$parent" = "improvement-reports" ]` branch (not behind a presence guard).
if grep -A1 'if \[ "\$parent" = "improvement-reports" \]' "$LINT_SCRIPT" 2>/dev/null \
    | tail -1 | grep -q 'specs=("recommendation='; then
    pass "improvement-reports directory branch → recommendation assigned unconditionally"
else
    fail "improvement-reports directory branch → recommendation NOT found assigned unconditionally immediately inside the if-branch (directory dispatch may be missing entirely)"
fi

# 2. mini_design_sprint_triggered and mini_sprint_status must each be behind a
#    count_lines ... -gt 0 && specs+= presence guard within the if/else range —
#    never assigned unconditionally.
_if_else_range() {
    awk '/if \[ "\$parent" = "improvement-reports" \]/{f=1} f{print} f && /else/{exit}' "$LINT_SCRIPT"
}

for mini_field in mini_design_sprint_triggered mini_sprint_status; do
    range_text=$(_if_else_range)
    if echo "$range_text" | grep -qE "count_lines.*\"${mini_field}\".*-gt 0.*&&.*specs\+="; then
        pass "improvement-reports directory branch → ${mini_field} is behind a presence guard (optional)"
    else
        fail "improvement-reports directory branch → ${mini_field} NOT found behind a presence guard (either the directory dispatch is missing, or it wrongly requires this field unconditionally)"
    fi
    # Regression guard: must NOT appear as an unconditional specs=(...) entry
    # (that would mean the over-matching bug crept back in)
    if echo "$range_text" | grep -qE 'specs=\("'"${mini_field}"'='; then
        fail "improvement-reports directory branch → ${mini_field} found assigned UNCONDITIONALLY (over-matching regression)"
    fi
done

# ── Router-side cross-check ──────────────────────────────────────────────────
router_missing=""
for name in IMPROVEMENT_REPORTS_DIR recommendation mini_design_sprint_triggered mini_sprint_status; do
    grep -q "$name" "$ROUTE_SCRIPT" || router_missing="$router_missing $name"
done
if [ -z "$router_missing" ]; then
    pass "route-initiative.sh references all of: IMPROVEMENT_REPORTS_DIR, recommendation, mini_design_sprint_triggered, mini_sprint_status"
else
    fail "route-initiative.sh missing references to:$router_missing"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1

#!/usr/bin/env bash
# Test harness for ops/route-initiative.sh
# Usage: bash ops/tests/route-initiative-test.sh
#
# Repo-relative — no $HOME dependency (the one portability requirement the
# architecture flags). Verify with: HOME=/nonexistent bash ops/tests/route-initiative-test.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SCRIPT_DIR/../route-initiative.sh"
FIXTURES="$SCRIPT_DIR/fixtures"
PASS=0
FAIL=0

assert_rule() {
    local fixture="$1" expected="$2"
    local actual
    actual=$(bash "$SCRIPT" "$FIXTURES/$fixture" "/dev/null" 2>/dev/null)
    if [ "$actual" = "$expected" ]; then
        echo "PASS: $fixture → $expected"
        PASS=$((PASS + 1))
    else
        echo "FAIL: $fixture"
        echo "  expected: $expected"
        echo "  actual:   $actual"
        FAIL=$((FAIL + 1))
    fi
}

# ── Rule coverage matrix — frontmatter-primary (31 branches: D0 through DEC3 + FALLBACK/EXP0) ──
assert_rule "empty-initiative"              "D0|dispatch|discovery"
assert_rule "discovery-pending"             "D1|escalate|gate-1"
assert_rule "discovery-rejected"            "D1b|update|archive-initiative"
assert_rule "discovery-approved"            "D2|dispatch|design-sprint"
assert_rule "design-pending"                "DS1|escalate|gate-2"
assert_rule "design-iterate"                "DS2|dispatch|design-sprint-iteration"
assert_rule "design-rejected"               "DS2b|update|archive-initiative"
assert_rule "design-approved-new-product"   "DS3|dispatch|build-mvp"
assert_rule "design-approved-iteration"     "DS4|dispatch|build-experiment"
assert_rule "mvp-pending-gate"              "MVP1|escalate|gate-3"
assert_rule "mvp-approved"                  "MVP2|dispatch|build-feature"
assert_rule "mvp-rejected"                  "MVP3|dispatch|decommission-analyst"
assert_rule "exp-pending"                   "EXP0|no-op|"
assert_rule "exp-promote"                   "EXP1|dispatch|build-feature"
assert_rule "exp-kill"                      "EXP2|dispatch|decommission-analyst"
assert_rule "exp-extend-0"                  "EXP3|update|extend-experiment"
assert_rule "exp-extend-1"                  "EXP3|update|extend-experiment"
assert_rule "exp-extend-2"                  "EXP4|escalate|gate-exp-inconclusive"
assert_rule "build-in-progress"             "BF0|no-op|"
assert_rule "build-complete-no-metrics"     "FALLBACK|escalate|human"
assert_rule "build-complete-with-metrics"   "BF1|update|begin-monitor"
assert_rule "monitor-urgent"                "MON1|dispatch|improve-urgent"
assert_rule "monitor-improve"               "MON2|dispatch|improve"
assert_rule "monitor-stable"                "MON3|no-op|"
assert_rule "improve-mini-sprint-pending"   "IMP1|dispatch|mini-design-sprint"
assert_rule "improve-mini-sprint-complete"  "IMP3|update|return-to-monitor"
assert_rule "improve-decommission"          "IMP2|dispatch|decommission-analyst"
assert_rule "improve-stable"                "IMP3|update|return-to-monitor"
assert_rule "decommission-pending"          "DEC1|escalate|gate-decommission"
assert_rule "decommission-approved"         "DEC2|dispatch|decommission-executor"
assert_rule "decommission-rejected"         "DEC3|update|return-to-monitor"

# ── Fallback-coverage subset — 6 legacy bold-markdown fixtures, unmodified ─────
assert_rule "discovery-pending-legacy-bold" "D1|escalate|gate-1"
assert_rule "design-pending-legacy-bold"    "DS1|escalate|gate-2"
assert_rule "mvp-pending-gate-legacy-bold"  "MVP1|escalate|gate-3"
assert_rule "exp-kill-legacy-bold"          "EXP2|dispatch|decommission-analyst"
assert_rule "build-in-progress-legacy-bold" "BF0|no-op|"
assert_rule "decommission-pending-legacy-bold" "DEC1|escalate|gate-decommission"

# ── Inline-comment/trailing-whitespace trim edge case ──────────────────────────
assert_rule "frontmatter-inline-comment"    "D2|dispatch|design-sprint"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1

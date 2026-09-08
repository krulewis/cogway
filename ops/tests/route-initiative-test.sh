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

# A fixture meant to encode CRLF must still contain CR at run time. .gitattributes
# preserves those bytes, but if it is edited, a checkout normalises them, or someone
# runs dos2unix, the fixture silently becomes a duplicate of its LF twin and asserts
# nothing — normalising them leaves the suite fully green even with the CR handling
# removed. This check, not .gitattributes, is what keeps them load-bearing.
assert_crlf() {
    local relpath="$1"
    if grep -q $'\r' "$FIXTURES/$relpath" 2>/dev/null; then
        echo "PASS: $relpath still contains CR"; PASS=$((PASS + 1))
    else
        if [ ! -r "$FIXTURES/$relpath" ]; then
            echo "FAIL: $relpath is missing or unreadable"
        else
            echo "FAIL: $relpath has NO CR — normalised, no longer tests CRLF handling"
        fi
        FAIL=$((FAIL + 1))
    fi
}

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

# ── Rule coverage matrix — frontmatter-primary (31 branches: D0 through DEC3 + FALLBACK/EXP0,
# including BF1b/IMP3b) ──
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
# Extensions written as a `## Extensions` heading rather than the `**Extensions:**`
# bold marker the schema shows. Both forms are accepted — see the counter in
# route-initiative.sh. The -2- case is the decisive one: before the counter
# recognised the heading form it read 0 extensions and returned EXP3, so EXP4's
# gate-exp-inconclusive human gate was unreachable and an experiment could extend
# without bound. The -1- case is the contrast: it must NOT reach the limit, which
# is what proves the header row is still being skipped rather than counted.
assert_rule "exp-extend-2-heading"          "EXP4|escalate|gate-exp-inconclusive"
assert_rule "exp-extend-1-heading"          "EXP3|update|extend-experiment"
# The Extensions counter had the same separator flaw as count_entries: a spaced
# `| --- |` separator counted as an extension, so ONE extension read as two and
# EXP4's inconclusive gate fired a full cycle early — cutting an experiment short
# rather than extending it.
assert_rule "exp-extend-1-spaced-separator" "EXP3|update|extend-experiment"
# The separator test is lexical (`-`/`:`/pipe/space only), but a table has exactly
# ONE delimiter row, positioned immediately after the header. A genuine data row
# whose every cell is a `-` placeholder (e.g. rationale "not captured yet") matches
# the same lexical pattern as a real separator and — if the test stayed purely
# lexical — would be silently dropped as if it were the separator. Row 1 is a real
# extension; row 2 is a hyphen-placeholder extension. Both must count (2 total),
# reaching EXP4's limit. A count of 1 (the placeholder row dropped) would wrongly
# return EXP3 and let the experiment extend past its limit unnoticed.
assert_rule "exp-extend-2-hyphen-row"       "EXP4|escalate|gate-exp-inconclusive"
# Same separator test, defeated by a trailing \r. On a CRLF experiment report ONE
# extension counted as two and EXP4 fired a cycle early; on a CRLF feature record an
# EMPTY metrics table satisfied BF1's populated-metrics guard.
assert_rule "exp-extend-1-crlf"             "EXP3|update|extend-experiment"
assert_rule "build-complete-crlf-empty-metrics" "FALLBACK|escalate|human"
assert_crlf "exp-extend-1-crlf/02-experiment/experiment-report.md"
assert_crlf "build-complete-crlf-empty-metrics/03-feature/feature-record.md"
assert_rule "build-in-progress"             "BF0|no-op|"
# Proves BF1b does not over-catch: it still requires populated baseline/threshold
# tables, so a malformed record and an ungated-but-otherwise-complete record stay
# distinguishable.
assert_rule "build-complete-no-metrics"     "FALLBACK|escalate|human"
assert_rule "build-complete-with-metrics"   "BF1|update|begin-monitor"
# ── Live-Data Validation Gate (Gate LD) — BF1/BF1b family ──────────────────────
# BF1 requires live_data_validation to be a passing claim (validated/not_applicable)
# backed by >=1 evidence row under "## Live Data Validation"; anything else (blank,
# absent, a non-passing value, or a passing scalar with no evidence row) escalates
# to BF1b instead of silently advancing to begin-monitor.
assert_rule "build-complete-gate-not-applicable" "BF1|update|begin-monitor"
assert_rule "build-complete-gate-blank"          "BF1b|escalate|gate-live-data"
assert_rule "build-complete-gate-absent"         "BF1b|escalate|gate-live-data"
assert_rule "build-complete-gate-claim-no-rows"  "BF1b|escalate|gate-live-data"
assert_rule "build-complete-gate-failed"         "BF1b|escalate|gate-live-data"
assert_rule "build-complete-gate-legacy-bold"    "BF1|update|begin-monitor"
# Markdown separator rows must never count as data rows, in either spelling.
# `|---|` was already skipped; the spaced form `| --- |` (what Prettier and most
# formatters emit) was counted as a row, so a feature record with EMPTY metrics
# tables satisfied BF1's populated-metrics guard and advanced straight to monitor.
# The -empty case is the bug; the -populated case is the contrast that proves the
# fix skips the separator rather than skipping the whole table.
assert_rule "build-complete-spaced-separator-empty"     "FALLBACK|escalate|human"
assert_rule "build-complete-spaced-separator-populated" "BF1|update|begin-monitor"
# A separator row is positional (the row immediately after the header), not just
# lexical. A genuine data row using `-` as a "not captured yet" placeholder in
# EVERY cell (e.g. `| - | - | - |`) is lexically indistinguishable from a real
# separator, but it is the SECOND pipe row after the header, not the first, so it
# must be counted as data. Both metrics tables here use this placeholder shape;
# dropping it (treating every separator-shaped row as a separator, not just the
# first) undercounts to zero and wrongly returns FALLBACK instead of BF1.
assert_rule "build-complete-hyphen-placeholder-metrics" "BF1|update|begin-monitor"
assert_rule "monitor-urgent"                "MON1|dispatch|improve-urgent"
assert_rule "monitor-improve"               "MON2|dispatch|improve"
assert_rule "monitor-stable"                "MON3|no-op|"
assert_rule "improve-mini-sprint-pending"   "IMP1|dispatch|mini-design-sprint"
assert_rule "improve-mini-sprint-complete"  "IMP3|update|return-to-monitor"
# Proves IMP2 precedes the gate: decommission-bound improvements are never
# required to record live_data_validation, because flag_decommission is checked
# (and wins) before IMP3/IMP3b.
assert_rule "improve-decommission"          "IMP2|dispatch|decommission-analyst"
assert_rule "improve-stable"                "IMP3|update|return-to-monitor"
# ── Live-Data Validation Gate (Gate LD) — IMP3/IMP3b family ────────────────────
# Mirrors the BF1/BF1b family above, on the improvement-report side.
assert_rule "improve-stable-gate-not-applicable"  "IMP3|update|return-to-monitor"
assert_rule "improve-stable-gate-blank"           "IMP3b|escalate|gate-live-data"
assert_rule "improve-stable-gate-claim-no-rows"   "IMP3b|escalate|gate-live-data"
assert_rule "improve-stable-gate-failed"          "IMP3b|escalate|gate-live-data"
assert_rule "improve-stable-gate-absent"          "IMP3b|escalate|gate-live-data"
assert_rule "decommission-pending"          "DEC1|escalate|gate-decommission"
assert_rule "decommission-approved"         "DEC2|dispatch|decommission-executor"
assert_rule "decommission-rejected"         "DEC3|update|return-to-monitor"

# ── Fallback-coverage subset — 7 legacy bold-markdown fixtures (one,
# build-complete-gate-legacy-bold, is asserted in the BF block above), unmodified ─
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

#!/usr/bin/env bash
# route-initiative.sh <initiative-path> <roadmap-path>
#
# Reads initiative deliverable routing fields and outputs the first matching rule.
# Output format: RULE|ACTION|TARGET
#
# Actions:
#   dispatch   — orchestrator should create team and run phase
#   escalate   — orchestrator should AskUserQuestion at the given gate
#   update     — orchestrator should update roadmap/files only, no agent dispatch
#   no-op      — nothing to do this run

INITIATIVE_PATH="${1:?Usage: route-initiative.sh <initiative-path> <roadmap-path>}"
ROADMAP_PATH="${2:?Usage: route-initiative.sh <initiative-path> <roadmap-path>}"

# ── Deliverable paths ─────────────────────────────────────────────────────────
DISCOVERY_SPEC="$INITIATIVE_PATH/00-discovery-spec.md"
DESIGN_SPRINT="$INITIATIVE_PATH/01-design-sprint.md"
EXPERIMENT_REPORT="$INITIATIVE_PATH/02-experiment/experiment-report.md"
MVP_REPORT="$INITIATIVE_PATH/02-mvp-experiment/mvp-experiment-report.md"
FEATURE_RECORD="$INITIATIVE_PATH/03-feature/feature-record.md"
SIGNAL_REPORTS_DIR="$INITIATIVE_PATH/03-feature/signal-reports"
IMPROVEMENT_REPORTS_DIR="$INITIATIVE_PATH/03-feature/improvement-reports"
DECOMMISSION_REPORT="$INITIATIVE_PATH/04-decommission-report.md"

# ── Helper: extract a simple "key: value" field (returns empty string if absent) ──
# Frontmatter-first: checks the leading --- / --- fence for `key: value`, trimming
# inline `# comment` and trailing whitespace, then falls back to a whole-file
# bold `**key:**`/plain `key:` scan for files not yet migrated to frontmatter.
# Values are lowercased before returning — every caller compares against
# lowercase enum literals ("approved", "in_progress", etc.), so normalizing
# here once keeps all routing comparisons case-insensitive-by-write.
field() {
    local file="$1" key="$2" val=""
    if [ -f "$file" ] && [ "$(head -n1 "$file")" = "---" ]; then
        val=$(awk 'NR==1{next} /^---$/{exit} {print}' "$file" \
            | grep -m1 "^${key}:[[:space:]]*" \
            | sed -E "s/^${key}:[[:space:]]*//; s/[[:space:]]*(#.*)?\$//" \
            | tr -d '\r')
    fi
    if [ -z "$val" ]; then
        val=$(grep -m1 "^\*\*${key}:\*\*\|^${key}:" "$file" 2>/dev/null \
            | sed -E "s/^\*\*${key}:\*\*[[:space:]]*|^${key}:[[:space:]]*//; s/[[:space:]]*(#.*)?\$//" \
            | tr -d '\r')
    fi
    echo "$val" | tr '[:upper:]' '[:lower:]'
}

# ── Helper: count data rows in a markdown table under a ## Section heading ────
# key is snake_case (e.g. "baseline_metrics"). Converts to title case heading.
# Counts pipe-delimited rows that are not the header or separator lines.
#
# A separator row is any pipe-led line whose cells hold nothing but `-`, `:`,
# pipes and whitespace — this matches BOTH `|---|---|` and the spaced `| --- | --- |`
# that Prettier and most markdown formatters emit. Matching only the compact form
# (the old `/^\|[^-]/`) counted a spaced separator as a data row, which meant an
# EMPTY metrics table satisfied BF1's populated-metrics guard and sent the
# initiative straight to monitor with no metrics at all. Fixtures:
# build-complete-spaced-separator-{empty,populated}.
#
# The strip of a trailing \r must come first: a CRLF file's separator ends in \r,
# which is none of `-`, `:`, pipe or space, so without it the separator fails the
# separator test and counts as a data row — the same empty-table bypass, reopened
# for anyone whose editor writes CRLF. field() has always done tr -d '\r'; these
# counters never did. Fixtures: build-complete-crlf-empty-metrics, exp-extend-1-crlf.
#
# The separator/data distinction is POSITIONAL, not lexical: a markdown table has
# exactly one delimiter row, immediately after the header. `| - | - | - |` is a
# valid CommonMark delimiter row AND a plausible data row (e.g. a "not captured
# yet" placeholder), so no amount of character-class cleverness can tell them
# apart by content alone. Only the first pipe row after the header is ever
# eligible to be skipped as the separator (and even then only if it lexically
# looks like one); every pipe row after that is data, even if it also happens to
# look separator-shaped. Fixture: build-complete-hyphen-placeholder-metrics.
count_entries() {
    local file="$1" key="$2"
    local heading
    heading=$(echo "$key" | sed 's/_/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2); print}')
    awk -v heading="$heading" \
        '{sub(/\r$/,"")} \
         $0 ~ "^## " heading {f=1;header=0;sep=0;next} \
         f && /^## /{exit} \
         f && /^\|/{if(!header){header=1;next}; if(!sep && $0 ~ /^\|[-|: \t]*$/){sep=1;next}; c++} \
         END{print c+0}' \
        "$file" 2>/dev/null
}

# ── Extract routing fields ────────────────────────────────────────────────────
discovery_approved=""
design_approved=""
initiative_type=""
mvp_verdict=""
mvp_investment=""
exp_verdict=""
exp_extensions_count=0
build_status=""
baseline_populated=0
thresholds_populated=0
signal_recommendation=""
improvement_recommendation=""
improvement_mini_sprint=""
decommission_approved=""
improvement_mini_sprint_status=""
live_data_validation=""
live_data_rows=0
improvement_live_data=""
improvement_live_data_rows=0

[ -f "$DISCOVERY_SPEC" ] && {
    discovery_approved=$(field "$DISCOVERY_SPEC" "discovery_approved")
}

[ -f "$DESIGN_SPRINT" ] && {
    design_approved=$(field "$DESIGN_SPRINT" "design_approved")
    initiative_type=$(field "$DESIGN_SPRINT" "initiative_type")
}

[ -f "$MVP_REPORT" ] && {
    mvp_verdict=$(field "$MVP_REPORT" "overall_verdict")
    mvp_investment=$(field "$MVP_REPORT" "investment_decision")
}

[ -f "$EXPERIMENT_REPORT" ] && {
    exp_verdict=$(field "$EXPERIMENT_REPORT" "overall_verdict")
    # Count data rows in the Extensions table (skip heading row "| Extended at |" and separator).
    # Two markers are accepted: the bold `**Extensions:**` form the schema shows, and a
    # plain `## Extensions` markdown heading. Reports in the wild are written both ways,
    # and a marker this counter does not recognise reads as zero extensions — which pins
    # the experiment on EXP3 (extend) forever and makes EXP4's gate-exp-inconclusive
    # human gate unreachable. Fixtures exist for both forms; keep it that way.
    # Separator-row test is the same one count_entries uses, and for the same reason:
    # a spaced `| --- |` separator counted as an extension, so ONE extension read as
    # two and EXP4's inconclusive gate fired a cycle early, cutting an experiment
    # short instead of extending it. Fixture: exp-extend-1-spaced-separator.
    # Positional, not lexical, for the same reason as count_entries: only the first
    # pipe row after the header is ever eligible to be skipped as the separator;
    # a later row that happens to look separator-shaped (e.g. a `| - | - | - |`
    # placeholder extension) is data. Fixture: exp-extend-2-hyphen-row.
    exp_extensions_count=$(awk '{sub(/\r$/,"")} \
        /^\*\*Extensions:\*\*/ || /^##[[:space:]]+Extensions[[:space:]]*$/{f=1;header=0;sep=0;next} \
        f && /^\|/{if(!header){header=1;next}; if(!sep && $0 ~ /^\|[-|: \t]*$/){sep=1;next}; c++} \
        f && /^[^|]/{exit} \
        END{print c+0}' "$EXPERIMENT_REPORT" 2>/dev/null || echo 0)
}

[ -f "$FEATURE_RECORD" ] && {
    build_status=$(field "$FEATURE_RECORD" "build_status")
    baseline_populated=$(count_entries "$FEATURE_RECORD" "baseline_metrics")
    thresholds_populated=$(count_entries "$FEATURE_RECORD" "monitoring_thresholds")
    # live_data_validation is read by BOTH field() (the scalar) and count_entries()
    # (the "## Live Data Validation" evidence table). field-map-consistency-test.sh's
    # EXPECTED_TABLE tracks field() keys only — baseline_metrics is absent from it for
    # the same reason. This is intentional, not an omission to fix (see R5 in the
    # architecture decision). count_entries()'s heading match is an unanchored
    # prefix, so a future "## Live Data Validation Evidence" heading would alias onto
    # this one. Harmless today because no such heading exists; noted so it is a known
    # constraint rather than a surprise.
    live_data_validation=$(field "$FEATURE_RECORD" "live_data_validation")
    live_data_rows=$(count_entries "$FEATURE_RECORD" "live_data_validation")
}

# Most recent signal report
if [ -d "$SIGNAL_REPORTS_DIR" ]; then
    latest_signal=$(ls -t "$SIGNAL_REPORTS_DIR"/*.md 2>/dev/null | head -1)
    [ -n "$latest_signal" ] && signal_recommendation=$(field "$latest_signal" "recommendation")
fi

# Most recent improvement report
# Fall back to root-level improvement-reports/ if 03-feature/improvement-reports/ absent
# (pre-schema initiatives stored improvement reports at the initiative root)
_effective_improvement_dir="$IMPROVEMENT_REPORTS_DIR"
[ ! -d "$IMPROVEMENT_REPORTS_DIR" ] && [ -d "$INITIATIVE_PATH/improvement-reports" ] && \
    _effective_improvement_dir="$INITIATIVE_PATH/improvement-reports"
if [ -d "$_effective_improvement_dir" ]; then
    latest_improvement=$(ls -t "$_effective_improvement_dir"/*.md 2>/dev/null | head -1)
    [ -n "$latest_improvement" ] && {
        improvement_recommendation=$(field "$latest_improvement" "recommendation")
        improvement_mini_sprint=$(field "$latest_improvement" "mini_design_sprint_triggered")
        improvement_mini_sprint_status=$(field "$latest_improvement" "mini_sprint_status")
        improvement_live_data=$(field "$latest_improvement" "live_data_validation")
        improvement_live_data_rows=$(count_entries "$latest_improvement" "live_data_validation")
    }
fi

[ -f "$DECOMMISSION_REPORT" ] && {
    decommission_approved=$(field "$DECOMMISSION_REPORT" "decommission_approved")
}

# ── Pre-compute compound conditions ──────────────────────────────────────────

# No signal reports yet (dir absent or no .md files)
_no_signals=0
{ [ ! -d "$SIGNAL_REPORTS_DIR" ] || \
  [ -z "$(ls "$SIGNAL_REPORTS_DIR"/*.md 2>/dev/null)" ]; } && _no_signals=1

# No improvement report in progress (dir absent or no .md files); check both locations
_no_improvement=0
{ [ ! -d "$_effective_improvement_dir" ] || \
  [ -z "$(ls "$_effective_improvement_dir"/*.md 2>/dev/null)" ]; } && _no_improvement=1

# Live-data gate satisfied: scalar is a passing value AND at least one evidence row
# exists under "## Live Data Validation". ${var:-0} defends against count_entries
# returning empty — count_entries's own `awk 'END{print c+0}'` always emits today, so
# this should never actually be empty, but new call sites should not depend on that
# invariant silently (existing baseline_populated/thresholds_populated sites are safe
# only because of that same invariant).
#
# Both clauses are independently load-bearing and both are covered by a dedicated
# fixture that isolates it: build-complete-gate-claim-no-rows (scalar valid, zero rows)
# proves the row-count clause; build-complete-gate-failed (scalar invalid/failed, ONE
# real row) proves the scalar clause.
_ldv_ok=0
{ [ "$live_data_validation" = "validated" ] || [ "$live_data_validation" = "not_applicable" ]; } \
  && [ "${live_data_rows:-0}" -gt 0 ] && _ldv_ok=1

_imp_ldv_ok=0
{ [ "$improvement_live_data" = "validated" ] || [ "$improvement_live_data" = "not_applicable" ]; } \
  && [ "${improvement_live_data_rows:-0}" -gt 0 ] && _imp_ldv_ok=1

# ── Routing rules (first match wins) ─────────────────────────────────────────

# D0: no discovery spec AND no feature record (truly new initiative; fast-track
#     initiatives that start at build_feature skip D0 and flow to BF rules)
[ ! -f "$DISCOVERY_SPEC" ] && [ ! -f "$FEATURE_RECORD" ] \
    && echo "D0|dispatch|discovery" && exit 0

# D1: discovery spec exists, human not yet approved
[ -f "$DISCOVERY_SPEC" ] \
    && { [ -z "$discovery_approved" ] || [ "$discovery_approved" = "null" ]; } \
    && echo "D1|escalate|gate-1" && exit 0

# D1b: discovery rejected → archive initiative
[ "$discovery_approved" = "rejected" ] \
    && echo "D1b|update|archive-initiative" && exit 0

# D2: human approved, no design sprint yet
[ "$discovery_approved" = "approved" ] && [ ! -f "$DESIGN_SPRINT" ] \
    && echo "D2|dispatch|design-sprint" && exit 0

# DS1: design sprint exists, human not yet approved
[ -f "$DESIGN_SPRINT" ] \
    && { [ -z "$design_approved" ] || [ "$design_approved" = "null" ]; } \
    && echo "DS1|escalate|gate-2" && exit 0

# DS2: design approved = iterate
[ "$design_approved" = "iterate" ] \
    && echo "DS2|dispatch|design-sprint-iteration" && exit 0

# DS2b: design rejected → archive initiative
[ "$design_approved" = "rejected" ] \
    && echo "DS2b|update|archive-initiative" && exit 0

# DS3: design approved, new_product, no MVP experiment yet
[ "$design_approved" = "approved" ] \
    && [ "$initiative_type" = "new_product" ] \
    && [ ! -d "$INITIATIVE_PATH/02-mvp-experiment" ] \
    && echo "DS3|dispatch|build-mvp" && exit 0

# DS4: design approved, iteration type, no experiment yet
[ "$design_approved" = "approved" ] \
    && [ "$initiative_type" = "iteration" ] \
    && [ ! -f "$EXPERIMENT_REPORT" ] \
    && echo "DS4|dispatch|build-experiment" && exit 0

# MVP1: MVP report has verdict, awaiting human investment decision
[ -f "$MVP_REPORT" ] \
    && [ -n "$mvp_verdict" ] && [ "$mvp_verdict" != "null" ] \
    && { [ -z "$mvp_investment" ] || [ "$mvp_investment" = "null" ]; } \
    && echo "MVP1|escalate|gate-3" && exit 0

# MVP2: investment approved, no feature record yet
[ "$mvp_investment" = "approved" ] && [ ! -f "$FEATURE_RECORD" ] \
    && echo "MVP2|dispatch|build-feature" && exit 0

# MVP3: investment rejected, no decommission report yet
[ "$mvp_investment" = "rejected" ] && [ ! -f "$DECOMMISSION_REPORT" ] \
    && echo "MVP3|dispatch|decommission-analyst" && exit 0

# EXP0: experiment report exists, verdict pending → no-op (experiment in progress)
[ -f "$EXPERIMENT_REPORT" ] && [ -z "$exp_verdict" ] \
    && echo "EXP0|no-op|" && exit 0

# EXP1: experiment promoted, no feature record yet
[ "$exp_verdict" = "promote" ] && [ ! -f "$FEATURE_RECORD" ] \
    && echo "EXP1|dispatch|build-feature" && exit 0

# EXP2: experiment killed, no decommission report yet
[ "$exp_verdict" = "kill" ] && [ ! -f "$DECOMMISSION_REPORT" ] \
    && echo "EXP2|dispatch|decommission-analyst" && exit 0

# EXP3: extend, extensions remaining (< 2)
[ "$exp_verdict" = "extend" ] && [ "$exp_extensions_count" -lt 2 ] \
    && echo "EXP3|update|extend-experiment" && exit 0

# EXP4: extend, hit extension limit (>= 2)
[ "$exp_verdict" = "extend" ] && [ "$exp_extensions_count" -ge 2 ] \
    && echo "EXP4|escalate|gate-exp-inconclusive" && exit 0

# BF0: feature record exists, build in progress → no-op
[ -f "$FEATURE_RECORD" ] && [ "$build_status" = "in_progress" ] \
    && echo "BF0|no-op|" && exit 0

# BF1: build complete, metrics populated, live-data gate recorded with evidence,
#      no signal reports yet, no improvement reports yet
# (_no_improvement guards against re-triggering begin-monitor on already-improved initiatives)
[ "$build_status" = "complete" ] \
    && [ "$baseline_populated" -gt 0 ] \
    && [ "$thresholds_populated" -gt 0 ] \
    && [ "$_ldv_ok" -eq 1 ] \
    && [ "$_no_signals" -eq 1 ] \
    && [ "$_no_improvement" -eq 1 ] \
    && echo "BF1|update|begin-monitor" && exit 0

# BF1b: everything BF1 requires EXCEPT the live-data gate record. Reached when
#       live_data_validation is blank, absent, `failed`, an unrecognised value, or set
#       to a passing value with zero evidence rows under "## Live Data Validation".
#       Named rather than left to FALLBACK so the escalation can say what is missing.
[ "$build_status" = "complete" ] \
    && [ "$baseline_populated" -gt 0 ] \
    && [ "$thresholds_populated" -gt 0 ] \
    && [ "$_no_signals" -eq 1 ] \
    && [ "$_no_improvement" -eq 1 ] \
    && echo "BF1b|escalate|gate-live-data" && exit 0

# MON1: urgent improve signal, no improvement in progress
[ "$signal_recommendation" = "trigger_improve_urgent" ] && [ "$_no_improvement" -eq 1 ] \
    && echo "MON1|dispatch|improve-urgent" && exit 0

# MON2: improve signal, no improvement in progress
[ "$signal_recommendation" = "trigger_improve" ] && [ "$_no_improvement" -eq 1 ] \
    && echo "MON2|dispatch|improve" && exit 0

# MON3: stable
[ "$signal_recommendation" = "stable" ] \
    && echo "MON3|no-op|" && exit 0

# IMP1: mini sprint triggered but not yet done
[ "$improvement_mini_sprint" = "true" ] \
    && { [ -z "$improvement_mini_sprint_status" ] || [ "$improvement_mini_sprint_status" = "pending" ]; } \
    && echo "IMP1|dispatch|mini-design-sprint" && exit 0

# IMP2: improvement recommends decommission
[ "$improvement_recommendation" = "flag_decommission" ] && [ ! -f "$DECOMMISSION_REPORT" ] \
    && echo "IMP2|dispatch|decommission-analyst" && exit 0

# IMP3: stable or continue_improve, live-data gate recorded with evidence
{ [ "$improvement_recommendation" = "stable" ] \
  || [ "$improvement_recommendation" = "continue_improve" ]; } \
    && [ "$_imp_ldv_ok" -eq 1 ] \
    && echo "IMP3|update|return-to-monitor" && exit 0

# IMP3b: recommendation set to stable/continue_improve, live-data gate not recorded
{ [ "$improvement_recommendation" = "stable" ] \
  || [ "$improvement_recommendation" = "continue_improve" ]; } \
    && echo "IMP3b|escalate|gate-live-data" && exit 0

# DEC1: decommission report exists, awaiting human approval
[ -f "$DECOMMISSION_REPORT" ] \
    && { [ -z "$decommission_approved" ] || [ "$decommission_approved" = "null" ]; } \
    && echo "DEC1|escalate|gate-decommission" && exit 0

# DEC2: decommission approved
[ "$decommission_approved" = "true" ] \
    && echo "DEC2|dispatch|decommission-executor" && exit 0

# DEC3: decommission rejected → return to monitor
[ "$decommission_approved" = "false" ] \
    && echo "DEC3|update|return-to-monitor" && exit 0

# FALLBACK: no rule matched
echo "FALLBACK|escalate|human"
exit 0

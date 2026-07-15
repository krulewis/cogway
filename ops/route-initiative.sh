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
    echo "$val"
}

# ── Helper: count data rows in a markdown table under a ## Section heading ────
# key is snake_case (e.g. "baseline_metrics"). Converts to title case heading.
# Counts pipe-delimited rows that are not the header or separator lines.
count_entries() {
    local file="$1" key="$2"
    local heading
    heading=$(echo "$key" | sed 's/_/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2); print}')
    awk "/^## ${heading}/{f=1;header=0;next} \
         f && /^## /{exit} \
         f && /^\|[^-]/{if(header){c++}else{header=1}} \
         END{print c+0}" \
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
    exp_verdict=$(field "$EXPERIMENT_REPORT" "overall_verdict" | tr '[:upper:]' '[:lower:]')
    # Count data rows in the Extensions table (skip heading row "| Extended at |" and separator)
    exp_extensions_count=$(awk '/^\*\*Extensions:\*\*/{f=1;header=0;next} \
        f && /^\|[^-]/{if(header){c++}else{header=1}} \
        f && /^[^|]/{exit} \
        END{print c+0}' "$EXPERIMENT_REPORT" 2>/dev/null || echo 0)
}

[ -f "$FEATURE_RECORD" ] && {
    build_status=$(field "$FEATURE_RECORD" "build_status")
    baseline_populated=$(count_entries "$FEATURE_RECORD" "baseline_metrics")
    thresholds_populated=$(count_entries "$FEATURE_RECORD" "monitoring_thresholds")
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

# BF1: build complete, metrics populated, no signal reports yet, no improvement reports yet
# (_no_improvement guards against re-triggering begin-monitor on already-improved initiatives)
[ "$build_status" = "complete" ] \
    && [ "$baseline_populated" -gt 0 ] \
    && [ "$thresholds_populated" -gt 0 ] \
    && [ "$_no_signals" -eq 1 ] \
    && [ "$_no_improvement" -eq 1 ] \
    && echo "BF1|update|begin-monitor" && exit 0

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

# IMP3: stable or continue → return to monitor
{ [ "$improvement_recommendation" = "stable" ] \
  || [ "$improvement_recommendation" = "continue_improve" ]; } \
    && echo "IMP3|update|return-to-monitor" && exit 0

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

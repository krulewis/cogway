#!/usr/bin/env bash
# check-deliverable-fields.sh <deliverable-file>
#
# WRITE-SIDE lint for lifecycle deliverables. Asserts that the routing field(s)
# route-initiative.sh will read are present, uniquely parseable, and (if filled)
# hold a valid value — so a missing field, a typo'd value, or a stray duplicate
# is caught when the deliverable is WRITTEN, not silently mis-routed later.
#
# Mirrors route-initiative.sh's field() parsing exactly (bold `**key:**` or plain
# `key:`), first-match-wins. A duplicate key line is an error because field()
# takes -m1 and a second line can shadow the intended value.
#
# Exit 0 = clean (or file is not a gated deliverable). Exit 1 = problems found.

set -uo pipefail

FILE="${1:?Usage: check-deliverable-fields.sh <deliverable-file>}"
[ -f "$FILE" ] || { echo "check-deliverable-fields: file not found: $FILE" >&2; exit 1; }

base=$(basename "$FILE")

# field() — identical parsing to route-initiative.sh: frontmatter-first (trims
# inline `# comment` and trailing whitespace), falls back to whole-file bold/plain scan.
# Lowercases the value before returning, matching route-initiative.sh, so the
# write-side lint validates against the same case-insensitive-by-write values
# the router will actually compare against.
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
count_lines() { grep -cE "^\*\*${2}:\*\*|^${2}:" "$1" 2>/dev/null; }

# count_entries() — mirrors route-initiative.sh's count_entries() exactly (verified
# character-for-character against ops/route-initiative.sh as of commit 1456dc1, which
# fixed a spaced-separator-row miscount bug there — see
# docs/bugs/build-status-complete-written-before-live-data-gate.md for unrelated context
# on that same file's known hazards, and the test suite's
# feature-record-spaced-separator fixture for the mutation this exact regex closes).
# Counts data rows under a "## <Title Case>" heading derived from a snake_case key,
# skipping the markdown separator row regardless of spacing (`|---|` or `| --- |`).
# Needed here so the lint can assert live_data_validation's evidence table is non-empty
# at WRITE time, matching what the router requires at ROUTE time (see R6 in the
# architecture decision — this copy and the router's are two places this logic can
# drift; the mirror-comment convention plus field-map-consistency-test.sh's assertion
# that this script calls count_entries with "live_data_validation" are the guard, and
# the feature-record-spaced-separator fixture is the guard against a *stale* copy).
count_entries() {
  local file="$1" key="$2"
  local heading
  heading=$(echo "$key" | sed 's/_/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2); print}')
  awk -v heading="$heading" \
      '{sub(/\r$/,"")} \
       $0 ~ "^## " heading {f=1;header=0;next} \
       f && /^## /{exit} \
       f && /^\|/ && $0 !~ /^\|[-|: \t]*$/{if(header){c++}else{header=1}} \
       END{print c+0}' \
      "$file" 2>/dev/null
}

# Required routing fields per deliverable type: "key=val1,val2,..."  (val list = allowed values; empty value is allowed pre-gate)
specs=()
parent="$(basename "$(dirname "$FILE")")"
if [ "$parent" = "improvement-reports" ]; then
  specs=("recommendation=flag_decommission,stable,continue_improve" "live_data_validation=validated,not_applicable,failed")
  if [ "$(count_lines "$FILE" "recommendation")" -eq 0 ]; then
    echo "check-deliverable-fields: $base is not a gated deliverable — nothing to check."
    exit 0
  fi
  [ "$(count_lines "$FILE" "mini_design_sprint_triggered")" -gt 0 ] && specs+=("mini_design_sprint_triggered=true,false")
  [ "$(count_lines "$FILE" "mini_sprint_status")" -gt 0 ] && specs+=("mini_sprint_status=pending,complete")
else
  case "$base" in
    00-discovery-spec.md)          specs=("discovery_approved=approved,rejected") ;;
    01-design-sprint.md)           specs=("design_approved=approved,rejected,iterate" "initiative_type=new_product,iteration") ;;
    mvp-experiment-report.md)      specs=("overall_verdict=" "investment_decision=approved,rejected") ;;
    experiment-report.md)          specs=("overall_verdict=promote,kill,extend") ;;
    feature-record.md)             specs=("build_status=in_progress,complete" "live_data_validation=validated,not_applicable,failed") ;;
    04-decommission-report.md)     specs=("decommission_approved=true,false") ;;
    *-signal.md)                   specs=("recommendation=trigger_improve_urgent,trigger_improve,stable") ;;
    *) echo "check-deliverable-fields: $base is not a gated deliverable — nothing to check."; exit 0 ;;
  esac
fi

fail=0
echo "Linting $base:"
for spec in "${specs[@]}"; do
  key="${spec%%=*}"; allowed="${spec#*=}"
  n=$(count_lines "$FILE" "$key")
  if [ "${n:-0}" -eq 0 ]; then
    echo "  FAIL  $key — field line absent; the router will not advance this initiative past this gate until it is added. Add (frontmatter, preferred): a '${key}: <value>' line inside the leading --- block. (Bold '**${key}:**' also still works via fallback.)"
    fail=1; continue
  fi
  if [ "$n" -gt 1 ]; then
    echo "  FAIL  $key — $n occurrences; field() takes the first match, so a duplicate can shadow the real value. Keep exactly one."
    fail=1
  fi
  val=$(field "$FILE" "$key")
  if [ -z "$val" ]; then
    echo "  OK    $key — present, blank (awaiting gate decision)"
    continue
  fi
  if [ -z "$allowed" ]; then
    echo "  OK    $key = $val (free-form; router checks presence only)"
    continue
  fi
  case ",$allowed," in
    *",$val,"*) echo "  OK    $key = $val" ;;
    *) echo "  FAIL  $key = '$val' is not a valid value; expected one of: ${allowed//,/, }"; fail=1 ;;
  esac
done

# Evidence-table check — live_data_validation only, NOT generalised into the specs loop
# above, because no other routing field is backed by a body table. If the scalar is set
# to a passing value with zero rows, the router will hit BF1b/IMP3b even though this
# lint would otherwise report PASS — this check exists to catch that drift at write time.
_ldv_val=$(field "$FILE" "live_data_validation")
# Only a PASSING claim needs evidence. `failed` escalates at BF1b/IMP3b whatever the
# table holds, so demanding rows for it would block a valid record for no routing
# benefit — and would contradict the message below.
if [ "$_ldv_val" = "validated" ] || [ "$_ldv_val" = "not_applicable" ]; then
  _ldv_rows=$(count_entries "$FILE" "live_data_validation")
  if [ "${_ldv_rows:-0}" -eq 0 ]; then
    echo "  FAIL  live_data_validation = '$_ldv_val' — no rows found under '## Live Data Validation'. Both 'validated' and 'not_applicable' require at least one row (for not_applicable, write a single '| (none) | — | — | — | <what you scanned, naming the PR> |' row)."
    fail=1
  else
    echo "  OK    live_data_validation = $_ldv_val"
  fi
fi

if [ "$fail" -eq 0 ]; then echo "PASS"; exit 0; else echo "FAIL — fix the deliverable before relying on routing."; exit 1; fi

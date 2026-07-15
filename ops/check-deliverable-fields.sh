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

# Required routing fields per deliverable type: "key=val1,val2,..."  (val list = allowed values; empty value is allowed pre-gate)
specs=()
parent="$(basename "$(dirname "$FILE")")"
if [ "$parent" = "improvement-reports" ]; then
  specs=("recommendation=flag_decommission,stable,continue_improve")
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
    feature-record.md)             specs=("build_status=in_progress,complete") ;;
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
    echo "  FAIL  $key — field line absent; route-initiative.sh will hit FALLBACK. Add (frontmatter, preferred): a '${key}: <value>' line inside the leading --- block. (Bold '**${key}:**' also still works via fallback.)"
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

if [ "$fail" -eq 0 ]; then echo "PASS"; exit 0; else echo "FAIL — fix the deliverable before relying on routing."; exit 1; fi

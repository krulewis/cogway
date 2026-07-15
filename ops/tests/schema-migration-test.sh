#!/usr/bin/env bash
# schema-migration-test.sh
#
# Asserts that each of the 8 ops/schemas/*.md files actually carries its
# expected gate field(s) INSIDE the leading frontmatter fence — not just
# present somewhere in the file. Without this, a silent basename-table miss
# in migrate-field-to-frontmatter.sh would go undetected on any future edit.
#
# Written against the schema files as ported into this repo — fails red until
# ops/schemas/*.md is populated with frontmatter-native gate fields.
#
# Usage: bash ops/tests/schema-migration-test.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMAS_DIR="$SCRIPT_DIR/../schemas"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

# Asserts that <key> appears as a `key:` line strictly between the first pair of
# `---` fences in <file> (i.e. inside the frontmatter, not just anywhere).
assert_key_in_fence() {
    local file="$1" key="$2"
    local label="$3"
    if [ ! -f "$file" ]; then
        fail "$label — file not found: $file"
        return
    fi
    if awk '/^---$/{n++; next} n==1' "$file" | grep -q "^${key}:"; then
        pass "$label — '${key}:' found inside frontmatter fence"
    else
        fail "$label — '${key}:' NOT found inside frontmatter fence (still un-migrated or table row missing)"
    fi
}

# ── Expected table: "schema-file|comma,separated,keys" ──────────────────────────
EXPECTED_TABLE='00-discovery-spec-schema.md|discovery_approved
01-design-sprint-schema.md|design_approved,initiative_type
02-mvp-experiment-report-schema.md|overall_verdict,investment_decision
02-experiment-report-schema.md|overall_verdict
03-feature-record-schema.md|build_status
decommission-report-schema.md|decommission_approved
signal-report-schema.md|recommendation
improvement-report-schema.md|recommendation,mini_design_sprint_triggered,mini_sprint_status'

while IFS='|' read -r schema_file keys; do
    [ -z "$schema_file" ] && continue
    IFS=',' read -ra key_arr <<< "$keys"
    for key in "${key_arr[@]}"; do
        assert_key_in_fence "$SCHEMAS_DIR/$schema_file" "$key" "$schema_file → $key"
    done
done <<< "$EXPECTED_TABLE"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1

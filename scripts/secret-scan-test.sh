#!/usr/bin/env bash
#
# secret-scan-test.sh — self-test for scripts/secret-scan.sh.
#
# Builds throwaway fixtures under a temp directory (not committed test data,
# since this repo's real fixtures live under ops/tests/ and are owned by the
# ops test suites) and asserts secret-scan.sh's behavior against them.
#
# Fake secret values below are assembled from split parts at runtime, on
# purpose — a contiguous copy would itself trip secret-scan.sh when it scans
# this file as part of the repo.
#
# Usage: scripts/secret-scan-test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRET_SCAN="$SCRIPT_DIR/secret-scan.sh"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

pass=0
fail=0

check() {
    local desc="$1" expected_exit="$2" actual_exit="$3"
    if [ "$actual_exit" = "$expected_exit" ]; then
        echo "PASS: $desc"
        pass=$((pass + 1))
    else
        echo "FAIL: $desc (expected exit $expected_exit, got $actual_exit)"
        fail=$((fail + 1))
    fi
}

# Fake AWS example key (AWS's own published example, not a real credential),
# and a fake generic secret value — both split across variables so neither
# appears contiguous in this script's own source.
aws_part1="AKIA"
aws_part2="IOSFODNN7EXAMPLE"
generic_part1="sk-live"
generic_part2="Abcdef0123456789"
pem_part1="-----BEGIN RSA PRIVATE"
pem_part2=" KEY-----"

# --- Case 1: positive — real-looking secrets should be caught ---
POS_DIR="$TMP_ROOT/positive"
mkdir -p "$POS_DIR"
{
    printf 'aws_key = %s%s\n' "$aws_part1" "$aws_part2"
    printf 'api_key = "%s%s"\n' "$generic_part1" "$generic_part2"
} > "$POS_DIR/config.env"
out_pos="$("$SECRET_SCAN" "$POS_DIR" 2>&1)"
exit_pos=$?
check "positive case: exits non-zero" "1" "$exit_pos"
if printf '%s\n' "$out_pos" | grep -q "AWS access key ID pattern"; then
    echo "PASS: positive case: AWS key match reported"
    pass=$((pass + 1))
else
    echo "FAIL: positive case: AWS key match NOT reported"
    fail=$((fail + 1))
fi
if printf '%s\n' "$out_pos" | grep -q "generic secret-shaped assignment"; then
    echo "PASS: positive case: generic secret match reported"
    pass=$((pass + 1))
else
    echo "FAIL: positive case: generic secret match NOT reported"
    fail=$((fail + 1))
fi

# --- Case 1b: private key PEM header should also be caught ---
PEM_DIR="$TMP_ROOT/pem"
mkdir -p "$PEM_DIR"
printf '%s%s\nMIIBOgIBAAJBAK...\n-----END RSA PRIVATE KEY-----\n' "$pem_part1" "$pem_part2" > "$PEM_DIR/id_rsa"
out_pem="$("$SECRET_SCAN" "$PEM_DIR" 2>&1)"
exit_pem=$?
check "PEM header case: exits non-zero" "1" "$exit_pem"
if printf '%s\n' "$out_pem" | grep -q "private key PEM header"; then
    echo "PASS: PEM header case: match reported"
    pass=$((pass + 1))
else
    echo "FAIL: PEM header case: match NOT reported"
    fail=$((fail + 1))
fi

# --- Case 2: negative — clean file, zero exit, no output ---
NEG_DIR="$TMP_ROOT/negative"
mkdir -p "$NEG_DIR"
cat > "$NEG_DIR/README.md" <<'EOF'
# Example Project

This project has no credentials checked in. Configuration is loaded from
environment variables at runtime.
EOF
out_neg="$("$SECRET_SCAN" "$NEG_DIR" 2>&1)"
exit_neg=$?
check "negative case: exits zero" "0" "$exit_neg"
if [ -z "$out_neg" ]; then
    echo "PASS: negative case: no output"
    pass=$((pass + 1))
else
    echo "FAIL: negative case: unexpected output: $out_neg"
    fail=$((fail + 1))
fi

# --- Case 3: exclusion — fixtures-lint prose mentioning "secret", no credential shape ---
EXCL_DIR="$TMP_ROOT/ops/tests/fixtures-lint"
mkdir -p "$EXCL_DIR"
cat > "$EXCL_DIR/prose.md" <<'EOF'
This fixture tests the secret handling of the lint script and its token
validation logic in prose only — no actual credential value here.
EOF
out_excl="$("$SECRET_SCAN" "$TMP_ROOT/ops" 2>&1)"
exit_excl=$?
check "exclusion case: prose mentioning secret/token is excluded, exits zero" "0" "$exit_excl"

# --- Case 4 (bonus): exclusion holds even with a real-shaped secret inside an excluded dir ---
printf 'api_key = "%s%s"\n' "$generic_part1" "$generic_part2" > "$EXCL_DIR/leaky.md"
out_excl2="$("$SECRET_SCAN" "$TMP_ROOT/ops" 2>&1)"
exit_excl2=$?
check "exclusion case: credential-shaped value inside fixtures-lint/ is still excluded" "0" "$exit_excl2"

echo ""
echo "── Summary ──"
echo "PASS: $pass"
echo "FAIL: $fail"

if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0

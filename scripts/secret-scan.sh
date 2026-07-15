#!/usr/bin/env bash
#
# secret-scan.sh — lightweight, pattern-based secret scanner.
#
# Shared by the CI "secret-scan" job and the local pre-push gate so the two
# can never drift out of sync — this file is the single source of truth for
# what counts as a leaked secret in this repo.
#
# Usage:
#   scripts/secret-scan.sh [path]
#     path defaults to "." (the current working tree).
#
# Detects:
#   - AWS access key IDs (AKIA...)
#   - generic secret-shaped assignments (api_key/secret/token/password = "...")
#     excluding obvious placeholder values (YOUR_KEY_HERE, <...>, xxx..., etc.)
#   - private key PEM headers
#
# Excludes test/demo fixture content (any directory named "fixtures" or
# "fixtures-lint", and "walkthrough-initiative") and .git/, since these
# intentionally contain the word "secret" in prose or synthetic test data,
# not real credentials.
#
# Exit status: 0 if clean (no output). Non-zero if anything is found — every
# match is printed as "file:line: reason".

set -uo pipefail

SCAN_PATH="${1:-.}"

if [ ! -e "$SCAN_PATH" ]; then
    echo "secret-scan: path not found: $SCAN_PATH" >&2
    exit 2
fi

AWS_KEY_RE='AKIA[0-9A-Z]{16}'
PEM_HEADER_RE='-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----'
ASSIGN_RE="(api[_-]?key|secret|token|password)[[:space:]]*[:=][[:space:]]*['\"][^'\"]{12,}['\"]"
PLACEHOLDER_RE='^(your_|<.*>$|change_?me|placeholder|example|dummy|redacted|fixme|xxx+|x{8,})'

found=0

while IFS= read -r file; do
    [ -f "$file" ] || continue

    # --- AWS access key ID ---
    while IFS= read -r n; do
        [ -z "$n" ] && continue
        echo "${file}:${n}: AWS access key ID pattern detected (value redacted)"
        found=1
    done < <(grep -nE -e "$AWS_KEY_RE" "$file" 2>/dev/null | cut -d: -f1)

    # --- Private key PEM header ---
    while IFS= read -r n; do
        [ -z "$n" ] && continue
        echo "${file}:${n}: private key PEM header detected"
        found=1
    done < <(grep -nE -e "$PEM_HEADER_RE" "$file" 2>/dev/null | cut -d: -f1)

    # --- Generic secret-shaped assignment (with placeholder exclusion) ---
    while IFS= read -r n; do
        [ -z "$n" ] && continue
        content="$(sed -n "${n}p" "$file")"
        val="$(printf '%s\n' "$content" | sed -E "s/.*[:=][[:space:]]*['\"]([^'\"]{12,})['\"].*/\1/")"
        [ "$val" = "$content" ] && continue  # sed found no quoted value on this line
        lower_val="$(printf '%s' "$val" | tr '[:upper:]' '[:lower:]')"
        if printf '%s' "$lower_val" | grep -qE "$PLACEHOLDER_RE"; then
            continue
        fi
        echo "${file}:${n}: generic secret-shaped assignment detected (value redacted, length=${#val})"
        found=1
    done < <(grep -inE -e "$ASSIGN_RE" "$file" 2>/dev/null | cut -d: -f1)

done < <(find "$SCAN_PATH" \( -name .git -o -name fixtures -o -name fixtures-lint -o -name walkthrough-initiative \) -prune -o -type f -print)

if [ "$found" -eq 1 ]; then
    exit 1
fi
exit 0

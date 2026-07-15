#!/usr/bin/env bash
# generate-test.sh
#
# Generator correctness test for agents/generate.sh, run against a hand-crafted
# minimal agents/_canonical/ fixture set (pm.md, monitor-technical.md — the
# latter exercises the host-provided-capability placeholder path). Full 35-agent
# roster is exercised once the real generator + full canonical set land; this
# suite proves the generator's per-format emission contract on a small,
# deliberately minimal input.
#
# Usage: bash ops/tests/generate-test.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GENERATOR="$REPO_ROOT/agents/generate.sh"
CANONICAL_DIR="$REPO_ROOT/agents/_canonical"
CC_DIR="$REPO_ROOT/.claude/agents"
CODEX_DIR="$REPO_ROOT/.codex/agents"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

# ── Run the generator ────────────────────────────────────────────────────────
if [ ! -f "$GENERATOR" ]; then
    fail "agents/generate.sh does not exist at $GENERATOR"
else
    if (cd "$REPO_ROOT" && bash "$GENERATOR"); then
        pass "agents/generate.sh ran successfully"
    else
        fail "agents/generate.sh exited non-zero"
    fi
fi

# ── Emitted-file-count sanity (avoids a vacuous pass if nothing was emitted) ──
canonical_count=$(find "$CANONICAL_DIR" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
cc_count=$(find "$CC_DIR" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
codex_count=$(find "$CODEX_DIR" -maxdepth 1 -name '*.toml' 2>/dev/null | wc -l | tr -d ' ')

if [ "$cc_count" -eq "$canonical_count" ] && [ "$canonical_count" -gt 0 ]; then
    pass "emitted $cc_count .claude/agents/*.md files, matching $canonical_count canonical source(s)"
else
    fail "expected $canonical_count emitted .claude/agents/*.md files (one per canonical source), found $cc_count"
fi

if [ "$codex_count" -eq "$canonical_count" ] && [ "$canonical_count" -gt 0 ]; then
    pass "emitted $codex_count .codex/agents/*.toml files, matching $canonical_count canonical source(s)"
else
    fail "expected $canonical_count emitted .codex/agents/*.toml files (one per canonical source), found $codex_count"
fi

# ── Claude Code emission checks ──────────────────────────────────────────────
if [ -d "$CC_DIR" ]; then
    for f in "$CC_DIR"/*.md; do
        [ -e "$f" ] || continue
        base="$(basename "$f")"
        first_line=$(head -n1 "$f")
        name_line=$(awk '/^---$/{n++; next} n==1 && /^name:[[:space:]]*[^[:space:]]/{print; exit}' "$f")
        description_line=$(awk '/^---$/{n++; next} n==1 && /^description:[[:space:]]*[^[:space:]]/{print; exit}' "$f")
        tools_line=$(awk '/^---$/{n++; next} n==1 && /^tools:[[:space:]]*[^[:space:]]/{print; exit}' "$f")
        model_line=$(awk '/^---$/{n++; next} n==1 && /^model:[[:space:]]*[^[:space:]]/{print; exit}' "$f")
        body=$(awk '/^---$/{n++; next} n>=2{print}' "$f")
        body_trimmed=$(echo "$body" | tr -d '[:space:]')

        if [ "$first_line" = "---" ]; then
            pass "$base — opens with ---"
        else
            fail "$base — does not open with --- (first line: '$first_line')"
        fi
        [ -n "$name_line" ] && pass "$base — non-empty name" || fail "$base — missing/empty name frontmatter line"
        [ -n "$description_line" ] && pass "$base — non-empty description" || fail "$base — missing/empty description frontmatter line"
        [ -n "$tools_line" ] && pass "$base — non-empty tools" || fail "$base — missing/empty tools frontmatter line"
        [ -n "$model_line" ] && pass "$base — non-empty model" || fail "$base — missing/empty model frontmatter line"
        [ -n "$body_trimmed" ] && pass "$base — non-empty body" || fail "$base — empty body"
    done
else
    fail "$CC_DIR does not exist — generator did not emit Claude Code output"
fi

# ── Codex emission checks ────────────────────────────────────────────────────
if [ -d "$CODEX_DIR" ]; then
    for f in "$CODEX_DIR"/*.toml; do
        [ -e "$f" ] || continue
        base="$(basename "$f")"
        triple_quote_count=$(grep -o '"""' "$f" | wc -l | tr -d ' ')

        if [ $((triple_quote_count % 2)) -eq 0 ] && [ "$triple_quote_count" -gt 0 ]; then
            pass "$base — balanced \"\"\" pairs ($triple_quote_count found)"
        else
            fail "$base — unbalanced or missing \"\"\" pairs (found $triple_quote_count)"
        fi

        grep -qE '^name[[:space:]]*=' "$f" && pass "$base — has name = key" || fail "$base — missing name = key"
        grep -qE '^description[[:space:]]*=' "$f" && pass "$base — has description = key" || fail "$base — missing description = key"
        grep -qE '^model[[:space:]]*=' "$f" && pass "$base — has model = key" || fail "$base — missing model = key"
        grep -qE '^role[[:space:]]*=' "$f" && pass "$base — has role = key" || fail "$base — missing role = key"

        # No unescaped raw """ inside the role body other than the delimiter pair:
        # strip the role = """...""" block's own delimiters, then check for any
        # remaining """ sequence in the file outside that block.
        role_body=$(awk '/^role[[:space:]]*=[[:space:]]*"""/{f=1; next} f && /"""/{exit} f{print}' "$f")
        if printf '%s' "$role_body" | grep -qF '"""'; then
            fail "$base — unescaped raw \"\"\" found inside role body"
        else
            pass "$base — no unescaped raw \"\"\" inside role body"
        fi
    done
else
    fail "$CODEX_DIR does not exist — generator did not emit Codex output"
fi

# ── Round-trip check: model_tier → concrete model name, per canonical source ──
if [ -d "$CANONICAL_DIR" ]; then
    for src in "$CANONICAL_DIR"/*.md; do
        [ -e "$src" ] || continue
        agent_name="$(basename "$src" .md)"
        tier=$(awk '/^---$/{n++; next} n==1{print}' "$src" | grep -m1 '^model_tier:' | sed -E 's/^model_tier:[[:space:]]*//')
        case "$tier" in
            critical) expected_model="opus" ;;
            standard) expected_model="sonnet" ;;
            mechanical) expected_model="haiku" ;;
            *) expected_model="" ;;
        esac

        if [ -z "$expected_model" ]; then
            fail "$agent_name — unrecognized model_tier '$tier' in canonical source"
            continue
        fi

        cc_model=""
        [ -f "$CC_DIR/$agent_name.md" ] && cc_model=$(awk '/^---$/{n++; next} n==1{print}' "$CC_DIR/$agent_name.md" | grep -m1 '^model:' | sed -E 's/^model:[[:space:]]*//')
        if [ "$cc_model" = "$expected_model" ]; then
            pass "$agent_name — Claude Code model '$cc_model' matches model_tier '$tier'"
        else
            fail "$agent_name — Claude Code model mismatch: model_tier '$tier' expects '$expected_model', emitted '$cc_model'"
        fi

        codex_model=""
        [ -f "$CODEX_DIR/$agent_name.toml" ] && codex_model=$(grep -m1 -E '^model[[:space:]]*=' "$CODEX_DIR/$agent_name.toml" | sed -E 's/^model[[:space:]]*=[[:space:]]*"?([^"]*)"?.*/\1/')
        if [ "$codex_model" = "$expected_model" ]; then
            pass "$agent_name — Codex model '$codex_model' matches model_tier '$tier'"
        else
            fail "$agent_name — Codex model mismatch: model_tier '$tier' expects '$expected_model', emitted '$codex_model'"
        fi
    done
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1

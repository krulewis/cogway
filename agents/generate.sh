#!/usr/bin/env bash
# generate.sh
#
# Pure bash, repo-relative agent roster generator (no Node/Python dependency).
# Reads every agents/_canonical/*.md and emits two per-platform formats:
#   .claude/agents/*.md   — Claude Code (near-identity transform)
#   .codex/agents/*.toml  — Codex CLI (TOML; model mapping and tools-grant key
#                            name are VERIFY-AT-BUILD-TIME, see README/plan)
#
# Usage: agents/generate.sh (run from anywhere; paths are repo-relative)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CANONICAL_DIR="$SCRIPT_DIR/_canonical"
CC_DIR="$REPO_ROOT/.claude/agents"
CODEX_DIR="$REPO_ROOT/.codex/agents"

mkdir -p "$CC_DIR" "$CODEX_DIR"

# model_tier -> concrete model name. Used for BOTH Claude Code and Codex
# emission today; the Codex half of this mapping is VERIFY-AT-BUILD-TIME
# (architecture Open Question #4 — unconfirmed pending Codex CLI access).
model_for_tier() {
    case "$1" in
        critical) echo "opus" ;;
        standard) echo "sonnet" ;;
        mechanical) echo "haiku" ;;
        *) echo "" ;;
    esac
}

# Concrete Claude Code grant strings for the normalized `codebase-memory`
# capability.
codebase_memory_tools() {
    echo "mcp__codebase-memory-mcp__list_projects, mcp__codebase-memory-mcp__search_graph, mcp__codebase-memory-mcp__get_code_snippet, mcp__codebase-memory-mcp__get_graph_schema, mcp__codebase-memory-mcp__trace_call_path, mcp__codebase-memory-mcp__search_code, mcp__codebase-memory-mcp__get_architecture"
}

emitted=0

for src in "$CANONICAL_DIR"/*.md; do
    [ -e "$src" ] || continue
    agent_name="$(basename "$src" .md)"

    # Frontmatter region: strictly between the first two lines that are
    # exactly "---". Guarded on n<2 so a literal "---" horizontal rule
    # appearing later in the body (several agent bodies use one) is never
    # mistaken for a third fence.
    fm=$(awk '/^---$/ && n<2 {n++; next} n==1 {print}' "$src")
    name=$(printf '%s\n' "$fm" | grep -m1 '^name:' | sed -E 's/^name:[[:space:]]*//')
    description=$(printf '%s\n' "$fm" | grep -m1 '^description:' | sed -E 's/^description:[[:space:]]*//')
    model_tier=$(printf '%s\n' "$fm" | grep -m1 '^model_tier:' | sed -E 's/^model_tier:[[:space:]]*//')
    tools_raw=$(printf '%s\n' "$fm" | grep -m1 '^tools:' | sed -E 's/^tools:[[:space:]]*//')

    # Body: everything after the second fence, verbatim — including any
    # "---" horizontal-rule lines the source uses for visual separation.
    body=$(awk '/^---$/ && n<2 {n++; next} n>=2 {print}' "$src")

    if [ -z "$name" ] || [ -z "$description" ] || [ -z "$tools_raw" ]; then
        echo "generate.sh: ERROR — $agent_name canonical source is missing name/description/tools frontmatter" >&2
        exit 1
    fi

    model=$(model_for_tier "$model_tier")
    if [ -z "$model" ]; then
        echo "generate.sh: ERROR — $agent_name has unrecognized model_tier '$model_tier' (expected critical|standard|mechanical)" >&2
        exit 1
    fi

    # Classify each comma-separated tools entry: portable primitives pass
    # through, `codebase-memory` expands to concrete CC grants, and
    # `host-provided:X` becomes a commented-out placeholder (never a broken
    # grant to a host-specific MCP server that may not exist on this host).
    IFS=',' read -ra tool_entries <<< "$tools_raw"
    cc_tools_line=""
    host_placeholders=()
    for entry in "${tool_entries[@]}"; do
        t="$(echo "$entry" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
        [ -z "$t" ] && continue
        case "$t" in
            codebase-memory)
                expanded="$(codebase_memory_tools)"
                ;;
            host-provided:*)
                host_placeholders+=("${t#host-provided:}")
                continue
                ;;
            *)
                expanded="$t"
                ;;
        esac
        if [ -z "$cc_tools_line" ]; then
            cc_tools_line="$expanded"
        else
            cc_tools_line="$cc_tools_line, $expanded"
        fi
    done

    # ── Claude Code emission ────────────────────────────────────────────────
    cc_file="$CC_DIR/$agent_name.md"
    {
        echo "---"
        echo "name: $name"
        echo "description: $description"
        echo "tools: $cc_tools_line"
        if [ "${#host_placeholders[@]}" -gt 0 ]; then
            for cap in "${host_placeholders[@]}"; do
                echo "# tools: <grant your own MCP for $cap here>"
            done
        fi
        echo "model: $model"
        echo "---"
        printf '%s\n' "$body"
    } > "$cc_file"

    # ── Codex emission (TOML) ───────────────────────────────────────────────
    # Refuse rather than emit invalid TOML if the body carries a literal
    # """ sequence — it would break the role = """...""" delimiter.
    if printf '%s' "$body" | grep -qF '"""'; then
        echo "generate.sh: ERROR — $agent_name body contains a literal '\"\"\"' sequence; refusing to emit $agent_name.toml (would produce invalid TOML)." >&2
        exit 1
    fi

    esc_name=$(printf '%s' "$name" | sed 's/"/\\"/g')
    esc_description=$(printf '%s' "$description" | sed 's/"/\\"/g')

    codex_file="$CODEX_DIR/$agent_name.toml"
    {
        echo "# model = mapping below is VERIFY-AT-BUILD-TIME — Codex model-name table unconfirmed pending Codex CLI access (architecture Open Question #4)."
        echo "name = \"$esc_name\""
        echo "description = \"$esc_description\""
        echo "model = \"$model\"  # VERIFY-AT-BUILD-TIME"
        echo "# tools-grant-key = VERIFY-AT-BUILD-TIME — exact Codex tools-grant key name unconfirmed; canonical capabilities: $tools_raw"
        echo "role = \"\"\""
        printf '%s\n' "$body"
        echo "\"\"\""
    } > "$codex_file"

    emitted=$((emitted + 1))
done

echo "agents/generate.sh: emitted $emitted Claude Code agent(s) to ${CC_DIR#$REPO_ROOT/}"
echo "agents/generate.sh: emitted $emitted Codex agent(s) to ${CODEX_DIR#$REPO_ROOT/}"

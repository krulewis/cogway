#!/usr/bin/env bash
#
# capture.sh — pluggable capture hook (no-op by default)
#
# The orchestrator calls this hook at lifecycle milestones (phase transitions,
# build completion, major bugs, experiment findings — see skills/orchestrator/
# SKILL.md for the exact trigger points). By default it does nothing and
# prints nothing, so Cogway has zero external dependencies out of the box.
#
# To wire your own persistence, replace the body below with a call to
# whatever you use to track this kind of thing — e.g.:
#   - a database insert (psql, sqlite3, an API call to your own service)
#   - a note-taking / knowledge-base API (Notion, Obsidian via REST, etc.)
#   - a local file append (e.g. `echo "$@" >> "$HOME/.cogway/capture.log"`)
#
# Usage:
#   hooks/capture.sh <event-type> <initiative-id-or-slug> <summary-text>
#
# Arguments:
#   event-type            short machine-readable tag, e.g. phase-transition,
#                          build-complete, major-bug, experiment-finding
#   initiative-id-or-slug  identifies which initiative the event belongs to
#   summary-text           free-text one-line (or short) summary of the event
#
# Exit status: always 0. This hook must never fail the orchestrator loop.

set -euo pipefail

event_type="${1:-}"
initiative_id="${2:-}"
summary_text="${3:-}"

# No-op by default. Replace the line below with your own persistence call,
# using $event_type / $initiative_id / $summary_text as needed.
:

exit 0

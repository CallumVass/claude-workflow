#!/usr/bin/env bash
set -euo pipefail

HALT_FLAG="<HALT>"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

if [ ! -f "PRD.md" ]; then
  err "PRD.md not found in current directory."
  exit 1
fi

echo "" >&2
header "Creating GitHub issues from PRD"

TMPFILE=$(run_agent "issue-creation-orchestrator" "Decompose PRD.md into vertical-slice GitHub issues.")

if check_signal "$TMPFILE" "$HALT_FLAG"; then
  REASON=$(extract_halt_field "$TMPFILE" "REASON")
  rm -f "$TMPFILE"
  err "Issue creation halted: ${REASON:-unknown}"
  exit 1
fi

rm -f "$TMPFILE"

echo "" >&2
ok "Done — check: gh issue list"

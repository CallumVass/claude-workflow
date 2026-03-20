#!/usr/bin/env bash
set -euo pipefail

MAX_LOOPS="${MAX_LOOPS:-10}"
HALT_FLAG="<HALT>"
COMPLETE_FLAG="<COMPLETE>"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/lib.sh"

cleanup() {
  trap - INT TERM EXIT
  echo ""
  warn "Shutting down prd-qa loop"
  kill -- -$$ 2>/dev/null
  exit 0
}
trap cleanup INT TERM EXIT

if [ ! -f "PRD.md" ]; then
  err "PRD.md not found in current directory. Create one first."
  exit 1
fi

echo "" >&2
header "PRD-QA — delegating to prd-orchestrator (max $MAX_LOOPS iterations)"

TMPFILE=$(run_agent "prd-orchestrator" "Refine PRD.md. Max iterations: $MAX_LOOPS.")
RESULT=$(extract_text "$TMPFILE")

if check_signal "$TMPFILE" "$COMPLETE_FLAG"; then
  rm -f "$TMPFILE"
  echo "" >&2
  ok "PRD complete"
  exit 0
fi

if check_signal "$TMPFILE" "$HALT_FLAG"; then
  REASON=$(extract_halt_field "$TMPFILE" "REASON")
  rm -f "$TMPFILE"
  echo "" >&2
  err "PRD refinement halted: ${REASON:-unknown}"
  exit 1
fi

rm -f "$TMPFILE"
echo "" >&2
warn "PRD orchestrator finished without signaling completion — review PRD.md manually"
exit 0

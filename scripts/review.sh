#!/usr/bin/env bash
set -euo pipefail

# Standalone code review: delegates to review-orchestrator.
# Outputs findings to stdout. Exit 0 = pass, exit 1 = findings.
#
# Usage:
#   ./review.sh <PR_NUMBER>              # review a PR
#   ./review.sh --branch <branch-name>   # review a branch vs main
#   ./review.sh --diff <diff-text>       # review a raw diff (used by pipeline for scoped re-review)
#
# Environment:
#   CHECK_CMD  — deterministic check command (default: pnpm check)
#   SKIP_CHECKS — set to 1 to skip deterministic checks

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

PASS_FLAG="<PASS>"
HALT_FLAG="<HALT>"

# --- Parse arguments ---
MODE=""
TARGET=""
REVIEW_CONTEXT=""
SKIP_CHECKS="${SKIP_CHECKS:-0}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --branch)
      MODE="branch"
      TARGET="$2"
      shift 2
      ;;
    --diff)
      MODE="diff"
      TARGET="$2"
      shift 2
      ;;
    --context)
      REVIEW_CONTEXT="$2"
      shift 2
      ;;
    --skip-checks)
      SKIP_CHECKS=1
      shift
      ;;
    *)
      # Positional arg = PR number
      MODE="pr"
      TARGET="$1"
      shift
      ;;
  esac
done

if [ -z "$MODE" ] || [ -z "$TARGET" ]; then
  echo "Usage: review.sh <PR_NUMBER>" >&2
  echo "       review.sh --branch <branch-name>" >&2
  echo "       review.sh --diff <diff-text> [--context <description>]" >&2
  exit 2
fi

# --- Build prompt for review-orchestrator ---
case "$MODE" in
  pr)
    PROMPT="Review PR #$TARGET."
    ;;
  branch)
    PROMPT="Review branch $TARGET vs main."
    ;;
  diff)
    PROMPT="Review the following diff:

$TARGET"
    [ -n "$REVIEW_CONTEXT" ] && PROMPT="$PROMPT

Context: $REVIEW_CONTEXT"
    ;;
esac

PROMPT="$PROMPT

MODE: autonomous"

[ "$SKIP_CHECKS" = "1" ] && PROMPT="$PROMPT

Skip deterministic checks."

# --- Run review orchestrator ---
TMPFILE=$(run_agent "review-orchestrator" "$PROMPT")
RESULT=$(extract_text "$TMPFILE")

# --- Translate result to exit code + stdout ---
if echo "$RESULT" | grep -qF "$PASS_FLAG"; then
  rm -f "$TMPFILE"
  ok "Review passed"
  echo "$PASS_FLAG"
  exit 0
fi

if check_signal "$TMPFILE" "$HALT_FLAG"; then
  REASON=$(extract_halt_field "$TMPFILE" "REASON")
  rm -f "$TMPFILE"
  err "Review halted: ${REASON:-deterministic checks failed}"
  exit 1
fi

# Validated findings remain
rm -f "$TMPFILE"
warn "Review found issues"
echo "$RESULT"
exit 1

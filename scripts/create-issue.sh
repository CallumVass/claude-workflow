#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

BRIEF_FILE=".cw-issue-brief.md"

if [ $# -eq 0 ]; then
  err "Usage: cw create-issue \"<feature description>\""
  exit 1
fi

DESCRIPTION="$*"

echo "" >&2
header "Create issue: interactive QA"

# Write brief for agent to read
echo "$DESCRIPTION" > "$BRIEF_FILE"
info "Brief written to $BRIEF_FILE"

cleanup() { rm -f "$BRIEF_FILE"; }
trap cleanup EXIT

# Build command — interactive mode (no -p, no stream-json)
cmd=(claude --agent single-issue-creator --dangerously-skip-permissions --verbose)
[ -n "$CW_MODEL" ] && cmd+=(--model "$CW_MODEL")

"${cmd[@]}"

echo "" >&2
ok "Done — check: gh issue list"

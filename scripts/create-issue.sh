#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

if [ $# -eq 0 ]; then
  err "Usage: cw create-issue \"<feature description>\""
  exit 1
fi

DESCRIPTION="$*"

echo "" >&2
header "Create issue: $DESCRIPTION"

PROMPT="Create a single GitHub issue for the following:

$DESCRIPTION

RULES:
- Explore the codebase first to understand context, relevant files, and patterns.
- Read CLAUDE.md for project conventions.
- Do NOT ask the user questions — make reasonable assumptions and note them in the issue if needed.
- Follow the issue-template skill format exactly.
- Populate Implementation Hints with specific files and patterns you discovered.
- Create the issue with: gh issue create --label \"auto-generated\"
- If the description is a bug report, frame the issue around investigating and fixing it."

TMPFILE=$(run_agent "single-issue-creator" "$PROMPT")
rm -f "$TMPFILE"

echo "" >&2
ok "Done — check: gh issue list"

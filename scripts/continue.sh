#!/usr/bin/env bash
set -euo pipefail

HALT_FLAG="<HALT>"
COMPLETE_FLAG="<COMPLETE>"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/lib.sh"

DESCRIPTION="${1:-}"

if [ ! -f "PRD.md" ]; then
  err "PRD.md not found in current directory."
  exit 1
fi

# --- Phase 1: Update PRD with Done/Next structure ---
echo "" >&2
header "Continue — updating PRD with Done/Next structure"

UPDATE_PROMPT="You are updating a PRD for the next phase of work on an existing project.

1. Read PRD.md to understand the product spec.
2. Explore the codebase thoroughly — file structure, existing features, git log, tests, what's actually built.
3. Compare what the PRD describes vs what exists in code.
4. Rewrite PRD.md with this structure:
   - Keep the Problem Statement, Goals, Tech Stack, and other top-level sections
   - Add or update a \`## Done\` section: a concise summary of what's already built (based on your codebase exploration, not just what the PRD previously said). Keep it brief — bullet points or short paragraphs describing completed user-facing capabilities.
   - Add or update a \`## Next\` section: the upcoming work.${DESCRIPTION:+ The user wants the next phase to focus on: $DESCRIPTION}
   - The \`## Next\` section should follow all PRD quality standards — user stories, functional requirements, edge cases, scope boundaries.
   - Remove any phase markers like 'Phase 1 (Complete)' — use Done/Next instead.

5. Keep the total PRD under 200 lines. The Done section should be especially concise — it's context, not spec.

CRITICAL RULES:
- Do NOT include code blocks, type definitions, or implementation detail.
- The Done section summarizes capabilities ('users can create runs and see streaming output'), not architecture ('Hono server with SSE endpoints').
- The Next section must be specific enough to create vertical-slice issues from.
- If no description was provided for Next, infer it from the existing PRD's roadmap, scope boundaries, or TODO items."

TMPFILE=$(run_agent "prd-architect" "$UPDATE_PROMPT")

if check_signal "$TMPFILE" "$HALT_FLAG"; then
  REASON=$(extract_halt_field "$TMPFILE" "REASON")
  rm -f "$TMPFILE"
  err "PRD update halted: ${REASON:-unknown}"
  exit 1
fi
rm -f "$TMPFILE"

ok "PRD updated with Done/Next structure"

# --- Phase 2: PRD QA on the Next section ---
echo "" >&2
"$SCRIPT_DIR/prd-qa.sh"

# --- Phase 3: Create issues for Next ---
echo "" >&2
"$SCRIPT_DIR/create-issues.sh"

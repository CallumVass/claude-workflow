#!/usr/bin/env bash
set -euo pipefail

# Standalone UI design script: analyzes app → designs system → implements component.
#
# Usage:
#   ./design-ui.sh "landing page"     # design + implement a landing page
#   ./design-ui.sh "dashboard"        # design + implement a dashboard
#   ./design-ui.sh                    # read target from DESIGN_BRIEF.md
#
# Environment:
#   DESIGN_BRIEF  — path to design brief file (default: DESIGN_BRIEF.md)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

DESIGN_BRIEF="${DESIGN_BRIEF:-DESIGN_BRIEF.md}"
HALT_SIGNAL="<HALT>"

# --- Resolve design target ---
if [ -n "${1:-}" ]; then
  DESIGN_TARGET="$1"
elif [ -f "$DESIGN_BRIEF" ]; then
  DESIGN_TARGET=$(cat "$DESIGN_BRIEF")
else
  err "No design target provided and $DESIGN_BRIEF not found."
  echo "Usage: design-ui.sh <target>   or   create $DESIGN_BRIEF" >&2
  exit 1
fi

echo "" >&2
header "UI Design: $DESIGN_TARGET"

# --- Build prompt ---
PROMPT="You have 3 phases. Complete ALL of them.

## Phase 1 — App Analysis

Read package.json (or equivalent manifest), README, and existing source files.
Identify:
- Domain/industry and target audience
- Tech stack and framework
- Styling approach (Tailwind, CSS modules, styled-components, etc.)
- Existing design patterns or component libraries in use

## Phase 2 — Design System

Based on your analysis, update the frontend-conventions skill with a COMPLETE design system tailored to this app.

The design system must include:
- Design philosophy (2-3 sentences — why this aesthetic fits this domain)
- Typography scale with domain-appropriate font pairings
- Color palette as CSS variables (primary, secondary, accent, semantic colors)
- Spacing scale and border/radius tokens
- Component patterns (buttons, inputs, cards, nav — with variants)
- Layout system (grid, max-widths, breakpoints)
- Motion & interaction principles
- Framework conventions (component lib, styling approach, icon set)

Make the design system SPECIFIC to this app's domain — not generic defaults.

## Phase 3 — Implementation

Build the following using the design system you just created:

$DESIGN_TARGET

Requirements:
- Production-grade, responsive code
- Hover, focus, and loading states
- Accessible (semantic HTML, ARIA where needed)
- Match the project's existing file structure and conventions
- Real, functional code — not mockups or descriptions"

# --- Run agent ---
TMPFILE=$(run_agent "frontend-designer" "$PROMPT")

# --- Check for halt ---
if check_signal "$TMPFILE" "$HALT_SIGNAL"; then
  rm -f "$TMPFILE"
  err "Design halted (agent signaled $HALT_SIGNAL)"
  exit 1
fi

rm -f "$TMPFILE"
ok "Design complete"

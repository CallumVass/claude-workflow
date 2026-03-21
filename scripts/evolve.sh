#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CW_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/lib.sh"

HALT_FLAG="<HALT>"
COMPLETE_FLAG="<COMPLETE>"

echo "" >&2
header "Evolve — pipeline retrospective"

# Check for data sources
HAS_DATA=false
DATA_SUMMARY=""

if [ -d "failures" ] && compgen -G "failures/issue-*.md" >/dev/null 2>&1; then
  COUNT=$(ls failures/issue-*.md 2>/dev/null | wc -l)
  info "Found $COUNT failure report(s)"
  DATA_SUMMARY+="- $COUNT failure report(s) in failures/"$'\n'
  HAS_DATA=true
fi

if [ -f "LEARNINGS.md" ]; then
  info "Found LEARNINGS.md"
  DATA_SUMMARY+="- LEARNINGS.md present"$'\n'
  HAS_DATA=true
fi

MERGED_PRS=$(gh pr list --state merged --limit 20 --json number --jq 'length' 2>/dev/null || echo "0")
if [ "$MERGED_PRS" -gt 0 ]; then
  info "Found $MERGED_PRS recently merged PR(s)"
  DATA_SUMMARY+="- $MERGED_PRS recently merged PR(s)"$'\n'
  HAS_DATA=true
fi

FAILED_RUNS=$(gh run list --limit 30 --json conclusion --jq '[.[] | select(.conclusion == "failure")] | length' 2>/dev/null || echo "0")
if [ "$FAILED_RUNS" -gt 0 ]; then
  info "Found $FAILED_RUNS failed CI run(s)"
  DATA_SUMMARY+="- $FAILED_RUNS failed CI run(s)"$'\n'
  HAS_DATA=true
fi

if [ "$HAS_DATA" = false ]; then
  warn "No data to analyze — run the pipeline first"
  warn "Needs: failures/, LEARNINGS.md, merged PRs, or CI runs"
  exit 0
fi

PROMPT="Analyze pipeline performance and generate improvements.

CW_ROOT: $CW_ROOT
Working directory (target project): $(pwd)

Available data:
$DATA_SUMMARY

Instructions:
1. Gather data from all available sources listed above
2. Analyze for recurring patterns (need 2+ data points each)
3. Generate patches to files under $CW_ROOT (agents/, skills/, templates/)
4. Create branch, commit, push, and create PR in the CW_ROOT repo
5. Output your retrospective report

If no actionable patterns found, output: $COMPLETE_FLAG"

TMPFILE=$(run_agent "retrospective" "$PROMPT")

if check_signal "$TMPFILE" "$COMPLETE_FLAG"; then
  rm -f "$TMPFILE"
  echo "" >&2
  ok "No actionable patterns found — pipeline is performing well"
  exit 0
fi

if check_signal "$TMPFILE" "$HALT_FLAG"; then
  REASON=$(extract_halt_field "$TMPFILE" "REASON")
  rm -f "$TMPFILE"
  echo "" >&2
  err "Retrospective halted: ${REASON:-unknown}"
  exit 1
fi

rm -f "$TMPFILE"
echo "" >&2
ok "Evolve complete — check PR for proposed improvements"

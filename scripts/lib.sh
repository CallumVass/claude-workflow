#!/usr/bin/env bash
# Shared utilities for pipeline scripts.
# Source this file: source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROGRESS_LOG="${PROGRESS_LOG:-progress.log}"

# --- Color/formatting ---
# Respects NO_COLOR (https://no-color.org/) and non-interactive stderr
if [ -n "${NO_COLOR:-}" ] || [ ! -t 2 ]; then
  C_RESET="" C_RED="" C_GREEN="" C_YELLOW="" C_CYAN="" C_BOLD="" C_DIM=""
  _NO_COLOR=1
else
  C_RESET=$'\033[0m' C_RED=$'\033[31m' C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m' C_CYAN=$'\033[36m' C_BOLD=$'\033[1m' C_DIM=$'\033[2m'
  _NO_COLOR=""
fi

S_OK="✓" S_FAIL="✗" S_ARROW="▸" S_WARN="⚠" S_INFO="●"

header() {
  local text="$1"
  local len=${#text}
  local bar
  bar=$(printf '─%.0s' $(seq 1 $((len + 2))))
  echo "${C_BOLD}┌${bar}┐${C_RESET}" >&2
  echo "${C_BOLD}│ ${text} │${C_RESET}" >&2
  echo "${C_BOLD}└${bar}┘${C_RESET}" >&2
}

info()  { echo "${C_CYAN}${S_INFO}${C_RESET} $*" >&2; }
ok()    { echo "${C_GREEN}${S_OK}${C_RESET} $*" >&2; }
warn()  { echo "${C_YELLOW}${S_WARN}${C_RESET} $*" >&2; }
err()   { echo "${C_RED}${S_FAIL}${C_RESET} $*" >&2; }

# --- Backend configuration ---
CW_BACKEND="${CW_BACKEND:-claude}"
CW_MODEL="${CW_MODEL:-}"

case "$CW_BACKEND" in
  claude)
    STREAM_FILTER="${STREAM_FILTER:-$LIB_DIR/stream-filter.jq}"
    STREAM_TEXT='select(.type == "assistant") | .message.content[]? | select(.type == "text").text // empty'
    ;;
  opencode)
    STREAM_FILTER="${STREAM_FILTER:-$LIB_DIR/stream-filter-opencode.jq}"
    STREAM_TEXT='select(.type == "text") | .part.text // empty'
    ;;
  *)
    echo "ERROR: unknown CW_BACKEND: $CW_BACKEND (expected: claude, opencode)" >&2
    exit 1
    ;;
esac

# Log a progress message to stderr (or fd3 in parallel mode) and the progress log file.
# Usage: progress "#42 — planning"
progress() {
  local msg="$1"
  local line
  line="${C_DIM}[$(date +%H:%M:%S)]${C_RESET} $msg"
  local plain_line
  plain_line="[$(date +%H:%M:%S)] $msg"
  # In parallel mode, CW_TERMINAL_FD points to the real terminal
  if [ -n "${CW_TERMINAL_FD:-}" ] && { true >&"$CW_TERMINAL_FD"; } 2>/dev/null; then
    echo "$line" >&"$CW_TERMINAL_FD"
  else
    echo "$line" >&2
  fi
  echo "$plain_line" >> "$PROGRESS_LOG"
}

# Run an agent, stream display to stderr, return tmpfile path on stdout.
# Usage: TMPFILE=$(run_agent <agent-name> <prompt>)
run_agent() {
  local agent="$1"
  # Replace common relative file references with absolute paths
  local cwd
  cwd=$(pwd)
  local prompt="$2"
  prompt="${prompt//PRD.md/$cwd/PRD.md}"
  prompt="${prompt//QUESTIONS.md/$cwd/QUESTIONS.md}"
  prompt="${prompt//DESIGN_BRIEF.md/$cwd/DESIGN_BRIEF.md}"
  local tmpfile
  tmpfile=$(mktemp)

  local cmd=()
  case "$CW_BACKEND" in
    claude)
      cmd=(claude --agent "$agent"
        --dangerously-skip-permissions
        --output-format stream-json
        --verbose)
      [ -n "$CW_MODEL" ] && cmd+=(--model "$CW_MODEL")
      cmd+=(-p "$prompt")
      ;;
    opencode)
      # Allow all permissions in non-interactive mode (equivalent to claude's --dangerously-skip-permissions)
      export OPENCODE_PERMISSION='{"*":"allow"}'
      cmd=(opencode run --agent "$agent" --format json)
      [ -n "$CW_MODEL" ] && cmd+=(-m "$CW_MODEL")
      cmd+=("$prompt")
      ;;
  esac

  "${cmd[@]}" \
  | grep --line-buffered '^{' \
  | tee "$tmpfile" \
  | jq --unbuffered -rj \
      --arg no_color "${_NO_COLOR:-}" \
      --arg verbose "${CW_VERBOSE:-}" \
      -f "$STREAM_FILTER" >&2 || true

  echo "$tmpfile"
}

# Check if a signal string exists in agent output.
# Usage: check_signal <tmpfile> "<HALT>"
check_signal() {
  local tmpfile="$1"
  local signal="$2"
  jq -r "$STREAM_TEXT" "$tmpfile" 2>/dev/null | grep -qF "$signal"
}

# Extract full text output from agent tmpfile.
# Usage: TEXT=$(extract_text <tmpfile>)
extract_text() {
  local tmpfile="$1"
  jq -r "$STREAM_TEXT" "$tmpfile" 2>/dev/null || true
}

# Extract a field from structured HALT output in agent tmpfile.
# Orchestrators emit: <HALT>\nREASON: ...\nRUN_ID: ...\nDETAILS: ...
# Usage: REASON=$(extract_halt_field <tmpfile> "REASON")
extract_halt_field() {
  local tmpfile="$1"
  local field="$2"
  jq -r "$STREAM_TEXT" "$tmpfile" 2>/dev/null | grep -m1 "^${field}:" | sed "s/^${field}: //"
}

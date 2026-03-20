# Formats opencode run --format json into readable terminal output.
# Usage: ... | jq --unbuffered -rj --arg no_color "" --arg verbose "" -f stream-filter-opencode.jq
# Set CW_THINKING=1 to display thinking/reasoning blocks.
#
# Event types:
#   step_start  — new step beginning
#   text        — assistant text output
#   tool_use    — tool call + result combined
#   step_finish — step completed with cost/token info

# --- Color helpers (conditional on $no_color) ---
def c_cyan:   if $no_color != "" then "" else "\u001b[36m" end;
def c_dim:    if $no_color != "" then "" else "\u001b[2m" end;
def c_green:  if $no_color != "" then "" else "\u001b[32m" end;
def c_red:    if $no_color != "" then "" else "\u001b[31m" end;
def c_bold:   if $no_color != "" then "" else "\u001b[1m" end;
def c_magenta: if $no_color != "" then "" else "\u001b[35m" end;
def c_reset:  if $no_color != "" then "" else "\u001b[0m" end;

# --- Truncation helpers ---
def truncate_result:
  if $verbose != "" then .
  else
    split("\n") |
    if length <= 8 then join("\n")
    else
      (length - 6) as $omitted |
      (.[0:3] | join("\n")) + "\n" +
      c_dim + "  ... (\($omitted) more lines)" + c_reset + "\n" +
      (.[-3:] | join("\n"))
    end
  end;

def truncate_arg:
  if $verbose != "" then .
  elif length > 200 then .[0:200] + "..."
  else .
  end;

if .type == "text" then
  (.part.text // empty) + (if (.part.text // "") | endswith("\n") then "" else "\n" end)

elif .type == "tool_use" then
  # Tool call
  "  " + c_cyan + "\u25b8 " + (.part.tool // "tool") + c_reset +
  (if .part.state.title then "  " + c_dim + (.part.state.title | truncate_arg) + c_reset
   elif .part.state.input then
     "  " + c_dim + (.part.state.input | tostring | truncate_arg) + c_reset
   else ""
   end)
  + "\n" +
  # Tool result
  (if .part.state.output then
     (.part.state.output | tostring) as $out |
     (if (.part.state.error // false) then
       "  " + c_red + "\u2502 " + c_reset + c_dim + ($out | truncate_result | gsub("\n"; "\n  \u2502 ")) + c_reset + "\n"
     else
       "  " + c_dim + "\u2502 " + ($out | truncate_result | gsub("\n"; "\n  \u2502 ")) + c_reset + "\n"
     end)
   else ""
   end)

elif (.type == "reasoning" or .type == "thinking") and ($ENV.CW_THINKING // "") != "" then
  c_dim + c_magenta + (.part.text // .part.thinking // empty) + c_reset +
  (if (.part.text // .part.thinking // "") | endswith("\n") then "" else "\n" end)

elif .type == "step_finish" then
  "\n" + c_green + "\u2713 Done" + c_reset +
  " (" +
  (.part.reason // "unknown") + ", " +
  "$" + (.part.cost // 0 | tostring | .[0:6]) +
  ")\n"

else
  empty
end

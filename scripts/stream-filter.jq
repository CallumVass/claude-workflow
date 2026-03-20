# Formats claude --output-format stream-json into readable terminal output.
# Usage: ... | jq --unbuffered -rj --arg no_color "" --arg verbose "" -f stream-filter.jq
# Set CW_THINKING=1 to display thinking/reasoning blocks.
#
# Event types:
#   assistant — message.content[]: text, tool_use, thinking
#   user      — tool results in .tool_use_result
#   result    — final status
#   system    — init, hooks (ignored)

# --- Color helpers (conditional on $no_color) ---
def c_cyan:   if $no_color != "" then "" else "\u001b[36m" end;
def c_dim:    if $no_color != "" then "" else "\u001b[2m" end;
def c_green:  if $no_color != "" then "" else "\u001b[32m" end;
def c_yellow: if $no_color != "" then "" else "\u001b[33m" end;
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

# --- Duration formatting ---
def format_duration:
  (. / 1000) |
  if . >= 60 then "\(. / 60 | floor)m\(. - ((. / 60 | floor) * 60) | round)s"
  else "\(. * 10 | round / 10)s"
  end;

if .type == "assistant" then
  (.message.content // [])[] |
    if .type == "text" then
      (.text // empty) + (if (.text // "") | endswith("\n") then "" else "\n" end)
    elif .type == "tool_use" then
      "  " + c_cyan + "\u25b8 " + .name + c_reset +
      (if .name == "Bash" then "  " + c_dim + (.input.command? // "" | truncate_arg) + c_reset
       elif .name == "Read" then "  " + c_dim + (.input.file_path? // "") + c_reset
       elif .name == "Edit" then "  " + c_dim + (.input.file_path? // "") + c_reset
       elif .name == "Write" then "  " + c_dim + (.input.file_path? // "") + c_reset
       elif .name == "Grep" then "  " + c_dim + (.input.pattern? // "") + c_reset
       elif .name == "Glob" then "  " + c_dim + (.input.pattern? // "") + c_reset
       else ""
       end)
      + "\n"
    elif .type == "thinking" and ($ENV.CW_THINKING // "") != "" then
      c_dim + c_magenta + (.thinking // empty) + c_reset +
      (if (.thinking // "") | endswith("\n") then "" else "\n" end)
    else empty
    end

elif .type == "user" and .tool_use_result then
  (if (.tool_use_result | type) == "string" then
     "  " + c_dim + "\u2502 " + (.tool_use_result | truncate_result | gsub("\n"; "\n  \u2502 ")) + c_reset + "\n"
   elif .tool_use_result.file then
     "  " + c_dim + "\u2502 " + "(\(.tool_use_result.file.numLines // "?") lines)" + c_reset + "\n"
   elif .tool_use_result.stdout then
     "  " + c_dim + "\u2502 " + (.tool_use_result.stdout | truncate_result | gsub("\n"; "\n  \u2502 ")) + c_reset + "\n"
   else
     (.message.content[]? | select(.type == "tool_result") |
       .content // "" | if type == "string" then
         "  " + c_dim + "\u2502 " + (. | truncate_result | gsub("\n"; "\n  \u2502 ")) + c_reset + "\n"
       else "" end)
   end)

elif .type == "result" then
  "\n" + c_green + "\u2713 Done" + c_reset +
  " (" +
  (.subtype // "unknown") + ", " +
  (.duration_ms // 0 | format_duration) + ", " +
  "$" + (.total_cost_usd // 0 | tostring | .[0:6]) +
  ")\n"

else
  empty
end

# Converts a Claude Code agent .md to OpenCode format.
# Strips name/tools from frontmatter, collects skills and injects load instruction into body.
# Converts color names to hex, sets mode from -v mode=<value> (default: subagent).
# Tools stripped because Claude uses array format, OpenCode uses record format (tool: bool).
# Usage: awk -v mode=subagent -f convert-agent-opencode.awk agent.md

BEGIN { in_fm = 0; fm_done = 0; skip = 0; in_skills = 0; skill_count = 0; injected = 0; if (!mode) mode = "subagent" }

/^---$/ && in_fm == 0 && fm_done == 0 {
  in_fm = 1; print; next
}

/^---$/ && in_fm == 1 {
  in_fm = 0; fm_done = 1
  print "mode: " mode
  print; next
}

# Collect skill names from frontmatter
in_fm == 1 && /^skills:/ { in_skills = 1; skip = 1; next }
in_fm == 1 && in_skills == 1 && /^  - / {
  sub(/^  - /, "")
  skills[skill_count++] = $0
  next
}
in_fm == 1 && in_skills == 1 && /^[^ ]/ { in_skills = 0; skip = 0 }

# Strip model: inherit (Claude concept; OpenCode uses its configured default)
in_fm == 1 && /^model: inherit$/ { next }

in_fm == 1 && /^(name|tools):/ { skip = 1; next }
in_fm == 1 && skip == 1 && /^  - / { next }
in_fm == 1 && skip == 1 && /^[^ ]/ { skip = 0 }
in_fm == 1 && skip == 1 { next }

# Convert named colors to hex
in_fm == 1 && /^color:/ {
  val = $2
  if      (val == "cyan")    print "color: \"#00FFFF\""
  else if (val == "red")     print "color: \"#FF0000\""
  else if (val == "green")   print "color: \"#00FF00\""
  else if (val == "blue")    print "color: \"#0000FF\""
  else if (val == "yellow")  print "color: \"#FFFF00\""
  else if (val == "magenta") print "color: \"#FF00FF\""
  else if (val == "white")   print "color: \"#FFFFFF\""
  else print  # already hex or unknown, pass through
  next
}

# Inject skill loading instruction after first blank line in body
fm_done == 1 && !injected && skill_count > 0 && /^$/ {
  print
  print "## Skills"
  print ""
  print "Before starting work, load these skills using the skill tool:"
  for (i = 0; i < skill_count; i++) {
    print "- `" skills[i] "`"
  }
  print ""
  injected = 1
  next
}

{ print }

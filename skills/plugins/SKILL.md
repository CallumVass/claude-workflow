---
name: plugins
description: Domain-specific plugin router. Scans project plugins, matches triggers against codebase/diff, returns which plugins to load for a given pipeline stage.
---

# Plugins

Domain-specific knowledge that is progressively loaded based on the project's codebase and the current pipeline stage. Plugins live in the user's project repository, not in claude-workflow.

## Plugin Location

Plugins are installed per-project at:

```
<repo-root>/.claude-workflow/plugins/<name>/PLUGIN.md
```

Example plugins ship in the claude-workflow repo under `examples/plugins/` — copy them into your project's `.claude-workflow/plugins/` directory when you want to use them.

## Plugin Structure

```
.claude-workflow/
  plugins/
    <name>/
      PLUGIN.md              # Triggers + stage-specific guidance (always read when matched)
      references/            # Deep context (read lazily when needed)
        *.md
```

Each `PLUGIN.md` has YAML frontmatter with trigger conditions and stage applicability:

```yaml
---
name: Human-readable name
description: One-line description
triggers:
  files: ["*.tsx", "*.jsx"]    # Glob patterns for project files
  content: ["useQuery", "cn("] # Literal strings to search for in codebase/diff
stages: [plan, implement, review, refactor]  # which pipeline stages use this plugin
---
```

If `stages` is omitted, default to `[review]` for backwards compatibility with older plugins.

## How to Match Plugins

Given a diff (or the codebase) and a current pipeline stage, scan each plugin at `<cwd>/.claude-workflow/plugins/*/PLUGIN.md`:

1. **files**: At least one file (changed or in codebase) matches any of the plugin's file glob patterns.
2. **content**: At least one of the plugin's content strings appears in the diff or codebase.
3. **stages**: The current pipeline stage is listed in the plugin's `stages` array.

All three conditions must be true for a plugin to match.

## Progressive Disclosure Layers

1. **Trigger scan** (this skill) — read only frontmatter, decide which plugins match. Cheap.
2. **Plugin body** — read the matched `PLUGIN.md` body for stage-specific guidance. Medium cost.
3. **Plugin references** — read files from `references/` only when a specific finding or decision needs deeper context. Expensive, on-demand only.

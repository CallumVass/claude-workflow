---
name: retrospective
description: Pipeline retrospective analysis. Identifies recurring failure patterns across agent runs and produces targeted improvements to agents, skills, and templates.
---

# Retrospective Skill

Analyzes pipeline run history — failures, review findings, CI logs, and learnings — to identify recurring patterns and generate targeted patches to claude-workflow's agents, skills, and templates.

## Data Sources

Gather from ALL available sources. Missing sources are fine — work with what exists.

### 1. Failure Reports (`failures/issue-*.md`)
Structured failure reports written by `implement-issues.sh`. Each contains:
- Branch name, failure reason, timestamp
- Changed files (git diff)
- Diagnostics (CI logs, check output)

**Look for**: repeated failure reasons, same file patterns causing trouble, recurring CI step failures.

### 2. LEARNINGS.md
Accumulated patterns/conventions discovered during implementation. Already distilled.

**Look for**: entries that suggest agents are fighting the codebase (e.g., "always do X" implies agents kept not doing X).

### 3. Recent Merged PRs
Query via `gh pr list --state merged --limit 20 --json number,title,body,reviewDecision,additions,deletions,changedFiles`.

For PRs with review comments: `gh api repos/{owner}/{repo}/pulls/{number}/reviews --jq '.[].body'`

**Look for**: PRs that required many review cycles, large PRs that could have been decomposed, review findings that recur across PRs.

### 4. Recent CI Runs
Query via `gh run list --limit 30 --json databaseId,conclusion,name,headBranch`.

**Look for**: failure rate by step name, branches that fail repeatedly, which CI steps fail most often.

## Pattern Categories

Classify every pattern into exactly one category:

### Agent Capability Gaps
The agent's instructions don't cover a scenario it keeps hitting.
- Example: "implementor fails on DB migration issues" → add migration guidance to implementor
- Example: "planner underestimates multi-file changes" → add complexity heuristics to planner

### Skill Knowledge Gaps
A skill is missing domain knowledge the agents need.
- Example: "TDD skill doesn't cover async test patterns" → add async section to TDD skill
- Example: "code-review misses auth patterns" → add project-specific checklist items

### Template Misconfigurations
Project templates produce suboptimal initial setups.
- Example: "CHECK_CMD default doesn't run typecheck" → update template default
- Example: "CLAUDE.md template missing common convention" → add to template

### Pipeline Flow Issues
Script-level configuration or flow problems.
- Example: "CI_FIX_RETRIES too low for flaky test suites" → suggest increasing default
- Example: "review cycles exhaust before complex PRs converge" → suggest increasing REVIEW_MAX_CYCLES

## Analysis Process

1. **Gather** — read all data sources, take notes on recurring themes
2. **Correlate** — cross-reference failures with review findings with CI logs. Same root cause may appear differently in each source.
3. **Classify** — assign each pattern to a category
4. **Prioritize** — rank by impact (how many issues affected × severity)
5. **Prescribe** — generate concrete file patches for the top patterns

## Evidence Requirements

Every proposed change MUST cite:
- **At least 2 independent data points** (e.g., 2 failure reports, or 1 failure + 1 review finding)
- **Specific references** — issue numbers, file paths, failure reasons, CI run IDs
- **Clear causal chain** — "X happened because agent lacks Y guidance, evidenced by Z"

Changes without sufficient evidence are noise and must be discarded.

## Output Format

```markdown
## Retrospective: <YYYY-MM-DD>

### Patterns Found

#### Pattern 1: <concise title>
- **Category**: [Agent Gap | Skill Gap | Template | Pipeline Flow]
- **Impact**: <N issues/PRs affected>
- **Evidence**:
  - <data point 1 with specific reference>
  - <data point 2 with specific reference>
- **Root cause**: <why agents are struggling>

### Proposed Changes

#### Change 1: <file path relative to CW_ROOT>
- **Pattern**: <which pattern this addresses>
- **Type**: [agent | skill | template | script]
- **Rationale**: <one sentence — why this specific edit helps>
- **Edit**: <describe the exact modification>
```

## Rules

- **Evidence-based only.** No speculative improvements. If you can't cite 2+ data points, don't propose it.
- **Additive over destructive.** Prefer adding guidance to removing/rewriting existing instructions.
- **Never remove capabilities.** Agents should only get smarter, not lose existing behavior.
- **Small, focused patches.** One concern per change. Don't bundle unrelated improvements.
- **No self-modification.** Never patch `agents/retrospective.md`, `skills/retrospective/`, or `scripts/evolve.sh`.
- **Backward-compatible.** Changes must not break existing pipeline behavior.
- **Respect the 2-data-point minimum.** A single failure is an anecdote; two is a pattern.

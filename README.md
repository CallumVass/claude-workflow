# claude-workflow

Autonomous software delivery pipeline. Takes a PRD to merged PRs — refines requirements, creates GitHub issues, implements via TDD, reviews, and merges.

Works with [Claude Code](https://docs.anthropic.com/en/docs/claude-code) or [OpenCode](https://opencode.ai). Requires [GitHub CLI](https://cli.github.com/) (`gh`) and `jq`.

## Setup

```bash
git clone <repo> ~/dev/claude-workflow
~/dev/claude-workflow/bin/cw setup    # symlinks 'cw' to ~/.local/bin
cw sync                               # copies agents + skills to ~/.claude

cd my-project
cw init                               # creates .claude/CLAUDE.md + hooks.json
# Edit .claude/CLAUDE.md — fill in {{PROJECT_NAME}}, {{CHECK_CMD}}, etc.
```

Run `cw sync` after editing agents or skills. OpenCode agents sync automatically if installed.

## Usage

### New project (greenfield)

```bash
# Write PRD.md (see examples/PRD.md)
cw prd-qa                  # refine PRD via critic → architect → integrator loop
cw create-issues            # decompose into vertical-slice GitHub issues
cw implement                # plan → TDD → CI → review → merge, per issue
```

### Existing project (next phase)

```bash
cw continue "add real-time collaboration"   # updates PRD with Done/Next, refines, creates issues
cw implement
```

`cw continue` explores the codebase, writes a `## Done` section summarizing what's built, adds a `## Next` section for the new work, then runs PRD QA and issue creation. This prevents issues from conflicting with existing code.

### Other commands

```bash
cw create-issue "retry failed webhooks"     # interactive QA → single issue
cw review 42                                # code review PR #42
cw review --branch feat/foo                 # review branch vs main
```

### Skip flags for `cw implement`

```bash
cw implement --skip-plan          # implement directly, no planner
cw implement --skip-refactor      # skip post-implementation deduplication
cw implement --skip-review        # skip code review cycle
```

## How it works

```
PRD.md → prd-qa → create-issues → implement → merged PRs
                                      │
                        per issue:    ├─ planner (test sequence)
                                      ├─ implementor (TDD)
                                      ├─ refactorer (dedup)
                                      ├─ ci-fixer (up to 3 retries)
                                      ├─ code-reviewer → review-judge
                                      └─ squash merge
```

**PRD QA** loops critic → architect → integrator until the PRD is implementation-ready. Each is a separate agent invocation with no shared context, forcing the PRD to be self-contained.

**Issue creation** explores the codebase, then decomposes the PRD into vertical-slice issues — each crossing all layers (DB → server → client → UI) with acceptance criteria, test plan, and implementation hints.

**Implementation** processes issues in dependency order, parallelizing independent ones via git worktrees. Each issue gets: planning, TDD, refactoring, CI fixes, code review, then merge.

### Phase-aware PRDs

For multi-phase projects, PRDs use `## Done` / `## Next` sections:

- `## Done` — concise summary of completed work (accepted context, not re-evaluated)
- `## Next` — the upcoming phase (evaluated, decomposed into issues)

The critic focuses only on `## Next`. The issue-creator explores the codebase and only creates issues for `## Next`.

## IDE use

Orchestrator agents work identically in Claude Code / OpenCode for human-in-the-loop workflows:

| Orchestrator | Does | Script equivalent |
|---|---|---|
| `implementation-orchestrator` | Plan → implement (TDD) | `cw implement` (per issue) |
| `review-orchestrator` | Checks → reviewer → judge | `cw review` |
| `prd-orchestrator` | Critic → architect → integrator | `cw prd-qa` |
| `issue-creation-orchestrator` | Validate PRD → create issues | `cw create-issues` |
| `ci-fix-orchestrator` | Diagnose → fix → verify CI | CI step in `cw implement` |

Scripts add automation glue (worktrees, parallelism, retries, merge). Orchestrators own the workflow logic.

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `CW_BACKEND` | `claude` | `claude` or `opencode` |
| `CW_MODEL` | *(default)* | Override model ID |
| `TEST_CMD` | *(auto-detected)* | Test command |
| `CHECK_CMD` | *(auto-detected)* | Full CI check |
| `INSTALL_CMD` | *(auto-detected)* | Dependency install |
| `CI_FIX_RETRIES` | `3` | CI fix attempts per failure |
| `MAX_PARALLEL` | `1` | Concurrent issue implementations |

Commands auto-detect from project files (`package.json` → bun/npm/pnpm/yarn, `mix.exs` → mix, `Cargo.toml` → cargo, `go.mod` → go, `pyproject.toml` → pytest/ruff, `*.csproj` → dotnet). Override with env vars: `CHECK_CMD="mix precommit" cw implement`.

## Troubleshooting

**"tests failing on main"** — Fix tests on main before running `cw implement`.

**"all issues in batch failed"** — Check `failures/issue-N.md` for diagnostics.

**Pipeline crashed** — Re-run `cw implement`. Already-merged issues are skipped; issues with PRs resume from CI/review.

**Logs**: `tail -f progress.log` for real-time progress. `failures/issue-N.md` for failure reports. `logs/issue-N.log` for per-issue output (parallel mode).

## Project structure

```
bin/cw                          CLI entrypoint
scripts/
  prd-qa.sh                    PRD refinement loop
  continue.sh                  Update PRD Done/Next → refine → create issues
  create-issues.sh             PRD → GitHub issues
  create-issue.sh              Interactive single issue
  implement-issues.sh          Autonomous implementation loop
  review.sh                    Standalone code review
  lib.sh                       Shared utilities
agents/                        16 agent definitions (orchestrators + workers)
skills/                        tdd, code-review, issue-template, prd-quality, opensrc, stitch, review-plugins
templates/                     CLAUDE.md.global, CLAUDE.md.project, hooks.json
examples/PRD.md                Sample PRD
```

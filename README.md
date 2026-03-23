# claude-workflow

Autonomous software delivery pipeline using Claude Code or OpenCode. Takes a project from PRD to merged PRs without human intervention.

## Quickstart

```bash
# Install (once per machine)
git clone <repo> ~/dev/claude-workflow
~/dev/claude-workflow/bin/cw setup    # symlinks 'cw' to ~/.local/bin
cw sync                               # copies agents + skills to ~/.claude (+ opencode if installed)

# Bootstrap a project (once per project)
cd my-project
cw init                               # creates .claude/CLAUDE.md + hooks.json
# Edit .claude/CLAUDE.md — fill in {{PROJECT_NAME}}, {{CHECK_CMD}}, etc.

# Run the pipeline
cw prd-qa                             # refine PRD.md
cw create-issues                      # decompose into GitHub issues
cw implement                          # autonomous TDD + CI + review + merge
```

After editing agents or skills in the repo, run `cw sync` to update `~/.claude`. If OpenCode is installed, agents are also converted and synced to `~/.config/opencode/agents` automatically.

## Pipeline

```
PRD.md  →  cw prd-qa  →  cw create-issues  →  cw implement  →  merged PRs
 (you)    (refine PRD)   (GitHub issues)       (TDD + CI + review + merge)
```

### 1. `cw prd-qa` — PRD Refinement

Multi-agent loop with 3 personas (Integrator, Critic, Architect) that iterate until the PRD is implementation-ready. Each agent is a separate Claude invocation with no shared context, forcing the PRD to be self-contained.

Requires `PRD.md` in the current directory. See [`examples/PRD.md`](examples/PRD.md) for a sample.

### 2a. `cw create-issue` — Single Issue (Interactive)

Turn a rough feature idea into a well-structured issue through interactive QA. Explores the codebase, asks clarifying questions, then creates a single issue when you're satisfied.

```bash
cw create-issue "Add dark mode support"
cw create-issue "Retry failed webhook deliveries with exponential backoff"
```

### 2b. `cw create-issues` — Bulk Decomposition (from PRD)

Reads PRD.md and creates GitHub issues via `gh`. Issues are vertical slices (not layer-sliced), each with full context, acceptance criteria, test plan, and implementation hints.

### 3. `cw implement` — Autonomous Implementation

Processes open issues in dependency-aware batches, parallelizing independent issues. For each:
- **Planner** — reads issue + codebase, outputs sequenced test plan for the implementor
- Spawns implementor agent with TDD (red-green-refactor)
- **CI check** — if CI fails, invokes ci-fixer agent (up to `CI_FIX_RETRIES`)
- **Code review** — runs reviewer→judge loop (up to `REVIEW_MAX_CYCLES`), implementor fixes findings
- Squash merges, then **synthesizer** distills patterns into `LEARNINGS.md`
- Independent issues run in parallel via git worktrees (up to `MAX_PARALLEL`)
- Writes diagnostic report to `failures/` before any halt

### 4. `cw review` — Standalone Code Review

Runs the full reviewer→judge pipeline independently.

```bash
cw review 42                  # review PR #42
cw review --branch feat/foo   # review branch vs main
cw review 42 --skip-checks    # skip deterministic checks
```

### Orchestrators (Interactive IDE Use)

Every `cw` command delegates workflow logic to an orchestrator agent. You can use these same orchestrators directly in Claude Code or OpenCode for a human-in-the-loop version of the pipeline:

| Orchestrator | What it does | Script equivalent |
|---|---|---|
| `implementation-orchestrator` | Plan → implement (TDD) | `cw implement` (per issue) |
| `review-orchestrator` | Checks → code-reviewer → review-judge | `cw review` |
| `prd-orchestrator` | Critic → architect → integrator loop | `cw prd-qa` |
| `issue-creation-orchestrator` | Validate PRD → create issues | `cw create-issues` |
| `ci-fix-orchestrator` | Diagnose → fix → verify CI | CI fix step in `cw implement` |

The difference: scripts add automation glue (git worktrees, parallelism, retries, failure reports, merge). Orchestrators own the workflow logic and work identically in both modes.

#### Improving Review Consistency

LLM-based reviews are non-deterministic — the same diff can surface different findings each run. To improve consistency, add project-specific review rules to your `CLAUDE.md`:

```markdown
# Code Review Rules
- All API routes must use auth middleware
- No raw SQL — use the query builder
- React components must not call hooks conditionally
```

These rules constrain the reviewer to check specific invariants rather than freestyle, making results more repeatable across runs. The generic checklist (Logic, Security, Error Handling, Performance, Test Quality) in the `code-review` skill still applies alongside your project rules.

### 5. `cw evolve` — Pipeline Retrospective

Analyzes pipeline run history — failure reports, merged PRs, review findings, CI logs, and LEARNINGS.md — to identify recurring patterns. Generates concrete patches to agent/skill/template files and opens a PR against claude-workflow for review.

```bash
cw evolve    # run from any project that has pipeline data (failures/, merged PRs, etc.)
```

Requires at least one data source: `failures/issue-*.md`, `LEARNINGS.md`, merged PRs, or failed CI runs. Every proposed change needs 2+ independent data points — one failure is an anecdote, two is a pattern.

### UI Design with Stitch

The pipeline integrates with [Stitch](https://stitch.google.com/) for UI design reference. When a project has Stitch designs:

1. **DESIGN.md** — auto-generated by Stitch, placed in the project root. Contains the design system (colors, typography, components, spacing, do's/don'ts). This is the styling authority for all UI work.
2. **Stitch project ID** — specified in the PRD or issue. Used to fetch screen mockups.
3. **Screen HTML** — the planner discovers available screens via `list_screens` and maps them to components. The implementor fetches screen HTML via `get_screen` and matches it exactly.
4. **Missing screens** — when implementing a UI component with no existing screen, the implementor generates one via `generate_screen_from_text`, fetches the HTML, and implements to match.

Requires the Stitch MCP server to be configured in your Claude Code or OpenCode settings.

## CLI Commands

| Command | Description |
|---------|-------------|
| `cw setup` | Install `cw` to `~/.local/bin` (once per machine) |
| `cw sync` | Copy agents + skills to `~/.claude` (+ opencode if installed) |
| `cw init` | Bootstrap current project (`.claude/CLAUDE.md` + `hooks.json`) |
| `cw prd-qa` | Refine PRD via multi-agent loop |
| `cw create-issue "<desc>"` | Interactive QA → single GitHub issue |
| `cw create-issues` | Decompose PRD.md into GitHub issues |
| `cw implement` | Autonomous implementation pipeline |
| `cw review <PR#>` | Code review (reviewer → judge) |
| `cw evolve` | Pipeline retrospective → agent/skill improvements (PR) |

## Individual Agents

Any agent can be invoked directly:

```bash
# Claude Code
claude --agent implementor -p "implement feature X using TDD"
claude --agent ci-fixer -p "fix CI failure on branch feat/foo, run ID 12345"

# OpenCode
opencode run --agent implementor "implement feature X using TDD"
opencode run --agent ci-fixer "fix CI failure on branch feat/foo, run ID 12345"
```

## What's Included

```
bin/
  cw                    — CLI entrypoint

scripts/
  implement-issues.sh   — autonomous implementation loop
  create-issue.sh       — interactive single issue creator
  create-issues.sh      — PRD to GitHub issues
  prd-qa.sh             — multi-agent PRD refinement
  review.sh             — standalone code review (reviewer + judge)
  evolve.sh             — pipeline retrospective (analyze failures → patch agents)
  lib.sh                — shared utilities (run_agent, check_signal, extract_text)
  stream-filter.jq            — Claude stream output formatter
  stream-filter-opencode.jq   — OpenCode stream output formatter
  convert-agent-opencode.awk  — converts Claude agents to OpenCode format

agents/
  # Orchestrators (use as main agent in IDE — same workflow as scripts)
  implementation-orchestrator.md — plan → implement pipeline
  review-orchestrator.md         — checks → code-reviewer → review-judge
  prd-orchestrator.md            — critic → architect → integrator loop
  issue-creation-orchestrator.md — validate PRD → create issues
  ci-fix-orchestrator.md         — diagnose → fix → verify CI

  # Core agents (invoked by orchestrators)
  planner.md            — pre-implementation test sequencer (researches unfamiliar deps)
  implementor.md        — TDD feature builder
  code-reviewer.md      — structured checklist-driven reviewer
  review-judge.md       — validates review findings against actual code
  ci-fixer.md           — diagnoses and fixes CI failures
  issue-creator.md      — decomposes PRD into vertical-slice issues
  prd-integrator.md     — incorporates answers into PRD
  prd-critic.md         — reviews PRD for completeness
  prd-architect.md      — answers PRD questions using code context + library research

  # Standalone agents
  synthesizer.md        — post-merge learnings distiller
  retrospective.md      — pipeline retrospective analyzer
  single-issue-creator.md — interactive QA → single issue

skills/
  tdd/                  — TDD philosophy, test examples, mocking, refactoring, interface design
  code-review/          — structured review criteria, categories, confidence scoring, anti-patterns
  issue-template/       — shared issue format (used by both issue creators)
  prd-quality/          — PRD completeness criteria
  opensrc/              — fetch library source code for any language
  stitch/               — UI design reference via Stitch (DESIGN.md convention, screen fetching, generation)
  retrospective/        — pipeline retrospective analysis patterns + output format

templates/
  CLAUDE.md.global      — user-level agent instructions (TDD, vertical slicing)
  CLAUDE.md.project     — project-level template (parameterized)
  hooks.json            — CI reminder hook (fires after git push / gh pr create)
```

## Configuration

Environment variables for `cw implement`:

| Variable | Default | Description |
|----------|---------|-------------|
| `TEST_CMD` | `pnpm test` | Command to run tests |
| `CHECK_CMD` | `pnpm check` | Full CI check command |
| `INSTALL_CMD` | `pnpm install --frozen-lockfile` | Dependency install command |
| `CI_FIX_RETRIES` | `2` | Max ci-fixer attempts per CI failure |
| `REVIEW_MAX_CYCLES` | `2` | Max review→fix cycles before halt |
| `MAX_PARALLEL` | `1` | Max concurrent issue implementations (via git worktrees) |
| `CW_BACKEND` | `claude` | Agent backend: `claude` or `opencode` |
| `CW_MODEL` | *(default)* | Override model ID for agent invocations |
| `NO_COLOR` | *(unset)* | Disable colored output ([no-color.org](https://no-color.org)) |
| `CW_VERBOSE` | *(unset)* | Show full tool output (no truncation) |

## Stack Examples

The pipeline is stack-agnostic — just set the env vars for your toolchain.

```bash
# Elixir / Phoenix
TEST_CMD="mix test" CHECK_CMD="mix precommit" INSTALL_CMD="mix deps.get" cw implement

# TypeScript / Node
TEST_CMD="pnpm test" CHECK_CMD="pnpm check" INSTALL_CMD="pnpm install --frozen-lockfile" cw implement

# .NET / C#
TEST_CMD="dotnet test" CHECK_CMD="dotnet build --warnaserror && dotnet test" INSTALL_CMD="dotnet restore" cw implement

# Python
TEST_CMD="pytest" CHECK_CMD="ruff check . && mypy . && pytest" INSTALL_CMD="pip install -r requirements.txt" cw implement

# Go
TEST_CMD="go test ./..." CHECK_CMD="go vet ./... && staticcheck ./... && go test ./..." INSTALL_CMD="go mod download" cw implement
```

## Guardrails

The pipeline enforces quality at 5 layers:

1. **Pre-commit hook** — blocks commits to main, runs typecheck + lint
2. **Claude hook** (`.claude/hooks.json`) — reminds agent to watch CI after push
3. **CLAUDE.md rules** — agent reads before acting (branch workflow, TDD, regression prevention)
4. **Code review loop** — reviewer finds issues, judge validates with evidence, implementor fixes
5. **Bash script gates** — verifies PR creation, CI pass, review pass, and diagnostics on failure

## Troubleshooting

### Signals

Orchestrators emit structured signals that scripts and the IDE both understand:

| Signal | Meaning | Used by |
|--------|---------|---------|
| `<COMPLETE>` | Work finished successfully | prd-orchestrator |
| `<PASS>` | Review passed, no findings | review-orchestrator |
| `<HALT>` | Blocker encountered | All orchestrators |

`<HALT>` includes structured metadata:
```
<HALT>
REASON: ci-failed
RUN_ID: 12345
DETAILS: CI failed after 3 attempts on branch feat/issue-42.
```

In scripts, `<HALT>` triggers failure reports and exits. In the IDE, the orchestrator explains the blocker before halting.

### Common failure causes

**"tests failing on main"** — Pre-flight check failed. Run your `TEST_CMD` on main manually, fix, then re-run `cw implement`.

**"all issues in batch failed"** — Every issue in the batch failed. Check `failures/issue-N.md` for diagnostics (includes CI logs and review findings). Fix the root cause, then re-run.

**"unresolved dependencies"** — Remaining issues depend on failed/incomplete issues. Check issue dependencies on GitHub, resolve the blocker, then re-run.

**"agent-halted" / "implementor-blocked"** — Implementor hit a conflict with previous work. Check the draft PR it created for details.

### Recovering from failures

**Pipeline crashed mid-batch**: Re-run `cw implement`. It resumes automatically — already-merged issues are skipped, and issues with existing PRs resume from CI/review instead of re-implementing.

**CI keeps failing**: Check `failures/issue-N.md` for the last 100 lines of CI logs. Common fixes: missing env vars in CI, dependency version mismatches, flaky tests.

**Review not resolving**: Reviewer found issues the implementor couldn't fix within `REVIEW_MAX_CYCLES`. Check `failures/issue-N.md` for unresolved findings. Consider increasing `REVIEW_MAX_CYCLES` or fixing manually.

### Logs

| Log | Location | Purpose |
|-----|----------|---------|
| Real-time progress | `tail -f progress.log` | Timeline of all issue progress |
| Per-issue detail | `./logs/issue-N.log` | Full agent output (parallel mode only) |
| Failure reports | `failures/issue-N.md` | Diagnostics with CI logs and review findings |

## Output

The CLI uses colored output with Unicode symbols by default:

```
┌──────────────────────────────────────────┐
│ Batch: issues 1 2 3 (3 issue(s), 5 open) │
└──────────────────────────────────────────┘
● Pre-flight: running tests on main
[14:32:01] #1 Add user auth — planning
  ▸ Read  src/index.ts
  │ (42 lines)
  ▸ Bash  pnpm test
  │ PASS  src/auth.test.ts
✓ Done (end_turn, 45.2s, $0.23)
✓ #1 — merged (PR #12)
✗ #2 — FAILED: ci-failed-after-2-attempts
```

Disable colors with `NO_COLOR=1`. Show full tool output with `CW_VERBOSE=1`.

## OpenCode Backend

The pipeline supports [OpenCode](https://opencode.ai) as an alternative backend. Set `CW_BACKEND=opencode` for all commands:

```bash
cw sync                            # auto-detects opencode and syncs agents
CW_BACKEND=opencode cw prd-qa
CW_BACKEND=opencode cw implement
```

The conversion (`convert-agent-opencode.awk`) handles differences between the two:

| Claude Code | OpenCode |
|-------------|----------|
| `skills:` in frontmatter (pre-loaded) | Skills auto-discovered; injected as `## Skills` load instruction |
| `tools:` as array | Stripped (incompatible record format; all tools enabled by default) |
| `model: inherit` | Stripped (OpenCode uses its configured default) |
| `color: cyan` (named) | Converted to hex (`#00FFFF`) |
| No mode concept | Script-called agents get `mode: all`; others get `mode: subagent` |

## Prerequisites

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) or [OpenCode](https://opencode.ai)
- [GitHub CLI](https://cli.github.com/) (`gh`)
- `jq`

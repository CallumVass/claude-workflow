#!/usr/bin/env bash
set -euo pipefail

COMPLETE_FLAG="<COMPLETE>"
HALT_FLAG="<HALT>"
PASS_FLAG="<PASS>"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(pwd)"

source "$SCRIPT_DIR/lib.sh"

# Pin progress log to repo root so worktrees share it
PROGRESS_LOG="$REPO_ROOT/progress.log"

# --- Auto-detect project commands ---
# Env var overrides always win. Otherwise, detect from project files.
auto_detect_commands() {
  local test_cmd="" check_cmd="" install_cmd=""

  if [ -f "mix.exs" ]; then
    test_cmd="mix test"
    check_cmd="mix format --check-formatted && mix credo && mix test"
    install_cmd="mix deps.get"
  elif [ -f "Cargo.toml" ]; then
    test_cmd="cargo test"
    check_cmd="cargo clippy -- -D warnings && cargo test"
    install_cmd=":"
  elif [ -f "go.mod" ]; then
    test_cmd="go test ./..."
    check_cmd="go vet ./... && go test ./..."
    install_cmd="go mod download"
  elif compgen -G "*.sln" >/dev/null 2>&1 || compgen -G "*.csproj" >/dev/null 2>&1; then
    test_cmd="dotnet test"
    check_cmd="dotnet build --warnaserror && dotnet test"
    install_cmd="dotnet restore"
  elif [ -f "pyproject.toml" ] || [ -f "requirements.txt" ]; then
    test_cmd="pytest"
    check_cmd="ruff check . && pytest"
    install_cmd="pip install -e '.[dev]' 2>/dev/null || pip install -r requirements.txt 2>/dev/null || :"
  elif [ -f "package.json" ]; then
    local pm="npm"
    if [ -f "pnpm-lock.yaml" ]; then pm="pnpm"
    elif [ -f "yarn.lock" ]; then pm="yarn"
    elif [ -f "bun.lockb" ]; then pm="bun"
    fi
    test_cmd="$pm test"
    check_cmd="$pm run check"
    case "$pm" in
      pnpm) install_cmd="pnpm install --frozen-lockfile" ;;
      yarn) install_cmd="yarn install --frozen-lockfile" ;;
      bun)  install_cmd="bun install --frozen-lockfile" ;;
      npm)  install_cmd="npm ci" ;;
    esac
  fi

  TEST_CMD="${TEST_CMD:-$test_cmd}"
  CHECK_CMD="${CHECK_CMD:-$check_cmd}"
  INSTALL_CMD="${INSTALL_CMD:-$install_cmd}"
}

auto_detect_commands

# --- Configuration ---
DEFAULT_RETRIES="${DEFAULT_RETRIES:-3}"
CI_FIX_RETRIES="${CI_FIX_RETRIES:-$DEFAULT_RETRIES}"
MAX_PARALLEL="${MAX_PARALLEL:-1}"
MERGE_RETRIES="${MERGE_RETRIES:-$DEFAULT_RETRIES}"

cleanup() {
  trap - INT TERM EXIT
  echo "" >&2
  warn "Shutting down"
  # Clean up worktrees
  for wt in /tmp/cw-worktree-*; do
    [ -d "$wt" ] && git worktree remove --force "$wt" 2>/dev/null || true
  done
  kill -- -$$ 2>/dev/null
  exit 0
}
trap cleanup INT TERM EXIT

# Pull main — fetch + rebase explicitly to avoid ambiguity with multiple branches
safe_pull() {
  # Stash any dirty state left by agents before pulling
  if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
    warn "Stashing uncommitted changes before pull"
    git stash --include-untracked -q
  fi
  git fetch origin main
  if ! REBASE_OUT=$(git rebase origin/main 2>&1); then
    # Check for untracked file conflicts
    CONFLICTING=$(echo "$REBASE_OUT" | sed -n 's/^\t\+//p')
    if [ -n "$CONFLICTING" ] && echo "$REBASE_OUT" | grep -q "untracked working tree files would be overwritten"; then
      warn "Removing untracked files that conflict with incoming changes:"
      echo "$CONFLICTING" | while read -r f; do warn "  $f"; rm -f "$f"; done
      git rebase origin/main
    else
      err "git pull failed: $REBASE_OUT"; return 1
    fi
  fi
}

# --- Failure capture ---
capture_failure() {
  local issue_num="$1"
  local branch="$2"
  local reason="$3"
  local extra="${4:-}"

  mkdir -p "$REPO_ROOT/failures"
  local report="$REPO_ROOT/failures/issue-${issue_num}.md"

  {
    echo "# Failure Report: Issue #${issue_num}"
    echo ""
    echo "- **Branch**: ${branch}"
    echo "- **Reason**: ${reason}"
    echo "- **Timestamp**: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo ""
    echo "## Changed Files"
    git diff --name-only main..."${branch}" 2>/dev/null || echo "(branch not found)"
    echo ""
    if [ -n "$extra" ]; then
      echo "$extra"
      echo ""
    fi
  } > "$report"

  echo "--- Failure report written to $report ---"
}

# --- Dependency graph ---
# Outputs issue numbers whose dependencies are all in the completed set.
get_ready_issues() {
  local all_issues="$1"
  local completed="$2"

  echo "$all_issues" | jq -r --arg completed "$completed" '
    ($completed | split(" ") | map(select(. != "")) | map(tonumber)) as $done |
    .[] |
    .number as $num |
    # Extract Dependencies section content
    (.body | split("## Dependencies") |
      if length > 1 then .[1] | split("\n## ") | .[0] else "" end
    ) as $dep_section |
    # Extract referenced issue numbers (#N)
    ([$dep_section | scan("#([0-9]+)") | .[0] | tonumber] | unique) as $deps |
    # Ready if no deps or all deps satisfied
    if ($deps | length == 0) or
       ([$deps[] | select(. as $d | $done | index($d) | not)] | length == 0)
    then $num
    else empty
    end
  '
}

# --- Implement a single issue ---
# Runs plan → implement → CI → review in the given work directory.
# Writes "success <PR_NUM>" or "failure <reason>" to status file.
implement_single_issue() {
  local issue_num="$1"
  local issue_title="$2"
  local issue_body="$3"
  local work_dir="$4"
  local branch="feat/issue-$issue_num"
  local status_file="/tmp/cw-issue-status-$issue_num"

  (
    cd "$work_dir"

    # Idempotency: check for existing PR (resume after restart)
    PR_NUM=$(gh pr list --head "$branch" --json number --jq '.[0].number' 2>/dev/null || echo "")

    if [ -n "$PR_NUM" ]; then
      progress "#$issue_num — PR #$PR_NUM exists, resuming from CI check"
      eval "$INSTALL_CMD" || { echo "failure install-failed" > "$status_file"; exit 1; }
    else
      eval "$INSTALL_CMD" || { echo "failure install-failed" > "$status_file"; exit 1; }

      # Learnings context
      LEARNINGS_CONTEXT=""
      if [ -f "LEARNINGS.md" ]; then
        LEARNINGS_CONTEXT="

LEARNINGS (patterns and conventions from previous issues):
$(cat LEARNINGS.md)"
      fi

      # --- Implementation orchestrator (plan → implement) ---
      progress "#$issue_num $issue_title — planning & implementing"

      ORCH_PROMPT="Implement issue #$issue_num: $issue_title

$issue_body
$LEARNINGS_CONTEXT
WORKFLOW:
1. Create branch: $branch
2. Read the codebase to understand current state.
3. Implement using TDD following the plan. One test at a time: write failing test -> minimal implementation -> test passes -> next test.
4. After all behaviors pass, look for refactoring opportunities. Run tests after each refactor.
5. Run \`$CHECK_CMD\`. Fix any failures.
6. Commit, push, and create a PR with 'Closes #$issue_num' in the PR body.
7. Watch CI with: gh run list --branch $branch --limit 1 --json databaseId --jq '.[0].databaseId' then gh run watch <id> --exit-status
8. If CI fails, read logs with gh run view <id> --log-failed, fix, push, and watch again.

CONSTRAINTS:
- Do NOT modify or delete tests from previous issues.
- Do NOT change public interfaces from previous issues unless this issue requires it.
- Do NOT merge the PR. Only create it — merging is handled externally.
- If you encounter a conflict with previous work that you cannot resolve, create the PR as draft and output exactly: $HALT_FLAG
- IMPORTANT: If the planner surfaces unresolved questions, resolve them yourself using reasonable defaults and proceed. Do NOT stop and wait — there is no human in the loop. Use your best judgment based on the issue context and codebase."

      TMPFILE=$(run_agent "implementation-orchestrator" "$ORCH_PROMPT")
      if check_signal "$TMPFILE" "$HALT_FLAG"; then
        rm -f "$TMPFILE"
        echo "failure agent-halted" > "$status_file"
        exit 1
      fi
      rm -f "$TMPFILE"

      # Verify PR was created
      progress "#$issue_num — checking for PR"
      PR_NUM=$(gh pr list --head "$branch" --json number --jq '.[0].number')
      if [ -z "$PR_NUM" ]; then
        PR_NUM=$(gh pr list --head "$branch" --state all --json number --jq '.[0].number')
      fi
      if [ -z "$PR_NUM" ]; then
        echo "failure no-pr-created" > "$status_file"
        exit 1
      fi
    fi

    # --- Refactorer (cross-codebase deduplication) ---
    progress "#$issue_num — refactoring pass"
    git checkout "$branch" 2>/dev/null || true

    REFACTOR_PROMPT="You are on branch $branch. A new feature was just implemented for issue #$issue_num: $issue_title.

Review the code added in this branch (use git diff main...$branch) and compare with the rest of the codebase.

RULES:
- Only refactor if there's a clear win (2+ duplicated blocks, or a pattern used 3+ times).
- Run \`$CHECK_CMD\` after any refactoring.
- Commit and push changes if you made any.
- If no refactoring is needed, just say so and exit."

    REFACTOR_TMPFILE=$(run_agent "refactorer" "$REFACTOR_PROMPT")
    rm -f "$REFACTOR_TMPFILE"

    # --- CI + code review in parallel ---
    progress "#$issue_num — PR #$PR_NUM created, CI + review in parallel"
    git checkout "$branch" 2>/dev/null || true

    # Start CI watch in background
    CI_STATUS_FILE="/tmp/cw-ci-status-$issue_num"
    rm -f "$CI_STATUS_FILE"
    (
      CI_FIX_PROMPT="Fix CI failures on branch $branch for issue #$issue_num: $issue_title.

Issue context:
$issue_body

Max retries: $CI_FIX_RETRIES"

      CI_TMPFILE=$(run_agent "ci-fix-orchestrator" "$CI_FIX_PROMPT")

      if check_signal "$CI_TMPFILE" "$HALT_FLAG"; then
        RUN_ID=$(extract_halt_field "$CI_TMPFILE" "RUN_ID")
        echo "failure $RUN_ID" > "$CI_STATUS_FILE"
      else
        RUN_ID=$(gh run list --branch "$branch" --limit 1 --json databaseId --jq '.[0].databaseId' 2>/dev/null || echo "")
        echo "success $RUN_ID" > "$CI_STATUS_FILE"
      fi
      rm -f "$CI_TMPFILE"
    ) &
    CI_PID=$!

    # Single-pass review (no re-review cycles)
    progress "#$issue_num — reviewing"
    FINDINGS=$("$SCRIPT_DIR/review.sh" "$PR_NUM" --skip-checks) || {
      progress "#$issue_num — fixing review findings"
      git checkout "$branch" 2>/dev/null || true

      FIX_PROMPT="You are on branch $branch. Fix the following code review findings:

$FINDINGS

RULES:
- Fix only the cited issues. Do not refactor or improve unrelated code.
- Run \`$CHECK_CMD\` after fixes.
- Commit and push the fixes."

      FIX_TMPFILE=$(run_agent "implementor" "$FIX_PROMPT")
      rm -f "$FIX_TMPFILE"
    }

    # Wait for CI to finish (may already be done)
    wait "$CI_PID" 2>/dev/null || true

    if [ ! -f "$CI_STATUS_FILE" ] || grep -q "^failure" "$CI_STATUS_FILE"; then
      RUN_ID=$(awk '{print $2}' "$CI_STATUS_FILE" 2>/dev/null || echo "")
      progress "${S_FAIL} #$issue_num — CI failed after $CI_FIX_RETRIES attempts"
      CI_LOGS=""
      [ -n "$RUN_ID" ] && CI_LOGS=$(gh run view "$RUN_ID" --log-failed 2>/dev/null | tail -100 || echo "(logs unavailable)")
      capture_failure "$issue_num" "$branch" "ci-failed-after-$CI_FIX_RETRIES-attempts" \
        "## CI Logs (last 100 lines)
\`\`\`
${CI_LOGS:-(logs unavailable)}
\`\`\`"
      rm -f "$CI_STATUS_FILE"
      echo "failure ci-failed-after-$CI_FIX_RETRIES-attempts" > "$status_file"
      exit 1
    fi

    rm -f "$CI_STATUS_FILE"
    progress "#$issue_num — CI + review passed"

    progress "#$issue_num — ready to merge (PR #$PR_NUM)"
    echo "success $PR_NUM" > "$status_file"
  )
}

# =============================================================================
# MAIN LOOP
# =============================================================================

# Seed completed set with already-closed issues (from previous runs)
COMPLETED=$(gh issue list --state closed --label "auto-generated" --json number --jq '.[].number | tostring' | tr '\n' ' ')

while true; do
  # Start from clean main
  git checkout main
  safe_pull
  eval "$INSTALL_CMD"

  info "Pre-flight: running tests on main"
  eval "$TEST_CMD" || { err "tests failing on main — fix before running pipeline"; exit 1; }

  # Seed LEARNINGS.md if it doesn't exist (one-time, first run only)
  # LEARNINGS.md is local-only (gitignored) to avoid divergence with parallel worktrees
  if [ ! -f "LEARNINGS.md" ]; then
    info "Seeding LEARNINGS.md from existing codebase"
    SEED_PROMPT="This is a new project with no LEARNINGS.md yet. Explore the codebase and create an initial LEARNINGS.md capturing existing conventions, patterns, and architectural decisions that would help a developer working on their first issue.

Keep it under 50 lines. Organize by topic. Only include non-obvious things."

    SEED_TMPFILE=$(run_agent "synthesizer" "$SEED_PROMPT")
    rm -f "$SEED_TMPFILE"
  fi

  # Fetch open issues
  ALL_ISSUES=$(gh issue list --state open --label "auto-generated" --json number,title,body --jq 'sort_by(.number)')
  TOTAL=$(echo "$ALL_ISSUES" | jq 'length')

  if [ "$TOTAL" -eq 0 ]; then
    echo "" >&2
    ok "$COMPLETE_FLAG — all issues implemented"
    exit 0
  fi

  # Find issues whose dependencies are satisfied
  READY_NUMS=()
  while IFS= read -r num; do
    [ -n "$num" ] && READY_NUMS+=("$num")
  done < <(get_ready_issues "$ALL_ISSUES" "$COMPLETED")

  if [ ${#READY_NUMS[@]} -eq 0 ]; then
    err "$TOTAL issues remain but all have unresolved dependencies"
    exit 1
  fi

  # Cap batch size
  BATCH=("${READY_NUMS[@]:0:$MAX_PARALLEL}")
  BATCH_SIZE=${#BATCH[@]}

  header "Batch: issues ${BATCH[*]} ($BATCH_SIZE issue(s), $TOTAL open)"

  if [ "$BATCH_SIZE" -eq 1 ]; then
    # Single issue — run in place
    NUM="${BATCH[0]}"
    TITLE=$(echo "$ALL_ISSUES" | jq -r --argjson n "$NUM" '.[] | select(.number == $n) | .title')
    BODY=$(echo "$ALL_ISSUES" | jq -r --argjson n "$NUM" '.[] | select(.number == $n) | .body')
    implement_single_issue "$NUM" "$TITLE" "$BODY" "$REPO_ROOT"
  else
    # Parallel — use git worktrees
    exec 3>&2
    export CW_TERMINAL_FD=3
    mkdir -p "$REPO_ROOT/logs"
    progress "parallel: $BATCH_SIZE workers — monitor: tail -f $PROGRESS_LOG"
    WORKTREES=()
    PIDS=()
    for NUM in "${BATCH[@]}"; do
      WT="/tmp/cw-worktree-$NUM"
      # Clean up stale worktree from previous run if it exists
      if [ -d "$WT" ]; then
        git worktree remove --force "$WT" 2>/dev/null || rm -rf "$WT"
        git worktree prune 2>/dev/null
      fi
      git worktree add --detach "$WT" main 2>/dev/null
      # Copy non-git config (.claude settings) if present
      [ -d ".claude" ] && cp -r .claude "$WT/.claude" 2>/dev/null || true
      WORKTREES+=("$WT")

      TITLE=$(echo "$ALL_ISSUES" | jq -r --argjson n "$NUM" '.[] | select(.number == $n) | .title')
      BODY=$(echo "$ALL_ISSUES" | jq -r --argjson n "$NUM" '.[] | select(.number == $n) | .body')

      implement_single_issue "$NUM" "$TITLE" "$BODY" "$WT" \
        > "$REPO_ROOT/logs/issue-$NUM.log" 2>&1 &
      PIDS+=($!)
    done

    # Wait for all in batch
    for pid in "${PIDS[@]}"; do
      wait "$pid" || true
    done

    # Clean up worktrees
    for wt in "${WORKTREES[@]}"; do
      git worktree remove --force "$wt" 2>/dev/null || true
    done
  fi

  # --- Process results: merge successful, capture failures ---
  ANY_SUCCESS=false
  MERGED_IN_BATCH=""
  for NUM in "${BATCH[@]}"; do
    STATUS_FILE="/tmp/cw-issue-status-$NUM"
    BRANCH="feat/issue-$NUM"
    TITLE=$(echo "$ALL_ISSUES" | jq -r --argjson n "$NUM" '.[] | select(.number == $n) | .title')
    BODY=$(echo "$ALL_ISSUES" | jq -r --argjson n "$NUM" '.[] | select(.number == $n) | .body')

    if [ -f "$STATUS_FILE" ] && grep -q "^success" "$STATUS_FILE"; then
      PR_NUM=$(awk '{print $2}' "$STATUS_FILE")

      # Capture diff before merge (stays available after squash)
      PR_DIFF=$(gh pr diff "$PR_NUM" 2>/dev/null || echo "(diff unavailable)")

      # Merge (with conflict resolution retry)
      merge_ok=false
      merge_blocked_by_ci=false
      for merge_attempt in $(seq 1 "$MERGE_RETRIES"); do
        git checkout main && safe_pull

        # Client-side CI gate (repo has no branch protection to enforce this)
        PR_CHECKS=$(gh pr checks "$PR_NUM" 2>/dev/null || echo "")
        if echo "$PR_CHECKS" | grep -qE '\bfail'; then
          progress "#$NUM — CI checks failing, cannot merge"
          merge_blocked_by_ci=true
          break
        fi

        if gh pr merge "$PR_NUM" --squash --delete-branch; then
          merge_ok=true
          break
        fi

        progress "#$NUM — merge conflict (attempt $merge_attempt/$MERGE_RETRIES), rebasing onto main"

        git checkout "$BRANCH" 2>/dev/null || git checkout -b "$BRANCH" "origin/$BRANCH"
        git fetch origin main

        if git rebase origin/main 2>/dev/null; then
          # Clean rebase — just push and retry
          git push --force-with-lease
        else
          # Conflicts require agent resolution
          CONFLICT_FILES=$(git diff --name-only --diff-filter=U 2>/dev/null || echo "(unknown)")

          RESOLVE_PROMPT="You are on branch $BRANCH which has merge conflicts after rebasing onto main.

ISSUE #$NUM: $TITLE

$BODY

RECENTLY MERGED INTO MAIN (these changes caused the conflict):
${MERGED_IN_BATCH:-(none — this is the first merge attempt in this batch)}

CONFLICTING FILES:
$CONFLICT_FILES

INSTRUCTIONS:
1. Read each conflicting file and resolve the merge conflicts.
2. Integrate BOTH this PR's changes AND the changes on main — do not drop either side.
3. After resolving each file: git add <file>
4. Run: git rebase --continue
5. Run \`$CHECK_CMD\` to verify everything works.
6. Push with: git push --force-with-lease
7. If the conflicts are too complex to resolve safely, output: $HALT_FLAG"

          RESOLVE_TMPFILE=$(run_agent "implementor" "$RESOLVE_PROMPT")
          if check_signal "$RESOLVE_TMPFILE" "$HALT_FLAG"; then
            rm -f "$RESOLVE_TMPFILE"
            git rebase --abort 2>/dev/null || true
            break
          fi
          rm -f "$RESOLVE_TMPFILE"
        fi

        # Wait for CI after rebase (if repo has CI)
        REBASE_RUN_ID=$(gh run list --branch "$BRANCH" --limit 1 --json databaseId --jq '.[0].databaseId' 2>/dev/null || echo "")
        if [ -n "$REBASE_RUN_ID" ]; then
          gh run watch "$REBASE_RUN_ID" --exit-status 2>/dev/null || {
            progress "#$NUM — CI failed after conflict resolution"
            continue
          }
        fi
      done

      if [ "$merge_ok" = false ]; then
        if [ "$merge_blocked_by_ci" = true ]; then
          capture_failure "$NUM" "$BRANCH" "ci-checks-failing" \
            "## Context
CI checks are failing — merge blocked.
$(gh pr checks "$PR_NUM" 2>/dev/null || echo "(checks unavailable)")"
          progress "${S_FAIL} #$NUM — CI checks failing, merge blocked"
        else
          capture_failure "$NUM" "$BRANCH" "merge-conflict-unresolved" \
            "## Context
Merge failed after $MERGE_RETRIES rebase attempt(s).
${MERGED_IN_BATCH:+PRs merged earlier in batch: $MERGED_IN_BATCH}"
          progress "${S_FAIL} #$NUM — merge conflict unresolved"
        fi
        git checkout main 2>/dev/null || true
        rm -f "$STATUS_FILE"
        continue
      fi

      progress "${S_OK} #$NUM — merged (PR #$PR_NUM)"
      MERGED_IN_BATCH="${MERGED_IN_BATCH}
- PR #$PR_NUM (issue #$NUM): $TITLE"

      # Synthesizer — update LEARNINGS.md
      SYNTH_PROMPT="A PR was just merged for issue #$NUM: $TITLE

PR diff:
$PR_DIFF

Update LEARNINGS.md with any useful patterns, conventions, or gotchas from this change.
If LEARNINGS.md exists, read it first and integrate — don't duplicate.
Keep the file under 100 lines, organized by topic."

      SYNTH_TMPFILE=$(run_agent "synthesizer" "$SYNTH_PROMPT")
      rm -f "$SYNTH_TMPFILE"

      # LEARNINGS.md is local-only (not committed) — no git add needed

      COMPLETED="$COMPLETED $NUM"
      ANY_SUCCESS=true
    else
      REASON=$(sed 's/^failure //' "$STATUS_FILE" 2>/dev/null || echo "unknown")
      # Only write failure report if implement_single_issue didn't already write a richer one
      if [ ! -f "$REPO_ROOT/failures/issue-${NUM}.md" ]; then
        capture_failure "$NUM" "$BRANCH" "$REASON"
      fi
      progress "${S_FAIL} #$NUM — FAILED: $REASON"
    fi
    rm -f "$STATUS_FILE"
  done

  if [ "$ANY_SUCCESS" = false ]; then
    echo "" >&2
    err "all issues in batch failed — check failures/ for diagnostics"
    exit 1
  fi
done

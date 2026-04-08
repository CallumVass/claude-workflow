---
name: code-review
description: Structured, checklist-driven code review with confidence scoring and evidence requirements. Designed for deterministic-first review (lint/types/tests run before LLM review) and precision over recall.
---

# Code Review Skill

Structured, checklist-driven code review with confidence scoring and evidence requirements. Designed for deterministic-first review (lint/types/tests run before LLM review) and precision over recall.

## Review Order

Always review in this order. Check each category completely before moving to the next.

### 1. Logic & Correctness
- Business logic errors (wrong conditions, missing branches)
- Control flow bugs (off-by-one, infinite loops, unreachable code)
- Wrong return values or incorrect transformations
- State management bugs (stale state, missing updates, race conditions)
- Dead wiring: new modules/classes only imported in test files, never called from production code. If a class is created but no production code path instantiates or calls it, the feature is not wired — flag as critical.

### 2. Security
- Injection vulnerabilities (SQL, XSS, command injection)
- Auth/authz bypass (missing checks, privilege escalation)
- Secrets exposure (hardcoded keys, tokens in logs)
- Unsafe deserialization or eval usage

### 3. Error Handling
- Unhandled null/undefined that will crash at runtime
- Missing error paths that silently fail
- Swallowed exceptions hiding real failures
- Error messages leaking internal details

### 4. Performance
- N+1 queries or unbounded loops over data
- Missing pagination on unbounded result sets
- Memory leaks (event listeners, subscriptions not cleaned up)
- Unnecessary re-renders or recomputation in hot paths

### 5. Test Quality
- TDD compliance: tests verify behavior through public interfaces, not implementation
- Boundary coverage: mocked boundaries have corresponding integration/contract tests
- Mock fidelity: mocks encode correct assumptions about external systems
- Missing tests for new behavior paths

## Evidence Requirements

Every finding MUST include:
- **File path and line number(s)** — exact location
- **Code snippet** — the problematic code, quoted verbatim
- **Explanation** — why this is wrong (not "could be better", but "this WILL cause X")
- **Suggested fix** — concrete, not vague

Findings without evidence are invalid and will be rejected by the review judge.

## Confidence Scoring

Rate each finding 0-100:
- **< 50**: Do not report. Not worth reviewer time.
- **50-84**: Do not report. Below threshold.
- **85-94**: Report. High confidence this is a real issue.
- **95-100**: Report. Certain. Evidence directly confirms.

**Threshold: only report findings with confidence >= 85.**

## Severity Levels

Rate each finding:

- **critical**: Will cause a bug, security vulnerability, data loss, or crash in production. Must be fixed before merge.
- **major**: Significant logic error, missing error handling that will affect users, or performance issue under normal load. Must be fixed.
- **minor**: Code quality issue, edge case gap, suboptimal pattern, or test improvement. Fix and merge.
- **nit**: Style preference, naming suggestion, or trivial improvement. Fix at author's discretion — does not block merge.

Guidelines:
- Security findings are always `critical`.
- Test Quality findings are `minor` unless they mask a real bug.

## FINDINGS Output Format

```markdown
## Review: [scope description]

### Finding 1
- **Confidence**: [85-100]
- **Severity**: [critical | major | minor | nit]
- **Category**: [Logic | Security | Error Handling | Performance | Test Quality]
- **File**: path/to/file.ts:42
- **Code**: `the problematic code`
- **Issue**: [clear explanation of what's wrong and what will happen]
- **Fix**: [concrete suggestion]

### Finding 2
...

## Summary
- Total findings: N
- Categories: [breakdown]
- Overall assessment: [one sentence]
```

If no findings meet the confidence threshold, output:

```markdown
## Review: [scope description]

No issues found above confidence threshold (85).

## Summary
- Reviewed: [what was checked]
- Overall assessment: Code meets standards.
```

## Anti-Patterns — Do NOT Flag

These are explicitly out of scope. Flagging them wastes everyone's time:

- **Naming/formatting** — linters handle this, not reviewers
- **Style preferences** — subjective choices (early return vs. else, ternary vs. if)
- **Theoretical edge cases** — "what if X is null?" when X is guaranteed non-null by the system
- **Architectural suggestions** — "you should restructure this as..." is out of scope for PR review
- **"You could also..." suggestions** — if it's not broken, don't suggest alternatives
- **Over-engineering suggestions** — "add error handling for..." when the error can't happen
- **Pre-existing issues** — problems that existed before this PR are not this PR's responsibility
- **Missing features** — "you should also add..." unless it's in the acceptance criteria
- **Documentation gaps** — unless the code is genuinely incomprehensible


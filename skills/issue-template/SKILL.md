---
name: issue-template
description: Standard format and rules for creating GitHub issues for autonomous agent implementation.
---

# Issue Template Skill

Standard format and rules for creating GitHub issues for autonomous agent implementation.

## Issue Template

Every issue MUST follow this exact format:

```
Title: <short descriptive title>

Body:
## Context
<Provide enough detail that an agent can implement without reading any external docs. Be generous — include full protocol details, message formats, edge cases, and technical reference sections that apply.>

## Acceptance Criteria
<Bulleted checklist describing what the USER sees/experiences. Not implementation details.>
- [ ] User does X and sees Y
- [ ] ...

## Test Plan
<Specific tests that must pass. Include at least one integration test per issue.>
- [ ] Integration: <describe end-to-end test>
- [ ] Unit: <describe key unit tests>

## Implementation Hints
<Concrete guidance: files to create/modify, key APIs, rough approach. Keep it actionable.>

## Dependencies
<Which previous issues must be complete first, if any>
```

## Creating Issues

- Use `gh issue create` to create each issue.
- Add a label "auto-generated" to each issue (create the label first if it does not exist).
- After creating each issue, note its number so you can reference it in subsequent issues' Dependencies sections.

## Rules

- The Context section is CRITICAL. Include full relevant detail inline — do NOT say "see PRD.md" or "see the codebase". The agent implementing the issue should have everything it needs in the issue body itself.
- Acceptance criteria must describe user-observable behavior, not code structure.
- Each vertical slice must cross all necessary layers to deliver a working flow.

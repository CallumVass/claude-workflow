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
<Provide enough detail for an agent to implement THIS slice. Include: user-observable behavior, relevant data model (conceptual), API contracts, technology choices, edge cases. Do NOT include: type definitions, internal state shapes, config blocks, file layout, or framework-specific patterns. Keep under ~60 lines.>

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

- The Context section is CRITICAL — the agent works from this alone. Include behavioral requirements, data model concepts, API contracts, and edge cases inline. Do NOT say "see PRD.md". But also do NOT paste raw PRD sections — extract and distill only what THIS slice needs.
- Acceptance criteria must describe user-observable behavior, not code structure.
- Each vertical slice must cross all necessary layers to deliver a working flow.

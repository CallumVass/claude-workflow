---
name: prd-quality
description: PRD completeness and quality criteria for evaluating product requirements documents.
---

This skill defines the quality criteria for evaluating whether a PRD is complete and implementation-ready.

## Completeness Criteria

A PRD is ready for implementation when it satisfies ALL of the following:

### 1. Problem Statement & Goals
- Clear description of the problem being solved
- Measurable success criteria or goals
- Why this matters (user pain, business value)

### 2. User Stories / Use Cases
- Clear actors (who does what)
- Each story follows a complete flow from trigger to outcome
- Covers primary happy paths and key alternative paths

### 3. Functional Requirements
- Detailed enough that a developer can implement without further clarification
- Covers inputs, outputs, and transformations for each feature
- API contracts (endpoints, request/response shapes) where applicable
- Data model (entities, relationships, constraints) where applicable

### 4. Non-Functional Requirements
- Performance expectations (latency, throughput)
- Security considerations (auth model, data protection, input validation)
- Scalability constraints or targets
- Reliability/availability requirements if relevant

### 5. Edge Cases & Error Handling
- Each flow identifies what can go wrong
- Error states have defined user-facing behavior
- Boundary conditions are addressed (empty states, limits, concurrent access)

### 6. Scope Boundaries
- Explicit "in scope" and "out of scope" sections
- No ambiguity about what will and won't be built

### 7. Vertical-Slice Readiness
- Requirements are structured around user-observable flows, not technical layers
- Each feature can be decomposed into end-to-end slices
- No requirement depends on a fully-built layer that doesn't yet exist

### 8. Implementation Clarity
- Enough technical detail that a developer can start without asking questions
- Technology choices specified where they matter
- Key library/dependency choices include brief rationale (not just named)
- When a dependency targets a specific version or API generation, the PRD includes enough detail for an implementor to install and use the correct version (e.g., install command, version tag, dist-tag, or link to migration guide)
- If the required API differs from the library's stable/well-known version, the PRD calls out what changed and what NOT to use
- Integration points with existing systems documented

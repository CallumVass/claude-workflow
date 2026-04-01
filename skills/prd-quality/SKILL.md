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
- API contracts as prose: "POST /api/rooms creates a room and returns a room code" — NOT code blocks with language-specific type definitions
- Data model as concepts: "a room tracks voters, their votes, and the current poll" — NOT language-level interface/type definitions

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

### 6a. Phase Structure (for multi-phase projects)
- If the project has prior work, the PRD should contain a `## Done` section summarizing completed work
- The `## Next` section describes what's being built now
- `## Done` is treated as accepted context — not re-evaluated for completeness
- Only `## Next` (or content outside `## Done`) is evaluated against these criteria

### 7. Vertical-Slice Readiness
- Requirements are structured around user-observable flows, not technical layers
- Each feature can be decomposed into end-to-end slices
- No requirement depends on a fully-built layer that doesn't yet exist

### 8. Implementation Clarity
- Enough technical detail to know WHAT to build and which technologies to use — not HOW to structure code
- Technology choices specified where they matter, with brief rationale
- Key library/dependency choices include version or API generation details when the default/latest differs from what's needed
- Integration points with existing systems documented
- Do NOT include: language-level type/interface definitions, internal state shapes or class hierarchies, file/directory layout prescriptions, framework-specific implementation patterns (hook usage, middleware chains, alarm mechanics), exact config file contents from tool-specific config files, or specific hex colors/pixel values

### 9. Specification Minimalism
- PRD describes behavior (what the system does), not implementation (how code is structured)
- ZERO code blocks allowed in the PRD. No language-specific code, structured config dumps, or pseudocode. All requirements expressed as prose
- "Swap test": if a detail would change when swapping to an equivalent library/framework but the behavior stays the same, it's implementation detail — remove it
- Technology choices name the tool and justify why — they do not prescribe usage patterns
- Data models describe entities and relationships conceptually, not as language-level types
- API contracts define endpoints and response descriptions in prose, not code blocks with type definitions
- Target ~150-200 lines for the entire PRD. If longer, it almost certainly contains implementation detail masquerading as requirements
- A PRD with complete behavioral requirements at 150 lines is BETTER than one with implementation detail at 300 lines

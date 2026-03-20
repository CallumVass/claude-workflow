# PRD: Task Board

## Problem Statement

Teams need a lightweight task board to track work items across statuses. Existing solutions (Jira, Linear) are powerful but heavyweight for small teams or side projects. We need a minimal, self-hosted task board with real-time updates.

## Goals

1. Provide a simple board with customizable columns (e.g., Todo, In Progress, Done)
2. Allow creating, editing, and moving tasks between columns
3. Support real-time updates across browser tabs/users
4. Deploy as a single binary/container with no external dependencies beyond a database

## User Stories

### US-1: View the board

As a user, I can see all columns with their tasks, ordered by position within each column.

### US-2: Create a task

As a user, I can create a task with a title and optional description. It appears at the bottom of the first column.

### US-3: Move a task

As a user, I can drag a task to a different column (or reorder within a column). The new position persists on refresh.

### US-4: Edit a task

As a user, I can click a task to edit its title and description inline.

### US-5: Delete a task

As a user, I can delete a task. A confirmation prompt appears before deletion.

### US-6: Real-time sync

As a user, when another user creates/moves/edits/deletes a task, I see the change without refreshing.

## Functional Requirements

- Board has 1+ columns, each with a name and display order
- Tasks belong to a column and have: id, title, description (optional), position, created_at
- Moving a task updates its column and position; other tasks in affected columns reorder accordingly
- WebSocket (or SSE) pushes board mutations to all connected clients
- Default columns on first run: "Todo", "In Progress", "Done"

## Non-Functional Requirements

- Page load < 1s on localhost
- Supports 10 concurrent users without degradation
- Database: SQLite (file-based, zero config)
- No authentication required (single-team use)

## Edge Cases & Error Handling

- Moving a task to the same position is a no-op
- Creating a task with an empty title shows a validation error
- If WebSocket disconnects, client reconnects automatically and fetches full board state
- Concurrent moves to the same position: last-write-wins, broadcast corrected state

## Scope Boundaries

**In scope**: board CRUD, drag-and-drop, real-time sync, single board

**Out of scope**: multiple boards, user accounts, labels/tags, due dates, search, mobile app

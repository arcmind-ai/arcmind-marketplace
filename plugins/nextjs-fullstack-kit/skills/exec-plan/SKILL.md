---
name: exec-plan
description: Manage execution plans as first-class versioned artifacts. Create, update, and complete plans with progress logs and decision records.
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Agent
argument-hint: <create|status|complete|list> [description or plan name]
---

# Execution Plan Management

Action: **$ARGUMENTS**

## Commands

### `create <description>`

1. Generate a slug from the description (e.g., "Add user onboarding flow" → `add-user-onboarding-flow`)
2. Create `docs/exec-plans/active/{slug}.md` from the template below
3. Fill in Goal and Context from the description
4. Break down the work into concrete tasks (read relevant code first)
5. Add entry to `docs/PLANS.md` under "Now" section with link to the plan
6. Commit: `docs: create exec plan — {description}`

### `status [plan-name]`

1. If plan-name provided, read that specific plan from `docs/exec-plans/active/`
2. If not provided, list all active plans and ask which one to update
3. For the selected plan:
   - Check `git log --oneline` for PRs that relate to plan tasks
   - Update task statuses (pending → in-progress → done)
   - Increment agent run counts
   - Add entries to Progress Log with PR links
   - Update the plan's Status field if all tasks are done
4. Commit: `docs: update exec plan status — {plan-name}`

### `complete [plan-name]`

1. Read the active plan
2. Verify all tasks are checked off
3. If uncompleted tasks remain, ask whether to:
   - Mark them as won't-do with rationale
   - Move them to tech-debt-tracker
4. Move file from `docs/exec-plans/active/` to `docs/exec-plans/completed/`
5. Update `docs/PLANS.md`:
   - Remove from "Now" / "Next"
   - Add to "Completed" with link and completion date
6. Commit: `docs: complete exec plan — {plan-name}`

### `list`

1. Read all files in `docs/exec-plans/active/`
2. For each plan, extract: title, status, owner, created date, task progress
3. Display summary table:
```
| Plan | Status | Owner | Progress | Created |
|------|--------|-------|----------|---------|
| add-user-onboarding | active | agent | 3/7 tasks | 2026-03-01 |
```
4. Also show completed plans count from `docs/exec-plans/completed/`

## Exec Plan Template

When creating a new plan, use this structure:

```markdown
# Exec Plan: [Title]

| Field | Value |
|-------|-------|
| **Status** | draft |
| **Owner** | [engineer or agent] |
| **Created** | [YYYY-MM-DD] |
| **Target** | [YYYY-MM-DD or "no deadline"] |
| **Autonomy** | assisted / semi-auto / full-auto |

## Goal

[1-2 sentences: what does success look like?]

## Context & Constraints

[Why this approach? What alternatives were considered? What are the risks?]

## Tasks

- [ ] **Task 1**: [description]
  - Status: pending
  - Agent runs: 0
  - PR: —
  - Notes:
- [ ] **Task 2**: [description]
  - Status: pending
  - Agent runs: 0
  - PR: —
  - Notes:

## Decision Log

| Date | Decision | Rationale | Reversible? |
|------|----------|-----------|-------------|
| | | | |

## Progress Log

| Date | What changed | PR | Agent/Human |
|------|-------------|-----|-------------|
| | | | |

## Dependencies

- [ ] [External dependency or blocker]

## Rollback Plan

[How to undo if things go wrong]

## Definition of Done

- [ ] All tasks completed or explicitly deferred
- [ ] Tests passing
- [ ] Agent review approved
- [ ] Documentation updated
- [ ] No regressions in quality score
```

### `run [plan-name]`

Execute an active plan autonomously using the `task-driver` agent:

1. If plan-name provided, use that plan. Otherwise list active plans and ask.
2. Delegate to the `task-driver` agent, which will:
   - Pick the next pending task
   - Classify it (bug/feature/migration/refactor/docs/cleanup)
   - Execute using the right skill (`/auto-fix`, `/implement`, `/db-migrate`, `/doc-gardening`, `/gc-sweep`)
   - Validate after each task (tests, linters, logs)
   - Update the plan's progress log
   - Loop until all tasks are done or blocked
3. On completion, `task-driver` runs `/gc-sweep scan`, creates one PR, and moves the plan to `completed/`

Autonomy level from the plan's metadata controls merge behavior:
- `assisted` → pauses for human review after each PR
- `semi-auto` → runs all tasks, requests human review at the end
- `full-auto` → runs all tasks, auto-merges if CI passes

## Integration with other skills

- When `/auto-fix` or `/implement` completes a task, it updates the exec plan's Progress Log.
- When `/gc-sweep` runs, it verifies active plans aren't stale (no progress in >7 days) and flags them.

## Agent collaboration

- `task-driver` agent orchestrates plan execution — delegates to `bug-detective`, `db-architect`, `code-reviewer`, and `quality-guard` based on task type.
- `quality-guard` agent runs between tasks to catch regressions.
- `code-reviewer` agent reviews every PR before merge.

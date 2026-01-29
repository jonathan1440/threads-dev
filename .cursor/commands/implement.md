# Feature Implementation

You are implementing a task from an approved plan.

## Pre-Implementation

1. Confirm which feature you're implementing (same `[feature-name]` as the plan/spec; use the slug from `docs/specs/[feature-name]/` if it exists).
2. Load the current plan: docs/specs/[feature-name]/plan.md
3. Identify the next unstarted task (respecting dependencies)
4. Confirm which task you're implementing

## Implementation Protocol

For each task:

### 1. Announce
````
IMPLEMENTING: Task [N]: [Name]
Dependencies satisfied: [Yes/list what's done]
Files to touch: [list]
````

### 2. Implement
- Follow existing codebase patterns (reference CLAUDE.md)
- Write tests alongside implementation, not after
- Keep changes focused on this task only

### 3. Self-Check Before Review
````
PRE-REVIEW CHECKLIST:
- [ ] Tests written and passing
- [ ] Linter passing
- [ ] Changes limited to stated files
- [ ] No unrelated changes snuck in
- [ ] Error cases handled
````

### 4. Update Plan
Mark task status in plan.md:
````markdown
### Task N: [Name]
**Status**: Complete ✓
**Actual Files Modified**: [list]
**Notes**: [Any deviations from plan]
````

### 5. Checkpoint Verification

If this task completes a checkpoint, pause and do broader verification:
````
CHECKPOINT: [Checkpoint Name]

Verifying:
- [ ] [Checkpoint-specific verification 1]
- [ ] [Checkpoint-specific verification 2]

Results:
[Document what you verified and how]
````

## Discovering New Tasks

If implementation reveals a needed task not in the plan:
````
DISCOVERED TASK:
Description: [what's needed]
Why: [why this wasn't in the original plan]
Suggested insertion point: [after Task N]
Blocking: [Yes/No - is current task blocked?]

Awaiting approval to update plan.
````

Do not implement discovered tasks without plan update and approval.

When all tasks for this feature are complete, suggest running `/review` before closing.
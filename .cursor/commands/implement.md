# Feature Implementation

You are implementing a task from an approved plan.

## Pre-Implementation

1. Confirm which feature you're implementing (same `[feature-name]` as the spec; use the slug from `.cursor/specs/[feature-name]/` if it exists).
2. Load the current tasks: `.cursor/specs/[feature-name]/tasks.md` (and optionally `design.md` for architecture context).
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
- Follow existing codebase patterns (reference CLAUDE.md and `.cursor/foundation/` if it exists)
- Write tests alongside implementation, not after
- Keep changes focused on this task only
- If implementation diverges from design (`.cursor/specs/[feature-name]/design.md`), document the as-built decision in design.md (e.g. "Deviations" or "As-built") or in the task Notes below so the spec stays coupled to the code

### 3. Self-Check Before Review
````
PRE-REVIEW CHECKLIST:
- [ ] Tests written and passing
- [ ] Linter passing
- [ ] Changes limited to stated files
- [ ] No unrelated changes snuck in
- [ ] Error cases handled
````

### 4. Update Tasks
Mark task status in `.cursor/specs/[feature-name]/tasks.md`:
````markdown
### Task N: [Name]
**Status**: Complete ✓
**Actual Files Modified**: [list]
**Notes**: [Any deviations from design or plan]
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

Awaiting approval to update tasks.md.
````

Do not implement discovered tasks without updating `.cursor/specs/[feature-name]/tasks.md` and getting approval.

When all tasks for this feature are complete, suggest running `/review` before closing.
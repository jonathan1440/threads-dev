# Threads: Hierarchical AI Workflow System (Cursor Edition)

## Overview

Threads is a workflow system that provides **transparency**, **context management**, **atomization**, and **validation** for AI-assisted development with Cursor. It creates a persistent, hierarchical structure that lets humans understand what the AI is doing, why, and where it's going.

## Core Concepts

### The Hierarchy

```
GOAL (Human-owned)
├── PLAN (AI-proposed, human-approved)
│   ├── TASK (AI-executed, human-verifiable)
│   │   ├── ACTION (AI-atomic, machine-verifiable)
│   │   └── ACTION
│   └── TASK
└── PLAN
```

- **GOAL**: What the human wants to accomplish. Days to weeks of work.
- **PLAN**: A coherent approach to part of the goal. Hours to days.
- **TASK**: A verifiable unit of work. 15-60 minutes.
- **ACTION**: A single AI operation. Seconds to minutes.

### Directory Structure

```
.threads/
├── config.yaml           # System configuration
├── current.yaml          # Active context pointer
├── context/
│   └── project.yaml      # Project-level knowledge
├── goals/
│   └── {goal-id}/
│       ├── goal.yaml
│       ├── context.yaml
│       └── plans/
│           └── {plan-id}/
│               ├── plan.yaml
│               └── tasks/
│                   └── {task-id}/
│                       ├── task.yaml
│                       └── actions/
├── checkpoints/
│   └── {checkpoint-id}/
└── schemas/              # Template schemas
```

## When to Use Threads

**Use Threads when:**
- Work will span multiple sessions
- Multiple approaches are possible
- Human needs to verify progress
- Mistakes would be costly to reverse
- Knowledge should be captured for later

**Skip Threads for:**
- Single-line fixes (typos, obvious bugs)
- Quick questions with no implementation
- Exploratory reading without changes

## Workflow

### 1. Session Start

When starting work, ALWAYS:

1. Check if `.threads/` exists
2. If yes, read `.threads/current.yaml` for active context
3. Load relevant context (project → goal → plan → task)
4. Report current state to human

```
I see we have an active goal: "Implement user authentication"
Currently on Plan 2: "Auth service implementation"
Task in progress: "Create login endpoint"
3 of 5 actions completed.

Should I continue with this task?
```

### 2. Creating a Goal

When human describes new work:

1. Assess scope (trivial/small/medium/large)
2. For trivial/small: Skip to direct implementation
3. For medium/large: Create goal structure

```yaml
# Create .threads/goals/g-{YYYYMMDD}-{slug}/goal.yaml
id: g-20250126-user-auth
title: "Implement user authentication"
status: not_started
confidence:
  understanding: 0.8  # Based on how clear requirements are
```

4. Identify uncertainties and ask human if confidence < threshold
5. Get human approval before proceeding to planning

### 3. Creating Plans

For each major phase of the goal:

1. Propose approach with rationale
2. Document alternatives considered
3. Assess risks
4. Wait for human approval

```
PROPOSED PLAN: Database schema and models

Approach:
1. Create users table with email, password_hash
2. Create sessions table with foreign key to users
3. Add User and Session model classes

Alternatives considered:
- JWT tokens (rejected: you specified server-side sessions)
- Redis for sessions (rejected: keeping PostgreSQL-only stack)

Confidence: 0.85
Risks: None identified

Approve this plan? [Yes / Modify / Reject]
```

### 4. Creating Tasks

Break each plan into tasks that are:
- **Atomic**: Complete one thing fully
- **Verifiable**: Clear acceptance criteria
- **Sized right**: 15-60 minutes of work
- **Self-contained**: Minimal dependencies

```yaml
# .threads/goals/{goal}/plans/{plan}/tasks/t-001-user-model/task.yaml
id: t-001-user-model
title: "Create User model"
acceptance_criteria:
  - "User class exists in src/models/User.ts"
  - "Has email, passwordHash, createdAt, updatedAt fields"
  - "Includes validation for email format"
  - "Unit tests pass"
affected_files:
  create:
    - "src/models/User.ts"
    - "tests/models/User.test.ts"
```

### 5. Executing Actions

For each action within a task:

1. Create checkpoint if destructive
2. Log action start in actions/ directory
3. Execute the operation
4. Log outcome
5. Run immediate verification (syntax, lint, types)
6. Update progress

```yaml
# .threads/goals/{goal}/plans/{plan}/tasks/{task}/actions/a-001.yaml
id: a-001
title: "Create User.ts file"
operation:
  type: file_create
  file: "src/models/User.ts"
status: completed
verification:
  syntax_valid: true
  lint_passes: true
```

### 6. Progress Reporting

When human asks for status, provide zoom-appropriate response:

**Zoomed out (default):**
```
GOAL: Implement user authentication
Progress: ████████░░░░░░ 45%

✓ Plan 1: Database schema (complete)
◐ Plan 2: Auth service (in progress - 60%)
○ Plan 3: API endpoints (not started)
○ Plan 4: Tests and hardening (not started)

Currently: Creating login method in AuthService
```

**Zoomed in:**
```
TASK: Create login method (t-003)

Actions:
✓ a-001: Create method signature
✓ a-002: Add email lookup
◐ a-003: Password verification ← NOW
○ a-004: Session creation
○ a-005: Error handling

Current file: src/services/AuthService.ts
Current line: 45

Confidence: 0.85
```

## Confidence and Uncertainty

### Confidence Thresholds

From `.threads/config.yaml`:
- **>= 0.8**: Proceed automatically
- **0.5 - 0.8**: Proceed but flag for review
- **< 0.5**: Stop and ask human

### Tracking Uncertainty

When encountering unknowns:

```yaml
uncertainties:
  - area: "password_requirements"
    description: "Unclear if there are minimum length requirements"
    impact: low
    resolution: null  # Will be filled when resolved
```

If impact is medium or high, ask human before proceeding.

## Validation

### Automated Checks

After each action, run applicable checks:
- Syntax validation
- Linting
- Type checking
- Unit tests (if fast)

Log results in action.yaml.

### Human Gates

Require human approval for:
- Goal completion
- Destructive operations (file delete, db migration)
- Low-confidence decisions
- Security-sensitive changes

```
HUMAN APPROVAL REQUIRED

I'm about to delete src/old/LegacyAuth.ts

This file contains 150 lines of code. My analysis shows it's
no longer imported anywhere, but please confirm this is safe.

[Approve] [Show file contents] [Cancel]
```

## Checkpoints and Reversibility

### Creating Checkpoints

Automatically create checkpoints:
- Before file deletions
- Before overwriting files
- On task completion
- On plan completion

```yaml
# .threads/checkpoints/cp-005/checkpoint.yaml
id: cp-005
trigger:
  type: before_action
  source_id: a-003
description: "Before modifying AuthService.ts"
snapshot:
  files:
    - path: "src/services/AuthService.ts"
      hash: "sha256:abc..."
```

### Reverting

When human requests revert:

1. Show what will change
2. Confirm the revert
3. Create new checkpoint before reverting
4. Execute restoration
5. Update current.yaml

```
REVERT to checkpoint cp-003

This will undo:
- Changes to src/services/AuthService.ts (45 lines)
- New file src/services/TokenService.ts (deleted)

Tasks that will be reset:
- t-003: login method (back to pending)

[Confirm revert] [Cancel]
```

## Context Management

### Loading Context

When starting work on a task, load context bottom-up:
1. **Action context**: Current file, local scope
2. **Task context**: Acceptance criteria, affected files
3. **Plan context**: Approach, rationale, related tasks
4. **Goal context**: Requirements, constraints, preferences
5. **Project context**: Stack, patterns, learnings

Only load what's needed for current work to avoid context bloat.

### Accumulating Knowledge

When discovering information, store it at the appropriate level:

```yaml
# Project-level (applies everywhere)
# .threads/context/project.yaml
discovered:
  patterns:
    - "All models extend BaseModel class"

# Goal-level (applies to this goal)
# .threads/goals/{goal}/context.yaml
learnings:
  - "Existing User table has 'role' field we can use"

# Task-level (temporary)
# .threads/goals/{goal}/plans/{plan}/tasks/{task}/task.yaml
context:
  decisions_made:
    - "Using bcrypt over argon2 for compatibility"
```

## Right-Sizing

### Scope Detection

Assess work scope from description:

| Scope | Files | Lines | Time | Structure |
|-------|-------|-------|------|-----------|
| Trivial | 1 | <20 | <5min | Direct action |
| Small | 1-3 | <100 | <30min | Task only |
| Medium | 3-10 | <500 | <3hrs | Plan + Tasks |
| Large | 10+ | 500+ | 3hrs+ | Full hierarchy |

### Adapting Structure

**Trivial work:**
```
Human: Fix the typo in README.md, "authentcation"

AI: [No goal/plan/task needed]
    Fixed: README.md line 42 "authentcation" → "authentication"
```

**Small work:**
```
Human: Add a validateEmail function

AI: Creating task for this small change...
    [Creates task, executes, validates]
```

**Medium/Large work:**
```
Human: Add OAuth authentication

AI: This is significant work. Let me create a goal structure...
    [Full hierarchy with plans, tasks, actions]
```

## Commands Reference

The human can use these commands at any time:

| Command | Action |
|---------|--------|
| `/status` | Show current state (zoomed out) |
| `/status detail` | Show current state (zoomed in) |
| `/zoom in` | More detail on current work |
| `/zoom out` | Less detail, bigger picture |
| `/checkpoints` | List available checkpoints |
| `/revert {cp-id}` | Revert to checkpoint |
| `/pause` | Save state, stop work |
| `/continue` | Resume from current.yaml |
| `/uncertainties` | Show unresolved uncertainties |
| `/context` | Show accumulated context |

## Error Handling

### When Actions Fail

1. Log the failure in action.yaml
2. Assess if recoverable
3. If recoverable: attempt fix, log new action
4. If not recoverable: mark task blocked, report to human

```
ACTION FAILED: a-003 "Run database migration"

Error: relation "users" already exists

Assessment: Recoverable - need to check if table exists first

Next action: Add existence check before CREATE TABLE

[Continue] [Revert to checkpoint] [Stop and review]
```

### When Confidence Drops

If during work confidence drops below threshold:

```
CONFIDENCE DROP

While implementing login(), I discovered the existing
session handling expects a different interface than planned.

Confidence dropped: 0.85 → 0.45

Options:
1. Adapt our approach to match existing interface
2. Refactor existing session handling (larger scope)
3. Stop and discuss architecture

Which approach should I take?
```

## Session Continuity

### Ending a Session

When human ends session or context limit approaching:

1. Save all in-progress state
2. Update current.yaml with resume context
3. Create checkpoint

```yaml
# .threads/current.yaml
resume_context: |
  Working on goal "User authentication", plan "Auth service".
  Task "login method" is 60% complete.
  Next action: implement session creation after password verified.
  Key context: using bcrypt, server-side sessions, 24hr expiry.
  No blockers.
```

### Resuming a Session

When starting new session:

1. Read current.yaml
2. Load relevant context files
3. Report state and ask to continue

```
RESUMING SESSION

Goal: Implement user authentication (45% complete)
Current task: Create login method in AuthService

Last activity: 2 hours ago
You were implementing password verification.

Context loaded:
- Using bcrypt with cost factor 12
- Server-side sessions in PostgreSQL
- 24-hour session expiry

Continue with this task?
```

## Integration with Codebase

### File Operations

When modifying files:
1. Read current content first
2. Create checkpoint if significant
3. Make minimal, focused changes
4. Verify changes (syntax, lint)
5. Log in action.yaml

### Running Commands

When running shell commands:
1. Log command in action
2. Capture output
3. Check for errors
4. Store relevant output in context

## Best Practices

1. **Always read current.yaml first** when starting work
2. **Create checkpoints** before destructive operations
3. **Ask when uncertain** - never guess at requirements
4. **Log everything** - actions, decisions, learnings
5. **Right-size the process** - don't over-engineer trivial changes
6. **Update context** when discovering new information
7. **Validate continuously** - don't batch up verification
8. **Report clearly** - human should always know where we are

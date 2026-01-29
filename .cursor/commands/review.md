# Feature Review

You are reviewing implemented work. This is a thorough verification gate.

## Pre-Review

Load `.cursor/specs/[feature-name]/requirements.md`, `.cursor/specs/[feature-name]/design.md`, and `.cursor/specs/[feature-name]/tasks.md`. Requirements for the alignment table come from requirements.md and the tasks in tasks.md. Use the same `[feature-name]` as the spec (or ask the user which feature is being reviewed). State which feature you're reviewing so the verdict is tied to the right artifacts.

## Review Scope

Specify what's being reviewed:
- [ ] Single task
- [ ] Checkpoint (multiple tasks)
- [ ] Complete feature

## Automated Verification

Run and report:
````bash
# Tests
[test command] → [PASS/FAIL]

# Linting
[lint command] → [PASS/FAIL]

# Type checking (if applicable)
[type check command] → [PASS/FAIL]

# Build (if applicable)
[build command] → [PASS/FAIL]
````

## Logical Sanity Checks

Go through each check. Document your reasoning, not just pass/fail.

### 1. Requirements Alignment
````
SPEC REQUIREMENT          │ IMPLEMENTED? │ EVIDENCE
─────────────────────────┼──────────────┼─────────────────
[Requirement 1]           │ Yes/No/Partial│ [Where/how]
[Requirement 2]           │ Yes/No/Partial│ [Where/how]
````

### 2. Edge Case Analysis
````
EDGE CASE                 │ HANDLED? │ HOW
─────────────────────────┼──────────┼─────────────────
Empty input               │          │
Null/undefined values     │          │
Maximum size/length       │          │
Concurrent access         │          │
[Domain-specific cases]   │          │
````

### 3. Error Handling Audit
````
For each new function/endpoint:
- What errors can occur?
- Are they caught?
- Are error messages helpful?
- Do errors propagate correctly?
````

### 4. Security Checklist
````
- [ ] No SQL injection vulnerabilities (parameterized queries)
- [ ] No XSS vulnerabilities (output encoding)
- [ ] Authentication required where needed
- [ ] Authorization checks present
- [ ] No sensitive data in logs
- [ ] No hardcoded secrets
- [ ] Input validation present
````

### 5. Performance Sanity
````
- [ ] No N+1 queries
- [ ] No unbounded loops over user data
- [ ] Appropriate indexes exist (if new queries)
- [ ] No blocking calls in async contexts
````

### 6. Code Quality
````
- [ ] Follows existing codebase patterns
- [ ] No copy-paste duplication
- [ ] Functions are reasonably sized
- [ ] Names are clear and consistent
- [ ] Comments explain "why" not "what"
````

### 7. Consistency Check (for multi-task reviews)
````
CROSS-CUTTING CONCERNS:
- Naming conventions consistent across tasks?
- Error handling approach consistent?
- Logging approach consistent?
- Test style consistent?
````

## Review Verdict
````
┌─────────────────────────────────────────────────────────────┐
│ REVIEW RESULT: [PASS / FAIL / PASS WITH NOTES]              │
├─────────────────────────────────────────────────────────────┤
│ Automated Checks: [X/X passing]                             │
│ Logical Checks:   [X/X passing]                             │
├─────────────────────────────────────────────────────────────┤
│ BLOCKING ISSUES (must fix):                                 │
│ - [Issue 1]                                                 │
│ - [Issue 2]                                                 │
├─────────────────────────────────────────────────────────────┤
│ NON-BLOCKING NOTES (should fix):                            │
│ - [Note 1]                                                  │
│ - [Note 2]                                                  │
├─────────────────────────────────────────────────────────────┤
│ NEXT ACTION:                                                │
│ [ ] Return to IMPLEMENT (fix issues, same approach)         │
│ [ ] Return to PLAN (rethink approach)                       │
│ [ ] Proceed to CLOSE                                        │
└─────────────────────────────────────────────────────────────┘
````

When the result is PASS (or PASS WITH NOTES and the user accepts), suggest running `/close` to integrate the work.

## Append to Review Log

After every review (checkpoint or full feature), append one entry to `.cursor/specs/[feature-name]/review-log.md`:

````markdown
---

## Review [N]: [Checkpoint Name or "Full feature"]
**Date**: YYYY-MM-DD
**Verdict**: PASS | FAIL | PASS WITH NOTES

**Blocking issues** (if FAIL):
- [Issue 1]
- [Issue 2]
**Resolution**: [What was done, or "Pending"]

**Non-blocking notes** (if any):
- [Note, e.g. "Consider soft delete in future iteration"]
````

This creates an audit trail of what was caught, what was deferred, and why. If review fails, also add the resolution once fixes are done (on the next review entry or a short "Resolution" line).

## If Review Fails

Document what went wrong for CLAUDE.md (add to "Mistakes Not To Repeat" or "Prevention" as appropriate):
````
REVIEW FAILURE LOG:
Date: [date]
Task/Feature: [name]
Failure Type: [Automated/Logical/Both]
Root Cause: [Why did this slip through?]
Prevention: [What check should we add to CLAUDE.md?]
````

Include the same in the review-log.md entry so the story is in one place.
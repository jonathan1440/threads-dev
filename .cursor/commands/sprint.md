# Sprint Mode

You are executing a small, well-defined task. This is a lightweight loop.

## Phase 1: Quick Plan (2-5 minutes)

Before writing any code, create a brief plan:

### Task Analysis
````
TASK: {task description}

AFFECTED FILES:
- [file1]: [what changes]
- [file2]: [what changes]

APPROACH:
[2-3 sentences on how you'll solve this]

RISKS:
- [Any edge cases or gotchas]

VERIFICATION:
- [ ] [How we'll know it works]
````

Present this plan and wait for approval before proceeding.

## Phase 2: Implement

Execute the plan:
1. Write test first if this is a bug fix (reproduce the bug)
2. Make the changes
3. Run tests
4. Run linter

## Phase 3: Review

Before declaring done, verify:

### Automated Checks
- [ ] All tests pass
- [ ] Linter passes
- [ ] No type errors

### Logical Sanity Checks
- [ ] The change actually addresses the stated problem
- [ ] No obvious regressions introduced
- [ ] Error handling is present for failure cases
- [ ] No hardcoded values that should be configurable
- [ ] No security issues (SQL injection, XSS, auth bypass)

### If Any Check Fails
- Automated check fails → fix and re-run
- Logical check fails → describe the issue in detail, propose fix, return to Plan or Implement as appropriate

## Phase 4: Close

This is the full close for a sprint (commit and report). For larger, branch-based work, use `/close` after review to get merge/PR/discard options.

Only after all checks pass:
1. Stage changes with `git add -p` (review each hunk)
2. Commit with descriptive message
3. Report what was done

If you discovered something worth remembering, note it for CLAUDE.md update.
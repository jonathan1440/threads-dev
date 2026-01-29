# /close

Complete development work by verifying tests, presenting integration options, and cleaning up.

## Step 1: Verify Tests

**Before presenting options, tests must pass:**

```bash
npm test / cargo test / pytest / go test ./...
```

**If tests fail:**
```
Tests failing (N failures). Must fix before completing:
[Show failures]

Cannot proceed with merge/PR until tests pass.
```

Stop. Do not proceed to Step 2.

**If tests pass:** Continue.

## Step 2: Determine Base Branch

```bash
git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null
```

Or ask: "This branch split from main — is that correct?"

## Step 3: Present Options

Present exactly these 4 options:

```
Implementation complete. Tests passing. What would you like to do?

1. Merge back to <base-branch> locally
2. Push and create a Pull Request
3. Keep the branch as-is (I'll handle it later)
4. Discard this work

Which option?
```

## Step 4: Execute Choice

### Option 1: Merge Locally

```bash
git checkout <base-branch>
git pull
git merge <feature-branch>
<run tests again>
# If tests pass:
git branch -d <feature-branch>
```

Then: Cleanup worktree (Step 5) + Update CLAUDE.md (Step 6)

### Option 2: Push and Create PR

```bash
git push -u origin <feature-branch>

gh pr create --title "<title>" --body "$(cat <<'EOF'
## Summary
<2-3 bullets of what changed>

## Test Plan
- [ ] <verification steps>
EOF
)"
```

Then: Keep worktree + Update CLAUDE.md (Step 6)

### Option 3: Keep As-Is

Report: "Keeping branch `<name>`. Worktree preserved at `<path>`."

Skip cleanup. Skip CLAUDE.md update (work not finished).

### Option 4: Discard

**Confirm first:**
```
This will permanently delete:
- Branch <name>
- All commits: <commit-list>
- Worktree at <path>

Type 'discard' to confirm.
```

Wait for exact confirmation.

```bash
git checkout <base-branch>
git branch -D <feature-branch>
```

Then: Cleanup worktree (Step 5)

## Step 5: Cleanup Worktree

**For Options 1, 2, 4 only:**

```bash
git worktree list | grep $(git branch --show-current)
# If in worktree:
git worktree remove <worktree-path>
```

**For Option 3:** Keep worktree.

## Step 6: Update CLAUDE.md

If anything was learned during this work:

```markdown
## Mistakes Not To Repeat
- [date]: [What happened, what to do instead]

## Patterns We Use
- [New pattern discovered]
```

## Step 7: Final Report

```
┌─────────────────────────────────────────────────────────────┐
│ CLOSED: [Task/Feature Name]                                 │
├─────────────────────────────────────────────────────────────┤
│ Outcome: [Merged / PR Created / Kept / Discarded]           │
│ Duration: [time from plan to close]                         │
│ Plan→Implement→Review cycles: [N]                           │
├─────────────────────────────────────────────────────────────┤
│ Tests: Passing                                              │
│ CLAUDE.md updated: [Yes/No]                                 │
└─────────────────────────────────────────────────────────────┘
```

## Quick Reference

| Option | Merge | Push | Keep Worktree | Cleanup Branch |
|--------|-------|------|---------------|----------------|
| 1. Merge locally | ✓ | - | - | ✓ |
| 2. Create PR | - | ✓ | ✓ | - |
| 3. Keep as-is | - | - | ✓ | - |
| 4. Discard | - | - | - | ✓ (force) |

## Never

- Proceed with failing tests
- Merge without verifying tests on result
- Delete work without typed confirmation
- Force-push without explicit request

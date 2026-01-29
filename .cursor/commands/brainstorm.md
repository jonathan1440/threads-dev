# /brainstorm

Start here before `/plan`. This command initiates an iterative conversation to fully understand the problem before specifying a solution.

## Purpose

Most failed implementations trace back to underspecified problems. This phase ensures you and the AI are solving the same problem before any code is written.

## Process

### Step 1: Problem Framing

Ask the user questions **one at a time** to understand:

1. What problem are we actually solving? (Not what feature — what pain point)
2. Who experiences this problem and when?
3. What does success look like? How will we know it's working?
4. What constraints exist? (Time, tech, dependencies, must-not-break)

Do not proceed until you have clear answers to all four.

### Step 2: Scope Boundaries

Explicitly establish:

- What is IN scope for this work
- What is explicitly OUT of scope
- What might be future work (but not now)

Get user confirmation on scope before continuing.

### Step 3: Explore Approaches

Present 2-3 possible approaches with tradeoffs:

```
APPROACH A: [Name]
How it works: [2-3 sentences]
Pros: [bullets]
Cons: [bullets]
Best if: [when to choose this]

APPROACH B: [Name]
...
```

Ask: "Which approach fits best, or should we combine elements?"

### Step 4: Edge Cases and Risks

Walk through:
- What happens when [common edge case]?
- What if [dependency] fails?
- What's the rollback plan?
- What could go wrong that we haven't discussed?

### Step 5: Validate Understanding

Present a 200-300 word summary of:
- The problem we're solving
- The chosen approach
- Key constraints and scope boundaries
- Success criteria

Ask: "Does this capture it correctly? Anything missing or wrong?"

## Output

Use a short, consistent slug for this feature (e.g. from the topic: `user-notifications`, `auth-refactor`). That slug is `[feature-name]` for all paths under `docs/specs/`. If the user hasn't named it, propose one and confirm before saving.

Once validated, save to `docs/specs/[feature-name]/brainstorm.md`

This becomes input for `/plan`.

## Example

**User:** `/brainstorm` We need to add notifications

**Assistant:**

Let me understand this better before we plan anything.

**What problem are we solving?**

When you say "notifications" — what's the pain point today? Are users missing important events? Is there a specific trigger that should notify someone but doesn't? Help me understand what's broken or missing.

*[Waits for response]*

---

**Note:** This phase typically takes 10-20 minutes of back-and-forth. That investment prevents hours of building the wrong thing.

# Thread System Institutional Memory

## What This Is

This file captures patterns, decisions, and mistakes for this repo. Cursor rules (`.cursor/rules/*.mdc`) refer back here, and commands (`.cursor/commands/*.md`) assume this exists.

## Tech Stack

Describe or update as the project evolves:
- Language: [fill in]
- Framework: [fill in]
- Database: [fill in]

## Patterns We Use

Document stable patterns you want future work to follow, for example:
- Plan → Implement → Review loop for all non-trivial work.
- Feature specs live under `docs/specs/[feature-name]`.
- Slash commands (`/sprint`, `/plan`, `/implement`, `/review`, `/close`) correspond to `.cursor/commands` docs.

Update this section as you discover patterns that work well.

## Hard Rules

Non-negotiables, to be refined over time:
- Do not merge or commit failing tests.
- Keep changes scoped to a single logical task or feature.
- Document why significant design decisions were made (in specs or here).

## Mistakes Not To Repeat

Use this when something slips through review or causes pain:
- [date]: [What happened, what to do instead]

## Current Phase

Start here and update over time:
- Foundation: wiring Cursor-aware workflow and documentation.


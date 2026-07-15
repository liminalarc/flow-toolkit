---
name: flow-review
description: Structured, multi-lens audit of a project — docs, UX, marketing, or product. Reads current state, finds gaps, proposes concrete fixes. Invoke as /flow-review [--docs|--ux|--marketing|--product]; runs all four lenses when none is named.
---

# flow-review

Structured audit from multiple lenses. Reads current state, identifies gaps, proposes concrete improvements. Run all lenses or narrow to one.

Usage:
- `/flow-review` — all lenses
- `/flow-review --docs` — documentation only
- `/flow-review --ux` — UX audit only
- `/flow-review --marketing` — marketing/positioning only
- `/flow-review --product` — product critique only

## Instructions

**Start fresh.** Read only from the project files — `CLAUDE.md`, `SPECIFICATIONS.md`, `README.md`, `MARKETING.md`. Do not reference or build on prior conversation context. Treat this as a new session regardless of what preceded it.

**Fan out to one reviewer per lens.** Each lens is audited by an independent, read-only `flow-reviewer` sub-agent that loads only its own rubric — so the main thread stays lean and lenses run in parallel. Lens → rubric:

| Lens | Flag | Rubric (passed to the reviewer) |
|---|---|---|
| Docs | `--docs` | `reference/docs.md` |
| UX | `--ux` | `reference/ux.md` |
| Marketing | `--marketing` | `reference/marketing.md` |
| Product | `--product` | `reference/product.md` |

**Dispatch.** For each requested lens, launch a `flow-reviewer` agent with: the lens name, the path to its rubric (`reference/<lens>.md` within this skill's directory), and the project root. When more than one lens runs, launch them **in parallel** — a single message with multiple agent calls. Each reviewer returns prioritized findings for its lens and never edits.

**Synthesize (main thread).**
- Single lens → present that lens's prioritized findings.
- All lenses (`/flow-review`, no flag) → run all four reviewers, then produce a **cross-lens summary** of the highest-priority items across docs, UX, marketing, and product.

**Applying fixes.** Reviewers only report. When a finding warrants an edit (e.g. a doc fix), you — the main thread — propose it and **confirm before making significant changes**. The review never edits silently.

## Rules
- Read before writing — understand current state before proposing changes.
- Confirm before making significant doc changes.
- Actionable findings only — specific suggested fixes, not just observations.

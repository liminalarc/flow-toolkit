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

**Progressive disclosure — load only the lens(es) you run.** Each lens's rubric lives under `reference/`. Read a rubric *only when you run that lens*, so a single-lens invocation never loads the other three:

| Lens | Flag | Rubric |
|---|---|---|
| Docs | `--docs` | `reference/docs.md` |
| UX | `--ux` | `reference/ux.md` |
| Marketing | `--marketing` | `reference/marketing.md` |
| Product | `--product` | `reference/product.md` |

**Run a lens:** read its rubric, follow the Discover → Review → Report phases, and produce prioritized, actionable findings — each with a concrete suggested fix.

**All lenses (`/flow-review`, no flag):** run docs → product → ux → marketing, then produce a cross-lens summary of the highest-priority items across all areas.

**Applying fixes:** the review produces *findings*. When findings warrant edits (e.g. doc fixes), you — the main thread — propose them and **confirm before making significant changes**. The review itself never edits silently.

## Rules
- Read before writing — understand current state before proposing changes.
- Confirm before making significant doc changes.
- Actionable findings only — specific suggested fixes, not just observations.

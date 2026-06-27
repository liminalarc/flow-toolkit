---
description: "Audit docs, UX, marketing, or product — /flow-review [--docs|--ux|--marketing|--product]"
---
# Review

Structured audit from multiple lenses. Reads current state, identifies gaps, proposes concrete improvements. Run all lenses or narrow to one.

Usage:
- `/flow-review` — all lenses
- `/flow-review --docs` — documentation only
- `/flow-review --ux` — UX audit only
- `/flow-review --marketing` — marketing/positioning only
- `/flow-review --product` — product critique only

## Instructions

**Start fresh.** Read only from the project files — `CLAUDE.md`, `SPECIFICATIONS.md`, `README.md`, `MARKETING.md`. Do not reference or build on prior conversation context. Treat this as a new session regardless of what preceded it.

### --docs

Phase 1 — Discover: find all docs (README files, CLAUDE.md hierarchy, SPECIFICATIONS.md, `docs/` directory, API docs, setup guides).

Phase 2 — Review: for each doc — Is it accurate? Does it match the current code/architecture? Are setup steps runnable? What would a new contributor need that's missing?

Phase 3 — Update: fix inaccuracies, fill gaps, remove stale content. Confirm before writing when changes are significant.

### --ux

Phase 1 — Discover: identify all user-facing pages and flows from CLAUDE.md, routes, or by reading the frontend source.

Phase 2 — Review: for each flow — clarity of purpose, friction in common paths, consistency of patterns, mobile/responsive behavior, error states, empty states, loading states. Read from a user's perspective.

Phase 3 — Report: prioritized list (critical / high / low). Propose fixes for the top items and ask which to implement.

### --marketing

Phase 1 — Read: find marketing content (landing page, MARKETING.md, any positioning docs).

Phase 2 — Review: PMM lens — does the positioning communicate clear value? Is the target audience explicit? Are features described in terms of user outcomes, not implementation? Is pricing (if any) clear and justified?

Phase 3 — Report: positioning gaps + specific copy improvements. Propose the most impactful changes and ask which to apply.

### --product

Phase 1 — Read: SPECIFICATIONS.md (what's built), CLAUDE.md (capabilities), any user feedback sources.

Phase 2 — Review: power-user perspective — what's frustrating? what's missing? what's over-complicated? where are likely drop-off points? what would make this 10/10 vs 7/10?

Phase 3 — Report: 5-10 specific, prioritized observations with concrete suggestions for each. Offer to draft top items as specs with `/flow --add`.

### `/flow-review` (all lenses)

Run in order: docs → product → ux → marketing. Produce a cross-lens summary at the end with the highest-priority items across all areas.

## Rules

- Read before writing — understand current state before proposing changes.
- Confirm before making significant doc changes.
- Actionable findings only — specific suggested fixes, not just observations.

---
description: "Hunt new feature opportunities through a domain-grounded persona panel — /flow-hunt [--deep|focus area]"
---
# Hunt

Scan for new feature opportunities the backlog doesn't already cover. Claude grounds itself in the project's domain — adopting the personas, competitors, and research dimensions that matter for *this* product — then surfaces concrete, prioritized opportunities and hands the best ones to `/flow --add`.

This is the deep, outside-the-backlog twin of `/flow --ideas`. Use `--ideas` for a fast three-lens brainstorm; use `/flow-hunt` when you want a researched, scored opportunity report.

Usage:
- `/flow-hunt` — full opportunity hunt, reasoning from project docs + model knowledge (offline)
- `/flow-hunt --deep` — same, plus live fan-out web research across the project's domain dimensions
- `/flow-hunt <focus area>` — narrow the hunt (e.g. a competitor, a user segment, a phase/track) — still grounds first to avoid duplicates
- `/flow-hunt --deep <focus area>` — narrowed hunt with web research

## Instructions

**Start fresh.** Read only from the project files — `CLAUDE.md`, `SPECIFICATIONS.md`, `README.md`, `MARKETING.md`. Do not reference or build on prior conversation context. Treat this as a new session regardless of what preceded it.

### Phase 0 — Derive the domain frame

This is what makes the hunt fit *this* project. Read `CLAUDE.md`, `MARKETING.md`, `README.md`, and the top of `SPECIFICATIONS.md`, then synthesize — do not invent from a generic template:

1. **Domain & product thesis** — What is this product, who is it for, and what is its strategic edge? Distill a one-line thesis you can filter every idea against (e.g. *"Does it deepen X? Does it close the Y loop? Does it give the user insight they can't get elsewhere?"*). Pull the thesis from MARKETING.md positioning and CLAUDE.md intent — don't guess.

2. **Persona panel** — Assemble 3-5 lenses you will reason *as*, chosen for this domain. Always include:
   - The **power user** (a demanding member of the actual target audience, described concretely)
   - A **domain expert** (the specialist whose knowledge the product encodes)
   - A **product expert** who knows every shipped and planned feature cold
   - A **competitive analyst** who has used the comparable products in this space
   Name them specifically for the domain — a fitness app's panel differs from a dev tool's or a B2B SaaS's.

3. **Comparable / competitor set** — List the real products, tools, or alternatives this project competes with or is measured against. Pull names from MARKETING.md (competitive tables, positioning) where present; otherwise infer the closest analogues. If none are evident, say so and reason from category leaders.

4. **Research dimensions** — Derive the 4-6 angles worth investigating for this domain. Adapt these archetypes to the project:
   - **Competitor intelligence** — what comparables shipped recently; what their reviews complain about; what their power users love that this product lacks
   - **User pain points (primary sources)** — where this audience talks (subreddits, forums, communities, review sites) and what they wish their tool could do
   - **Domain frontier** — techniques, metrics, or research at the leading edge of the field that haven't reached this product's tier yet
   - **Adjacent signals** — what nearby tech / hardware / platforms are doing that opens new capability
   - **Behavior & retention** — how this audience actually adopts, practices, and churns; what drives the "aha moment" in this category

**Checkpoint.** Present the derived frame compactly: thesis, persona panel, comparable set, and the research dimensions you'll pursue. Let the user correct it before you go deep — this is cheap to fix now and expensive later, especially before web research.

### Phase 1 — Ground in what's built and planned

Map `SPECIFICATIONS.md`: what's DONE, IN PROGRESS, NOT STARTED. Read `SPECIFICATIONS-ARCHIVE.md` if it exists. Build a model of the current feature surface so you don't propose duplicates. Note where the backlog is thin — those gaps are hunting grounds.

### Phase 2 — Generate opportunities

Reason *as the persona panel* across the Phase 0 research dimensions.

- **Default (offline):** work from the project docs + your own knowledge of the domain and comparables. Be concrete and current; don't hedge into vagueness because you're offline.
- **`--deep`:** additionally run parallel web searches across the research dimensions. Use real queries — don't summarize from memory. Search comparable products' recent releases and reviews, primary-source community threads, domain-frontier research, and adjacent-tech signals. Cite what you find.

If a focus area was given, weight generation toward it — but still cover enough breadth to catch adjacent wins.

### Phase 3 — Cross-reference, filter, score

For each candidate opportunity:
1. Check it against `SPECIFICATIONS.md` — already planned? Skip it, or note it as validation of the roadmap.
2. Test it against the Phase 0 product thesis. If it doesn't advance the thesis, drop it.
3. Rate it on two axes: **User Impact** (1-5) × **Build Effort** (S/M/L/XL).

### Phase 4 — Opportunity report

Produce a prioritized list of **5-10 concrete opportunities**, ordered by Impact/Effort (high impact, low effort first). For each:

```
## [Opportunity Name]

**The insight**: What you learned (cite the source if from research — community, competitor, paper)
**The user problem**: How a real member of the audience experiences this pain today
**The angle**: Why this product is uniquely positioned to solve it (data already captured, architecture already in place, positioning already owned)
**Competitor gap**: Whether comparables have this — and how to do it better
**Impact**: [High/Medium/Low] — retention, conversion, or growth
**Effort**: [S/M/L/XL]
**Spec seed**: 2-3 sentences that would become the User Story in a `/flow --add` spec
```

### Phase 5 — Offer next steps

After the report, offer to:
- Draft any opportunity as a full spec with `/flow --add`
- Run a deeper dive on a specific competitor, persona, or research thread (`/flow-hunt --deep <focus>`)
- Map the opportunities against the existing SPECIFICATIONS.md phase/track structure

## Rules

- Derive the domain frame from the project's own docs — never run a generic golf/SaaS/dev-tool template by default.
- Checkpoint the frame before going deep; confirm before launching `--deep` web research.
- Don't re-propose what's already in SPECIFICATIONS.md — ground first.
- Every opportunity ends in a `/flow --add`-ready spec seed. This command proposes; it never writes specs or code itself.
- With `--deep`, cite sources. Offline, be concrete anyway.

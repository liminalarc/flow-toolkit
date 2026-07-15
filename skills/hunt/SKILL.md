---
name: hunt
description: Hunt new feature opportunities through a domain-grounded persona panel, fanning research out to one flow-researcher agent per dimension. Invoke as /flow:hunt [--deep|focus area].
---

# Hunt

Scan for new feature opportunities the backlog doesn't already cover. Claude grounds itself in the project's domain — adopting the personas, competitors, and research dimensions that matter for *this* product — then fans the research out to one `flow-researcher` agent per dimension (in parallel), synthesizes their findings into concrete, prioritized opportunities, and hands the best ones to `/flow:run --add`.

This is the deep, outside-the-backlog twin of `/flow:run --ideas`. Use `--ideas` for a fast three-lens brainstorm; use `/flow:hunt` when you want a researched, scored opportunity report.

Usage:
- `/flow:hunt` — full opportunity hunt, reasoning from project docs + model knowledge (offline)
- `/flow:hunt --deep` — same, plus live fan-out web research across the project's domain dimensions
- `/flow:hunt <focus area>` — narrow the hunt (e.g. a competitor, a user segment, a phase/track) — still grounds first to avoid duplicates
- `/flow:hunt --deep <focus area>` — narrowed hunt with web research

## Instructions

**Start fresh.** Read only from the project files — `CLAUDE.md`, `SPECIFICATIONS.md`, `README.md`, `MARKETING.md`. Do not reference or build on prior conversation context. Treat this as a new session regardless of what preceded it.

### Phase 0 — Derive the domain frame

This is what makes the hunt fit *this* project. Read `CLAUDE.md`, `MARKETING.md`, `README.md`, and the top of `SPECIFICATIONS.md`, then synthesize — do not invent from a generic template:

1. **Domain & product thesis** — What is this product, who is it for, and what is its strategic edge? Distill a one-line thesis you can filter every idea against (e.g. *"Does it deepen X? Does it close the Y loop? Does it give the user insight they can't get elsewhere?"*). Pull the thesis from MARKETING.md positioning and CLAUDE.md intent — don't guess.

2. **Persona panel** — Assemble 3-5 lenses the researchers will reason *as*, chosen for this domain. Always include:
   - The **power user** (a demanding member of the actual target audience, described concretely)
   - A **domain expert** (the specialist whose knowledge the product encodes)
   - A **product expert** who knows every shipped and planned feature cold
   - A **competitive analyst** who has used the comparable products in this space
   Name them specifically for the domain — a fitness app's panel differs from a dev tool's or a B2B SaaS's.

3. **Comparable / competitor set** — List the real products, tools, or alternatives this project competes with or is measured against. Pull names from MARKETING.md (competitive tables, positioning) where present; otherwise infer the closest analogues. If none are evident, say so and reason from category leaders.

4. **Research dimensions** — Derive the 4-6 angles worth investigating for this domain — **these become the fan-out units** (one `flow-researcher` per dimension). Adapt these archetypes to the project:
   - **Competitor intelligence** — what comparables shipped recently; what their reviews complain about; what their power users love that this product lacks
   - **User pain points (primary sources)** — where this audience talks (subreddits, forums, communities, review sites) and what they wish their tool could do
   - **Domain frontier** — techniques, metrics, or research at the leading edge of the field that haven't reached this product's tier yet
   - **Adjacent signals** — what nearby tech / hardware / platforms are doing that opens new capability
   - **Behavior & retention** — how this audience actually adopts, practices, and churns; what drives the "aha moment" in this category

**Checkpoint.** Present the derived frame compactly: thesis, persona panel, comparable set, and the research dimensions you'll pursue. Let the user correct it before you go deep — this is cheap to fix now and expensive later, especially before web research.

### Phase 1 — Ground in what's built and planned

Map the backlog from the index (`SPECIFICATIONS.md`, or the board in ADO mode): what's DONE, IN PROGRESS, NOT STARTED. Skim the `specs/<id>.md` detail files (and `specs/archive/`) for the current feature surface so no duplicate is proposed. Note where the backlog is thin — those gaps are hunting grounds. **Keep this backlog summary — you pass it to every researcher** so they don't re-propose what exists.

### Phase 2 — Fan out to one researcher per dimension

Each research dimension is investigated by an independent, read-only `flow-researcher` sub-agent — so the main thread stays lean and dimensions run in parallel. The researcher reasons through the **whole persona panel** on its one dimension.

**Dispatch.** For each dimension from Phase 0, launch a `flow-researcher` with: the **dimension** name + what it means for this project, the **domain frame** (thesis, full persona panel, comparable set), the **backlog summary** from Phase 1, the **project root**, and the **mode** — `offline` (reason from knowledge) or `--deep` (additionally run live web queries, citing sources). The `--deep` flag is the *only* difference between modes: the fan-out shape is identical either way. Launch the dimensions **in parallel** — a single message with multiple agent calls. Each researcher returns prioritized, scored opportunity candidates for its dimension and never edits.

If a focus area was given, weight every researcher's brief toward it — but still let them surface adjacent wins.

### Phase 3 — Cross-reference, filter, score (main thread)

Collect the researchers' candidates and synthesize:
1. **Dedupe** across dimensions — the same opportunity often surfaces from two angles; merge them, keeping the strongest evidence.
2. Check each against `SPECIFICATIONS.md` — already planned? Skip it, or note it as validation of the roadmap.
3. Test each against the Phase 0 product thesis. If it doesn't advance the thesis, drop it.
4. Confirm the **Impact (High/Medium/Low) × Effort (S/M/L/XL)** rating each researcher assigned; adjust for cross-dimension context.

### Phase 4 — Opportunity report

Produce a prioritized list of **5-10 concrete opportunities**, ordered by Impact/Effort (high impact, low effort first). For each:

```
## [Opportunity Name]

**The insight**: What was learned (cite the source if from research — community, competitor, paper)
**The user problem**: How a real member of the audience experiences this pain today
**The angle**: Why this product is uniquely positioned to solve it (data already captured, architecture already in place, positioning already owned)
**Competitor gap**: Whether comparables have this — and how to do it better
**Impact**: [High/Medium/Low] — retention, conversion, or growth
**Effort**: [S/M/L/XL]
**Spec seed**: 2-3 sentences that would become the User Story in a `/flow:run --add` spec
```

### Phase 5 — Offer next steps

After the report, offer to:
- Draft any opportunity as a full spec with `/flow:run --add`
- Run a deeper dive on a specific competitor, persona, or research thread (`/flow:hunt --deep <focus>`)
- Map the opportunities against the existing SPECIFICATIONS.md phase/track structure

## Rules

- Derive the domain frame from the project's own docs — never run a generic golf/SaaS/dev-tool template by default.
- Checkpoint the frame before dispatching researchers; confirm before launching `--deep` web research.
- Fan out one `flow-researcher` per dimension, in parallel, in **both** offline and `--deep` modes — the flag only toggles whether each researcher web-searches.
- Don't re-propose what's already in SPECIFICATIONS.md — ground first, and pass the backlog summary to every researcher.
- Researchers only report; the main thread dedupes and synthesizes. Every opportunity ends in a `/flow:run --add`-ready spec seed. This command proposes; it never writes specs or code itself.
- With `--deep`, cite sources. Offline, be concrete anyway.

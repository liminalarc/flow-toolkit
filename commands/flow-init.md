---
description: "Bootstrap any project with SPECIFICATIONS.md + CLAUDE.md + MARKETING.md — /flow-init [concept]"
---
# Init

Bootstrap a new project or onboard an existing one into the spec-driven workflow. Creates `SPECIFICATIONS.md` (backlog starting with Spec 0.1 — Walking Skeleton), a `CLAUDE.md` hierarchy (root + one lean file per major layer), and optionally `MARKETING.md` for user-facing products. Safe to re-run — reads existing files and extends rather than replaces.

Usage: `/flow-init` · `/flow-init <concept description>`

## Instructions

### 1. Discover what exists

Before generating anything, read:
- `CLAUDE.md` in the current directory (if present)
- `SPECIFICATIONS.md` (if present)
- `MARKETING.md` (if present)
- Top-level directory structure

If the key files look complete and well-formed, offer to **extend** (add specs, update architecture, refresh marketing) rather than regenerate.

### 2. Understand the project

Use args as the starting concept if provided. Otherwise ask 2-3 questions (maximum):
- What does this project do? (one sentence)
- Tech stack — language(s), frameworks, key libraries?
- Main layers/apps — how many distinct runnable things? (e.g., API + SPA, CLI tool, microservices + frontend)
- Is this user-facing (public product, paying customers, website)? — determines whether to generate MARKETING.md

### 3. Generate root CLAUDE.md

Keep under 200 lines. Include:

**`## Architecture`** — 4-8 bullets covering key decisions and patterns. Specific enough to constrain future choices; short enough to skim in 60 seconds.

**`## Development Rules`** — Adapted to the stack:
- TDD is mandatory — write the failing test first, then make it pass
- Testing stack (based on tech choices)
- Async all the way (if applicable), thin vertical slices, no premature abstractions, no comments unless WHY is non-obvious
- Conventional commits: `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`

**`## Spec Status Vocabulary`** — `DONE · IN PROGRESS · PARTIAL · NOT STARTED · SUPERSEDED`

**`## Feature Completion Checklist`** — Items tailored to what exists in this project. Always include: update SPECIFICATIONS.md status + archive the spec; update CLAUDE.md patterns if new conventions introduced. If MARKETING.md exists, add: update MARKETING.md feature highlights if user-facing capabilities changed.

**`## Project Structure`** — Directory tree with one-line descriptions.

**`## See Also`** — "See subdirectory CLAUDE.md files for detailed patterns: [list layers]"

### 4. Generate subdirectory CLAUDE.md files

For each major layer (e.g., `server/`, `web/`, `api/`, `frontend/`, `src/`): create a lean `CLAUDE.md` (under 100 lines) covering only patterns specific to that layer:
- Only things you can't derive from reading the code (non-obvious conventions, named patterns, things that differ from framework defaults)
- No duplication with the root file
- **How the hierarchy works**: root always loads; subdirectory files load in addition to root when Claude works within that directory. Stack additively — root universal rules + layer-specific details. Never repeat root content in a subdirectory file.

### 5. Generate SPECIFICATIONS.md

```
# [Project Name] — Specifications

## Phase 0 — Foundation

### Spec 0.1 — Walking Skeleton
**Status:** NOT STARTED

Establish the minimal end-to-end skeleton so every subsequent spec builds on a working system. All layers wired together and reachable, even if they do nothing useful yet.

**User story:** As a developer, I can run [Project Name] locally and reach every layer of the stack end to end.

**Acceptance criteria:**
- [ ] [Stack-specific: e.g., build succeeds, dev server starts, containers healthy]
- [ ] All layers communicate end-to-end
- [ ] Local setup documented in README
- [ ] Basic CI passes (lint + tests, even if minimal)
```

Add 3-5 Phase 1 specs derived from the concept. Keep them high-level — the user evolves them with `/flow --add`.

Always append an Archive section at the end:

```
## Archive

Specs are moved here after completion. Spec numbers are never reused — preserved
so commits, PRs, and notes that cite a spec number remain meaningful over time.
```

### 6. Generate MARKETING.md (user-facing projects only)

If the project is user-facing (public product, website, or paying customers), generate `MARKETING.md`. Skip and say so for internal tools, CLIs, or libraries with no direct end-customers.

```markdown
# [Project Name] — Marketing

## Positioning

**One-liner:** [What it is and who it's for — one sentence]
**Problem we solve:** [The specific pain, in the customer's language]
**How we're different:** [Key differentiator vs. the obvious alternatives]

## Target Audience

**Primary:** [Role · context · pain point]
**Secondary:** [Role · context · pain point]

## Key Messages

1. [Outcome-focused message, not feature-focused]
2. [Message 2]
3. [Message 3]

## Feature Highlights

| Feature | User Outcome |
|---|---|
| [Feature] | [What it does for the user] |

## Pricing

[Tiers and what's included, or "Free / TBD" if not yet decided]

## Channels

[Where customers find this — SEO, social, direct sales, partnerships, etc.]
```

Fill in what can be inferred from the concept; mark unknowns as `[TBD]`. This doc grows over time — run `/flow-review --marketing` to audit it periodically. Update Feature Highlights whenever a spec ships a user-facing capability.

### 7. Explain the workflow

Tell the user:
- `/flow` — implement a spec, manage backlog, or brainstorm
- `/flow-ship` — cut a release when work is validated
- `/flow-review` — audit docs, UX, marketing, or product
- `/flow-lint` — check CLAUDE.md hierarchy health and SPECIFICATIONS.md validity
- `/flow-init` — re-run to update these files as the project evolves
- **Spec archival**: when a spec is DONE, `/flow` moves it to the `## Archive` section — number preserved, never reused
- For more rigorous spec work (formal investigation, business sign-off, multi-week features): use `/card-spec` → `/card-implement`

## Rules

- Never overwrite files without reading them first and confirming intent.
- Subdirectory CLAUDE.md files must be additive — no duplication with root.
- SPECIFICATIONS.md must stay in the standard format so `/flow` can read it.
- Walking skeleton (Spec 0.1) is always the first spec.
- Archive section is always the last section in SPECIFICATIONS.md.
- Skip MARKETING.md for internal/developer tools — don't generate it by default, ask.

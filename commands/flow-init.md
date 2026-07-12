---
description: "Bootstrap or adopt a project: index + specs/ detail files, CLAUDE.md, config — /flow-init [concept|--adopt|--greenfield|--backend ado]"
---
# Init

Bootstrap a new project or onboard an existing one into the spec-driven workflow. Creates the **spec model** (an index + one `specs/<id>.md` detail file per spec), a `CLAUDE.md` hierarchy (root + one lean file per major layer), optionally `MARKETING.md` for user-facing products, and optionally `.flow/config.yml` when the backlog is tracked outside the repo (e.g. an ADO board). Safe to re-run — reads existing files and extends rather than replaces.

Usage:
- `/flow-init` — detect the project shape and bootstrap conversationally
- `/flow-init <concept description>` — greenfield bootstrap from a one-line concept
- `/flow-init --greenfield` — force new-project mode (scaffold a Walking Skeleton)
- `/flow-init --adopt` — force existing-project mode (no Walking Skeleton)
- `/flow-init --backend ado` — configure an ADO-tracked backlog (writes `.flow/config.yml`)

## The spec model this creates

- **The index** — the lifecycle ledger (id, title, status, phase, link). **Status lives only here.** In `local` mode it's `SPECIFICATIONS.md`; in `ado` mode the board *is* the index (no `SPECIFICATIONS.md`).
- **`specs/<id>.md`** — one detail file per spec (Problem, Value user story, Scope, AC, Plan, Decisions, Verification, Progress log). **No status field.** Backend-neutral.
- **Canonical status vocabulary:** `NOT STARTED · IN PROGRESS · PARTIAL · DONE · SUPERSEDED`.

## Instructions

**Start fresh.** Read only from the project files — `CLAUDE.md`, `SPECIFICATIONS.md`, `specs/`, `README.md`, `MARKETING.md`, `.flow/config.yml` (if present). Do not build on prior conversation context.

### 1. Discover what exists + pick the mode

Read the current directory: root `CLAUDE.md`, `SPECIFICATIONS.md` or `specs/`, `README.md`, `MARKETING.md`, `.flow/config.yml`, and the top-level directory structure.

Decide **greenfield vs. brownfield**:
- **Greenfield** — an empty or near-empty repo (no meaningful source), or `--greenfield`, or the user describes a brand-new concept. → scaffold a **Walking Skeleton** (Spec 0.1) + 3-5 Phase-1 specs.
- **Brownfield / adopt** — substantial existing source, or a `CLAUDE.md`/`README.md` describing a running system, or `--adopt`. → **no Walking Skeleton** (there's nothing to stand up end-to-end; the system already runs). Seed the backlog from real upcoming work instead.

When source already exists, default to **adopt** and *ask to confirm* before emitting a skeleton — never scaffold a skeleton into a live codebase. A flag overrides the guess.

If the key files already look complete and well-formed, offer to **extend** rather than regenerate.

### 2. Understand the project

Use args as the starting concept if provided. Otherwise ask up to 3 questions:
- What does this project do? (one sentence)
- Tech stack — language(s), frameworks, key libraries?
- Main layers/apps — how many distinct runnable things?
- Is it user-facing (public product, paying customers, website)? — determines MARKETING.md.

### 3. Choose the backend + scaffold `.flow/config.yml`

Default is **`local`** — no config file needed; `SPECIFICATIONS.md` is the index and flow owns the lifecycle. Skip to step 4 unless the backlog is tracked outside the repo.

If the backlog lives in an external tracker (`--backend ado`, or the user says so), write `.flow/config.yml`:

```yaml
flow:
  lifecycle_authority: ado
  spec_dir: specs
  ado:
    org: https://dev.azure.com/<org>/
    project: "<Project>"
    area: "<Area\\Path>"
    item_type: "Work Item"
    state_map:            # board state -> canonical token (see auto-discovery below)
      "<State>": <CANONICAL>
```

**Auto-discover the ADO config (preferred over hand-authoring):**

1. **Board coordinates are independent of the repo.** The board frequently lives in a **different ADO project — even a different org — than the git remote.** Do **not** infer org/project from the git remote; use it at most as a hint the user confirms. Ask for / confirm `org`, `project`, and let the user pick the `area` path from a query.
2. **Build `state_map` from state *categories*, not state names.** Query the work-item type's states and each state's **category** (`az boards` / the `wit_*` MCP), then map mechanically — this works on *any* custom process without knowing its state names:

   | ADO state category | canonical token |
   |---|---|
   | Proposed | `NOT STARTED` |
   | InProgress | `IN PROGRESS` |
   | Resolved | `IN PROGRESS` (built, awaiting verify) |
   | Completed | `DONE` |
   | Removed | `SUPERSEDED` |

3. **MCP-first, `az` CLI fallback, prompt-and-paste if both are unavailable** (headless/unauthed) — never emit a half-built map silently.
4. Show the generated `.flow/config.yml` and confirm before writing.

> **Extending to other trackers:** each backend adapter (`github-issues`, `jira`, …) ships its own `discover_config()` — the "backend introspects itself" pattern. Only `ado` exists today.

In `ado` mode, **do not create `SPECIFICATIONS.md`** — the board is the index. Still create the `specs/` directory for detail files.

### 4. Generate root CLAUDE.md

Keep under 300 lines (the root cap; a project may raise it via `rootMax` in `.flow-toolkit.json`). Include:

- **`## Architecture`** — 4-8 bullets on key decisions and patterns.
- **`## Development Rules`** — adapted to the stack: TDD mandate, testing stack, thin slices, no premature abstractions, conventional commits (`feat:`/`fix:`/`chore:`/`docs:`/`refactor:`/`test:`, optionally with a leading `[#id]` tag when the backlog is external), **no silent deferrals** (never narrow a spec's scope silently — surface each deferred in-scope item with its reason, get a per-item build-now-or-re-home decision, cross-link, and record it; deferrals gate `DONE`).
- **`## Spec Status Vocabulary`** — `NOT STARTED · IN PROGRESS · PARTIAL · DONE · SUPERSEDED`.
- **`## Feature Completion Checklist`** — tailored; always include: **deferrals reconciled** (every in-scope item was built or re-homed by user decision and cross-linked — no silent scope narrowing); **restart affected local services + smoke-test** (restart every service the change touched so nothing serves stale code, then drive the changed behavior end-to-end — Claude-automated wherever feasible — and show a brief pass/fail verification checklist before marking DONE); update the index status + archive the detail file; update `specs/<id>.md` Progress/Decisions; update CLAUDE.md patterns if new conventions introduced. If MARKETING.md exists, add its feature-highlights update.
- **`## Project Structure`** — directory tree with one-line descriptions (include `specs/`).
- **`## See Also`** — pointer to subdirectory CLAUDE.md files.

### 5. Generate subdirectory CLAUDE.md files

For each major layer (`server/`, `web/`, `src/`, …): a lean `CLAUDE.md` (under 200 lines) with only layer-specific patterns — nothing derivable from the code, no duplication with root. Root always loads; subdirectory files load additively when Claude works in that directory.

### 6. Generate or update README.md

The README is the front door — a new developer clones and reaches a running app by following it alone. Read the existing one; extend if robust, generate if thin. Required sections (adapt to the stack): Prerequisites, Local Setup (numbered, every command exact), Environment Variables, Running the App, Running Tests, Docker (if applicable), Deployment. Every command exact and runnable; name any required secret and where to get it. For monorepos, a root README pointing to per-layer READMEs.

(In greenfield mode, "Local setup documented in README" is the Walking Skeleton's primary acceptance criterion — README and skeleton ship together.)

### 7. Generate the spec model

Create the `specs/` directory. Then:

**Greenfield** — write the index `SPECIFICATIONS.md` starting with the Walking Skeleton, and a `specs/<id>.md` detail file for each seeded spec:

```markdown
# [Project Name] — Specifications

> Index only. Each spec's detail is in `specs/<id>.md`. **Status here is the
> single source of truth** for lifecycle — edit it as work moves.

## Phase 0 — Foundation
- **0.1** Walking Skeleton — `NOT STARTED` — [detail](specs/0.1.md)

## Phase 1 — Core Features
- **1.1** [First core feature] — `NOT STARTED` — [detail](specs/1.1.md)

## Archive
```

Seed 3-5 Phase-1 specs from the concept (high-level; the user evolves them with `/flow --add`). The Walking Skeleton's `specs/0.1.md`:

```markdown
---
id: 0.1
title: Walking Skeleton
links: []
---

## Problem
Establish the minimal end-to-end skeleton so every subsequent spec builds on a working system — all layers wired together and reachable, even if they do nothing useful yet.

## Value
As a developer I want to run [Project] locally and reach every layer end to end so that subsequent specs add behavior to a proven skeleton rather than building in isolation.

## Scope
**In:** minimal wiring across all layers; local run; basic CI.
**Out:** real features (later specs).

## Acceptance criteria
- [ ] [Stack-specific: build succeeds / dev server starts / containers healthy]
- [ ] All layers communicate end-to-end
- [ ] Local setup documented in README
- [ ] Basic CI passes (lint + tests, even if minimal)

## Plan (thin slices)
1. [ ] <slice>

## Decisions

## Verification / evidence

## Progress log
```

**Brownfield / adopt** — **no Walking Skeleton.** Write the index seeded from real upcoming work (or leave it with just the header + `## Archive` and let the user add specs). Derive a few candidate specs from the existing code/CLAUDE.md if useful; each gets a `specs/<id>.md`. Number from `1.1` (or a phase that fits the existing roadmap).

**ADO mode** — no `SPECIFICATIONS.md` (the board is the index). Create `specs/` and, if adopting existing work items, offer to write a `specs/<id>.md` for each in-flight item keyed by work-item number.

The detail template for every non-skeleton spec is the one in `/flow --add`.

### 8. Generate MARKETING.md (user-facing projects only)

If user-facing, generate `MARKETING.md` (positioning, audience, key messages, feature highlights, pricing). Skip for internal tools/CLIs/libraries — ask first.

### 9. Explain the workflow

Tell the user:
- `/flow` — implement a spec, manage backlog, brainstorm
- `/flow-ship` — cut a release
- `/flow-review` — audit docs, UX, marketing, product
- `/flow-lint` — check the CLAUDE.md hierarchy + index↔detail integrity; `--migrate` converts a legacy inline `SPECIFICATIONS.md` to the index + `specs/` model
- `/flow-init` — re-run to update as the project evolves
- Status lives in the index (or the board); detail lives in `specs/<id>.md`; archived specs move to `specs/archive/<id>.md` — id never reused.

## Rules

- Never overwrite files without reading them first and confirming intent.
- Subdirectory CLAUDE.md files must be additive — no duplication with root.
- The index and detail files must stay in the standard format so `/flow` and the hooks can read them.
- **Walking Skeleton is greenfield-only** — never scaffold it into an existing codebase.
- **Status is single-source** (index/board); never write status into a `specs/<id>.md`.
- ADO config: board coordinates are explicit (not inferred from the git remote); build `state_map` from state categories; confirm before writing `.flow/config.yml`.
- Skip MARKETING.md for internal/developer tools — ask, don't assume.

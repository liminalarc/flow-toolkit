# flow-toolkit

A set of Claude Code slash commands for a conversational, spec-driven development workflow. Works in any project — .NET, Node, Python, whatever — by reading from two plain markdown files (`SPECIFICATIONS.md` and `CLAUDE.md`) that live in your project.

Works alongside [Card Pilot](https://github.com/cardpilot) — `flow-*` commands are fast and conversational; Card Pilot's `card-*` commands are rigorous and formal. Use both: pick the right tool for the complexity of the work.

---

## Table of Contents

- [Install](#install)
- [Quick Start](#quick-start)
- [The Two Files](#the-two-files)
  - [SPECIFICATIONS.md — the backlog](#specificationsmd--the-backlog)
  - [CLAUDE.md — the rules](#claudemd--the-rules)
- [The Development Cycle](#the-development-cycle)
- [Commands](#commands)
  - [/flow-init](#flow-init)
  - [/flow](#flow)
  - [/flow-ship](#flow-ship)
  - [/flow-review](#flow-review)
- [When to use Card Pilot instead](#when-to-use-card-pilot-instead)
- [Project-Specific Commands](#project-specific-commands)
- [Updating](#updating)

---

## Install

**Windows (PowerShell):**
```powershell
git clone https://github.com/liminalarc/flow-toolkit.git
cd flow-toolkit
.\install.ps1
```

**Mac / Linux:**
```bash
git clone https://github.com/liminalarc/flow-toolkit.git
cd flow-toolkit
chmod +x install.sh
./install.sh
```

Commands are copied to `~/.claude/commands/` — Claude Code's global user-level directory. They appear in the `/` picker in every project. Restart Claude Code after installing.

---

## Quick Start

```
# In a new project directory:
/flow-init My new SaaS app — React frontend, Node API, Postgres

# See the backlog:
/flow

# Start working on the first spec:
/flow 0.1

# When it's done, ship:
/flow-ship
```

That's the whole loop. Everything else is detail.

---

## The Two Files

Every project using flow-toolkit has two plain markdown files. `/flow-init` generates them; you evolve them over time.

### SPECIFICATIONS.md — the backlog

The single source of truth for what to build. Structured as phases → specs, each with a status, user story, and acceptance criteria.

**Format:**

```markdown
# Project Name — Specifications

## Phase 0 — Foundation

### Spec 0.1 — Walking Skeleton
**Status:** NOT STARTED

Establish the minimal end-to-end skeleton so every subsequent spec builds on a working system.

**User story:** As a developer, I can run the app locally and reach every layer of the stack.

**Acceptance criteria:**
- [ ] Build succeeds
- [ ] All layers communicate end-to-end
- [ ] Local setup documented in README
- [ ] Basic CI passes

## Phase 1 — Core Features

### Spec 1.1 — User Authentication
**Status:** IN PROGRESS

...
```

**Status vocabulary** — exactly one of these per spec, no other values:

| Status | Meaning |
|---|---|
| `NOT STARTED` | In the backlog, not yet worked |
| `IN PROGRESS` | Actively being built |
| `PARTIAL` | Some criteria met, work paused |
| `DONE` | All acceptance criteria met |
| `SUPERSEDED` | Replaced by a different spec |

**Numbering convention:** `Phase.Spec` — so Spec 1.2 is the second spec in Phase 1. Walking Skeleton is always Spec 0.1. Use whole numbers for phases (0, 1, 2) and sequential numbers within phases (1, 2, 3...). No two specs share a number.

**The walking skeleton rule:** Spec 0.1 is always the walking skeleton — the minimal end-to-end system where all layers are wired together and reachable, even if they do nothing useful yet. Every project starts here. Subsequent specs add behavior to a proven skeleton rather than building in isolation.

**How `/flow` reads the backlog:**
- `/flow` shows all specs by status, IN PROGRESS first, then NOT STARTED grouped by phase
- `/flow 1.2` finds and loads Spec 1.2 directly
- `/flow --clean` normalizes status keywords and heading formats to match the spec above

### CLAUDE.md — the rules

The architectural and operational context that Claude Code reads in every session. Two tiers:

**Root `CLAUDE.md`** (always loads):
- Architecture overview — what the system is and the key decisions that constrain future work
- Development rules — TDD mandate, testing stack, code style, commit format
- Feature completion checklist — what to update when a spec is done
- Project structure — directory tree with one-line descriptions

**Subdirectory `CLAUDE.md`** (loads when Claude works in that directory):
- Layer-specific patterns that don't belong in the root
- Non-obvious conventions for that layer's framework or tools
- Named patterns used consistently in that layer

**How loading works:** Root always loads. When Claude works in `server/`, it loads root + `server/CLAUDE.md`. When it works in `web/`, it loads root + `web/CLAUDE.md`. They stack — they don't swap. This means:
- Put universal rules in root
- Put layer-specific detail in subdirectory files
- Never duplicate root content in a subdirectory file

**What NOT to put in CLAUDE.md:**
- Code patterns derivable from reading the code
- Git history or who changed what
- Ephemeral task state

---

## The Development Cycle

A typical week looks like this:

```
Monday morning:
  /flow                          → see the backlog, pick the next spec

During the day:
  /flow 2.3                      → understand + plan Spec 2.3
  [Claude proposes a plan]
  [you review and approve]
  [Claude builds test-first, commits per slice]
  [spec done, status set to DONE]

  /flow --add                    → capture an idea that came up
  /flow --ideas                  → brainstorm new features

Friday afternoon:
  /flow-ship                     → validate everything and cut the release

Any time:
  /flow-review --docs            → audit the docs
  /flow-review --ux              → UX critique
```

**The checkpoint discipline:** `/flow` never writes code until you approve the plan. For every spec, the cycle is:

1. **Understand** — Claude reads the spec and the relevant code, asks 1-2 clarifying questions if needed
2. **Plan** — Claude proposes thin vertical slices, the files/layers touched, the test strategy
3. **Checkpoint** — you review and approve (or redirect) the plan
4. **Build** — test-first, small commits, surfaces decisions as they come up
5. **Done** — spec marked DONE, CLAUDE.md updated if new patterns were introduced, validation checklist handed off

This keeps you in control of direction without having to micromanage implementation.

**Cross-cutting specs** (touching multiple independent layers like server + web): Claude locks the API contract in the plan step, then spawns one isolated agent per layer to build in parallel against that contract. Layers merge after and the seam is verified.

---

## Commands

### /flow-init

Bootstrap a new project or update an existing one.

```
/flow-init
/flow-init My project concept — brief description here
```

**What it does:**
1. Reads any existing `CLAUDE.md` and `SPECIFICATIONS.md` — extends rather than overwrites if they look good
2. Asks 2-3 focused questions: what does this do, what's the stack, what are the layers?
3. Generates root `CLAUDE.md` with architecture, dev rules, feature checklist, and project structure
4. Generates subdirectory `CLAUDE.md` files for each major layer (under 100 lines each)
5. Generates `SPECIFICATIONS.md` with Spec 0.1 (Walking Skeleton) + 3-5 Phase 1 specs from your concept
6. Explains the workflow and how the CLAUDE.md hierarchy works

Re-run it as the project evolves — it reads what's there and offers to extend, not replace.

---

### /flow

The primary development command. All backlog management and implementation in one place.

**Show the backlog:**
```
/flow
```
Shows all specs by status. IN PROGRESS first, then NOT STARTED grouped by phase. Suggests the next spec based on phase order.

**Implement a spec:**
```
/flow 2.3
/flow "add dark mode to the settings page"
```
Spec number or free-form description. If the description maps to an existing spec, Claude says so. If it's net-new, it offers to capture it first with `--add`.

**Brainstorm ideas:**
```
/flow --ideas
```
Three lenses: **Sellable** (acquisition/retention/WTP), **Profitable** (cost reduction or pricing tier), **Easy wins** (high-leverage, low-effort). Reads the backlog first to avoid re-suggesting what's already planned. Offers to draft the best ones into specs.

**Add a new spec:**
```
/flow --add
```
Conversational spec capture. Claude asks what it is, who it's for, and what success looks like — then drafts the spec in the standard format and shows it to you before writing to `SPECIFICATIONS.md`.

**Normalize the spec file:**
```
/flow --clean
```
Enforces the status vocabulary, fixes heading formats, removes orphaned lines. Shows a diff before writing.

---

### /flow-ship

Cut a release. Reads `CLAUDE.md` for this project's deploy mechanism — works whether you use git tags → CI/CD, npm publish, docker push, or something else.

```
/flow-ship
/flow-ship --dry-run
```

**What it does:**
1. Reads `CLAUDE.md` to discover the release mechanism
2. Validates: no uncommitted changes, tests pass, build succeeds, CLAUDE.md is current, any project-specific pre-ship steps
3. Reads recent tags + commits to propose a version bump (major/minor/patch based on conventional commits)
4. **Confirms the version with you** before tagging
5. Executes the release
6. Reports the tag/version and what to verify after deploy

`--dry-run` runs all validation and prints what would happen without tagging or deploying.

---

### /flow-review

Structured audit from multiple perspectives.

```
/flow-review               # all lenses
/flow-review --docs        # documentation only
/flow-review --ux          # UX audit
/flow-review --marketing   # positioning and copy
/flow-review --product     # product critique
```

**`--docs`** — Finds all docs (READMEs, CLAUDE.md hierarchy, SPECIFICATIONS.md, API docs, setup guides). Checks accuracy, freshness, and coverage for new contributors. Updates inaccuracies after confirming.

**`--ux`** — Identifies all user-facing flows from CLAUDE.md or route files. Reviews clarity, friction, consistency, responsive behavior, error/empty/loading states. Produces a prioritized list (critical / high / low) and proposes fixes.

**`--marketing`** — PMM lens on the landing page and positioning docs. Reviews value communication, audience clarity, feature framing (outcomes vs implementation), and pricing justification. Proposes specific copy changes.

**`--product`** — Power-user perspective. Identifies friction, missing features, over-complexity, and likely drop-off points. Outputs 5-10 prioritized observations with concrete suggestions. Offers to draft top items as specs.

When run without flags, all four lenses run in sequence (docs → product → ux → marketing) with a cross-lens summary at the end.

---

## When to use Card Pilot instead

`flow-*` commands are optimized for fast, conversational work. Reach for [Card Pilot](https://github.com/cardpilot) when the work needs:

- **Formal investigation** — you need to prove technical feasibility before committing to an approach
- **Business sign-off** — decisions need stakeholder approval, not just your sign-off
- **Multi-week features** — complex enough that you want a full Problem → Proposal → Approach → Investigation → Plan arc before writing code
- **PR-based delivery** — Card Pilot's `card-implement` manages feature branches, PR creation, and review cycles

Both toolkits read `SPECIFICATIONS.md` and follow the same `CLAUDE.md` conventions. Use `/flow --add` to capture specs quickly; use `/card-spec` when you need the full 5-phase exploration.

---

## Project-Specific Commands

Project-level commands live in `.claude/commands/` inside the project root. They appear in the `/` picker alongside the global toolkit.

**Example structure (Cortex Golf):**
```
.claude/
  commands/
    gs-facility-discover.md   # find golf facilities near a location
    gs-facility-onboard.md    # drive a facility through the import pipeline
```

These are project-specific and not installed globally. They only appear when Claude Code is working in that project. Name them with a project prefix to keep them distinct from toolkit commands in the `/` picker.

---

## Updating

```powershell
# Windows
cd C:\path\to\flow-toolkit
git pull
.\install.ps1
```

```bash
# Mac/Linux
cd ~/path/to/flow-toolkit
git pull
./install.sh
```

Restart Claude Code after updating. The install script overwrites the previous versions in `~/.claude/commands/`.

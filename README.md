# flow-toolkit

A set of Claude Code slash commands for a conversational, spec-driven development workflow. Works in any project — .NET, Node, Python, whatever — by reading from two plain markdown files (`SPECIFICATIONS.md` and `CLAUDE.md`) that live in your project.

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
  - [/flow-lint](#flow-lint)
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

Commands are copied to `~/.claude/commands/` and appear in the `/` picker in every project. Restart Claude Code after installing.

---

## Starting a New Project

Navigate to your project directory and run `/flow-init`. Pass a one-line concept to skip the first question, or leave it blank to answer everything conversationally.

```
mkdir my-project && cd my-project
# open Claude Code here, then:
/flow-init Task management SaaS — Next.js frontend, Python API, Postgres
```

Claude will ask 2-3 focused questions (stack, layers, user-facing or internal?), then generate:

- **`CLAUDE.md`** — root guardrails (architecture, dev rules, project structure)
- **`server/CLAUDE.md`**, **`web/CLAUDE.md`**, etc. — one lean file per layer
- **`SPECIFICATIONS.md`** — Spec 0.1 (Walking Skeleton) + 3-5 Phase 1 specs derived from your concept
- **`MARKETING.md`** — positioning, target audience, feature highlights (user-facing projects only)

**On an existing project:** `/flow-init` reads what's already there and offers to extend, not replace. Safe to run at any time.

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

**Spec archival** — when a spec is marked `DONE`, `/flow` moves it to the archive. New projects use a `## Archive` section at the bottom of `SPECIFICATIONS.md`. Once that section grows past 20 specs, `/flow-lint` flags it and `/flow-lint --fix` migrates automatically to a `SPECIFICATIONS-ARCHIVE.md` sidecar file — keeping the active backlog lean while preserving every spec number for reference integrity. Commits, PRs, and notes that cite a spec number (e.g., "closes Spec 2.3") remain meaningful forever.

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

### CLAUDE.md — the guardrails

Engineering principles and architectural context that Claude Code reads in every session. Not a list of restrictions — a set of principles that keep every session pointed in the same direction: TDD mandate, testing stack, architecture decisions, commit format, named patterns. The goal is that Claude never has to ask "how do we do things here?"

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

**Keeping the hierarchy healthy:** Run `/flow-lint` periodically to catch drift — subdirectory files that have grown too large, sections that duplicate root content, or specs with invalid status keywords.

**MARKETING.md** — for user-facing projects, `/flow-init` generates a `MARKETING.md` with positioning, target audience, key messages, feature highlights, and pricing. Update the Feature Highlights table whenever a spec ships a user-facing capability. `/flow-review --marketing` audits it; `/flow-lint` checks for shipped specs that haven't been reflected in the marketing doc.

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

| Command | Description |
|---|---|
| `/flow-init [concept]` | Bootstrap any project with `SPECIFICATIONS.md` + `CLAUDE.md` hierarchy |
| `/flow [spec# \| --ideas \| --add \| --clean \| description]` | Implement specs, manage backlog, brainstorm |
| `/flow-ship [--dry-run]` | Cut a release — reads deploy conventions from `CLAUDE.md` |
| `/flow-review [--docs \| --ux \| --marketing \| --product]` | Audit docs, UX, marketing, or product |
| `/flow-lint [--claude \| --specs \| --fix]` | Enforce CLAUDE.md hierarchy rules and SPECIFICATIONS.md validity |

---

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

### /flow-lint

Enforce the CLAUDE.md hierarchy rules and SPECIFICATIONS.md format. Catches problems before they cause confusion.

```
/flow-lint               # full audit
/flow-lint --claude      # CLAUDE.md hierarchy only
/flow-lint --specs       # SPECIFICATIONS.md only
/flow-lint --fix         # audit + auto-fix safe mechanical issues
```

**What it checks:**

*CLAUDE.md hierarchy:*
- Root CLAUDE.md exists and is under 200 lines
- Root has required sections: `## Architecture`, `## Development Rules`, `## Project Structure`
- Subdirectory CLAUDE.md files are under 150 lines each
- Subdirectory files don't duplicate `##` section headings from root (content loaded twice = drift risk)
- Layers with 10+ source files have a subdirectory CLAUDE.md

*SPECIFICATIONS.md:*
- Spec 0.1 (Walking Skeleton) is present
- No duplicate spec numbers (checked across both `SPECIFICATIONS.md` and `SPECIFICATIONS-ARCHIVE.md`)
- Every spec heading matches `### Spec X.Y — Title`
- Every spec has exactly one `**Status:**` line
- Status keyword is one of: `DONE · IN PROGRESS · PARTIAL · NOT STARTED · SUPERSEDED`
- DONE specs have no unchecked `- [ ]` acceptance criteria remaining
- Non-DONE specs with all `- [x]` items are flagged (status probably needs updating)
- Inline `## Archive` section with more than 20 specs flagged — run `--fix` to migrate to `SPECIFICATIONS-ARCHIVE.md`

**Severity levels:** `ERROR` (must fix — breaks `/flow` parsing or creates contradiction), `WARNING` (should fix — will cause drift over time), `INFO` (consider — best practice not met).

**`--fix`** auto-corrects safe mechanical issues: status keyword casing, spec heading punctuation, and archive migration (inline → sidecar file when archive exceeds 20 specs). Never modifies CLAUDE.md content or resolves ambiguous issues — those require human judgment.

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

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
  - [/flow-hunt](#flow-hunt)
  - [/flow-ship](#flow-ship)
  - [/flow-review](#flow-review)
  - [/flow-pr](#flow-pr)
  - [/flow-lint](#flow-lint)
- [Hooks](#hooks)
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

Commands are copied to `~/.claude/commands/` and appear in the `/` picker in every project. The installer also registers the toolkit's [hooks](#hooks) in `~/.claude/settings.json` (an additive merge — your existing settings are preserved and backed up to `settings.json.bak` first). Restart Claude Code after installing.

> ⚠️ **The installer overwrites.** It copies every `commands/*.md` over the versions in `~/.claude/commands/` and `~/.claude-company/commands/` with `--force`. If you've edited a toolkit command in place (e.g. customized `flow.md` for one machine), those local edits will be lost on the next install. Keep customizations as separate, project-prefixed commands in a project's `.claude/commands/` (see [Project-Specific Commands](#project-specific-commands)) — or fork the toolkit and edit the source `commands/` files so your changes survive `git pull` + install.

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

## Built to Use Context Wisely

Every token in Claude's context window is either signal or noise. The toolkit is designed to keep the ratio high — so you get more useful work per session without burning budget on irrelevant history.

**Enforced size limits.** Root `CLAUDE.md` is capped at 200 lines; subdirectory files at 150. `/flow-lint` catches drift before it compounds. A bloated guardrail file isn't just a style problem — it's wasted context on every session, forever.

**Only the active backlog loads.** Completed specs are archived out of `SPECIFICATIONS.md` as they're done. Claude reads 15 active specs, not 150 historical ones. The archive is preserved for reference integrity (spec numbers never reused) but stays out of the working context.

**Subdirectory scoping.** The `CLAUDE.md` hierarchy means working in `server/` loads root + `server/CLAUDE.md` — not `web/`, not `admin/`. Claude gets exactly the layer-specific context it needs, nothing it doesn't.

**Thin vertical slices.** Each `/flow` call is scoped to one spec at a time. Claude isn't reasoning about the whole roadmap — it's reasoning about a defined, bounded increment.

The result: a session that starts sharp and stays sharp, because the structure of the project files keeps Claude's working set lean by default.

**Every command reinforces this.** Each of the six commands opens with an explicit instruction to ignore prior conversation context and read only from the project files. You can chain `/flow-init` → `/flow` → `/flow-lint` without a `/clear` in between — each one starts fresh on its own.

## The Three Files

Every project using flow-toolkit has three plain markdown files. `/flow-init` generates them; you evolve them over time.

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

### README.md — the day-1 guide

The README is the front door. A new developer should be able to clone the repo and reach a running app by following it alone, with no outside knowledge required. `/flow-init` generates it; `/flow-lint` checks that it stays complete.

**Required sections:**

| Section | What it must contain |
|---|---|
| Prerequisites | Runtime versions (Node 20, .NET 10...), tools, accounts needed before step 1 |
| Local Setup | Numbered steps: clone → install → configure env → run. Every command exact and runnable. |
| Environment Variables | Every required var, a description, and an example value. Point to `.env.example` files. |
| Running the App | Exact commands, one block per runnable thing. Include the URL where it's reachable. |
| Running Tests | Exact commands for each test layer (unit, integration, E2E). |
| Docker | `docker compose up` steps, ports, first-run notes — if the project has Docker. |
| Deployment | How code gets to production: CI/CD trigger, release process, or link to runbook. |

Rules:
- Every command must be exact — no pseudocode, no elided steps.
- If a step requires a secret, name it and say where to get it. Don't write `[configure your env]`.
- Spec 0.1's primary acceptance criterion is "Local setup documented in README" — the README and the walking skeleton ship together.
- For monorepos, add a root README pointing to per-layer READMEs; each layer gets its own app-specific setup guide.

`/flow-lint` checks: README exists (ERROR if missing), has a local-setup section (ERROR), has prerequisites (WARNING), has test instructions (WARNING), and that Spec 0.1 DONE implies a real setup guide exists.

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
  /flow --ideas                  → quick brainstorm, three lenses
  /flow-hunt --deep              → researched opportunity report

Before merging a branch or PR:
  /flow-pr                       → spec fidelity + code quality + test coverage

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
| `/flow-hunt [--deep \| focus area]` | Hunt new feature opportunities through a domain-grounded persona panel |
| `/flow-ship [--dry-run]` | Cut a release — reads deploy conventions from `CLAUDE.md` |
| `/flow-review [--docs \| --ux \| --marketing \| --product]` | Audit docs, UX, marketing, or product |
| `/flow-pr [pr# \| branch] [--spec \| --quality \| --tests]` | Spec-aware review of a PR or branch diff, with clean-code and test-coverage checks |
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
Three lenses: **Sellable** (acquisition/retention/WTP), **Profitable** (cost reduction or pricing tier), **Easy wins** (high-leverage, low-effort). Reads the backlog first to avoid re-suggesting what's already planned. Offers to draft the best ones into specs. For a deeper, researched, domain-grounded version, use [`/flow-hunt`](#flow-hunt).

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

### /flow-hunt

The deep, outside-the-backlog twin of `/flow --ideas`. Where `--ideas` is a fast three-lens brainstorm, `/flow-hunt` grounds itself in *this* project's domain, then produces a researched, scored opportunity report.

```
/flow-hunt                     → opportunity report from project docs + model knowledge
/flow-hunt --deep              → same, plus live fan-out web research
/flow-hunt social retention    → narrow the hunt to a focus area
/flow-hunt --deep arccos       → narrowed hunt with web research
```

**What makes it portable:** before hunting, it *derives the domain frame* from your project's own `CLAUDE.md`, `MARKETING.md`, `README.md`, and `SPECIFICATIONS.md` — there's no hardcoded industry. Specifically it synthesizes:

- **A product thesis** — the one-line strategic filter every idea is tested against
- **A persona panel** — 3-5 lenses Claude reasons *as* (power user, domain expert, product expert, competitive analyst), named for your domain
- **A comparable/competitor set** — pulled from your positioning docs
- **Research dimensions** — the 4-6 angles worth investigating for your field (competitor intel, user pain points, domain frontier, adjacent signals, behavior & retention)

It checkpoints that frame for your correction before going deep, grounds against `SPECIFICATIONS.md` to avoid duplicates, scores each opportunity on **Impact × Effort**, and ends every opportunity with a `/flow --add`-ready spec seed. With `--deep` it runs live web searches and cites sources; offline it reasons from the docs and model knowledge. It proposes only — never writes specs or code.

> This generalizes the project-specific `gs-opportunity-hunt` pattern (a Cortex Golf command) into a portable command that adapts to any domain.

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

### /flow-pr

Spec-aware PR review. Where GitHub's generic review asks "is this good code?", `/flow-pr` asks "is this the code the spec asked for, built the way this project builds things?"

```
/flow-pr                  # review current branch vs main
/flow-pr 42               # review GitHub PR #42 (via gh)
/flow-pr feature/auth     # review a branch by name
/flow-pr --spec           # spec fidelity only
/flow-pr --quality        # clean code + correctness only
/flow-pr --tests          # test coverage only
```

**Four review dimensions:**

1. **Spec fidelity** — finds the spec the diff claims to implement (from the PR title, branch name, or commit messages), walks its acceptance criteria one by one (✅ satisfied / ⬜ not addressed / ❌ contradicted), flags scope creep, and checks the bookkeeping: status updated, CLAUDE.md updated if new patterns shipped.
2. **Correctness** — bugs, edge cases, and a quick security pass on the changed code only.
3. **Clean Code** — intent-revealing naming, small single-purpose functions, no duplication or dead code, comments that explain *why*. Judged against `CLAUDE.md`'s named patterns first, general principles second — a locally-clean function in a foreign style is still a finding.
4. **Tests** — every behavior change must have a test change (the TDD check), tests assert behavior not implementation, and the suite actually runs. If coverage tooling is configured, reports coverage on the changed files only.

**Output:** a verdict (`READY` / `READY WITH NITS` / `NEEDS WORK`), the spec scorecard, and findings grouped `BLOCKER` / `SHOULD FIX` / `NIT` — each with a `file:line` and a concrete fix. A failing test suite is an automatic `NEEDS WORK`. It never posts to GitHub, approves, or merges unless you explicitly ask.

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
- Every spec heading matches `### Spec A.B — Title` (alphanumeric — e.g. `2.37a`, `P.10`, `BL.12`)
- Every spec has exactly one `**Status:**` line
- Status keyword is one of: `DONE · IN PROGRESS · PARTIAL · NOT STARTED · SUPERSEDED`
- DONE specs have no unchecked `- [ ]` acceptance criteria remaining
- Non-DONE specs with all `- [x]` items are flagged (status probably needs updating)
- Inline `## Archive` section with more than 20 specs flagged — run `--fix` to migrate to `SPECIFICATIONS-ARCHIVE.md`

**Severity levels:** `ERROR` (must fix — breaks `/flow` parsing or creates contradiction), `WARNING` (should fix — will cause drift over time), `INFO` (consider — best practice not met).

**`--fix`** auto-corrects safe mechanical issues: status keyword casing, spec heading punctuation, and archive migration (inline → sidecar file when archive exceeds 20 specs). Never modifies CLAUDE.md content or resolves ambiguous issues — those require human judgment.

---

## Hooks

Where `/flow-lint` is the audit you run on demand, hooks are the seatbelt that's always on. A [Claude Code hook](https://docs.anthropic.com/en/docs/claude-code/hooks) is a script that fires automatically on events in Claude's loop — the toolkit uses them to enforce its file-format invariants deterministically, with zero tokens spent and no reliance on Claude remembering the rules.

### The hook suite

| Hook | Event | What it does |
|---|---|---|
| `flow-spec-guard.sh` | After every file edit | Validates `SPECIFICATIONS.md` / `SPECIFICATIONS-ARCHIVE.md` format the moment it changes |
| `flow-claude-guard.sh` | After every file edit | Enforces CLAUDE.md line caps — 200 root, 150 subdirectory |
| `flow-commit-guard.sh` | Before every `git commit` | Conventional Commit message format + spec file must be valid to commit + soft nudge on spec-less work |
| `flow-session-brief.sh` | Session start | Injects a one-line backlog orientation into every new session |

All four exit instantly when they don't apply (non-spec file, non-commit command, project without a spec file) — running them globally costs nothing in projects that don't use the toolkit.

**`flow-spec-guard.sh`** validates on every edit to a spec file:

- Spec headings match `### Spec A.B — Title` — alphanumeric spec number (e.g. `2.37a`, `P.10`, `BL.12`), em dash, title required
- Every spec has exactly one `**Status:**` line
- Status is exactly one of `DONE · IN PROGRESS · PARTIAL · NOT STARTED · SUPERSEDED`
- No duplicate spec numbers — within the file *and* against the archive sidecar (this also protects archive reference integrity: numbers are never reused)
- `DONE` specs have no unchecked `- [ ]` acceptance criteria

On failure the guard blocks with the error list, and — this is the key difference from a git hook — **Claude reads the errors and fixes the file in the same turn**. Format drift gets corrected the moment it's introduced instead of surfacing weeks later in a lint run.

**`flow-claude-guard.sh`** catches guardrail bloat at the moment of creation. A CLAUDE.md over its cap isn't a style problem — it's wasted context in every session, forever. When Claude pushes a file over the limit, the block message tells it to trim now: move detail to subdirectory files, delete what's derivable from code.

**`flow-commit-guard.sh`** runs three checks before any commit: the message follows Conventional Commits (`/flow-ship` derives version bumps from commit types, so a malformed message silently breaks releases); `SPECIFICATIONS.md` passes validation (catches hand edits that bypassed the edit-time guard); and — as a note to Claude, never a block — flags commits that stage source changes while no spec is `IN PROGRESS`.

**`flow-session-brief.sh`** injects ~30 tokens of orientation into each new session in a flow project:

```
flow-toolkit: Spec 1.1 — User Authentication is IN PROGRESS · 12 NOT STARTED · 8 DONE — run /flow for the board
```

*Deliberately not included:* a `Stop`-event "did you update the checklist?" nudge. It can't reliably distinguish work-in-progress from forgetfulness, so it fires constantly on normal WIP — a hook that cries wolf gets disabled. The commit guard's soft nudge covers the same ground at the moment that actually matters.

### How they're installed

The install scripts copy `hooks/*.sh` to `~/.claude/hooks/` and merge the registrations from `hooks/hooks.json` into `~/.claude/settings.json`. The merge is **additive and idempotent**: your existing permissions and hooks are untouched, a `settings.json.bak` backup is written first, and each hook is registered at most once no matter how many times you re-run the installer. Hook scripts are written in bash and run everywhere — on Windows, Claude Code executes hooks through Git Bash (which you already have, since you cloned this repo).

**To remove:** delete the entries whose command mentions a `flow-*.sh` script from `~/.claude/settings.json` and the scripts from `~/.claude/hooks/`.

---

## Project-Specific Commands

Project-level commands live in `.claude/commands/` inside the project root. They appear in the `/` picker alongside the global toolkit.

**Example structure (Cortex Golf):**
```
.claude/
  commands/
    gs-facility-discover.md   # find golf facilities near a location
    gs-facility-onboard.md    # drive a facility through the import pipeline
    gs-opportunity-hunt.md    # golf-specific feature ideation (now generalized — see below)
```

These are project-specific and not installed globally. They only appear when Claude Code is working in that project. Name them with a project prefix to keep them distinct from toolkit commands in the `/` picker.

**When a project command is worth generalizing:** Cortex Golf's `gs-opportunity-hunt` — a persona-driven, web-researched feature-ideation command — proved useful enough to lift into the portable toolkit as [`/flow-hunt`](#flow-hunt). The portable version derives its domain frame (personas, competitors, research dimensions, product thesis) from each project's own docs instead of hardcoding the domain. Keep a `gs-`/project-prefixed command only when it depends on something truly project-specific; if the pattern is generic with the domain swapped out, it belongs in the toolkit.

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

Restart Claude Code after updating.

> ⚠️ **Updating overwrites your installed commands.** The install script force-copies the toolkit's `commands/*.md` over whatever is in `~/.claude/commands/` and `~/.claude-company/commands/`. Any in-place edits you made to an installed command are replaced. If you've been customizing a command, make the change in the toolkit's source `commands/` files (so it persists across updates) or keep it as a project-prefixed command in the project's own `.claude/commands/`.

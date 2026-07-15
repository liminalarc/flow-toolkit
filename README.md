# flow-toolkit

A Claude Code **plugin** for a conversational, spec-driven development workflow — a set of `/flow:*` slash commands, sub-agents, and always-on hooks. Works in any project — .NET, Node, Python, whatever — by reading plain markdown that lives in your project: `CLAUDE.md` for the rules, and a **spec model** = a lightweight index (the backlog) plus one detail file per spec. Track the backlog locally or on an external board (e.g. Azure DevOps) via a small config file — same spec files either way.

---

## Table of Contents

- [Install](#install)
  - [Migrating from the installer](#migrating-from-the-installer)
- [Quick Start](#quick-start)
- [The Project Files](#the-project-files)
  - [The spec model — index + detail files](#the-spec-model--index--detail-files)
  - [CLAUDE.md — the guardrails](#claudemd--the-guardrails)
  - [.flow/config.yml — the backend](#flowconfigyml--the-backend)
- [The Development Cycle](#the-development-cycle)
  - [Autonomy & sub-agents](#autonomy--sub-agents)
- [Commands](#commands)
  - [/flow:init](#flowinit)
  - [/flow:run](#flowrun)
  - [/flow:hunt](#flowhunt)
  - [/flow:ship](#flowship)
  - [/flow:review](#flowreview)
  - [/flow:pr](#flowpr)
  - [/flow:lint](#flowlint)
- [Hooks](#hooks)
- [Project-Specific Commands](#project-specific-commands)
- [Updating](#updating)

---

## Install

flow-toolkit installs as a Claude Code **plugin** named `flow`, from its GitHub marketplace:

```
/plugin marketplace add liminalarc/flow-toolkit
/plugin install flow@flow-toolkit
```

The plugin bundles everything — skills, sub-agents, and the always-on [hooks](#hooks) — and updates are versioned (`/plugin update`). After installing, restart Claude Code (or run `/reload-plugins`). Every entry point lives under the `flow:` namespace:

`/flow:run` · `/flow:hunt` · `/flow:init` · `/flow:lint` · `/flow:ship` · `/flow:review` · `/flow:pr`

**Per profile:** the plugin installs per Claude profile (each `~/.claude`, `~/.claude-*`, or `$CLAUDE_CONFIG_DIR`), and its hooks are scoped to the profile that enabled it — enable it in each profile you use.

### Migrating from the installer

Earlier versions distributed the toolkit via `git clone` + an `install.{sh,ps1}` force-copy, which created **bare** commands (`/flow`, `/flow-hunt`, …). The plugin replaces those with the namespaced set. To migrate:

1. Install the plugin (above) and restart.
2. Verify `/flow:run` responds.
3. Remove the old bare files: running the fallback installer once prunes them automatically, or delete `~/.claude/commands/flow*.md` and `~/.claude/skills/{flow,flow-hunt,flow-review,flow-pr}` by hand (a leftover `~/.claude/commands/CLAUDE.md` from the old installer is safe to delete too).

| Before (bare) | Now (plugin) |
|---|---|
| `/flow` | `/flow:run` |
| `/flow-hunt` | `/flow:hunt` |
| `/flow-init` | `/flow:init` |
| `/flow-lint` | `/flow:lint` |
| `/flow-ship` | `/flow:ship` |
| `/flow-review` | `/flow:review` |
| `/flow-pr` | `/flow:pr` |

### Fallback: the install script

Where the plugin isn't an option, the legacy installer still works. It force-copies the same commands/skills/agents as **bare** names (`/run`, `/hunt`, … — not `/flow:run`) and registers the hooks in every detected profile's `settings.json` (an additive merge, backed up to `settings.json.bak`). It auto-detects every profile — `~/.claude`, siblings like `~/.claude-work`, and `$CLAUDE_CONFIG_DIR` — with no account names hardcoded.

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

The installer is a **criterion-gated fallback**: it's retired only once the plugin registers the toolkit's hooks reliably across all profiles **and** every in-use project has migrated — no fixed date (spec 1.2 D5). It overwrites on each run, so keep customizations as project-prefixed commands in a project's `.claude/commands/` (see [Project-Specific Commands](#project-specific-commands)), not by editing installed files.

---

## Starting a New Project

Navigate to your project directory and run `/flow:init`. Pass a one-line concept to skip the first question, or leave it blank to answer everything conversationally.

```
mkdir my-project && cd my-project
# open Claude Code here, then:
/flow:init Task management SaaS — Next.js frontend, Python API, Postgres
```

Claude will ask 2-3 focused questions (stack, layers, user-facing or internal?), then generate:

- **`CLAUDE.md`** — root guardrails (architecture, dev rules, project structure)
- **`server/CLAUDE.md`**, **`web/CLAUDE.md`**, etc. — one lean file per layer
- **`SPECIFICATIONS.md`** (the index) + **`specs/<id>.md`** detail files — Spec 0.1 (Walking Skeleton) + 3-5 Phase 1 specs derived from your concept
- **`MARKETING.md`** — positioning, target audience, feature highlights (user-facing projects only)

**Greenfield vs. adopting:** on a new project `/flow:init` scaffolds the Walking Skeleton; on an **existing** codebase it reads what's there, **skips the skeleton**, and seeds a real backlog instead (`--adopt` to force, `--greenfield` to override). Safe to run at any time. To track the backlog on an ADO board instead of a local `SPECIFICATIONS.md`, run `/flow:init --backend ado`.

---

## Quick Start

```
# In a new project directory:
/flow:init My new SaaS app — React frontend, Node API, Postgres

# See the backlog:
/flow:run

# Start working on the first spec:
/flow:run 0.1

# When it's done, ship:
/flow:ship
```

That's the whole loop. Everything else is detail.

---

## Built to Use Context Wisely

Every token in Claude's context window is either signal or noise. The toolkit is designed to keep the ratio high — so you get more useful work per session without burning budget on irrelevant history.

**Enforced size limits.** Root `CLAUDE.md` is capped at 300 lines; subdirectory files at 200. Projects that need more room can raise either cap in a repo-root `.flow-toolkit.json` (see below). `/flow:lint` catches drift before it compounds. A bloated guardrail file isn't just a style problem — it's wasted context on every session, forever.

**Index in, one detail file at a time.** The backlog is a lightweight index; the full spec detail lives in per-spec `specs/<id>.md` files. `/flow:run` loads the tiny index to orient, then reads only the one detail file it's working on — not 150 historical specs. Completed specs archive out of the index (ids never reused) but stay out of the working context.

**Subdirectory scoping.** The `CLAUDE.md` hierarchy means working in `server/` loads root + `server/CLAUDE.md` — not `web/`, not `admin/`. Claude gets exactly the layer-specific context it needs, nothing it doesn't.

**Thin vertical slices.** Each `/flow:run` call is scoped to one spec at a time. Claude isn't reasoning about the whole roadmap — it's reasoning about a defined, bounded increment.

The result: a session that starts sharp and stays sharp, because the structure of the project files keeps Claude's working set lean by default.

**Every command reinforces this.** Each skill (`run`, `hunt`, `review`, `pr`) and command (`init`, `lint`, `ship`) opens with an explicit instruction to ignore prior conversation context and read only from the project files. You can chain `/flow:init` → `/flow:run` → `/flow:lint` without a `/clear` in between — each one starts fresh on its own.

## The Project Files

Every project using flow-toolkit has a `CLAUDE.md` hierarchy and a **spec model** — an index plus one detail file per spec. User-facing projects add `MARKETING.md`. `/flow:init` generates them; you evolve them over time.

### The spec model — index + detail files

Specs are stored as **an index (the backlog) + one `specs/<id>.md` detail file per spec.** The split keeps the working set lean: `/flow:run` reads the tiny index to see the whole backlog, then loads only the one detail file it's working on.

**The index** is the lifecycle ledger — id, title, status, phase grouping, order (= priority within a phase), and a link to each detail file. **Status lives only here** (single source of truth). In local mode it's `SPECIFICATIONS.md`:

```markdown
# Project Name — Specifications

> Index only. Each spec's detail is in `specs/<id>.md`. **Status here is the
> single source of truth** for lifecycle — edit it as work moves.

## Phase 0 — Foundation
- **0.1** Walking Skeleton — `DONE` — [detail](specs/0.1.md)

## Phase 1 — Core Features
- **1.1** User Authentication — `IN PROGRESS` — [detail](specs/1.1.md)
- **1.2** Password Reset — `NOT STARTED` — [detail](specs/1.2.md)

## Archive
- **0.0** Spike: auth options — `SUPERSEDED` — [detail](specs/archive/0.0.md)
```

**A detail file** (`specs/<id>.md`) holds everything else — and carries **no status field** (status is owned by the index):

```markdown
---
id: 1.1
title: User Authentication
links: []
# deferrals:         # OPTIONAL — present only if something in scope was deferred
#   - what: "SSO login"
#     why: "scope; password login shipped first"
#     to: 1.4         # `built` (done here), or the spec id that now owns it
---

## Problem
<why this exists; what "shipped" means>

## Value
As a <role> I want <capability> so that <benefit>.

## Scope
**In:** ...   **Out:** ...

## Acceptance criteria
- [ ] <criterion> — <how proven>

## Plan (thin slices)
## Decisions
## Verification / evidence
## Progress log
```

**Value is a user story** — `As a <role> I want <capability> so that <benefit>`. Consistent across specs on purpose, so a future analysis can group the backlog by persona and benefit.

**Specs are terse by rule.** A detail file is read into context every time its spec is worked, so bloat is wasted budget on every session. `/flow:run --add` authors to three rules — one job per section (no cross-section restatement — Value doesn't restate Problem, Plan doesn't restate the AC), the shortest lossless form (bullets over prose; terse ≠ dropping detail), and an append-only one-line Progress log. A soft budget (default 120 lines, `spec.maxLines` in `.flow-toolkit.json`) makes drift visible — `flow-spec-guard.sh` nudges on edit, `/flow:lint --specs` reports it — always a warning, never a block. To bring an existing or pre-rule spec into line, `/flow:run --condense <id>` rewrites it losslessly (or `--all` to migrate a whole backlog; `--check` to audit without rewriting).

**Big specs earn a directory.** Most specs are a single flat `specs/<id>.md`. A spec that grows large can break its "how" into task files by taking a **directory** instead:

```
specs/1.7/
  1.7.md       # orchestrator — the ordinary detail file (Problem/Value/Scope/AC/Plan/…), plus a task list
  1.7.T1.md    # task file — the "how" for one slice + a local "Done when" AC
  1.7.T2.md
```

The **orchestrator** (`specs/<id>/<id>.md`) holds *why/what* and owns status + deferrals, exactly like a flat spec — the guards gate on it alone. Each **task file** (`specs/<id>/<id>.T<n>.md`) holds *how* plus a local acceptance criterion (a `Done when` checkbox — the seam a per-task implementer builds to and a verifier checks against); it carries **no status and no deferrals**. Break out by a manual guideline — **≥3 tasks, or a task with its own AC** — never enforced; below that, stay flat (thin slices, no premature abstraction). Both shapes work everywhere: the spec guard, the deferral `DONE`-gate, `/flow:lint`, and archival all accept flat and directory forms. To reshape an existing flat spec, run **`/flow:lint --migrate <id>`** (git-moves `specs/<id>.md` → `specs/<id>/<id>.md`, repoints the index; dry-run by default).

**Spec archival** — when a spec is `DONE`/`SUPERSEDED`, `/flow:run` moves its index entry to the `## Archive` section and relocates its detail to `specs/archive/<id>.md` — or, for a directory spec, the whole `specs/<id>/` → `specs/archive/<id>/` (orchestrator + every task file together). The id is never reused — commits, PRs, and notes that cite an id (e.g. "closes 2.3") stay meaningful forever.

**Deferrals — the machine-checkable trace.** When work in a spec's scope gets cut, the [deferral protocol](#the-development-cycle) records it as a structured `deferrals:` front-matter entry — not just prose — so "no unreconciled deferrals" becomes a *mechanical* check instead of something a reader has to notice:

```yaml
deferrals:
  - what: "import from file"          # what was cut
    why: "scope; paste-only shipped"  # the reason
    to: 1.6                           # `built` (done here), or the spec id that now owns it
```

The rule: **a spec cannot reach `DONE` while any deferral has an unresolved `to`** (not `built`, and no spec with that id exists). This is enforced identically in three places by one shared helper (`flow-preflight.sh`): the commit guard blocks it (local mode), `/flow:lint` reports it, and `/flow:ship`'s preflight gates on it. The trace lives in `specs/<id>.md`, so it works the same in ado mode (where status is on the board). No deferrals? Omit the key — there's no ceremony for specs that didn't defer anything.

**Status vocabulary** — flow's own, single-source, exactly one per index entry:

| Status | Meaning |
|---|---|
| `NOT STARTED` | In the backlog, not yet worked |
| `IN PROGRESS` | Actively being built |
| `PARTIAL` | Some criteria met, work paused |
| `DONE` | All acceptance criteria met |
| `SUPERSEDED` | Replaced by a different spec |

**Numbering:** `Phase.Spec` (Spec 1.2 = second spec in Phase 1). Alphanumeric ids are allowed (`2.37a`, `P.10`, `BL-12`). No two specs share an id; the filename is `specs/<id>.md`.

**The walking skeleton is greenfield-only:** on a brand-new project, Spec 0.1 is the walking skeleton — the minimal end-to-end system wired together and reachable. When you *adopt* flow into an existing codebase, there's nothing to stand up end-to-end, so `/flow:init` skips the skeleton and seeds a real backlog instead.

**Coming from an older flow project?** If your `SPECIFICATIONS.md` still has inline `### Spec` blocks with `**Status:**` lines, run **`/flow:lint --migrate`** to convert it to the index + `specs/` model (dry-run by default, non-destructive).

**How `/flow:run` reads the backlog:**
- `/flow:run` shows all specs by status, IN PROGRESS first, then NOT STARTED grouped by phase
- `/flow:run 1.2` loads the `1.2` index entry + `specs/1.2.md` directly
- `/flow:run --clean` normalizes the index entry format and status keywords

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

**Keeping the hierarchy healthy:** Run `/flow:lint` periodically to catch drift — subdirectory files that have grown too large, sections that duplicate root content, or specs with invalid status keywords.

**MARKETING.md** — for user-facing projects, `/flow:init` generates a `MARKETING.md` with positioning, target audience, key messages, feature highlights, and pricing. Update the Feature Highlights table whenever a spec ships a user-facing capability. `/flow:review --marketing` audits it; `/flow:lint` checks for shipped specs that haven't been reflected in the marketing doc.

### README.md — the day-1 guide

The README is the front door. A new developer should be able to clone the repo and reach a running app by following it alone, with no outside knowledge required. `/flow:init` generates it; `/flow:lint` checks that it stays complete.

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

`/flow:lint` checks: README exists (ERROR if missing), has a local-setup section (ERROR), has prerequisites (WARNING), has test instructions (WARNING), and that Spec 0.1 DONE implies a real setup guide exists.

### .flow/config.yml — the backend

Optional. **Absent ⇒ local mode** — `SPECIFICATIONS.md` is the index and `/flow:run` owns the full lifecycle (the default; nothing to configure). Add `.flow/config.yml` only to track the backlog on an external board:

```yaml
flow:
  lifecycle_authority: local    # DEFAULT — SPECIFICATIONS.md index owns status/priority/close
                                # or: ado  — the ADO board owns lifecycle
  spec_dir: specs               # where detail files live
  ado:                          # only when lifecycle_authority: ado
    org: https://dev.azure.com/<org>/   # the BOARD's org — may differ from the repo's remote
    project: "<Project>"                # the BOARD's project — often NOT the repo's project
    area: "<Area\\Path>"
    item_type: "Work Item"
    state_map:                          # board state -> canonical status (auto-built by /flow:init)
      Backlog: NOT STARTED
      Ready: NOT STARTED
      "In Progress": IN PROGRESS
      "Story Done": IN PROGRESS
      Closed: DONE
      Removed: SUPERSEDED
```

The **one axis** is `lifecycle_authority`:

- **`local`** — the index is `SPECIFICATIONS.md`; ids are `Phase.Spec`. The status vocabulary is used directly; **no `state_map`** (there's nothing to translate).
- **`ado`** — the **board is the index** (no `SPECIFICATIONS.md`); ids are the work-item numbers (`specs/642103.md`). The board owns the lifecycle state machine, so `state_map` translates each board state to a canonical token. `/flow:init --backend ado` builds it automatically from ADO **state categories** (`Proposed → NOT STARTED`, `InProgress → IN PROGRESS`, `Resolved → IN PROGRESS`, `Completed → DONE`, `Removed → SUPERSEDED`), so it works on any custom process. Flow's card writes are **propose-only** — it transitions state on your sign-off and refreshes one "Spec:" pointer comment, never reprioritizing, reassigning, or closing a card unprompted. The board may live in a **different ADO project/org than the repo**; only the `specs/<id>.md` detail files live in the repo.

Either way the `specs/<id>.md` detail files are byte-for-byte the same shape — only *where lifecycle is owned* changes.

---

## The Development Cycle

A typical week looks like this:

```
Monday morning:
  /flow:run                          → see the backlog, pick the next spec

During the day:
  /flow:run 2.3                      → understand + plan Spec 2.3
  [Claude proposes a plan]
  [you review and approve]
  [Claude builds test-first, commits per slice]
  [spec done, status set to DONE]

  /flow:run --add                    → capture an idea that came up
  /flow:run --ideas                  → quick brainstorm, three lenses
  /flow:hunt --deep              → researched opportunity report

Before merging a branch or PR:
  /flow:pr                       → spec fidelity + code quality + test coverage

Friday afternoon:
  /flow:ship                     → validate everything and cut the release

Any time:
  /flow:review --docs            → audit the docs
  /flow:review --ux              → UX critique
```

**The checkpoint discipline:** by default (`checkpoint` mode) `/flow:run` never writes code until you approve the plan. A spec can opt into `auto-build` to skip that pause — with an independent verifier as the safety net (see [Autonomy & sub-agents](#autonomy--sub-agents)). For every spec, the cycle is:

1. **Understand** — Claude reads the spec and the relevant code, asks 1-2 clarifying questions if needed
2. **Plan** — Claude proposes thin vertical slices, the files/layers touched, the test strategy
3. **Checkpoint** — you review and approve (or redirect) the plan *(skipped under `auto-build`; the plan is still written and committed)*
4. **Build** — test-first, small commits, surfaces decisions as they come up
5. **Done** — before marking DONE, Claude restarts every local service the change touched and runs an automated smoke test of the changed behavior end-to-end (not just unit tests), then shows you a brief pass/fail verification checklist; then the spec is marked DONE, CLAUDE.md updated if new patterns were introduced, validation checklist handed off

This keeps you in control of direction without having to micromanage implementation.

**No silent deferrals.** Scope only ever narrows by *your* decision, never Claude's. The moment Claude is about to drop or narrow something the spec put in scope — at plan-time, mid-build, or at done-time — it stops and runs the **deferral protocol**: it states *why* it would defer (cost, a missing dependency, scope creep, risk) and asks you to decide, per item, whether to **build it here** or **re-home it** to a new or related spec (cross-linked both ways, recorded in the detail file's Decisions *and* as a structured `deferrals:` front-matter entry). Each deferred item is its own decision — nothing gets batched under a blanket "later." Because the trace is machine-readable, a spec **cannot reach `DONE` with an unreconciled deferral** — the commit guard, `/flow:lint`, and `/flow:ship` all block it — so "quietly built less than asked" stops being a failure mode the workflow allows.

**Cross-cutting specs** (touching multiple independent layers like server + web): Claude locks the API contract in the plan step, then spawns one isolated `flow-implementer` agent per layer to build in parallel against that contract. Each layer's diff is checked by an independent `flow-verifier` before it merges, then the seam is verified.

### Autonomy & sub-agents

`/flow:run` can run per-task work in **isolated-context sub-agents** and dial how much it pauses for you:

- **`flow-implementer`** builds one task (or one layer of a cross-cutting spec) against that task's local acceptance criteria — worktree-isolated when layers run in parallel. It builds to the seam and never touches lifecycle state (index/status/deferrals).
- **`flow-verifier`** independently checks the implementer's diff against the same criteria *before it integrates* and returns a `PASS`/`FAIL` verdict. It **judges, never fixes** — the "agents reviewing agents" safety net.

**Autonomy modes** decide whether `/flow:run` pauses for *plan approval*:

| Mode | Plan approval | Verifier |
|---|---|---|
| `checkpoint` *(default)* | pauses for your sign-off | **advisory** — informs you, you're already in the loop |
| `auto-build` | no pause (plan still written) | **blocking** — a `FAIL` doesn't integrate: one bounded retry, then it escalates back to `checkpoint` and hands you the verdict |

Autonomy controls **only** the plan-approval pause — it never bypasses Claude Code's permission system, edits config, or self-approves. Set it per spec via `autonomy: checkpoint | auto-build` front-matter, or repo-wide in `.flow-toolkit.json`:

```json
{ "autonomy": { "default": "checkpoint", "force": "auto-build" } }
```

Precedence: `autonomy.force` (hard project override) > the spec's `autonomy:` front-matter > `autonomy.default` (fallback when the spec is silent) > builtin `checkpoint`. It's resolved by the shared helper (`flow-preflight.sh autonomy specs/<id>.md`), so the rule is defined once and can't drift.

---

## Commands

| Command | Description |
|---|---|
| `/flow:init [concept\|--adopt\|--backend ado]` | Bootstrap or adopt a project: spec index + `specs/` detail files + `CLAUDE.md` hierarchy |
| `/flow:run [spec# \| --ideas \| --add \| --clean \| --condense \| description]` _(skill)_ | Implement specs, manage backlog, brainstorm |
| `/flow:hunt [--deep \| focus area]` _(skill)_ | Hunt new feature opportunities through a domain-grounded persona panel |
| `/flow:ship [--dry-run]` | Cut a release — reads deploy conventions from `CLAUDE.md` |
| `/flow:review [--docs \| --ux \| --marketing \| --product]` _(skill)_ | Audit docs, UX, marketing, or product |
| `/flow:pr [pr# \| branch] [--spec \| --quality \| --tests]` _(skill)_ | Spec-aware review of a PR or branch diff, with clean-code and test-coverage checks |
| `/flow:lint [--claude \| --specs \| --fix \| --migrate]` | Enforce CLAUDE.md hierarchy + spec index/detail integrity; migrate legacy specs |

---

### /flow:init

Bootstrap a new project or update an existing one.

```
/flow:init
/flow:init My project concept — brief description here
```

**What it does:**
1. Reads any existing `CLAUDE.md` and `SPECIFICATIONS.md` — extends rather than overwrites if they look good
2. Asks 2-3 focused questions: what does this do, what's the stack, what are the layers?
3. Generates root `CLAUDE.md` with architecture, dev rules, feature checklist, and project structure
4. Generates subdirectory `CLAUDE.md` files for each major layer (under 100 lines each)
5. Generates the spec model — the `SPECIFICATIONS.md` index + a `specs/<id>.md` detail file per spec (Walking Skeleton only on greenfield; an existing codebase gets a real backlog, no skeleton). With `--backend ado`, writes `.flow/config.yml` instead of a local index.
6. Explains the workflow and how the CLAUDE.md hierarchy works

Re-run it as the project evolves — it reads what's there and offers to extend, not replace.

---

### /flow:run

The primary development command. All backlog management and implementation in one place. `/flow:run` is a **skill**: `SKILL.md` routes by invocation and loads only the invoked path's `reference/*` (implement / `--add` / `--clean` / `--condense`; the no-arg backlog view and `--ideas` stay inline), so the two most-used paths stay lean. The build path dispatches `flow-implementer`/`flow-verifier` sub-agents. Entry point is unchanged — you still invoke `/flow:run`.

**Show the backlog:**
```
/flow:run
```
Shows all specs by status. IN PROGRESS first, then NOT STARTED grouped by phase. Suggests the next spec based on phase order.

**Implement a spec:**
```
/flow:run 2.3
/flow:run "add dark mode to the settings page"
```
Spec number or free-form description. If the description maps to an existing spec, Claude says so. If it's net-new, it offers to capture it first with `--add`.

**Brainstorm ideas:**
```
/flow:run --ideas
```
Three lenses: **Sellable** (acquisition/retention/WTP), **Profitable** (cost reduction or pricing tier), **Easy wins** (high-leverage, low-effort). Reads the backlog first to avoid re-suggesting what's already planned. Offers to draft the best ones into specs. For a deeper, researched, domain-grounded version, use [`/flow:hunt`](#flowhunt).

**Add a new spec:**
```
/flow:run --add
```
Conversational spec capture. Claude asks what it is, who it's for, and what success looks like — then drafts **both** the index entry and the `specs/<id>.md` detail file (Value as a user story), and shows them before writing.

**Normalize the index:**
```
/flow:run --clean
```
Normalizes the index: status vocabulary, entry format, and links to detail files. Shows a diff before writing.

**Condense or audit existing specs:**
```
/flow:run --condense 2.3             # rewrite one spec to the terseness rules
/flow:run --condense --all           # migrate a whole backlog
/flow:run --condense --all --check   # audit only — report, don't rewrite
```
Rewrites bloated detail files to the terseness rules **losslessly** — the Progress log is copied verbatim and every acceptance criterion is preserved — with a per-spec diff you confirm before any write. `--check` reports terseness findings (including the cross-section restatement a line count can't catch) without writing. Where `/flow:lint --specs` flags the mechanical line budget, `--condense` is the judgment pass that fixes or audits it. It never changes a spec's status.

---

### /flow:hunt

The deep, outside-the-backlog twin of `/flow:run --ideas`. Where `--ideas` is a fast three-lens brainstorm, `/flow:hunt` grounds itself in *this* project's domain, then produces a researched, scored opportunity report. `/flow:hunt` is a **skill**: after checkpointing the domain frame, it fans the research out to one read-only `flow-researcher` sub-agent per dimension (running in parallel), then the main thread dedupes and synthesizes. Entry point is unchanged — you still invoke `/flow:hunt`.

```
/flow:hunt                     → opportunity report from project docs + model knowledge
/flow:hunt --deep              → same, plus live fan-out web research
/flow:hunt social retention    → narrow the hunt to a focus area
/flow:hunt --deep arccos       → narrowed hunt with web research
```

**What makes it portable:** before hunting, it *derives the domain frame* from your project's own `CLAUDE.md`, `MARKETING.md`, `README.md`, and `SPECIFICATIONS.md` — there's no hardcoded industry. Specifically it synthesizes:

- **A product thesis** — the one-line strategic filter every idea is tested against
- **A persona panel** — 3-5 lenses Claude reasons *as* (power user, domain expert, product expert, competitive analyst), named for your domain
- **A comparable/competitor set** — pulled from your positioning docs
- **Research dimensions** — the 4-6 angles worth investigating for your field (competitor intel, user pain points, domain frontier, adjacent signals, behavior & retention)

It checkpoints that frame for your correction before dispatching researchers, grounds against `SPECIFICATIONS.md` to avoid duplicates (passing that backlog to every researcher), scores each opportunity on **Impact × Effort**, and ends every opportunity with a `/flow:run --add`-ready spec seed. The fan-out runs in both modes — with `--deep` each researcher runs live web searches and cites sources; offline each reasons from the docs and model knowledge. It proposes only — never writes specs or code.

> This generalizes the project-specific `gs-opportunity-hunt` pattern (a Cortex Golf command) into a portable skill that adapts to any domain.

---

### /flow:ship

Cut a release. Reads `CLAUDE.md` for this project's deploy mechanism — works whether you use git tags → CI/CD, npm publish, docker push, or something else.

```
/flow:ship
/flow:ship --dry-run
```

**What it does:**
1. Reads `CLAUDE.md` to discover the release mechanism
2. Runs a **programmatic preflight** — each pre-req is a discrete check with an explicit ✅/❌ and a defined behavior on ❌ (never a silent pass; a check it can't evaluate is a ⚠️ that blocks). The checks sort into three classes:
   - **Auto-remediable (git state)** — on the default branch, clean tree, up to date with origin. On failure it detects the situation and **offers** the fix as a confirm-first prompt (merging a feature branch is always a prompt, never automatic).
   - **Gate-able** — every spec in the release is `DONE` (derived from the `[#id]` commit tags since the last tag, cross-checked against the index/board) and CI is green on the release commit (queried via `gh` — polled or reported, never assumed).
   - **Judgment** — no unreconciled deferrals on the release's `DONE` specs (surfaced, can't be auto-fixed).
3. Reads recent tags + commits to propose a version bump (major/minor/patch based on conventional commits)
4. **Confirms the version with you** before tagging
5. Executes the release
6. Reports the tag/version and what to verify after deploy

The git-state and deferral checks are the same shared `flow-preflight.sh` helper the commit guard and `/flow:lint` use, so a check is defined once. `--dry-run` runs the full preflight and prints the computed version, changelog, and tag without tagging or deploying.

---

### /flow:review

Structured audit from multiple perspectives. `/flow:review` is a **skill**: it loads only the lens rubric you invoke, and fans each lens out to an independent, read-only `flow-reviewer` sub-agent (running in parallel), then the main thread synthesizes. Entry point is unchanged — you still invoke `/flow:review`.

```
/flow:review               # all lenses
/flow:review --docs        # documentation only
/flow:review --ux          # UX audit
/flow:review --marketing   # positioning and copy
/flow:review --product     # product critique
```

**`--docs`** — Finds all docs (READMEs, CLAUDE.md hierarchy, SPECIFICATIONS.md, API docs, setup guides). Checks accuracy, freshness, and coverage for new contributors. Reports findings with suggested fixes; the main thread applies significant changes only after you confirm.

**`--ux`** — Identifies all user-facing flows from CLAUDE.md or route files. Reviews clarity, friction, consistency, responsive behavior, error/empty/loading states. Produces a prioritized list (critical / high / low) and proposes fixes.

**`--marketing`** — PMM lens on the landing page and positioning docs. Reviews value communication, audience clarity, feature framing (outcomes vs implementation), and pricing justification. Proposes specific copy changes.

**`--product`** — Power-user perspective. Identifies friction, missing features, over-complexity, and likely drop-off points. Outputs 5-10 prioritized observations with concrete suggestions. Offers to draft top items as specs.

When run without flags, all four lenses run **in parallel** (one reviewer each) and the main thread produces a cross-lens summary of the highest-priority items at the end.

---

### /flow:pr

Spec-aware PR review. Where GitHub's generic review asks "is this good code?", `/flow:pr` asks "is this the code the spec asked for, built the way this project builds things?" `/flow:pr` is a **skill**: it loads only the dimension rubric you invoke, and fans each dimension out to an independent, read-only `flow-pr-reviewer` sub-agent (running in parallel over the diff), then the main thread synthesizes the verdict. Entry point is unchanged — you still invoke `/flow:pr`.

```
/flow:pr                  # review current branch vs main
/flow:pr 42               # review GitHub PR #42 (via gh)
/flow:pr feature/auth     # review a branch by name
/flow:pr --spec           # spec fidelity only
/flow:pr --quality        # clean code + correctness only
/flow:pr --tests          # test coverage only
```

**Three review dimensions** (one `flow-pr-reviewer` each):

1. **Spec fidelity** (`--spec`) — finds the spec the diff claims to implement (from the PR title, branch name, or commit messages), walks its acceptance criteria one by one (✅ satisfied / ⬜ not addressed / ❌ contradicted), flags scope creep, and checks the bookkeeping: status updated, CLAUDE.md updated if new patterns shipped.
2. **Quality** (`--quality`) — correctness (bugs, edge cases, a quick security pass on the changed code only) plus clean code: intent-revealing naming, small single-purpose functions, no duplication or dead code, comments that explain *why*. Judged against `CLAUDE.md`'s named patterns first, general principles second — a locally-clean function in a foreign style is still a finding.
3. **Tests** (`--tests`) — every behavior change must have a test change (the TDD check), tests assert behavior not implementation, and the suite actually runs (the reviewer runs it). If coverage tooling is configured, reports coverage on the changed files only.

**Output:** a verdict (`READY` / `READY WITH NITS` / `NEEDS WORK`), the spec scorecard, and findings grouped `BLOCKER` / `SHOULD FIX` / `NIT` — each with a `file:line` and a concrete fix. A failing test suite is an automatic `NEEDS WORK`. It never posts to GitHub, approves, or merges unless you explicitly ask.

---

### /flow:lint

Enforce the CLAUDE.md hierarchy rules and SPECIFICATIONS.md format. Catches problems before they cause confusion.

```
/flow:lint               # full audit
/flow:lint --claude      # CLAUDE.md hierarchy only
/flow:lint --specs       # SPECIFICATIONS.md only
/flow:lint --fix         # audit + auto-fix safe mechanical issues
```

**What it checks:**

*CLAUDE.md hierarchy:*
- Root CLAUDE.md exists and is under the root cap (default 300 lines; configurable — see [Customizing the CLAUDE.md line caps](#customizing-the-claudemd-line-caps))
- Root has required sections: `## Architecture`, `## Development Rules`, `## Project Structure`
- Subdirectory CLAUDE.md files are under the subdirectory cap (default 200 lines each; configurable)
- Subdirectory files don't duplicate `##` section headings from root (content loaded twice = drift risk)
- Layers with 10+ source files have a subdirectory CLAUDE.md

*Spec model (index + detail files):*
- Index entries match `- **<id>** <Title> — `STATUS` — [detail](specs/<id>.md)`, with a valid status and unique ids
- Every index entry has a `specs/<id>.md`; every detail file is indexed (no orphans)
- A detail file's front-matter `id` matches its filename, and it carries **no status** (single-source in the index)
- Each detail file has the expected sections; `## Value` reads as a user story
- Any `deferrals:` front-matter is well-formed, and no `DONE` spec has an unresolved deferral (the `DONE`-gating rule — same `flow-preflight.sh` the guards and `/flow:ship` use)
- DONE specs have no unchecked `- [ ]` acceptance criteria; the archive holds only DONE/SUPERSEDED
- (Greenfield only) Walking Skeleton `0.1` is present

**Severity levels:** `ERROR` (must fix — breaks `/flow:run` parsing or creates contradiction), `WARNING` (should fix — will cause drift over time), `INFO` (consider — best practice not met).

**`--fix`** auto-corrects safe mechanical issues: index status-keyword casing, entry format, and archival (moving DONE/SUPERSEDED entries to `## Archive` + their detail to `specs/archive/` — a flat file, or a whole `specs/<id>/` directory). Never modifies CLAUDE.md content or resolves ambiguous issues.

**`--migrate`** converts a legacy inline `SPECIFICATIONS.md` (`### Spec` blocks with `**Status:**` lines) to the index + `specs/<id>.md` model — dry-run by default, non-destructive (backs up, preserves unclassified content, idempotent). **`--migrate <id>`** is the other conversion: it git-moves one flat spec `specs/<id>.md` → the directory form `specs/<id>/<id>.md` (so it can hold task files) and repoints the index — also dry-run by default, contents untouched.

---

## Hooks

Where `/flow:lint` is the audit you run on demand, hooks are the seatbelt that's always on. A [Claude Code hook](https://docs.anthropic.com/en/docs/claude-code/hooks) is a script that fires automatically on events in Claude's loop — the toolkit uses them to enforce its file-format invariants deterministically, with zero tokens spent and no reliance on Claude remembering the rules.

### The hook suite

| Hook | Event | What it does |
|---|---|---|
| `flow-spec-guard.sh` | After every file edit | Validates the spec index entries and `specs/<id>.md` detail files the moment they change |
| `flow-claude-guard.sh` | After every file edit | Enforces CLAUDE.md line caps — 300 root, 200 subdirectory by default ([configurable per project](#customizing-the-claudemd-line-caps)) |
| `flow-commit-guard.sh` | Before every `git commit` | Conventional Commit message format + spec file must be valid to commit + no `DONE` spec with an unreconciled deferral + soft nudge on spec-less work + soft `[#id]` subject-tag nudge |
| `flow-session-brief.sh` | Session start | Injects a one-line backlog orientation into every new session |

All four exit instantly when they don't apply (non-spec file, non-commit command, project without a spec file) — running them globally costs nothing in projects that don't use the toolkit.

Alongside them the installer copies **`flow-preflight.sh`** — not an event hook but a shared, unit-tested helper that is the *single source of truth* for four machine-checkable rules: `git-state` (release-branch hygiene), `resolved` (the deferral `DONE`-gating rule), `wellformed` (deferral front-matter shape), and `autonomy` (resolves a spec's `checkpoint`/`auto-build` mode by precedence — see [Autonomy](#autonomy--sub-agents)). The spec/commit guards, `/flow:run`, `/flow:lint`, and `/flow:ship` all call it, so a rule is defined once and can't drift between the always-on guard and the on-demand command. A human can run it directly too (`bash ~/.claude/hooks/flow-preflight.sh git-state --repo .`).

**`flow-spec-guard.sh`** validates on every edit to a spec file:

- On the **index** (`SPECIFICATIONS.md`): each entry matches `- **<id>** <Title> — `STATUS` — [detail](specs/<id>.md)` — alphanumeric id (e.g. `2.37a`, `P.10`, `BL-12`), em dashes, a valid status (`NOT STARTED · IN PROGRESS · PARTIAL · DONE · SUPERSEDED`), and no duplicate ids
- On a **detail file** (`specs/<id>.md`, or the directory form's orchestrator `specs/<id>/<id>.md` and task files `specs/<id>/<id>.T<n>.md`): it carries **no** status field (status is single-source in the index), its front-matter `id` matches the filename stem, and any `deferrals:` entries are well-formed (each has `what`/`why`/`to`) — delegated to `flow-preflight.sh`. A **task file** also gets a soft "no local AC" nudge (never a block) when it lacks a `Done when` checkbox
- A legacy inline `SPECIFICATIONS.md` is detected and passed with a one-line `/flow:lint --migrate` advisory — never blocked, so a pre-migration repo stays editable

It also emits a **soft bloat warning** (a nudge, never a block) when a `specs/<id>.md` grows past a line budget — default 120, overridable via `spec.maxLines` in `.flow-toolkit.json` (the same file as the CLAUDE.md caps; see [Customizing the CLAUDE.md line caps](#customizing-the-claudemd-line-caps)). The same principle as the CLAUDE.md caps, applied to spec detail files: a terse spec keeps the working set lean.

On failure the guard blocks with the error list, and — this is the key difference from a git hook — **Claude reads the errors and fixes the file in the same turn**. Format drift gets corrected the moment it's introduced instead of surfacing weeks later in a lint run. The parsing is unit-tested (`hooks/hooks.test.sh`), and CI (`.github/workflows/test.yml`) runs that harness on every push/PR to `main` — so `/flow:ship`'s CI gate has something real to check.

**`flow-claude-guard.sh`** catches guardrail bloat at the moment of creation. A CLAUDE.md over its cap isn't a style problem — it's wasted context in every session, forever. When Claude pushes a file over the limit, the block message tells it to trim now: move detail to subdirectory files, delete what's derivable from code. The caps default to 300 lines (root) and 200 (subdirectory), and are [configurable per project](#customizing-the-claudemd-line-caps) when a codebase genuinely needs more room.

**`flow-commit-guard.sh`** runs these checks before any commit: the message follows Conventional Commits (`/flow:ship` derives version bumps from commit types, so a malformed message silently breaks releases); `SPECIFICATIONS.md` passes validation (catches hand edits that bypassed the edit-time guard); no `DONE` spec carries an unreconciled deferral (the `DONE`-gating rule, via `flow-preflight.sh` — local mode, where the index reveals which specs are `DONE`); and — as notes to Claude, never blocks — it flags commits that stage source changes while no spec is `IN PROGRESS`, and, when **exactly one** spec *is* `IN PROGRESS` but the subject carries no bracket tag, nudges the exact `[#<id>]` to prepend. The Conventional-Commit check accepts an optional leading issue-tracker tag in brackets (e.g. `[#123] feat: …`, `[JIRA-45] fix: …`) so teams that prefix commits with a work-item id still pass; the type stays parseable for `/flow:ship`.

**Why the `[#id]` nudge matters:** `/flow:ship` derives which specs are in a release from the `[#id]` tags on commits since the last tag. Tagging the subject (which `/flow:run` does automatically, and the guard nudges when missing) lets that gate run mechanically off `git log` instead of falling back to guessing from the index.

**`flow-session-brief.sh`** injects ~30 tokens of orientation into each new session in a flow project:

```
flow-toolkit: Spec 1.1 — User Authentication is IN PROGRESS · 12 NOT STARTED · 8 DONE — run /flow:run for the board
```

*Deliberately not included:* a `Stop`-event "did you update the checklist?" nudge. It can't reliably distinguish work-in-progress from forgetfulness, so it fires constantly on normal WIP — a hook that cries wolf gets disabled. The commit guard's soft nudge covers the same ground at the moment that actually matters.

### How they're installed

For each detected profile, the install scripts copy `hooks/*.sh` to that profile's `hooks/` and merge the registrations from `hooks/hooks.json` into its `settings.json` (e.g. `~/.claude/hooks/` and `~/.claude/settings.json` for the default profile). The merge is **additive and idempotent**: your existing permissions and hooks are untouched, a `settings.json.bak` backup is written first, and each hook is registered at most once no matter how many times you re-run the installer. Hook scripts are written in bash and run everywhere — on Windows, Claude Code executes hooks through Git Bash (which you already have, since you cloned this repo).

**To remove:** delete the entries whose command mentions a `flow-*.sh` script from `~/.claude/settings.json` and the scripts from `~/.claude/hooks/`.

### Customizing the CLAUDE.md line caps

The line caps enforced by `flow-claude-guard.sh` (and reported by `/flow:lint`) default to **300 lines** for the root `CLAUDE.md` and **200 lines** for each subdirectory `CLAUDE.md`. These defaults suit most projects — the whole point of the cap is that every line loads into context on *every* session, so leaner is better.

When a codebase genuinely needs more room, raise either cap per project with a `.flow-toolkit.json` file at the **repo root** (next to `.git`):

```json
{
  "claudeMd": {
    "rootMax": 400,
    "subdirMax": 250
  },
  "spec": {
    "maxLines": 150
  }
}
```

- Any key may be omitted to keep its default (`spec.maxLines` defaults to **120**).
- The file is read fresh on every edit — no reinstall needed. Commit it so the whole team (and CI) shares the same caps.
- Precedence is simply: the value in `.flow-toolkit.json` if present, otherwise the built-in default.

Both the always-on guard hook and the on-demand `/flow:lint` audit read the same config, so they never disagree. Raising the CLAUDE.md caps is a deliberate, visible act — when the guard blocks at the default, its message points you at this knob; when it blocks against a raised cap, the message names the config file the limit came from.

`spec.maxLines` is the one knob here that only ever **warns** — a `specs/<id>.md` over the budget is a nudge to tighten it (one job per section, no cross-section restatement, append-only one-line Progress log), never a block, because specs legitimately vary in size. `flow-spec-guard.sh` surfaces it on edit and `/flow:lint --specs` reports it as `INFO`.

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

**When a project command is worth generalizing:** Cortex Golf's `gs-opportunity-hunt` — a persona-driven, web-researched feature-ideation command — proved useful enough to lift into the portable toolkit as [`/flow:hunt`](#flowhunt). The portable version derives its domain frame (personas, competitors, research dimensions, product thesis) from each project's own docs instead of hardcoding the domain. Keep a `gs-`/project-prefixed command only when it depends on something truly project-specific; if the pattern is generic with the domain swapped out, it belongs in the toolkit.

---

## Updating

Plugin install (recommended) — versioned, in-session:

```
/plugin update flow@flow-toolkit
```

Then restart Claude Code (or `/reload-plugins`).

Fallback installer — `git pull` + reinstall:

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

> ⚠️ **The fallback installer overwrites.** It force-copies the toolkit's `commands/*.md`, skills, and agents over whatever is in each detected profile, so in-place edits to installed files are replaced. Keep customizations in the toolkit's source (so they survive `git pull`) or as project-prefixed commands in a project's own `.claude/commands/`. The plugin path avoids this — its files live in the versioned plugin cache.

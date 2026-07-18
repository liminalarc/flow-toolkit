# flow-toolkit — Guide (how to use it)

The complete usage manual: every command, skill, sub-agent, and hook, with examples —
and, for each skill, **exactly when its sub-agents get dispatched**.

- The [README](../README.md) is the front door (install + the 5-command loop).
- [how-it-works.md](how-it-works.md) is the visual model (five diagrams).
- [architecture.md](architecture.md) is the design decision record (why it's shaped this way).
- **This file** is the deep how-to.

## Contents

- [1. Mental model in 60 seconds](#1-mental-model-in-60-seconds)
- [2. Core concepts](#2-core-concepts)
  - [2.1 The spec model — index + detail files](#21-the-spec-model--index--detail-files)
  - [2.2 The CLAUDE.md hierarchy](#22-the-claudemd-hierarchy)
  - [2.3 Backends — local vs ado](#23-backends--local-vs-ado)
  - [2.4 Autonomy — checkpoint vs auto-build](#24-autonomy--checkpoint-vs-auto-build)
  - [2.5 Deferrals — the no-silent-scope-narrowing rule](#25-deferrals--the-no-silent-scope-narrowing-rule)
  - [2.6 The validation done-gate — declared per-spec](#26-the-validation-done-gate--declared-per-spec)
- [3. Commands & skills, with examples](#3-commands--skills-with-examples)
  - [/flow:init](#flowinit) · [/flow:run](#flowrun) · [/flow:hunt](#flowhunt) · [/flow:review](#flowreview) · [/flow:pr](#flowpr) · [/flow:validate](#flowvalidate) · [/flow:ship](#flowship) · [/flow:lint](#flowlint)
- [4. The sub-agent catalog](#4-the-sub-agent-catalog)
- [5. The hooks (the always-on seatbelt)](#5-the-hooks-the-always-on-seatbelt)
- [6. Worked walkthroughs](#6-worked-walkthroughs)
- [7. Customizing — .flow-toolkit.json](#7-customizing--flow-toolkitjson)
- [8. Cheat sheet](#8-cheat-sheet)

---

## 1. Mental model in 60 seconds

flow-toolkit is **prompts + scripts, not an app**. Four moving parts:

1. **A spec model** — a lightweight *index* (the backlog, status lives here) plus one *detail file* per spec. `/flow:run` reads the tiny index to orient, then loads only the one spec it's working on.
2. **A `CLAUDE.md` hierarchy** — the rules Claude reads every session: root always loads; a subdirectory file loads only when Claude works in that directory.
3. **Skills & commands** — `/flow:*` entry points. Heavy, path-dependent ones are **skills** (`run`, `hunt`, `review`, `pr`); thin deliberate ones are **commands** (`init`, `lint`, `ship`).
4. **Hooks** — always-on bash guards that enforce file-format invariants deterministically (zero tokens), all funnelling machine-checkable rules through one helper, `flow-preflight.sh`.

The loop is: **`/flow:run`** to see the backlog → **`/flow:run <id>`** to plan-then-build one spec (it pauses for your sign-off by default) → **`/flow:ship`** to cut a release. Everything else supports that loop.

**Where sub-agents come in:** the build path of `/flow:run` and the three audit skills (`hunt`, `review`, `pr`) fan work out to isolated-context sub-agents. [Section 4](#4-the-sub-agent-catalog) is the catalog; each skill in [Section 3](#3-commands--skills-with-examples) says exactly when its agents fire.

---

## 2. Core concepts

### 2.1 The spec model — index + detail files

A spec = **one index entry** + **one detail file**. The split keeps the working set lean: the index is tiny (whole backlog at a glance), and only the one detail file being worked is read into context.

**The index** (local mode = `SPECIFICATIONS.md`) is the lifecycle ledger — id, title, **status** (single source of truth), phase grouping, order, link:

```markdown
## Phase 1 — Core Features
- **1.1** User Authentication — `IN PROGRESS` — [detail](specs/1.1.md)
- **1.2** Password Reset — `NOT STARTED` — [detail](specs/1.2.md)

## Archive
- **0.0** Spike: auth options — `SUPERSEDED` — [detail](specs/archive/0.0.md)
```

**A detail file** (`specs/<id>.md`) holds everything else and carries **no status field** (status is owned by the index):

```markdown
---
id: 1.1
title: User Authentication
links: []
# validate:         # OPTIONAL — declare a UI/UX validation target (see §2.6)
#   target: login
#   intent: "a returning user signs in and lands on their dashboard"
#   lens: [ui, ux]  # optional — default both
# deferrals:        # OPTIONAL — only if something in scope was deferred
#   - what: "SSO login"
#     why: "scope; password login first"
#     to: 1.4        # `built`, or the spec id that now owns it
---

## Problem       <why this exists; what "shipped" means>
## Value         As a <role> I want <capability> so that <benefit>.
## Scope         **In:** …  **Out:** …
## Acceptance criteria
- [ ] <criterion> — <how proven>
## Plan (thin slices)
## Decisions
## Verification / evidence
## Progress log
```

**Two shapes.** Most specs are a **flat** `specs/<id>.md`. A spec that grows large earns a **directory** — an orchestrator plus task files:

```
specs/1.7/
  1.7.md       # orchestrator — Problem/Value/Scope/AC/Plan/…, owns status + deferrals
  1.7.T1.md    # task file — the "how" for one slice + a local "Done when" AC
  1.7.T2.md
```

Break out by a manual guideline — **≥3 tasks, or a task with its own AC** — never enforced. The orchestrator owns status and deferrals (the guards gate on it alone); task files carry a **local AC** (the "Done when" seam an implementer builds to and a verifier checks against) and **no status**. Reshape a flat spec to a directory with `/flow:lint --migrate <id>`.

**Status vocabulary** — exactly one per index entry: `NOT STARTED · IN PROGRESS · PARTIAL · DONE · SUPERSEDED`.

**Archival** — when a spec is DONE/SUPERSEDED, `/flow:run` moves its index entry to `## Archive` and its detail to `specs/archive/<id>.md` (or the whole `specs/<id>/` dir). **Ids are never reused** — "closes 2.3" stays meaningful forever.

**Terseness by rule** — a detail file is read every time its spec is worked, so bloat is wasted budget. `/flow:run --add` authors to three rules (one job per section, shortest lossless form, append-only one-line Progress log); a soft line budget (default 120, `spec.maxLines`) *warns* on drift but never blocks. `/flow:run --condense` is the judgment pass that tightens an existing spec losslessly.

### 2.2 The CLAUDE.md hierarchy

Engineering principles Claude reads every session — a set of rules that keep sessions pointed the same direction (TDD mandate, testing stack, architecture, commit format, named patterns).

- **Root `CLAUDE.md`** always loads: architecture overview, development rules, feature-completion checklist, project structure.
- **Subdirectory `CLAUDE.md`** loads only when Claude works in that directory: layer-specific patterns and conventions.
- **They stack, they don't swap** — working in `server/` loads root + `server/CLAUDE.md`, not `web/`. So: universal rules in root, layer detail in subdirectories, **never duplicate root content** in a subdirectory file.

**Line caps** keep them lean: root ≤ 300 lines, subdirectory ≤ 200 (raise per project via `.flow-toolkit.json` — see [Section 7](#7-customizing--flow-toolkitjson)). `flow-claude-guard.sh` blocks a breach at the moment of creation; `/flow:lint --claude` audits on demand.

**Don't put in CLAUDE.md:** code patterns derivable from the code, git history, ephemeral task state.

### 2.3 Backends — local vs ado

The backend is set by an optional `.flow/config.yml`. **Absent ⇒ local mode** (the default; nothing to configure).

- **`local`** — the index is `SPECIFICATIONS.md`; `/flow:run` owns the full lifecycle; ids are `Phase.Spec` (`1.2`, `2.37a`); the status vocabulary is used directly (no translation).
- **`ado`** — the **board is the index** (no `SPECIFICATIONS.md`); ids are work-item numbers (`specs/642103.md`); the board owns the state machine, so a `state_map` translates each board state → a canonical token. The board may live in a **different ADO project/org than the repo** — only the `specs/<id>.md` detail files live in the repo. Flow's card writes are **propose-only**: it transitions state on your sign-off and refreshes one "Spec:" pointer comment — never reprioritizing, reassigning, or closing a card unprompted.

The `specs/<id>.md` detail files are **byte-for-byte the same shape** in both modes; only *where lifecycle is owned* changes. Set up ado with `/flow:init --backend ado` (it auto-builds the `state_map` from ADO state categories).

### 2.4 Autonomy — checkpoint vs auto-build

Autonomy controls **exactly one thing**: whether `/flow:run` pauses for *plan approval*. It never bypasses Claude Code's permission system, edits config, or self-approves.

| Mode | Plan approval | Verifier |
|---|---|---|
| `checkpoint` *(default)* | pauses for your sign-off before any code is written | **advisory** — informs you; you're already in the loop |
| `auto-build` | no pause (the plan is still written + committed first) | **blocking** — a `FAIL` doesn't integrate: one bounded retry, then it escalates back to `checkpoint` and hands you the verdict |

Set it per spec via `autonomy: checkpoint | auto-build` front-matter, or repo-wide in `.flow-toolkit.json`:

```json
{ "autonomy": { "default": "checkpoint", "force": "auto-build" } }
```

Precedence (resolved once by `flow-preflight.sh autonomy`, so it can't drift): `autonomy.force` > the spec's front-matter > `autonomy.default` > builtin `checkpoint`.

### 2.5 Deferrals — the no-silent-scope-narrowing rule

Scope only ever narrows by **your** decision, never Claude's. The moment Claude is about to drop or narrow something a spec put in scope — at plan-time, mid-build, or done-time — it stops and runs the **deferral protocol**:

1. It states *why* it would defer (cost, missing dependency, scope creep, risk).
2. You decide, per item: **(a) build it here**, or **(b) re-home it** to a new or existing spec (cross-linked both ways).

Each decision is recorded as a machine-readable `deferrals:` front-matter entry — not just prose:

```yaml
deferrals:
  - what: "import from file"          # what was cut
    why: "scope; paste-only shipped"  # the reason
    to: 1.6                           # `built` (done here), or the spec id that now owns it
```

**The DONE-gate:** a spec **cannot reach `DONE`** while any deferral has an unresolved `to`. This is enforced identically in three places by one helper (`flow-preflight.sh resolved`): the commit guard blocks it, `/flow:lint` reports it, and `/flow:ship`'s preflight gates on it. So "quietly built less than asked" stops being a failure mode the workflow allows.

### 2.6 The validation done-gate — declared per-spec

A spec that touches the interface can declare a **validation target** in its front-matter. When it does, `/flow:run`'s done-step **dispatches the `flow-ux-validator` agent** (the same one `/flow:validate` drives) before flipping `DONE` — so UI/UX findings are caught under the build gate instead of only when someone remembers to run `/flow:validate`. It's **opt-in per spec**: no `validate:` block ⇒ the gate is a **pure no-op**, zero friction on specs that don't touch UI.

```yaml
validate:
  target: checkout                                        # one screen or flow
  intent: "a new user buys one item and reaches confirmation"  # required with target
  lens: [ui, ux]                    # optional — default both; ui = design-system, ux = task+friction
  design_system: design/tokens.md   # optional — else .flow/validate/* (spec 1.16) / infer from source
```

At the done-gate `/flow:run` reads the block and dispatches **one `flow-ux-validator` per lens, serially** (driving a live app is stateful — concurrent drivers would collide). The design-system pointer resolves by precedence: the block's `design_system` > the project's persisted `.flow/validate/*.md` (spec 1.16, when present) > infer from source. Then:

- **Findings are triaged before `DONE`** — each open finding is either fixed here (the lens is re-run to confirm) or explicitly re-homed through the [deferral protocol](#25-deferrals--the-no-silent-scope-narrowing-rule) (which records a `deferrals:` entry and mechanically gates `DONE`). No untriaged finding survives to `DONE`.
- **`NOT APPLICABLE` passes cleanly** — a repo with no drivable UI (backend-only, CLI, infra) gets the verdict shown and the gate proceeds. Declaring `validate:` on an undrivable repo is a mistake to surface, never a hard stop, and never an invented critique.

Standalone, the same agent runs on demand via [`/flow:validate`](#flowvalidate); the done-gate is that agent wired into the lifecycle.

---

## 3. Commands & skills, with examples

Every entry point lives under the `flow:` namespace. **Skills** (`run`, `hunt`, `review`, `pr`) load only the path you invoke and can fan out to sub-agents; **commands** (`init`, `lint`, `ship`) run inline.

### /flow:init

Bootstrap a new project or adopt an existing one. **Dispatches no sub-agents.**

```
/flow:init                                          # answer everything conversationally
/flow:init Task SaaS — Next.js web, Python API, Postgres   # skip the first question
/flow:init --adopt                                  # force adopt-mode on an existing repo
/flow:init --greenfield                             # force skeleton scaffolding
/flow:init --backend ado                            # track the backlog on an ADO board
```

It reads any existing `CLAUDE.md`/`SPECIFICATIONS.md` (extends rather than overwrites), asks 2-3 focused questions (what it does, stack, layers), then generates the root + subdirectory `CLAUDE.md` files, the spec model (Walking Skeleton `0.1` on greenfield; a real backlog on adopt), and `MARKETING.md` for user-facing projects. Safe to re-run as the project evolves.

### /flow:run

The primary development command — all backlog management and implementation. A **skill** that routes by invocation and loads only that path's reference.

```
/flow:run                       # show the backlog, suggest the next spec
/flow:run 2.3                   # plan + build spec 2.3
/flow:run "add dark mode"       # free-form; maps to a spec or offers --add
/flow:run --add                 # co-author a new spec (index entry + detail file)
/flow:run --ideas               # fast three-lens brainstorm
/flow:run --clean               # normalize the index formatting/status
/flow:run --condense 2.3        # rewrite one spec to the terseness rules (losslessly)
/flow:run --condense --all --check   # audit terseness across the backlog, don't rewrite
```

**> When agents fire:** only on the **build path** (`/flow:run <id>` or a description that maps to a spec), and only **after** the plan is settled (after sign-off in `checkpoint`; immediately after the plan is written in `auto-build`). For each task/layer:
> - one **`flow-implementer`** builds it to the task's local AC (worktree-isolated when layers run in parallel), then
> - one **`flow-verifier`** independently checks that diff before it integrates — **blocking** under `auto-build`, **advisory** under `checkpoint`.
>
> A single-layer spec in `checkpoint` mode may be built inline (verifier still runs, advisory). The backlog view, `--ideas`, `--add`, `--clean`, and `--condense` paths dispatch **no agents**.

The build cycle is Understand → Plan → **Checkpoint** → Build (test-first, per-slice commits tagged `[id]`) → Done (restart services, smoke-test end-to-end, verification checklist, status → DONE, archive). See the [full walkthrough](#61-a-full-spec-start-to-finish-checkpoint).

**Validation done-gate.** If the spec carries a `validate:` block, the done-step dispatches the **`flow-ux-validator`** agent (one per lens, serially) and triages its findings before flipping `DONE` — the [validation done-gate](#26-the-validation-done-gate--declared-per-spec). No block ⇒ no-op.

### /flow:hunt

The deep, researched twin of `/flow:run --ideas`. A **skill** that grounds itself in *this* project's domain, then produces a scored opportunity report.

```
/flow:hunt                      # offline: reason from project docs + model knowledge
/flow:hunt --deep               # + live fan-out web research (cites sources)
/flow:hunt social retention     # narrow to a focus area
/flow:hunt --deep arccos        # narrowed + web research
```

It runs in phases: **Phase 0** derives the domain frame (product thesis, a 3-5 persona panel, competitor set, and 4-6 research dimensions) from your `CLAUDE.md`/`MARKETING.md`/`README.md` and **checkpoints it for your correction**; **Phase 1** grounds in the backlog so nothing already planned is re-proposed; **Phase 2** fans out; **Phase 3-4** dedupe, score (Impact × Effort), and produce 5-10 opportunities each ending in a `/flow:run --add`-ready spec seed.

**> When agents fire:** in **Phase 2**, *after* you approve the frame — one **`flow-researcher`** per research dimension (typically 4-6), launched **in parallel**. Each is read-only, reasons through the whole persona panel on its one dimension, and (with `--deep`) runs live web searches citing sources. The main thread then dedupes and synthesizes. It **proposes only** — never writes specs or code.

### /flow:review

Structured multi-lens audit. A **skill** that loads only the lens rubric you invoke.

```
/flow:review               # all four lenses
/flow:review --docs        # documentation accuracy/freshness/coverage
/flow:review --ux          # UX friction, states, consistency
/flow:review --marketing   # positioning, value communication, pricing
/flow:review --product     # power-user critique, friction, drop-off
```

**> When agents fire:** immediately — one **`flow-reviewer`** per requested lens (up to 4), launched **in parallel**, each loading only its own rubric (`reference/<lens>.md`). Each is read-only and returns prioritized findings (location + problem + concrete fix). The main thread synthesizes — a single lens's findings, or (no flag) a cross-lens summary of the highest-priority items. Reviewers never edit; the main thread applies significant fixes only after you confirm.

### /flow:pr

Spec-aware PR/branch review — "is this the code the spec asked for, built the way this project builds things?" A **skill**.

```
/flow:pr                   # current branch vs main
/flow:pr 42                # GitHub PR #42 (via gh)
/flow:pr feature/auth      # a branch by name
/flow:pr --spec            # spec fidelity only
/flow:pr --quality         # correctness + clean code only
/flow:pr --tests           # test coverage only
```

**Phase 1** (main thread) resolves the exact diff refs and identifies the spec under review (from PR title/branch/commit tags). **Phase 3** synthesizes a verdict (`READY` / `READY WITH NITS` / `NEEDS WORK`), a spec scorecard, and findings grouped `BLOCKER` / `SHOULD FIX` / `NIT`.

**> When agents fire:** in **Phase 2**, after the diff is resolved — one **`flow-pr-reviewer`** per dimension (spec / quality / tests; up to 3), launched **in parallel**. Each reads the diff itself (it has Bash), audits against its rubric, and returns findings; the `tests` reviewer runs the suite and the `spec` reviewer returns the per-criterion scorecard. A failing suite is an automatic `NEEDS WORK`. It never posts, approves, or merges unless you explicitly ask.

### /flow:validate

Drive the **running app** and validate its interface against a rubric — the live-driving complement to `/flow:review`'s static UX lens. **Dispatches the `flow-ux-validator` sub-agent** (the only agent that runs the app).

```
/flow:validate checkout --intent "a new user buys one item and reaches confirmation"   # both lenses
/flow:validate login --intent "…" --ui       # UI lens only — design-system conformance
/flow:validate login --intent "…" --ux       # UX lens only — task completion + friction
/flow:validate login --intent "…" --design-system design/tokens.md   # point at the design system
```

Two lenses: **UI** (does the screen conform to the design system) and **UX** (can a user complete the intended flow, at what friction, vs Nielsen heuristics + WCAG). Scoped to one screen/flow per run; the rubric = the toolkit's baseline (`reference/{ui,ux}.md`) merged with your project specifics (`--intent` + design system, or infer from source).

**> When agents fire:** immediately — one **`flow-ux-validator`** per requested lens, dispatched **serially** (unlike `/flow:review`'s parallel fan-out: driving one live app concurrently would collide). Each agent runs its applicability check first — a repo with no drivable UI gets a clean `NOT APPLICABLE` verdict, never an invented critique — then drives (Playwright-first, vision fallback), captures screenshots, scores its lens, and returns prioritized findings. Read-only: it drives and judges, never edits or auto-fixes. The main thread synthesizes and proposes fixes only on your confirm. The **same agent** is reused by `/flow:run`'s done-gate (spec 1.15).

### /flow:ship

Cut a release. Reads `CLAUDE.md` for the project's deploy mechanism. **Dispatches no sub-agents.**

```
/flow:ship
/flow:ship --dry-run       # run the full preflight, print version/changelog/tag, don't tag
```

It runs a **programmatic preflight** (each pre-req an explicit ✅/❌/⚠️, never a silent pass): auto-remediable git state (offers the fix confirm-first), gate-able checks (every spec in the release is `DONE`, derived from `[id]` commit tags and cross-checked against the index; CI green via `gh`), and judgment checks (no unreconciled deferrals). Then it proposes a version bump from conventional-commit history, **confirms with you**, tags, and reports what to verify. The git-state and deferral checks are the same `flow-preflight.sh` the guards use.

### /flow:lint

Audit the CLAUDE.md hierarchy + spec integrity. **Dispatches no sub-agents.**

```
/flow:lint                 # full audit
/flow:lint --claude        # CLAUDE.md hierarchy only
/flow:lint --specs         # spec index/detail only
/flow:lint --fix           # auto-fix safe mechanical issues (casing, format, archival)
/flow:lint --migrate       # convert a legacy inline SPECIFICATIONS.md → index + specs/ model
/flow:lint --migrate 1.7   # git-move a flat spec → the directory form
```

Checks (with severity `ERROR` / `WARNING` / `INFO`): CLAUDE.md caps + required sections + no root-duplication; index entry format + valid/unique statuses; every entry has a detail file and vice-versa; detail-file `id` matches filename and carries no status; `## Value` reads as a user story; deferral well-formedness + the DONE-gate; DONE specs have no unchecked AC; archive holds only DONE/SUPERSEDED. `--fix` never touches CLAUDE.md *content* or resolves ambiguous issues.

---

## 4. The sub-agent catalog

Six isolated-context sub-agents. Only the **implementer** writes; the other five are **read-only** (they report; the main thread decides and applies). Each runs in its own context, so the main thread stays lean and parallel units don't collide.

| Agent | Dispatched by | When | R/W | Returns |
|---|---|---|---|---|
| **flow-implementer** | `/flow:run` build path | Per task/layer, post-plan; worktree-isolated when parallel | **write** (code) | A diff + report: what it built, tests run, files touched, any out-of-scope items hit |
| **flow-verifier** | `/flow:run` build path | After each implementer, before integration | read-only | `VERDICT: PASS\|FAIL` + per-criterion `MET/UNMET/UNCONFIRMED` + test result |
| **flow-researcher** | `/flow:hunt` | Phase 2, one per research dimension, parallel | read-only | Scored opportunity candidates (insight, user problem, angle, gap, Impact×Effort, spec seed) |
| **flow-reviewer** | `/flow:review` | One per lens, parallel | read-only | Prioritized findings (location + problem + suggested fix) for its lens |
| **flow-pr-reviewer** | `/flow:pr` | Phase 2, one per dimension, parallel | read-only | Findings (`BLOCKER/SHOULD FIX/NIT` + `file:line` + fix); scorecard (spec) or test result (tests) |
| **flow-ux-validator** | `/flow:validate` (+ `/flow:run` done-gate) | One per lens, **serial** (drives a live app) | read-only (drives + judges, never fixes) | Applicability verdict + prioritized UI/UX findings (screen/step + rule + suggested direction) |

**Shared boundaries** (why the safety net holds):

- **The implementer never touches lifecycle state** (index, status, `deferrals:`) and never widens scope silently — if it hits out-of-scope work it stops and reports; the main thread runs the deferral protocol.
- **The verifier never fixes** — it has no Edit/Write tools by design; a verifier that patches its own findings is no longer independent. It defaults to `FAIL` when it can't confirm a criterion.
- **The three auditors (researcher/reviewer/pr-reviewer) never edit** and **stay in their one unit** — the fan-out's value is that each is focused and blind to the others; the main thread does cross-unit synthesis.
- **The validator drives but never fixes** — the only read-only agent that *runs* the app. It writes throwaway screenshots to a scratch dir (never under the project tree) and **abstains** (`NOT APPLICABLE`) rather than critique an app it couldn't drive.
- **None self-approve or bypass permissions** — every agent runs under the same Claude Code permission system; a denied action is a signal to report, not route around.

**Freshly installed?** New agents/skills dispatch by name only after a Claude Code **restart** (or `/reload-plugins`).

---

## 5. The hooks (the always-on seatbelt)

Where `/flow:lint` is the audit you run on demand, hooks are always on. Each fires on a Claude Code event, enforces a file-format invariant deterministically (zero tokens), and — critically — **exits instantly when it doesn't apply**, so unrelated projects pay nothing.

| Hook | Event | What it does |
|---|---|---|
| `flow-spec-guard.sh` | PostToolUse (Edit\|Write) | Validates index entries + `specs/<id>.md` detail files the moment they change |
| `flow-claude-guard.sh` | PostToolUse (Edit\|Write) | Enforces CLAUDE.md line caps (300 root / 200 subdir, or `.flow-toolkit.json`) |
| `flow-commit-guard.sh` | PreToolUse (Bash) | Conventional-commit format + spec validity + deferral DONE-gate + soft `[id]`/spec-less nudges |
| `flow-session-brief.sh` | SessionStart | Injects ~30 tokens of backlog orientation into each new session |

The key difference from a git hook: when a guard blocks, **Claude reads the error and fixes the file in the same turn** — format drift is corrected the moment it's introduced.

**`flow-preflight.sh` is the single source of truth** — not an event hook but a shared, unit-tested helper the guards *and* the commands all call, so a rule is defined once. Four rules live only here:

- `git-state` — release-branch hygiene (prints ✅/❌/⚠️ + the exact remediation command; never runs it).
- `resolved` — the deferral DONE-gate (no `DONE` spec with an unresolved `to`).
- `wellformed` — one detail file's `deferrals:` shape (each entry has `what`/`why`/`to`).
- `autonomy` — resolves a spec's `checkpoint`/`auto-build` mode by precedence.

You can run it directly: `bash ~/.claude/hooks/flow-preflight.sh git-state --repo .`

**Session brief example** (SessionStart output):

```
flow-toolkit: Spec 1.1 — User Authentication is IN PROGRESS · 12 NOT STARTED · 8 DONE — run /flow:run for the board
```

The parsing is unit-tested (`hooks/hooks.test.sh`) and CI runs that harness on every push/PR to `main`, so `/flow:ship`'s CI gate has something real to check.

---

## 6. Worked walkthroughs

### 6.1 A full spec, start to finish (checkpoint)

```
You:    /flow:run 2.3
Claude: [reads the index entry + specs/2.3.md, restates the problem]
        [presents a plan: thin slices, files touched, test strategy, Value story]
        — CHECKPOINT — waits. No code is written yet.
You:    "looks good, go"
Claude: writes/commits specs/2.3.md, sets 2.3 IN PROGRESS in the index
        builds test-first, one commit per slice, each tagged [2.3] feat: …
        [dispatches a flow-verifier on the diff — advisory in checkpoint — and shows you the verdict]
        restarts affected services, smoke-tests the behavior end-to-end
        shows a verification checklist (each AC ✅/⚠️ with what proved it)
        sets 2.3 DONE, archives the entry + detail
You:    /flow:ship
```

### 6.2 A cross-cutting spec — implementer/verifier fan-out (auto-build)

A spec touching `server/` + `web/`, with `autonomy: auto-build`:

```
/flow:run 3.1
  → plan written + committed (no approval pause — auto-build)
  → API contract / seam locked in the plan
  → fan out, in parallel:
       flow-implementer(server)  builds to the seam in an isolated worktree
       flow-implementer(web)     builds to the seam in an isolated worktree
  → for each returned diff:
       flow-verifier checks it vs that task's local AC → PASS | FAIL   (BLOCKING)
         FAIL → one bounded retry with the findings → still FAIL → escalate to checkpoint
         PASS → integrate
  → verify the seam where the layers meet
  → smoke-test, DONE, archive
```

The implementers never merge or touch status; the verifiers judge but never fix. Nothing integrates unverified.

### 6.3 An opportunity hunt — researcher fan-out

```
/flow:hunt --deep
  Phase 0: derive frame (thesis, persona panel, competitors, dimensions) — CHECKPOINT, you correct it
  Phase 1: ground in SPECIFICATIONS.md so nothing planned is re-proposed
  Phase 2: fan out, in parallel (one flow-researcher per dimension):
             competitor-intel · user-pain-points · domain-frontier · adjacent-signals · behavior-retention
           each reasons through the whole persona panel, runs live web searches, cites sources
  Phase 3-4: main thread dedupes across dimensions, scores Impact×Effort, produces 5-10 opportunities
             each ending in a /flow:run --add-ready spec seed
```

### 6.4 A PR review — pr-reviewer fan-out

```
/flow:pr 42
  Phase 1: resolve the diff (gh pr diff 42), find the spec ([id] in title/commits)
  Phase 2: fan out, in parallel:
             flow-pr-reviewer(spec)     walks the AC → scorecard
             flow-pr-reviewer(quality)  correctness + clean code vs CLAUDE.md patterns
             flow-pr-reviewer(tests)    runs the suite, checks TDD coverage
  Phase 3: main thread → verdict (READY / READY WITH NITS / NEEDS WORK) + scorecard + grouped findings
```

---

## 7. Customizing — `.flow-toolkit.json`

A single repo-root file (next to `.git`) tunes the toolkit per project. Any key may be omitted to keep its default; it's read fresh on every edit (no reinstall). Commit it so the team and CI share the same settings.

```json
{
  "claudeMd": { "rootMax": 400, "subdirMax": 250 },
  "spec":     { "maxLines": 150 },
  "autonomy": { "default": "checkpoint", "force": "auto-build" }
}
```

- **`claudeMd.rootMax` / `subdirMax`** — CLAUDE.md line caps (defaults 300 / 200). Both the always-on guard and `/flow:lint` read the same values, so they never disagree. Raising a cap is deliberate and visible — the block message names the config file the limit came from.
- **`spec.maxLines`** — the detail-file soft budget (default 120). This one **only ever warns** — a spec over budget is a nudge to tighten (one job per section, no cross-section restatement), never a block, because specs legitimately vary. Surfaced by `flow-spec-guard.sh` on edit and `/flow:lint --specs` as `INFO`.
- **`autonomy.default` / `force`** — see [2.4](#24-autonomy--checkpoint-vs-auto-build). `force` is a hard project override; `default` is the fallback when a spec is silent.

## 8. Cheat sheet

| I want to… | Run |
|---|---|
| See the backlog / pick next | `/flow:run` |
| Plan + build a spec | `/flow:run <id>` |
| Capture a new spec | `/flow:run --add` |
| Quick brainstorm (3 lenses) | `/flow:run --ideas` |
| Deep, researched opportunity hunt | `/flow:hunt` / `/flow:hunt --deep` |
| Tidy a bloated spec | `/flow:run --condense <id>` |
| Normalize the index | `/flow:run --clean` |
| Audit docs/UX/marketing/product | `/flow:review [--docs\|--ux\|--marketing\|--product]` |
| Review a PR/branch vs its spec | `/flow:pr [pr#\|branch]` |
| Validate live UI/UX (drive the app) | `/flow:validate <screen\|flow> --intent "…"` |
| Audit CLAUDE.md + specs | `/flow:lint` (`--fix` to auto-correct) |
| Reshape a flat spec → directory | `/flow:lint --migrate <id>` |
| Bootstrap / adopt a project | `/flow:init` |
| Cut a release | `/flow:ship` (`--dry-run` to preview) |

| Agents fire when… | Skill | Agent(s) |
|---|---|---|
| Building a spec (post-plan) | `/flow:run <id>` | `flow-implementer` → `flow-verifier` per task |
| Hunting opportunities (Phase 2) | `/flow:hunt` | `flow-researcher` × dimensions |
| Auditing a project | `/flow:review` | `flow-reviewer` × lenses |
| Reviewing a diff (Phase 2) | `/flow:pr` | `flow-pr-reviewer` × dimensions |
| Validating UI/UX (drives the app) | `/flow:validate` | `flow-ux-validator` × lenses (serial) |
| — never (run inline) | `/flow:init` · `/flow:lint` · `/flow:ship` | none |

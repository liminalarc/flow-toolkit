---
description: "Implement specs, manage backlog, brainstorm — /flow [spec#|--ideas|--add|--clean|description]"
---
# Flow

Conversational, fast development cycle. Implement specs, manage the backlog, brainstorm ideas. Reads `CLAUDE.md` and the project's spec model from the current project — works with any project initialized by `/flow-init`.

For rigorous spec work with formal investigation and sign-off requirements, use `/card-spec` → `/card-implement`.

Usage:
- `/flow` — show backlog status and suggest next item
- `/flow 2.84` — implement spec 2.84
- `/flow <description>` — implement described work
- `/flow --ideas` — brainstorm new features through three lenses
- `/flow --add` — co-author a new spec
- `/flow --clean` — normalize the index formatting and status

## The spec model

Every flow project stores specs as **an index + one detail file per spec**:

- **The index** — the lifecycle ledger: id, title, status, phase grouping, order (= priority within a phase), and a link to each spec's detail file. **Status lives only here** (single source of truth). In `local` mode this is `SPECIFICATIONS.md`; in `ado` mode the tracking board *is* the index.
- **`specs/<id>.md`** — the detail: Problem, Value (user story), Scope, Acceptance criteria, Plan, Decisions, Verification, Progress log. Carries **no status field** (status is owned by the index/board, never duplicated).

`/flow` reads the tiny index to see the backlog, then loads only the one `specs/<id>.md` in play — the working set stays lean by construction.

### Resolving the backend

Read `.flow/config.yml` at the project root (absent ⇒ all defaults):

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
    state_map: …                        # tracker state -> canonical status (see below)
```

**Status vocabulary is flow's own, single-source:** `NOT STARTED · IN PROGRESS · PARTIAL · DONE · SUPERSEDED`.

- **`local`** (default) → the index is `SPECIFICATIONS.md`; `flow` owns the full lifecycle and the index uses the canonical vocabulary **directly — no `state_map`** (there's nothing to translate). Spec ids are `Phase.Spec` (`1.2`, `0.1`, alphanumeric like `2.37a` allowed).
- **`ado`** → the **board is the index** (no `SPECIFICATIONS.md`); spec ids are the work-item numbers (`specs/642103.md`). The tracker owns the state machine, so `state_map` translates each **board state -> a canonical token** (defined once in `.flow/config.yml`, scaffolded by `/flow-init` — the command docs reference the vocabulary, they don't re-list the map). The board may live in a **different ADO project/org than this repo** — the `ado` coordinates are independent of the git remote; only the `specs/<id>.md` detail files live in this repo. Flow's card writes are **propose-only**: it transitions `System.State` on your sign-off and refreshes a single "Spec:" pointer comment, and **never** reprioritizes, reassigns, sets iteration, or closes a card unprompted. Prefer the tracking MCP tools (`wit_*`); if a call is unavailable or returns 401/403, announce the fallback and use the `az boards` CLI — never silently no-op (a green run that did nothing is the worst failure). If both fail, stop and report.

## Instructions

**Start fresh.** Read only from the project files — `CLAUDE.md`, `.flow/config.yml`, the index (`SPECIFICATIONS.md` or the board), the relevant `specs/<id>.md`, and `README.md`. Do not reference or build on prior conversation context. Treat this as a new session regardless of what preceded it.

**Resolve the backend first** (above) so every step below reads/writes the right place.

### `/flow` (no args)

Read the index. Show a concise summary: IN PROGRESS first, then NOT STARTED grouped by phase (local) or the equivalent states via `state_map` (ado). Suggest the next item by order/phase. Invite the user to pick or describe work.

- local: if `SPECIFICATIONS.md` doesn't exist, suggest `/flow-init`.
- ado: query open items under the configured area path (`NOT IN ('Closed','Removed')`). If the query returns nothing, say so plainly — never assume the backlog is empty without confirming the query ran.

### `/flow --ideas`

Read the index first to avoid re-suggesting existing specs. Brainstorm through three lenses:

1. **Sellable** — features that move acquisition, retention, or willingness-to-pay
2. **Profitable** — things that reduce cost or unlock a pricing tier
3. **Easy wins** — high-leverage, low-effort improvements a user would notice

3-5 ideas per lens. Offer to capture the best ones with `/flow --add`.

### `/flow --add`

Co-author a new spec. Ask: what is it, who is it for, what does success look like? Then create **both** the index entry and the detail file:

1. **Index entry** —
   - local: add a line under the right phase in `SPECIFICATIONS.md`: `- **<id>** <Title> — \`NOT STARTED\` — [detail](specs/<id>.md)`. Assign the next logical `Phase.Spec` number.
   - ado: create the work item (confirm the drafted fields first), then use the returned `#NNNNNN` as the id.
2. **Detail file** — write `specs/<id>.md` from the template below (Problem, Value user story, Scope, Acceptance criteria populated; Plan/Decisions/Verification/Progress scaffolded).

Show the draft (index line + detail) and confirm before writing.

**Detail file template** (`specs/<id>.md`):
```markdown
---
id: <id>
title: <Title>
links: []            # related spec ids or external URLs
# deferrals:         # OPTIONAL — omit entirely if nothing was deferred.
#   - what: "<what was cut>"
#     why: "<the reason>"
#     to: <id|built>  # `built` (done here) or the spec id that now owns it
---

## Problem
<why this exists; what "shipped" means>

## Value
As a <role> I want <capability> so that <benefit>.

## Scope
**In:** <what changes>
**Out:** <excluded; link the spec/id that owns it>

## Acceptance criteria
- [ ] <criterion> — <how proven>

## Plan (thin slices)
1. [ ] <slice> -> <commit sha once landed>

## Decisions
- YYYY-MM-DD — <decision + why>

## Verification / evidence
<how each AC is proven>

## Progress log
- YYYY-MM-DD `<sha>` — <what landed>
```

### `/flow --clean`

Normalize the **index** (local mode):
- Status keyword per entry: `DONE · IN PROGRESS · PARTIAL · NOT STARTED · SUPERSEDED`
- Entry format: `- **<id>** <Title> — \`STATUS\` — [detail](specs/<id>.md)`
- Every index entry links to an existing `specs/<id>.md`; every detail file is indexed; no duplicate ids.

Show a diff before writing. (In ado mode the board owns lifecycle — there's no local index to clean; use `/flow-lint` to check index↔detail integrity of the `specs/` dir.)

### `/flow <spec id>` or `/flow <description>`

1. **Understand.** Read the index entry for that id, and **if `specs/<id>.md` exists, read it and resume from its Plan/Progress log rather than re-deriving.** For free-form work, restate it and identify affected layers; ask 1-2 clarifying questions only when genuinely ambiguous.

   If a free-form description maps to an existing spec, say so and switch to it. If it's net-new and will produce commits, offer `/flow --add` first so there's an id to tag.

2. **Plan + CHECKPOINT.** Concise plan: thin vertical slices, files/layers touched, test strategy, risks, open questions. **The plan you present IS the draft detail file** — include the **Value** user story so it can be weighed against other specs. **Stop for sign-off before writing any code.**

   On sign-off, write/update `specs/<id>.md` (Problem, Value, Scope, AC, Plan, Decisions) and commit it. Then set the item IN PROGRESS in the index (local) or, if `Backlog`/`Ready`, offer to transition the card (ado, with a comment noting work started) — only after sign-off. For cross-cutting work, sign-off is where the API contract / seam is locked so parallel layers build to the same interface.

3. **Build test-first.** Follow the conventions in `CLAUDE.md` for this project. Keep commits small and — if the project tags commits with a spec/work-item id — tag them. Surface decisions as you go.

   - **Single-layer specs**: build inline, test-first, commit per slice.
   - **Cross-cutting specs** (multiple independent layers): after sign-off, spawn one worktree-isolated agent per layer with its slice + the full contract; run in parallel, merge, verify the seam. Skip layers with no independent work.

   If at any point you're about to drop or narrow something the spec put in scope, **run the deferral protocol** (below) — don't narrow scope silently.

4. **Definition of done.**
   - **Reconcile deferrals** — every in-scope item you didn't build has been run through the deferral protocol (built here, or re-homed to a spec by user decision), cross-linked, and recorded in the spec's `deferrals:` front-matter with a resolved `to`. This is **machine-checked** (`flow-preflight.sh resolved`): the commit guard blocks a `DONE` spec with an open deferral, so it **must** be clear before the spec reaches `DONE`.
   - **Restart & smoke-test** — before flipping status, get the change actually running and exercise it. **Restart every local service the change touched** (use the run/dev commands in `CLAUDE.md`/`README.md`) so nothing is serving stale code. Then **run an automated smoke test yourself wherever it's feasible** — drive the changed behavior end-to-end (hit the endpoint, run the flow, exercise the CLI/UI), not just the unit suite. Where automation genuinely isn't possible (e.g. a manual-only device/UX step), say so and list it for the user rather than skipping silently. Finish by showing the user a **brief verification checklist**: each acceptance criterion with what you smoke-tested to prove it (✅ / ⚠️), plus any items they should confirm manually. Only proceed to `DONE` once this passes.
   - **Status** → `DONE` in the index (local), or transition the card's `System.State` (ado, propose-only) after the user confirms.
   - Update `specs/<id>.md`: tick the AC checkboxes, append Decisions/Verification, add a Progress-log entry with the commit SHA(s); commit it. The detail file — not a tracker comment thread — is the canonical working record.
   - **Archive** (local): move the index entry to the `## Archive` section and relocate its detail file to `<spec_dir>/archive/<id>.md`. The id is never reused — reference integrity for commits/PRs is preserved.
   - Update `CLAUDE.md` if new conventions were introduced.
   - Update `MARKETING.md` if the spec changed user-facing capabilities (if the file exists).
   - Run the project's feature completion checklist (from `CLAUDE.md`).
   - ado only: refresh the single "Spec:" pointer comment (`Spec: specs/<id>.md @ <sha>`) rather than posting a fresh comment each time.
   - Hand off with a summary; `/flow-ship` cuts the release when ready.

### The deferral protocol

A **deferral** is any moment you're about to *not* build something the spec put in scope, or to add a "future / for now / out of scope / noted, not built" narrowing — at plan-time, mid-build, or at done-time. When you hit one, **stop and surface it**. Never narrow scope silently.

For each deferral, prompt the user:

1. **Does it really need to be deferred, and why?** State the reason you'd defer it (cost, a missing dependency, scope creep, risk) so the user can weigh it rather than rubber-stamp it.
2. Then take their decision:
   - **(a) Do it in this spec** — if it's feasible now, build it. Prefer this when the work is small or genuinely core to the spec's value. → the deferral resolves to `built`.
   - **(b) Re-home it** — capture it in a **new spec** or an **existing/related spec** (extend its Scope). Cross-link both ways: the current spec's Decisions note *what* went *where* and *why*; the receiving spec notes its origin in Problem/`links`. → the deferral resolves to the receiving spec's `<id>` (which must exist — re-homing to a new spec means creating it first).

**Record every deferral as a machine-readable trace, not just prose.** On each decision, write an entry to the spec's `deferrals:` front-matter (create the key on first use; omit it entirely when nothing was deferred):

```yaml
deferrals:
  - what: "import from file"        # what was cut
    why: "scope; paste-only shipped" # the reason
    to: 1.6                          # `built`, or the receiving spec id
```

The Decisions section stays the human narrative; the front-matter is the enforceable trace. Each deferral is its **own** decision — don't batch a bunch under one blanket "deferred to later."

**The `DONE`-gating rule (now mechanically enforced):** a spec cannot reach `DONE` while any `deferrals:` entry is unresolved — `to` must be `built` or an id whose spec exists. The `flow-preflight.sh resolved` helper enforces this at commit time (the commit guard blocks it in local mode), in `/flow-lint`, and in `/flow-ship`'s preflight. So an unreconciled deferral is a hard stop, not a reminder.

## Rules

- Checkpoint after the plan — never write code before sign-off.
- TDD — test first, per `CLAUDE.md`.
- **Status is single-source** — the index (local) or the board (ado). Never write a status into a `specs/<id>.md` detail file.
- **Detail files are backend-neutral** — the same shape in every mode.
- **No silent deferrals** — the deferral protocol is mandatory: surface what you're deferring + why, get a per-item decision (build-now or re-home), cross-link, and record it as a `deferrals:` front-matter entry (the enforceable trace). Never narrow a spec's scope unilaterally; deferrals gate `DONE` mechanically (`flow-preflight.sh resolved` — enforced at commit, in `/flow-lint`, and in `/flow-ship`).
- Never ship from here. `/flow-ship` is the separate, deliberate release step.
- ado mode: flow owns *spec content* (`specs/<id>.md`); the board + humans own *card lifecycle*. Never reprioritize, reassign, set iteration, or close a card unprompted — the only card writes are the sign-off state transition and the single refreshed "Spec:" pointer comment. On card-AC vs detail conflict, surface the diff — never silently overwrite. MCP-first, `az` CLI fallback; on a write failure announce it and fall back or stop, never a silent no-op.
- If the work depends on an unfinished spec, stop and say so.
- Conversational — propose and confirm; don't barrel ahead.

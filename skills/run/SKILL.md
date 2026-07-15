---
name: run
description: Implement specs, manage backlog, brainstorm — routes each path (implement / --add / --ideas / --clean / --condense) loading only its reference. Invoke as /flow:run [spec#|--ideas|--add|--clean|--condense|description].
---

# Flow

Conversational, fast development cycle. Implement specs, manage the backlog, brainstorm ideas. Reads `CLAUDE.md` and the project's spec model from the current project — works with any project initialized by `/flow:init`.

For rigorous spec work with formal investigation and sign-off requirements, use `/card-spec` → `/card-implement`.

Usage:
- `/flow:run` — show backlog status and suggest next item
- `/flow:run 2.84` — implement spec 2.84
- `/flow:run <description>` — implement described work
- `/flow:run --ideas` — brainstorm new features through three lenses
- `/flow:run --add` — co-author a new spec
- `/flow:run --clean` — normalize the index formatting and status
- `/flow:run --condense [<id>|--all] [--check]` — rewrite existing spec(s) to the terseness rules, or audit them (`--check`)

## Instructions

**Start fresh.** Read only from the project files — `CLAUDE.md`, `.flow/config.yml`, the index (`SPECIFICATIONS.md` or the board), the relevant `specs/<id>.md`, and `README.md`. Do not reference or build on prior conversation context. Treat this as a new session regardless of what preceded it.

**This skill is a router — load only the path you invoke.** Resolve the backend (below) first, then read the one reference file for the invoked path and follow it. Everything else stays on disk, unread, so the working set stays lean by construction.

| Invocation | Read + follow |
|---|---|
| `/flow:run <spec id>` or `/flow:run <description>` | `reference/implement.md` |
| `/flow:run --add` | `reference/add.md` (+ `reference/authoring.md`) |
| `/flow:run --condense …` | `reference/condense.md` (+ `reference/authoring.md`) |
| `/flow:run --clean` | `reference/clean.md` |
| `/flow:run` (no args) | *inline below* |
| `/flow:run --ideas` | *inline below* |

`reference/authoring.md` holds the shared authoring format (detail-file + task-file templates, terseness rules); `implement.md`, `add.md`, and `condense.md` pull it in when they need to write or judge a detail file. Read it only on those paths.

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
    state_map: …                        # tracker state -> canonical status
```

**Status vocabulary is flow's own, single-source:** `NOT STARTED · IN PROGRESS · PARTIAL · DONE · SUPERSEDED`.

- **`local`** (default) → the index is `SPECIFICATIONS.md`; `flow` owns the full lifecycle and the index uses the canonical vocabulary **directly — no `state_map`**. Spec ids are `Phase.Spec` (`1.2`, `0.1`, alphanumeric like `2.37a` allowed).
- **`ado`** → the **board is the index** (no `SPECIFICATIONS.md`); spec ids are the work-item numbers (`specs/642103.md`). The tracker owns the state machine, so `state_map` translates each **board state -> a canonical token** (defined once in `.flow/config.yml`, scaffolded by `/flow:init`). The board may live in a **different ADO project/org than this repo** — the `ado` coordinates are independent of the git remote; only the `specs/<id>.md` detail files live here. Flow's card writes are **propose-only**: it transitions `System.State` on your sign-off and refreshes a single "Spec:" pointer comment, and **never** reprioritizes, reassigns, sets iteration, or closes a card unprompted. Prefer the tracking MCP tools (`wit_*`); if a call is unavailable or returns 401/403, announce the fallback and use the `az boards` CLI — never silently no-op. If both fail, stop and report.

### The spec model (concept)

Every flow project stores specs as **an index + one detail file per spec**. **Status lives only in the index** (single source of truth) — never in a `specs/<id>.md`. A detail file has two shapes: **flat** (`specs/<id>.md`) or, once it grows big (≥3 tasks, or a task with its own AC), a **directory** (`specs/<id>/<id>.md` orchestrator + `specs/<id>/<id>.T<n>.md` task files). The hooks accept both and enforce neither. Full templates + the breakout guideline live in `reference/authoring.md`.

### `/flow:run` (no args)

Read the index. Show a concise summary: IN PROGRESS first, then NOT STARTED grouped by phase (local) or the equivalent states via `state_map` (ado). Suggest the next item by order/phase. Invite the user to pick or describe work.

- local: if `SPECIFICATIONS.md` doesn't exist, suggest `/flow:init`.
- ado: query open items under the configured area path (`NOT IN ('Closed','Removed')`). If the query returns nothing, say so plainly — never assume the backlog is empty without confirming the query ran.

### `/flow:run --ideas`

Read the index first to avoid re-suggesting existing specs. Brainstorm through three lenses:

1. **Sellable** — features that move acquisition, retention, or willingness-to-pay
2. **Profitable** — things that reduce cost or unlock a pricing tier
3. **Easy wins** — high-leverage, low-effort improvements a user would notice

3-5 ideas per lens. Offer to capture the best ones with `/flow:run --add`.

## Rules

- Checkpoint after the plan — in `checkpoint` mode never write code before sign-off; `auto-build` skips only the approval pause and still records the plan first. (See `reference/implement.md`.)
- **Autonomy gates only the plan-approval pause** — resolved via `flow-preflight.sh autonomy`. `auto-build` never bypasses Claude Code permissions, edits config, or self-approves; its safety net is the verifier.
- **Nothing integrates unverified under `auto-build`** — a `flow:flow-verifier` FAIL blocks; one bounded retry, then escalate to `checkpoint`. Verifiers judge, never fix; implementers build only to the task-local AC and never touch status/index/`deferrals:`.
- TDD — test first, per `CLAUDE.md`.
- **Status is single-source** — the index (local) or the board (ado). Never write a status into a `specs/<id>.md` detail file.
- **Detail files are backend-neutral** — the same shape in every mode.
- **No silent deferrals** — the deferral protocol is mandatory (see `reference/implement.md`): surface what you're deferring + why, get a per-item decision, cross-link, and record it as a `deferrals:` front-matter entry. Deferrals gate `DONE` mechanically (`flow-preflight.sh resolved`).
- Never ship from here. `/flow:ship` is the separate, deliberate release step.
- ado mode: flow owns *spec content* (`specs/<id>.md`); the board + humans own *card lifecycle*. Never reprioritize, reassign, set iteration, or close a card unprompted. On card-AC vs detail conflict, surface the diff — never silently overwrite. MCP-first, `az` CLI fallback; on a write failure announce it and fall back or stop, never a silent no-op.
- If the work depends on an unfinished spec, stop and say so.
- Conversational — propose and confirm; don't barrel ahead.

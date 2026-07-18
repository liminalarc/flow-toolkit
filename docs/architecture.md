# flow-toolkit architecture decision record

Ratified by **spec 1.2** (Skills + sub-agents + spec orchestration) on 2026-07-14.
This is the *design*; each piece below is built by its own implementation spec (1.6–1.11).

## The five pieces (a–e)

- **a. Spec → tasks.** A spec earns a `specs/<id>/` directory (orchestrator `<id>.md` + task files `<id>.T<n>.md`) only when big enough; small specs stay flat `specs/<id>.md`.
- **b. Commands → skills.** Convert the heavy, path-dependent commands (`flow`, `flow-hunt`, `flow-review`, `flow-pr`) to skills for progressive disclosure; keep thin, deliberate-only ones (`flow-lint`, `flow-ship`) as commands.
- **c. Sub-agent catalog.** Isolated-context agents: reviewers, researchers, per-task implementers, verifiers, spec-writer.
- **d. Autonomy controls.** `checkpoint` vs `auto-build`, with a verifier safety net. Precedence: project force > repo default > per-spec.
- **e. Distribution: plugin.** `/plugin install` for versioned skills/agents/commands; installer stays for hooks + fallback.

## Ratified decisions

- **D1 — Breakout threshold = manual + documented guideline, no enforcement.** Hooks support both flat and dir shapes; a hook enforces neither. Guideline: break out at ≥3 tasks or a task carrying its own AC. *Added scope:* a migration path for existing flat specs → dir model (flow is used across several projects), realized as spec **1.6**.
- **D2 — Task files carry a *local* AC; deferrals + DONE-gating stay on the orchestrator only.** A task file = the "how" plus a local "done when X" contract (the seam an implementer builds to and a verifier checks against). `flow-preflight.sh` and the commit guard keep pointing at exactly one file per spec (the orchestrator), never rolling up task files.
- **D3 — Verifier gating is mode-dependent, single verifier.** Blocking under `auto-build`, advisory under `checkpoint`. One verifier per task; a failing `auto-build` verdict → one bounded retry → escalate to human (that task falls back to checkpoint). Majority-vote panels are a future refinement.
- **D4 — First skill migration = `flow-review`, then `flow-pr`.** `flow-review`'s four independent read-only lenses are the cleanest fan-out + most natural per-lens `reference/*` split.
- **D5 — Distribution = both, criterion-gated transition.** Plugin becomes primary for skills/agents/commands; installer stays for hook registration + fallback. Retire the installer only once the plugin registers the toolkit's hooks reliably across both profiles AND every in-use project has migrated — not a fixed date.

## Sub-agent catalog

| Agent | Purpose | Tools | R/W | Invoked |
|---|---|---|---|---|
| Reviewer | Audit one `flow-review` lens / `flow-pr` dimension | Read, Grep, Glob, WebFetch | read-only | one per lens/dim; main thread synthesizes |
| Researcher | Explore one `flow-hunt` persona × dimension | Read, Grep, Glob, WebSearch, WebFetch | read-only | persona-panel fan-out |
| Implementer | Build one task against the approved contract | Read, Edit, Write, Bash, Grep, Glob | write (worktree-isolated when parallel) | one per task file, post-sign-off |
| Verifier | Check an implementer's diff vs the task's local AC | Read, Grep, Glob, Bash | read-only (judges, never fixes) | after each implementer, pre-integration; gates per D3 |
| Spec-writer | Draft specs, enforce 1.1 terseness | Read, Write, Edit, Grep, Glob | write (specs only) | `/flow --add`, spec spawning |
| UX-validator | Drive a **running app**, score one UI/UX lens vs a rubric | Read, Grep, Glob, Bash | read-only (drives + judges, never fixes) | `/flow:validate` (one per lens, serial) + `/flow:run` done-gate _(added 1.14; the only agent that runs the app)_ |

## Concrete edits the task model (a) forces

- **`flow-spec-guard.sh`** — `*/specs/*` classification already catches `specs/<id>/…` as "detail". Edit: distinguish a task file (`<id>.T<n>.md`) so the id==stem check accepts `1.7.T1`; task files keep the no-status check and gain a light local-AC presence nudge.
- **`flow-preflight.sh`** — `to_resolves()` and `cmd_resolved`'s lookup only try `specs/<id>.md` + `specs/archive/<id>.md`. Edit: add dir-form fallbacks `specs/<id>/<id>.md` and `specs/archive/<id>/<id>.md`. Single point that fixes both the DONE-gate and `to`-resolution for dir specs.
- **`flow-commit-guard.sh`** — delegates path logic to preflight, inherits the fix; verify no inline `specs/<id>.md` assumption.
- **`/flow-lint`** — task files must not be flagged orphans; archival moves the whole `specs/<id>/` dir → `specs/archive/<id>/`.
- **`/flow`** — `--add` and done-of-done create/move the directory; migration of flat → dir extends `/flow-lint --migrate`.
- **`README.md` + `hooks.test.sh`** — document the dir model; add cases for dir-form `resolved`/`wellformed` and task-file validation.

## Implementation backlog (spawned by 1.2)

| id | Spec | Covers | Depends on |
|---|---|---|---|
| 1.6 | Task-file model — dual-shape `specs/<id>/` across hooks + commands, incl. migrating existing flat specs | a + D1 | — |
| 1.7 | Sub-agent catalog + autonomy controls + verifier gating | c + d | 1.6 |
| 1.8 | Migrate `flow-review` → skill w/ parallel-reviewer sub-agents | b (first) | 1.7 |
| 1.9 | Migrate `flow-pr` → skill w/ parallel-dimension sub-agents | b (second) | 1.8 |
| 1.10 | Plugin packaging + marketplace; criterion-gated installer transition | e | — (parallel) |
| 1.11 | Migrate `flow` + `flow-hunt` → skills (after pattern proven) | b (remainder) | 1.8 |

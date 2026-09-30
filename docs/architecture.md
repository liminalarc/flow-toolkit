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

- **D6 — The spec gets a read-only adversary, not a write-capable author** _(1.20, reverses this ADR's original Spec-writer row)_. The catalog below first ratified a **Spec-writer** (`Read, Write, Edit, Grep, Glob`, "write (specs only)") to draft specs and enforce terseness. It was never built, and 1.20 concluded it should not be: every judging agent in the toolkit is read-only by design — a judge that patches its own findings is no longer independent (the same reason the verifier never fixes). The gap was never an author; `--add` and implement §2 already draft specs inline and cheaply. The gap was that the spec — the artifact every other check builds *to* — was the only one with no independent adversary, and under `auto-build` no check at all. So the row becomes a read-only **Spec-reviewer** judging INVEST (spec) and SMART (each criterion). Terseness enforcement, the old row's other job, stays where it already lives: `flow-spec-guard.sh`'s soft budget and `/flow:run --condense`.

- **D7 — A work item may span repos; flow is aware of it, never drives it** _(1.24)_. One work item = one canonical spec + one slice per touched repo, never a card per repo. Four clauses:
  - **`work_item:` is the join, the id is not.** In flat-file mode each repo numbers `Phase.Spec` from its own backlog, so repo A's `1.24` and repo B's `1.24` are unrelated — an id cannot address a slice across repos. Each slice keeps its own `id:` and its own index entry; a `work_item:` handle joins them, **defaulting to `id:`** so ado (where the card number is already globally unique) needs no extra key. `canonical_repo:` names which repo holds the full spec, checkable without reading a sibling.
  - **Front-matter is the portable authority; ado tags are load-bearing, not decoration.** `repos:` in the spec files is the record every backend shares. In ado a card exists before any repo holds a spec file for it, so `repo:<name>` card tags are the *only* possible footprint source on first open in a second repo — they are the source where no local slice exists, front-matter wins where one does, and `/flow:lint --fix` re-syncs tags **from** front-matter, never the reverse.
  - **Flow may read a sibling; it writes one only to create a new slice.** Tamper-isolation lives on the write path, so a read costs it nothing — and flat-file mode has no write-free way to know a sibling's state, which is why "awareness only" was unimplementable. The one exception: when the human asks in that turn, `--add` may create a new slice file in a sibling and append one line to its index — never editing existing content, never touching another file, never unasked. Per-slice completion is each repo's own index (flat-file) or `slice-done:<name>` card tags (ado); there is no `slices:` map, which would duplicate status into a file forbidden to carry it.
  - **`.flow/config.yml` carries `related_repos`, amending D-era practice from 1.7.** 1.7 split prompt-side (`.flow/config.yml`) from hook-side (`.flow-toolkit.json`); that boundary already moved when 1.19 had `flow-session-brief.sh` read the former in bash. The footprint is backend config, so it goes where a reader expects it. **1.17's placement of `spec_filename` is untouched** — its rationale was per-knob and still holds.

  *Method note:* the group below splits **by mechanism, not by user-facing moment**. The first decomposition split on when the human sees something (declare / remind / gate / author) and three independent spec reviews each found the same consequence — two mechanisms claimed by two members apiece, with 1.26 ordered to build a prose reader that 1.27 would rewrite in bash. 1.29 exists to own them.

## Sub-agent catalog

| Agent | Purpose | Tools | R/W | Invoked |
|---|---|---|---|---|
| Reviewer | Audit one `flow-review` lens / `flow-pr` dimension | Read, Grep, Glob, WebFetch | read-only | one per lens/dim; main thread synthesizes |
| Researcher | Explore one `flow-hunt` persona × dimension | Read, Grep, Glob, WebSearch, WebFetch | read-only | persona-panel fan-out |
| Implementer | Build one task against the approved contract | Read, Edit, Write, Bash, Grep, Glob | write (worktree-isolated when parallel) | one per task file, post-sign-off |
| Verifier | Check an implementer's diff vs the task's local AC | Read, Grep, Glob, Bash | read-only (judges, never fixes) | after each implementer, pre-integration; gates per D3 |
| Spec-reviewer | Judge a draft spec vs the INVEST/SMART rubric before build | Read, Grep, Glob | read-only (critiques, never authors) | `/flow:run` implement §2 pre-sign-off (mandatory), `--add` (offered) _(added 1.20; **replaces** the write-capable Spec-writer this table originally ratified — see below)_ |
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

## Implementation backlog (spawned by 1.24)

| id | Spec | Covers | Depends on |
|---|---|---|---|
| 1.25 | Related-repos declaration + validation | the declared format + `repos` validator | — |
| 1.29 | Cross-repo resolvers | `resolve-footprint` + `slice-status`, the shared read surface | 1.25 |
| 1.26 | Cross-repo footprint banner + sibling reminder | presentation of the footprint at run start + done-step | 1.29 |
| 1.27 | Per-slice completion + terminal gate | the ado completion record + the terminal disposition | 1.26 |
| 1.28 | Cross-repo authoring + sibling discovery | the write side — `--add`, `/flow:init`, the tag mirror | 1.29 (parallel to 1.26/1.27) |
| 1.30 | Adoption path for repos configured before cross-repo | consuming 1.29's `undeclared:` report at four surfaces | 1.29 (split from 1.28, 2026-09-30) |

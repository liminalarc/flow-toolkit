# flow — authoring format (shared)

Loaded by the `add`, `implement`, and `condense` paths whenever a detail file is written or judged. Holds the two spec shapes, both templates, and the terseness rules. Nothing here is path-specific — it's the format every detail file obeys.

## The spec model

Every flow project stores specs as **an index + one detail file per spec**:

- **The index** — the lifecycle ledger: id, title, status, phase grouping, order (= priority within a phase), and a link to each spec's detail file. **Status lives only here** (single source of truth). In `local` mode this is `SPECIFICATIONS.md`; in `ado` mode the tracking board *is* the index.
- **`specs/<id>.md`** — the detail: Problem, Value (user story), Scope, Acceptance criteria, Plan, Decisions, Verification, Progress log. Carries **no status field** (status is owned by the index/board, never duplicated).

### Two shapes: flat spec, or a spec directory

Most specs are **flat** — `specs/<id>.md`. A spec that grows big earns a **directory**:

```
specs/1.7/
  1.7.md       # orchestrator: the same detail file — Problem/Value/Scope/AC/Plan/Decisions/…
  1.7.T1.md    # task file: the "how" for one slice + a local "done when" AC
  1.7.T2.md
```

**Breakout guideline (manual, unenforced):** break a spec into a directory when it reaches **≥3 tasks, or a task carrying its own acceptance criterion**. Below that, stay flat — thin slices, no premature abstraction. The hooks accept both shapes and enforce neither; you decide per spec. To reshape an existing flat spec, run `/flow-lint --migrate <id>` (git-moves `specs/<id>.md` → `specs/<id>/<id>.md`).

The **orchestrator** `<id>.md` is an ordinary detail file (Problem/Value/Scope/AC/…) — it holds *why/what* and lists its tasks. Each **task file** holds *how* plus a local AC — the seam a per-task implementer builds to and a verifier checks against. A task file carries **no status and no deferrals** (both stay single-source on the orchestrator; the guards gate on the orchestrator alone).

**Task-file template** (`specs/<id>/<id>.T<n>.md`):
```markdown
---
id: <id>.T<n>
title: <task title>
---

## Goal
<the "how" — the approach for this slice; not restating the orchestrator's why>

## Done when
- [ ] <local acceptance criterion — the seam an implementer builds to / a verifier checks>

## Notes
<optional — links, gotchas, sequencing>
```

Everything else about detail files (no status, `id` matches the filename stem, terseness) applies to orchestrators and task files alike.

## Write it terse — a hard rule, not a preference

A spec is read into context every time it's worked, so bloat is wasted budget on every session. Author to these rules and hold existing specs to them when you touch one:

- **One job per section.** Each section says what no other does. Don't let Value restate Problem, Scope restate the acceptance criteria, or Plan restate them — cross-reference, don't repeat.
- **Shortest form that keeps the detail.** Prefer a bullet to a sentence, a sentence to a paragraph; cut throat-clearing and restated context. Never drop a concrete acceptance detail to save space — terse ≠ lossy.
- **Progress log is append-only one-liners** — one dated `` `<sha>` — <what landed> `` per entry, newest last; never rewrite it into prose.

A soft budget (default 120 lines; `spec.maxLines` in `.flow-toolkit.json`) warns — never blocks — when a detail file drifts past terse; the spec guard and `/flow-lint --specs` surface it.

## Detail file template (`specs/<id>.md`)

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

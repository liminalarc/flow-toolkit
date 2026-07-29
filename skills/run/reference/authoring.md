# flow — authoring format (shared)

Loaded by the `add`, `implement`, and `condense` paths whenever a detail file is written or judged. Holds the two spec shapes, both templates, and the terseness rules. Nothing here is path-specific — it's the format every detail file obeys.

## The spec model

Every flow project stores specs as **an index + one detail file per spec**:

- **The index** — the lifecycle ledger: id, title, status, phase grouping, order (= priority within a phase), and a link to each spec's detail file. **Status lives only here** (single source of truth). In `local` mode this is `SPECIFICATIONS.md`; in `ado` mode the tracking board *is* the index.
- **`specs/<id>-<slug>.md`** — the detail: Problem, Value (user story), Scope, Acceptance criteria, Plan, Decisions, Verification, Progress log. Carries **no status field** (status is owned by the index/board, never duplicated).

### Descriptive filenames

A detail file's name carries the id **and a slug of its title**, so the backlog is readable in a file tree, an editor tab, a `git log --stat`, and a PR's changed-files list without opening anything: `specs/1.7-sub-agent-catalog.md`.

- **The `id:` front-matter is the identity** — always. The slug is decoration and is *never* parsed back out of the filename, so an id containing `-` (`BL-12`) stays unambiguous. The guard validates the stem against the `id:`; `flow-preflight.sh spec-path <id>` is the one thing that resolves an id to a path.
- **Slugify:** lowercase; every run of non-`[a-z0-9]` becomes a single `-`; trim leading/trailing `-`; truncate **at a word boundary** to **40 chars** (a task's context suffix: **20**); then **drop trailing stopwords** (`a an and for in of on or the to with`) so a truncation can't end on a dangling `…-for-the`. If the result is empty (a title of pure punctuation), use the bare id.
- **Where the text comes from:** `local` ⇒ the index entry's Title, so it's inferred at no extra cost; `ado` ⇒ the work item's `System.Title`. A task file's suffix comes from **its own** `title:`, not the parent's — the story name already arrives via the `<id>-<slug>` prefix.
- **The bare `<id>.md` form stays permanently valid.** The hooks accept both unconditionally, so no existing spec in any repo breaks. Set `flow.spec_filename: id` in `.flow/config.yml` to author bare names in a project that prefers them (default `id-slug`). To retrofit an existing repo, run `/flow:lint --rename --all`.

### Two shapes: flat spec, or a spec directory

Most specs are **flat** — `specs/<id>-<slug>.md`. A spec that grows big earns a **directory**, and the slug repeats on the dir, the orchestrator, and each task file (the dir is always named for its orchestrator's stem):

```
specs/1.7-sub-agent-catalog/
  1.7-sub-agent-catalog.md                # orchestrator: the same detail file — Problem/Value/Scope/AC/Plan/Decisions/…
  1.7-sub-agent-catalog.T1-agent-defs.md  # task file: the "how" for one slice + a local "done when" AC
  1.7-sub-agent-catalog.T2-autonomy.md
```

**Breakout guideline (manual, unenforced):** break a spec into a directory when it reaches **≥3 tasks, or a task carrying its own acceptance criterion**. Below that, stay flat — thin slices, no premature abstraction. The hooks accept both shapes and enforce neither; you decide per spec. To reshape an existing flat spec, run `/flow:lint --migrate <id>` (git-moves the flat detail file into the directory form) — that changes the *shape*, while `/flow:lint --rename` changes the *name*.

The **orchestrator** `<id>.md` is an ordinary detail file (Problem/Value/Scope/AC/…) — it holds *why/what* and lists its tasks. Each **task file** holds *how* plus a local AC — the seam a per-task implementer builds to and a verifier checks against. A task file carries **no status and no deferrals** (both stay single-source on the orchestrator; the guards gate on the orchestrator alone).

**Task-file template** (`specs/<id>-<slug>/<id>-<slug>.T<n>-<context>.md`):
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

Everything else about detail files (no status, `id` matching the filename stem, terseness) applies to orchestrators and task files alike.

## Write it terse — a hard rule, not a preference

A spec is read into context every time it's worked, so bloat is wasted budget on every session. Author to these rules and hold existing specs to them when you touch one:

- **One job per section.** Each section says what no other does. Don't let Value restate Problem, Scope restate the acceptance criteria, or Plan restate them — cross-reference, don't repeat.
- **Shortest form that keeps the detail.** Prefer a bullet to a sentence, a sentence to a paragraph; cut throat-clearing and restated context. Never drop a concrete acceptance detail to save space — terse ≠ lossy.
- **Progress log is append-only one-liners** — one dated `` `<sha>` — <what landed> `` per entry, newest last; never rewrite it into prose.

A soft budget (default 120 lines; `spec.maxLines` in `.flow-toolkit.json`) warns — never blocks — when a detail file drifts past terse; the spec guard and `/flow:lint --specs` surface it.

## Detail file template (`specs/<id>-<slug>.md`)

```markdown
---
id: <id>
title: <Title>
links: []            # related spec ids or external URLs
# validate:          # OPTIONAL — declare a UI/UX validation target; omit for specs that
#   target: checkout #   don't touch the interface (then /flow:run's done-gate is a no-op).
#   intent: "a new user buys one item and reaches confirmation"  # required with target
#   lens: [ui, ux]   #   optional — default both; ui = design-system, ux = task+friction
#   design_system: design/tokens.md   # optional — else .flow/validate/* (1.16) / infer
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

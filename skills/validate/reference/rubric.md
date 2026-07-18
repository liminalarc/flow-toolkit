# /flow:validate — the persisted project rubric (`.flow/validate/*.md`)

The **project layer** of the validation rubric, committed in the target repo (spec 1.16). Baseline
heuristics stay in `reference/{ui,ux}.md` (the toolkit); this file is *this project's* specifics — the
design system, its tokens/components, named patterns, project conventions. The agent **reads** it; the
**main thread persists** it (the agent is read-only re the project tree). Two files, one per lens:

- `.flow/validate/ui.md` — design-system conformance specifics (tokens, component library, layout scale).
- `.flow/validate/ux.md` — task/flow conventions (canonical happy paths, project a11y bar, tone).

It is **committed** (engineer-owned standard, like `.flow/config.yml`) — never gitignored.

## File format

Front-matter records when it was generated and its **basis** — the source files it was derived from, each
with a 12-char `sha256` fingerprint so drift is cheap to detect. Then the project-layer rubric prose.

```markdown
---
generated: 2026-07-18
basis:                          # source the rubric was inferred from (drift-checked)
  - path: design/tokens.css
    sha: f2ca1bb6c7e9
  - path: tailwind.config.js
    sha: 9a3f00c1d2e4
---

## Design system
<the source of truth — tokens file / component library / style guide, and where it lives>

## Conformance rules (project layer)
- <project-specific rule the baseline UI/UX rubric can't know — e.g. "spacing from the 4px scale only">
- <named pattern this project standardizes — e.g. "destructive actions use the Danger button variant">
```

Generate the `basis:` block with the shared helper so stamping and drift-checking share one fingerprint:
`flow-preflight.sh rubric-basis <src1> <src2> …`.

## Bootstrap — first run, no rubric yet

1. The agent finds `.flow/validate/<lens>.md` absent, infers a **draft project rubric** from source (tokens,
   component library, most-repeated patterns), and returns it in its report as a *proposed* draft + the list
   of source files it used — **it never saves** (read-only re the project tree).
2. The **main thread** shows the draft, lets the engineer edit, and on approval writes
   `.flow/validate/<lens>.md`: the approved prose + a `basis:` block stamped via `rubric-basis` over the
   source files. **Never silently authoritative** — no approval, no file.

## Refresh — later runs, drift detected

1. Drift check: `flow-preflight.sh rubric-drift .flow/validate/<lens>.md --repo <root>` re-hashes each basis
   file. Exit 0 = in sync (use the rubric as-is); exit 2 = a file **CHANGED**/**MISSING** — the design system
   moved since the rubric was written.
2. On drift, the **main thread surfaces what changed** and **offers** a refresh — re-infer the affected
   section, show a diff, and re-write (re-stamping `basis:`) **only on approval**. Never overwrite the curated
   rubric silently — the engineer's edits are the standard.

## Read / merge model

When present, the agent reads `.flow/validate/<lens>.md` as the **project layer** and scores against it
**merged with** the baseline `reference/<lens>.md` heuristics — the persisted rubric refines and overrides the
baseline where they overlap. When absent, the agent falls back to bootstrap (infer + propose), never a silent
skip.

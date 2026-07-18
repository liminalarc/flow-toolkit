---
name: validate
description: Live UI/UX validation — drive the running app and score it against a rubric via the flow-ux-validator agent. UI lens = design-system conformance; UX lens = task completion + friction. The entry point into UI/UX review; the reusable agent is also wired into /flow:run's done-gate (1.15). Invoke as /flow:validate <screen|flow> --intent "<outcome>" [--ui|--ux] [--design-system <path|url>].
---

# flow:validate

Drive the **running app** and validate its interface against a rubric — the live-driving complement to
`/flow:review`'s static UX lens. Two lenses: **UI** (does the screen conform to the design system) and
**UX** (can a user complete the intended flow, at what friction). Read-only — it validates and reports,
never edits.

Usage:
- `/flow:validate <screen|flow> --intent "<outcome>"` — both lenses (default)
- `/flow:validate <screen|flow> --intent "<outcome>" --ui` — UI lens only
- `/flow:validate <screen|flow> --intent "<outcome>" --ux` — UX lens only
- `--design-system <path|url>` — pointer to this project's design system (else the agent infers from source)

## Instructions

**Start fresh.** Read only from the project files — `CLAUDE.md`, `README.md`, the frontend source, and any
design-system pointer given. Do not build on prior conversation context.

**This skill is a thin launcher.** It owns no *validation* logic — it picks the lens(es), dispatches the
`flow:flow-ux-validator` agent, and synthesizes the result. All the real work (applicability, driving,
scoring) lives **in the agent**, so `/flow:run`'s done-gate (1.15) reuses identical validation by dispatching
the same agent directly. The one thing the skill *does* own beyond dispatch is **persisting the project
rubric** (below) — the agent is read-only re the project tree, so writing `.flow/validate/*` is the main
thread's job. (The done-gate keeps this lean: it drift-checks + nudges to `/flow:validate` rather than
re-implementing the persist flow.)

**Resolve the target + lenses.**
- **Target** — the one screen or flow to validate (bound every run to it).
- **Intent** — the `--intent` outcome a user should reach. Required for UX; frames UI relevance. If missing,
  ask for it — a vague intent produces slop.
- **Lenses** — `--ui`, `--ux`, or **both** when neither flag is given.

**Dispatch — serially, not in parallel.** For each requested lens, launch a `flow:flow-ux-validator` agent
with: the lens name, the path to its **baseline** rubric (`reference/<lens>.md` within this skill), the target,
the intent, the design-system pointer (or "infer from source"), the project root, and a scratch dir for
screenshots. The agent resolves the **project layer** itself — reading `.flow/validate/<lens>.md` when present
(and drift-checking it) or inferring a draft to propose. When both lenses run, dispatch them **one at a time** —
driving a live app is stateful (shared server/browser/data), so unlike `/flow:review`'s read-only parallel
fan-out, concurrent drivers would collide. Each agent returns an applicability verdict + prioritized findings
+ a rubric status (bootstrap draft / drift / in sync), and never edits.

**Persist the project rubric (main thread, confirm-first — spec 1.16).** The agent proposes; **you write**.
Full protocol + file format in `reference/rubric.md`. Per lens, act on the agent's rubric status:
- **bootstrap** (no `.flow/validate/<lens>.md` yet) — show the proposed draft, let the engineer edit, and on
  approval write `.flow/validate/<lens>.md`: the approved prose + a `basis:` block stamped with
  `flow-preflight.sh rubric-basis <src…>` over the source files the draft was inferred from. No approval ⇒ no
  file (never silently authoritative).
- **drift** (a basis file CHANGED/MISSING) — surface exactly what changed, offer to refresh the affected
  section, show the diff, and re-write (re-stamping `basis:`) **only on approval**. Never overwrite the curated
  rubric silently.
- **in sync** — nothing to persist.

**Relay a NOT APPLICABLE verdict plainly.** If the agent reports the repo has no drivable UI (backend-only,
CLI, infra), say so and stop — never present an invented critique.

**Synthesize (main thread).**
- Single lens → present that lens's applicability verdict + prioritized findings.
- Both lenses → present a combined, prioritized UI/UX assessment (critical items across UI + UX first).

**Applying fixes.** The agent only reports. When a finding warrants a change, you — the main thread —
propose it and **confirm before editing**. The validation never edits silently, and never auto-fixes the app.

## Rules
- Read-only validation — the agent drives + scores; it never edits or fixes project files.
- One screen/flow per run — scope-bound by construction.
- Rubric is an explicit input — baseline (`reference/{ui,ux}.md`) merged with the **project layer**
  (`.flow/validate/{ui,ux}.md` when present; else infer). A vague rubric produces slop; ask rather than guess.
- **Persist confirm-first** — the project rubric is engineer-owned: save a bootstrap draft or a drift refresh
  only on approval, stamping `basis:` via `flow-preflight.sh rubric-basis`. Never overwrite it silently.
- Serial dispatch when both lenses run — never parallel drivers against one live app.
- Confirm before making any change a finding suggests.
- Never ship from here. `/flow:validate` validates; it doesn't release.

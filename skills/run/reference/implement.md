# flow — implement a spec (`/flow:run <spec id>` or `/flow:run <description>`)

The build path. Read `reference/authoring.md` alongside this when you write or update the detail file.

**Autonomy — `checkpoint` (default) vs `auto-build`.** Before planning, resolve the spec's mode with the shared helper (locate `flow-preflight.sh` the way `/flow:ship`/`/flow:lint` do): `flow-preflight.sh autonomy specs/<id>.md --repo .` → `checkpoint | auto-build`. Precedence is defined once, in the helper: `.flow-toolkit.json` `autonomy.force` > the spec's `autonomy:` front-matter > `.flow-toolkit.json` `autonomy.default` > builtin `checkpoint`. **Autonomy controls exactly one thing — whether flow pauses for _plan approval_.** It never bypasses Claude Code's permission system, edits config, or self-approves; the `flow:flow-verifier` (step 3) is the safety net that makes `auto-build` tolerable. `checkpoint` → pause for sign-off (step 2), verifier **advisory**. `auto-build` → skip the plan-approval pause and build, verifier **blocking** (nothing integrates unverified).

## 1. Understand

Read the index entry for that id, and **if `specs/<id>.md` exists, read it and resume from its Plan/Progress log rather than re-deriving.** For free-form work, restate it and identify affected layers; ask 1-2 clarifying questions only when genuinely ambiguous.

If a free-form description maps to an existing spec, say so and switch to it. If it's net-new and will produce commits, offer `/flow:run --add` first so there's an id to tag.

## 2. Plan + CHECKPOINT

Concise plan: thin vertical slices, files/layers touched, test strategy, risks, open questions. **The plan you present IS the draft detail file** — include the **Value** user story so it can be weighed against other specs. **In `checkpoint` mode, stop for sign-off before writing any code.** In `auto-build`, do not pause for approval — but still write and commit the detail file first (auto-build skips the human gate, never the record).

On sign-off (checkpoint) or immediately (auto-build), write/update `specs/<id>.md` (Problem, Value, Scope, AC, Plan, Decisions — see `reference/authoring.md` for the template) and commit it. Then set the item IN PROGRESS in the index (local) or, if `Backlog`/`Ready`, offer to transition the card (ado, with a comment noting work started) — checkpoint only after sign-off. For cross-cutting work, this is where the API contract / seam is locked so parallel layers build to the same interface.

## 3. Build test-first

Follow the conventions in `CLAUDE.md` for this project. Keep commits small and **tag every commit's subject with the spec id as a leading bracket** — `[<id>] type: subject` (e.g. `[1.4] feat: …`). Use a bare `[<id>]` with **no `#`** — a `#` collides with GitHub's `#N` issue/PR autolink and mis-links every dotted id to issue 1. The id goes in the **subject line, not the body**, so `/flow:ship` derives the release's specs mechanically from `git log`; the commit guard accepts the leading tag and nudges the exact id when a spec is IN PROGRESS and it's missing. Surface decisions as you go.

How you dispatch depends on mode and shape:
- **`checkpoint`, single-layer**: build inline, test-first, commit per slice. The human is watching, so `flow:flow-verifier` is an **advisory** check on the diff.
- **`auto-build`, or any cross-cutting spec**: dispatch one **`flow:flow-implementer`** agent per task/layer against its local-AC contract (worktree-isolated when layers run in parallel). It builds to the seam and reports a diff — it never merges or touches lifecycle state (index/status/`deferrals:`). Skip layers with no independent work.

**Verifier gating before integration (the safety net).** For each task/layer, run one **`flow:flow-verifier`** on the implementer's diff against that task's local AC; it returns a structured `PASS`/`FAIL` and **never fixes** (judges only):
- **`auto-build` → blocking.** A `FAIL` does not integrate. Give the implementer **one** bounded retry with the verifier's findings; if it still fails, **escalate** — that task falls back to `checkpoint` and you hand the verdict to the user. Merge only `PASS` diffs, then verify the seam.
- **`checkpoint` → advisory.** Surface the verdict + diff to the user (you're already paused for their call) rather than blocking.

If at any point you're about to drop or narrow something the spec put in scope, **run the deferral protocol** (below) — don't narrow scope silently. (An implementer that hits out-of-scope work reports it back; you run the protocol, not the agent.)

## 4. Definition of done

- **Reconcile deferrals** — every in-scope item you didn't build has been run through the deferral protocol (built here, or re-homed to a spec by user decision), cross-linked, and recorded in the spec's `deferrals:` front-matter with a resolved `to`. This is **machine-checked** (`flow-preflight.sh resolved`): the commit guard blocks a `DONE` spec with an open deferral, so it **must** be clear before the spec reaches `DONE`.
- **Restart & smoke-test** — before flipping status, get the change actually running and exercise it. **Restart every local service the change touched** (use the run/dev commands in `CLAUDE.md`/`README.md`) so nothing is serving stale code. Then **run an automated smoke test yourself wherever it's feasible** — drive the changed behavior end-to-end (hit the endpoint, run the flow, exercise the CLI/UI), not just the unit suite. Where automation genuinely isn't possible (e.g. a manual-only device/UX step), say so and list it for the user rather than skipping silently. Finish by showing the user a **brief verification checklist**: each acceptance criterion with what you smoke-tested to prove it (✅ / ⚠️), plus any items they should confirm manually. Only proceed to `DONE` once this passes.
- **Validation gate (declared per-spec, opt-in).** If the spec's front-matter carries a `validate:` block, the done-step **dispatches the `flow:flow-ux-validator` agent** (the same 1.14 agent `/flow:validate` uses — dispatched directly, never via the skill) before flipping `DONE`. No `validate:` block ⇒ **the gate is a pure no-op** — say nothing, add no friction to specs that don't touch the interface.
  - **Read the block:** `target` (one screen/flow) and `intent` (the outcome) are required; `lens` defaults to both `ui`+`ux`; the design-system pointer resolves by precedence — the block's `design_system` > the project's persisted `.flow/validate/*.md` (1.16, when present) > "infer from source".
    ```yaml
    validate:
      target: checkout            # one screen or flow
      intent: "a new user buys one item and reaches confirmation"
      lens: [ui, ux]              # optional — default both
      design_system: design/tokens.md   # optional — else .flow/validate/* / infer
    ```
  - **Dispatch one `flow:flow-ux-validator` per declared lens, SERIALLY** (driving a live app is stateful — a shared server/browser/data means concurrent drivers collide; this is unlike the read-only parallel fan-outs). Give each agent: the lens + its rubric path (`skills/validate/reference/<lens>.md`), the `target`, the `intent`, the resolved design-system pointer, the project root, and a scratch dir.
  - **`NOT APPLICABLE` passes cleanly.** If the agent reports no drivable UI (backend-only/CLI/infra), **show the verdict and proceed** — declaring `validate:` on an undrivable repo is a mistake to surface, never a hard stop. Don't invent a critique.
  - **Persisted project rubric (1.16) — read + nudge, don't author here.** The agent reads `.flow/validate/<lens>.md` (the project layer) when present. The gate stays lean: if the agent reports a **bootstrap draft** (no rubric yet) or **drift** (a basis file changed — the agent runs `flow-preflight.sh rubric-drift`), **surface it and nudge the engineer to run `/flow:validate`**, which owns the confirm-first persist/refresh flow. Don't write `.flow/validate/*` from the gate (no duplicate persist logic).
  - **Triage before `DONE`.** Surface the prioritized findings. Each open finding must be **resolved** — either fixed here (re-run the affected lens to confirm), or explicitly re-homed through the **deferral protocol** (below), which records a `deferrals:` entry and mechanically gates `DONE`. Do not flip `DONE` with an untriaged finding standing.
- **Status** → `DONE` in the index (local), or transition the card's `System.State` (ado, propose-only) after the user confirms.
- Update `specs/<id>.md`: tick the AC checkboxes, append Decisions/Verification, add a Progress-log entry with the commit SHA(s); commit it. The detail file — not a tracker comment thread — is the canonical working record.
- **Archive** (local): move the index entry to the `## Archive` section and relocate its detail — a flat `specs/<id>.md` → `<spec_dir>/archive/<id>.md`, or a whole directory `specs/<id>/` → `<spec_dir>/archive/<id>/` (orchestrator + every task file, moved together). The id is never reused — reference integrity for commits/PRs is preserved.
- Update `CLAUDE.md` if new conventions were introduced.
- Update `MARKETING.md` if the spec changed user-facing capabilities (if the file exists).
- Run the project's feature completion checklist (from `CLAUDE.md`).
- ado only: refresh the single "Spec:" pointer comment (`Spec: specs/<id>.md @ <sha>`) rather than posting a fresh comment each time.
- Hand off with a summary; `/flow:ship` cuts the release when ready.

## The deferral protocol

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

**The `DONE`-gating rule (mechanically enforced):** a spec cannot reach `DONE` while any `deferrals:` entry is unresolved — `to` must be `built` or an id whose spec exists. The `flow-preflight.sh resolved` helper enforces this at commit time (the commit guard blocks it in local mode), in `/flow:lint`, and in `/flow:ship`'s preflight. So an unreconciled deferral is a hard stop, not a reminder.

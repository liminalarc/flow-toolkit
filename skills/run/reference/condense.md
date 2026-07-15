# flow — condense existing specs (`/flow:run --condense [<id> | --all] [--check]`)

Read `reference/authoring.md` alongside this for the terseness rules being applied.

Bring **existing** detail files up to the terseness rules (one job per section, shortest lossless form, append-only one-line Progress log) — a **judgment** rewrite, distinct from the mechanical *index* normalization `--clean` does. Use it to migrate a backlog authored before those rules, or as an ongoing hygiene pass.

**Targets:** `<id>` condenses one `specs/<id>.md`; `--all` sweeps every detail file under `spec_dir` (including `archive/`). **Amend freely** — a `DONE`/archived spec condenses like any other, and **status is never touched** (that stays single-source in the index).

**Rewrite (default).** For each target, rewrite the prose sections to the terseness rules, then show a **diff and confirm per spec** before writing — never rewrite silently, even under `--all`. Two hard guarantees:
- **Progress log copied verbatim** — never reworded, reordered, or dropped (it's append-only history).
- **No acceptance detail lost** — every AC's concrete criterion survives; condensing changes wording, never coverage.

If a spec is already under budget and non-repetitive, echo a one-line no-op and move on.

**`--check` (report only).** Audit each target against the *full* terseness rules and report findings — no writes, no diff. This catches what the line budget can't: cross-section restatement (Value ≈ Problem, Scope ≈ AC, Plan ≈ AC), prose that should be bullets, a Progress log rewritten into paragraphs. Report per spec as `✅ terse` or a findings list; a clean spec reports `✅`. Complements `/flow:lint --specs` (which flags only the mechanical line budget) — use `--check` for the qualitative pass.

After any write the spec guard re-validates the file and re-checks the budget on save, so a condensed spec is confirmed well-formed — and usually back under budget — in the same turn.

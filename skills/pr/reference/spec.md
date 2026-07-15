# flow:pr — spec-fidelity dimension

Audit whether the diff is *the code the spec asked for*. **Read-only: produce findings, do not edit.**

## Discover
Read the diff (the refs/command you were given — e.g. `git diff main...HEAD`, `gh pr diff <n>`). Read the spec under review (`specs/<id>.md`) — its acceptance criteria, scope, and plan. If you were told the diff is intentionally spec-less (hotfix/chore), skip AC-walking and only do the scope + bookkeeping checks.

## Review
- **AC walk** — go through the spec's acceptance criteria one by one: which does the diff satisfy, which are untouched, which are contradicted? Cite the diff hunk that proves each verdict.
- **Scope** — does the diff contain work *beyond* the spec? Flag scope creep; note it may deserve its own spec via `/flow:run --add`.
- **Bookkeeping** — is the spec's status updated correctly? If the diff introduces a new pattern, is `CLAUDE.md` updated per the feature-completion checklist? Are any `deferrals:` reconciled?

## Report
Return a **spec scorecard** — each acceptance criterion marked ✅ satisfied / ⬜ not addressed / ❌ contradicted, with the `file:line` proving it — plus prioritized findings (BLOCKER / SHOULD FIX / NIT), each with location and concrete fix. Hand findings back for synthesis — do not write changes.

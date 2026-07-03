---
description: "Spec-aware review of a PR or branch diff — /flow-pr [pr# | branch] [--spec|--quality|--tests]"
---
# PR Review

Review a pull request or branch diff against this project's own standards: the spec it claims to implement, the conventions in `CLAUDE.md`, clean-code quality, and test coverage. Where generic PR review asks "is this good code?", this asks "is this the code the spec asked for, built the way this project builds things?"

Usage:
- `/flow-pr` — review the current branch's diff against the main branch
- `/flow-pr 42` — review GitHub PR #42 (uses `gh`)
- `/flow-pr feature/auth` — review a branch by name
- `/flow-pr --spec` — spec fidelity only
- `/flow-pr --quality` — clean code + correctness only
- `/flow-pr --tests` — test coverage only

## Instructions

**Start fresh.** Read only from the project files (`CLAUDE.md` hierarchy, `SPECIFICATIONS.md`, `README.md`) and the diff itself. Do not reference or build on prior conversation context. Treat this as a new session regardless of what preceded it.

### Phase 1 — Gather

1. Resolve the diff:
   - PR number given → `gh pr view <n>` for title/body/comments, `gh pr diff <n>` for the diff.
   - Branch name given → diff that branch against the main branch (`git diff main...<branch>`).
   - No argument → diff the current branch against the main branch (`git diff main...HEAD`). If the current branch *is* main, review uncommitted + unpushed work instead.
2. Identify the spec under review: look for a spec number in the PR title/body, branch name, or commit messages (e.g. `feat: login form (Spec 1.1)`). If none is found, list IN PROGRESS specs from `SPECIFICATIONS.md` and ask which one this diff implements — or confirm it's intentionally spec-less (hotfix, chore).
3. Read `CLAUDE.md` (root + any subdirectory files covering the changed paths) for the conventions this diff must follow — testing stack, named patterns, code style, commit format.

### Phase 2 — Review

Run each dimension against the diff. With a focus flag, run only that dimension.

**Spec fidelity** (`--spec`)
- Walk the spec's acceptance criteria one by one: which does this diff satisfy, which are untouched, which are contradicted?
- Scope check: does the diff contain work *beyond* the spec? Flag scope creep — it may deserve its own spec via `/flow --add`.
- Bookkeeping: is the spec's status updated correctly? If the diff introduces a new pattern, is `CLAUDE.md` updated per the feature completion checklist?

**Correctness**
- Bugs in the changed code: unhandled edge cases, off-by-one, race conditions, broken error paths, null/empty handling.
- Quick security pass on changed code: injection, missing authorization checks, secrets in the diff, unsafe deserialization.
- Only report issues *in or caused by* the diff — pre-existing problems are out of scope (note them separately if severe).

**Clean Code** (`--quality` covers this + Correctness)
- Naming reveals intent; functions do one thing and stay small; no duplication introduced (or near-duplication of existing code that should have been reused).
- No dead code, commented-out blocks, debug leftovers, or magic values that deserve names.
- Comments explain *why*, not *what*; no redundant narration.
- Consistency: does the new code match the named patterns in `CLAUDE.md` and the idioms of the surrounding files? A locally-clean function written in a foreign style is still a finding.

**Tests** (`--tests`)
- The TDD check: does every behavior change in the diff have a corresponding test change? List new/changed behaviors that ship untested.
- Test quality: do the tests assert behavior (inputs → outcomes) rather than implementation details? Do they cover the unhappy paths the spec's criteria imply?
- Run the test suite using the command from `CLAUDE.md`/`README.md` and report results. If the project has coverage tooling configured, run it and report coverage on the changed files only — whole-repo coverage is noise here.

### Phase 3 — Report

Produce a verdict and findings:

1. **Verdict** — one of: `READY` (mergeable as-is), `READY WITH NITS` (mergeable; nits listed), `NEEDS WORK` (blockers listed).
2. **Spec scorecard** — each acceptance criterion with ✅ satisfied / ⬜ not addressed / ❌ contradicted.
3. **Findings** — grouped by severity, each with `file:line`, what's wrong, and the concrete fix:
   - `BLOCKER` — bug, failing/missing test for core behavior, contradicted acceptance criterion, security issue
   - `SHOULD FIX` — clean-code violation, convention drift, untested edge case
   - `NIT` — naming, style, minor polish
4. Offer next steps: apply the fixes locally, and/or (only if the user asks) post the review to the PR via `gh`.

## Rules

- Review the diff, not the whole repo — pre-existing issues are out of scope unless severe enough to block.
- Judge against *this project's* standards from `CLAUDE.md` first, general principles second. If they conflict, the project's rules win — flag the conflict instead.
- Every finding needs a location and a concrete fix. "Consider improving naming" is not a finding.
- Never post comments, approve, or merge on GitHub unless the user explicitly asks. Never push.
- If the test suite fails, that's an automatic `NEEDS WORK` — report the failure output.

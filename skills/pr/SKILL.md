---
name: pr
description: Spec-aware review of a PR or branch diff — /flow:pr [pr# | branch] [--spec|--quality|--tests]
---

# flow:pr

Review a pull request or branch diff against this project's own standards: the spec it claims to implement, the conventions in `CLAUDE.md`, clean-code quality, and test coverage. Where generic PR review asks "is this good code?", this asks "is this the code the spec asked for, built the way this project builds things?"

Usage:
- `/flow:pr` — review the current branch's diff against the main branch
- `/flow:pr 42` — review GitHub PR #42 (uses `gh`)
- `/flow:pr feature/auth` — review a branch by name
- `/flow:pr --spec` — spec fidelity only
- `/flow:pr --quality` — clean code + correctness only
- `/flow:pr --tests` — test coverage only

## Instructions

**Start fresh.** Read only from the project files (`CLAUDE.md` hierarchy, `SPECIFICATIONS.md`, `README.md`) and the diff itself. Do not reference or build on prior conversation context. Treat this as a new session regardless of what preceded it.

### Phase 1 — Gather (main thread)

1. **Resolve the diff** — settle the exact refs/command so it can be handed to each reviewer:
   - PR number given → `gh pr view <n>` for title/body/comments, `gh pr diff <n>` for the diff.
   - Branch name given → `git diff main...<branch>`.
   - No argument → `git diff main...HEAD`. If the current branch *is* main, diff the unpushed + uncommitted work instead — resolve to one concrete command (`git diff @{upstream}` when an upstream exists, else `git diff HEAD`) so Phase 2 has a single runnable diff to hand each reviewer.
2. **Identify the spec under review** — look for a spec id in the PR title/body, branch name, or commit messages (e.g. `[#1.1] feat: …`, `feat: login (Spec 1.1)`). If none is found, list IN PROGRESS specs from `SPECIFICATIONS.md` and ask which one this diff implements — or confirm it's intentionally spec-less (hotfix, chore).
3. Note the `CLAUDE.md` files (root + any subdirectory files covering the changed paths) the reviewers must judge against.

### Phase 2 — Fan out to one reviewer per dimension

Each dimension is audited by an independent, read-only `flow:flow-pr-reviewer` sub-agent that loads only its own rubric — so the main thread stays lean and dimensions run in parallel. With a focus flag, run only that dimension; with none, run all three. Dimension → rubric:

| Dimension | Flag | Rubric (passed to the reviewer) |
|---|---|---|
| Spec fidelity | `--spec` | `reference/spec.md` |
| Quality (correctness + clean code) | `--quality` | `reference/quality.md` |
| Tests | `--tests` | `reference/tests.md` |

**Dispatch.** For each requested dimension, launch a `flow:flow-pr-reviewer` with: the dimension name, the path to its rubric (`reference/<dimension>.md` within this skill's directory), the **resolved diff refs/command** from Phase 1, the **spec under review** (`specs/<id>.md` path, or "spec-less"), and the project root. When more than one dimension runs, launch them **in parallel** — a single message with multiple agent calls. Each reviewer reads the diff itself (it has Bash), returns prioritized findings, and never edits.

### Phase 3 — Synthesize (main thread)

Collect the reviewers' findings and produce one report:

1. **Verdict** — `READY` (mergeable as-is), `READY WITH NITS` (mergeable; nits listed), or `NEEDS WORK` (blockers listed). A failing test suite is an automatic `NEEDS WORK`.
2. **Spec scorecard** — each acceptance criterion with ✅ satisfied / ⬜ not addressed / ❌ contradicted (from the spec reviewer).
3. **Findings** — grouped by severity, each with `file:line`, what's wrong, and the concrete fix:
   - `BLOCKER` — bug, failing/missing test for core behavior, contradicted acceptance criterion, security issue
   - `SHOULD FIX` — clean-code violation, convention drift, untested edge case
   - `NIT` — naming, style, minor polish
4. Offer next steps: apply the fixes locally, and/or (only if the user asks) post the review to the PR via `gh`.

## Rules
- Review the diff, not the whole repo — pre-existing issues are out of scope unless severe enough to block.
- Judge against *this project's* standards from `CLAUDE.md` first, general principles second. If they conflict, the project's rules win — flag the conflict.
- Every finding needs a location and a concrete fix. "Consider improving naming" is not a finding.
- Reviewers only report; the main thread applies fixes on the user's confirmation. Never post comments, approve, merge, or push on GitHub unless the user explicitly asks.
- If the test suite fails, that's an automatic `NEEDS WORK` — report the failure output.

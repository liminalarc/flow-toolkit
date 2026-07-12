---
description: "Cut a release — /flow-ship [--dry-run]"
---
# Ship

Cut a release. Reads CLAUDE.md to understand this project's deploy mechanism. Validates before tagging, then executes.

Usage: `/flow-ship` · `/flow-ship --dry-run`

## Instructions

**Start fresh.** Read only from the project files — `CLAUDE.md`, `.flow/config.yml`, the index (`SPECIFICATIONS.md` or the board), `specs/`, `README.md`. Do not reference or build on prior conversation context. Treat this as a new session regardless of what preceded it.

1. **Discover the release mechanism.** Read CLAUDE.md for: deploy commands, CI/CD trigger patterns (git tag push is common), Docker/container steps, npm publish, cloud deploy scripts. If the mechanism isn't documented, ask before proceeding.

2. **Validate.**
   - No uncommitted changes (`git status`)
   - Tests pass locally (run the test command from CLAUDE.md)
   - Build succeeds
   - CLAUDE.md patterns are current
   - **No unreconciled deferrals** — every `DONE` spec was reconciled (per the deferral protocol); a spec with an open deferral is not shippable
   - Any project-specific pre-ship steps documented in CLAUDE.md

3. **Determine the version.** Read recent tags (`git tag --sort=-v:refname | head -10`) and commits (`git log --oneline -20`). The version bump is **commit-derived** (the reliable, mechanical signal):
   - Breaking changes → major
   - New features (`feat:` commits) → minor
   - Bug fixes only (`fix:`) → patch

   **Confirm with the user before tagging.**

4. **Execute.** Follow the mechanism documented in CLAUDE.md exactly — typically: create and push a git tag, which triggers CI/CD.

5. **Report.** State the tag/version, link to CI/CD if known, note what to verify post-deploy.

**Changelog:** derive it from the commits (the source of truth), not from spec Progress logs — those stay a human working record, never a release input. As an optional enrichment, map the released commits' spec/work-item ids to their `specs/<id>.md` files and *link* them in the changelog so a reader can click through to Decisions/Progress — without parsing that prose. Read a spec's status from the **index** (or board), never from a detail file.

## Rules

- Never skip validation. Fix failures before tagging.
- `--dry-run`: validate and print what would happen, but don't tag or deploy.
- If the mechanism is unclear, ask — a bad release is hard to undo.
- Confirm the version bump before creating the tag.

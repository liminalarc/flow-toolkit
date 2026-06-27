---
description: "Cut a release — /flow-ship [--dry-run]"
---
# Ship

Cut a release. Reads CLAUDE.md to understand this project's deploy mechanism. Validates before tagging, then executes.

Usage: `/flow-ship` · `/flow-ship --dry-run`

## Instructions

1. **Discover the release mechanism.** Read CLAUDE.md for: deploy commands, CI/CD trigger patterns (git tag push is common), Docker/container steps, npm publish, cloud deploy scripts. If the mechanism isn't documented, ask before proceeding.

2. **Validate.**
   - No uncommitted changes (`git status`)
   - Tests pass locally (run the test command from CLAUDE.md)
   - Build succeeds
   - CLAUDE.md patterns are current
   - Any project-specific pre-ship steps documented in CLAUDE.md

3. **Determine the version.** Read recent tags (`git tag --sort=-v:refname | head -10`) and commits (`git log --oneline -20`). Propose:
   - Breaking changes → major
   - New features (`feat:` commits) → minor
   - Bug fixes only (`fix:`) → patch

   **Confirm with the user before tagging.**

4. **Execute.** Follow the mechanism documented in CLAUDE.md exactly — typically: create and push a git tag, which triggers CI/CD.

5. **Report.** State the tag/version, link to CI/CD if known, note what to verify post-deploy.

## Rules

- Never skip validation. Fix failures before tagging.
- `--dry-run`: validate and print what would happen, but don't tag or deploy.
- If the mechanism is unclear, ask — a bad release is hard to undo.
- Confirm the version bump before creating the tag.

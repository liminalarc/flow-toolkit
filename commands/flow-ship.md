---
description: "Cut a release — /flow-ship [--dry-run]"
---
# Ship

Cut a release. Reads CLAUDE.md to understand this project's deploy mechanism. Validates before tagging, then executes.

Usage: `/flow-ship` · `/flow-ship --dry-run`

## Instructions

**Start fresh.** Read only from the project files — `CLAUDE.md`, `.flow/config.yml`, the index (`SPECIFICATIONS.md` or the board), `specs/`, `README.md`. Do not reference or build on prior conversation context. Treat this as a new session regardless of what preceded it.

1. **Discover the release mechanism.** Read CLAUDE.md for: deploy commands, CI/CD trigger patterns (git tag push is common), Docker/container steps, npm publish, cloud deploy scripts. If the mechanism isn't documented, ask before proceeding.

2. **Preflight.** Run each pre-req as a **discrete check with an explicit ✅/❌ result** and a defined behavior on ❌. **Never a silent pass** — a check that cannot be *evaluated* (tool missing, commits untagged, board unreachable) is a ⚠️ that blocks, not a green. Print one line per check. The checks sort into three classes; treat each per its class.

   **Locate the shared helper first.** The git-state and deferral checks are defined once in `flow-preflight.sh`. Find it in your Claude profile's hooks dir — try `$CLAUDE_CONFIG_DIR/hooks/flow-preflight.sh`, then `~/.claude/hooks/flow-preflight.sh`, then `~/.claude-*/hooks/flow-preflight.sh`. **If none is found, stop and tell the user to reinstall flow-toolkit** — do not fall back to eyeballing git state (a green run that skipped the check is the worst failure).

   **Class 1 — auto-remediable (git state).** Run `flow-preflight.sh git-state --repo .`. It checks: on the default branch, clean tree, up to date with origin, and prints a ✅/❌ line each plus the exact remediation on failure.
   - On ❌, **detect the situation and OFFER the fix as a confirm-first prompt** (e.g. "on `feat/x`, 3 commits ahead of main → checkout main → merge → pull?"). Present the commands; run them only on confirmation.
   - **Merging a feature branch is always a prompt, never automatic** — which branch, and whether it's reviewed, is a human call. Same for stashing vs committing a dirty tree.

   **Class 2 — gate-able (detect, then wait or report).**
   - **Every spec in the release is DONE.** Derive the release's specs from the `[#id]` tags on commits since the last tag (`git log <lastTag>..HEAD`), then cross-check each id's status against the index (local) / board (ado). **If commits carry no `[#id]` tags** (common in local mode), say so and list the untagged commits — report ⚠️, never assume the set is empty or all-DONE.
   - **CI gates are green on the release commit.** Query actual status with `gh` (e.g. `gh run list`/`gh pr checks` on the release SHA). **Poll or report — never assume.** If `gh` is absent/unauthed, report ⚠️ and ask the user to confirm CI manually.
   - **Tests pass locally / build succeeds** (run the commands from CLAUDE.md) and any project-specific pre-ship steps documented there.

   **Class 3 — judgment (surface, can't auto-fix).**
   - **No unreconciled deferrals.** Run the same helper against the release's DONE specs:
     - **local**: `flow-preflight.sh resolved --repo .` (reads `SPECIFICATIONS.md` for the DONE set).
     - **ado**: resolve the DONE work items from the board, then `flow-preflight.sh resolved --repo . --done <id,id,...>`.
     Surface any unresolved deferral (which DONE spec, what was deferred). This can't be auto-fixed — the fix is a `/flow` deferral-protocol decision. **Block the release.**
   - **CLAUDE.md patterns are current** — spot-check against the shipped work.

3. **Determine the version.** Read recent tags (`git tag --sort=-v:refname | head -10`) and commits (`git log --oneline -20`). The version bump is **commit-derived** (the reliable, mechanical signal):
   - Breaking changes → major
   - New features (`feat:` commits) → minor
   - Bug fixes only (`fix:`) → patch

   **Confirm with the user before tagging.**

4. **Execute.** Follow the mechanism documented in CLAUDE.md exactly — typically: create and push a git tag, which triggers CI/CD.

5. **Report.** State the tag/version, link to CI/CD if known, note what to verify post-deploy.

**Changelog:** derive it from the commits (the source of truth), not from spec Progress logs — those stay a human working record, never a release input. As an optional enrichment, map the released commits' spec/work-item ids to their `specs/<id>.md` files and *link* them in the changelog so a reader can click through to Decisions/Progress — without parsing that prose. Read a spec's status from the **index** (or board), never from a detail file.

## Rules

- Never skip a preflight check. Every check prints ✅/❌; a check that can't be evaluated is ⚠️ (blocks), never a silent green. Fix failures before tagging.
- `--dry-run`: run the full preflight and **print the computed version, changelog, and tag**, but don't tag or deploy.
- If the mechanism is unclear, ask — a bad release is hard to undo.
- Confirm the version bump before creating the tag.

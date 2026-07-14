# hooks/ — CLAUDE.md

Authoring conventions for the bash hooks. Additive to root `CLAUDE.md` — read that first.

## The suite

| Script | Event | Job |
|---|---|---|
| `flow-spec-guard.sh` | PostToolUse (Edit\|Write) | Validate index entries + `specs/<id>.md` on every edit |
| `flow-claude-guard.sh` | PostToolUse (Edit\|Write) | Enforce CLAUDE.md line caps (300 root / 200 subdir, or `.flow-toolkit.json`) |
| `flow-commit-guard.sh` | PreToolUse (Bash) | Conventional-commit format + spec validity + deferral `DONE`-gate + spec-less nudge |
| `flow-session-brief.sh` | SessionStart | Inject ~30 tokens of backlog orientation |
| `flow-preflight.sh` | (not an event hook) | Shared source-of-truth checks called by the above + `/flow-lint` + `/flow-ship` |

`hooks.json` maps events → scripts using a `__HOOKS_DIR__` placeholder the installer replaces with each profile's real hooks path.

## Rules for every hook

- **Fail fast and cheap.** The first thing a hook does is decide "does this apply?" and exit 0 if not (non-spec file, non-`git commit` command, repo with no spec model). These hooks are registered *globally*, so they run in every project — they must cost nothing where the toolkit isn't used. Never add latency or output to an unrelated project.
- **Block with an actionable message.** When a guard blocks, its stderr must tell Claude exactly what's wrong and how to fix it — the value is that Claude reads the error and fixes the file in the same turn.
- **POSIX bash, portable.** Hooks run through Git Bash on Windows and native bash on macOS/Linux. Stick to portable constructs; prefer `awk` for parsing (see `parse_deferrals` in `flow-preflight.sh`) over GNU-only tool flags. Mind `\r` — strip carriage returns when reading files that may have CRLF endings.

## flow-preflight.sh is the single source of truth

Three rules live **only** here and are consumed everywhere else:

- `git-state [--repo DIR] [--no-fetch]` — release-branch hygiene. Prints ✅/❌/⚠️ per check and the exact remediation command on failure, but **never runs it**. Exit 0 all-pass · 2 fail-or-unverifiable.
- `resolved [--repo DIR] [--spec-dir specs] [--done ID,…]` — the deferral `DONE`-gate: no `DONE` spec may have an unresolved `deferrals:` entry (`to` = `built` or an id whose detail file exists). DONE set from `--done` (ado) or `SPECIFICATIONS.md` (local).
- `wellformed <detail.md>` — one detail file's `deferrals:` shape (every entry has non-empty `what`/`why`/`to`).

Every rule reads only the repo's own files, so it behaves identically in local and ado mode. **Never re-implement any of these inline** in a guard or command — call the helper.

## Testing

`hooks.test.sh` is the bash test harness for hook parsing/validation. Any change to how a hook parses or validates gets a matching case here, and `bash hooks/hooks.test.sh` must be green before committing (TDD mandate from root).

## Rules

- A machine-checkable rule is defined once, in `flow-preflight.sh`.
- Every hook exits 0 instantly when it doesn't apply.
- Changes to hook behavior get a `hooks.test.sh` case and a README update if user-visible.
- Keep hooks portable across Git Bash / macOS / Linux.

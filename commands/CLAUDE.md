# commands/ — CLAUDE.md

Authoring conventions for the slash-command prompt files. Additive to root `CLAUDE.md` — read that first.

## What a command file is

Each `commands/<name>.md` is a **pure prompt**: YAML front-matter + markdown instructions that Claude reads and executes. No executable code, no shell, no state. The installer force-copies these into every profile's `~/.claude/commands/`, where they become `/<name>` slash commands.

## Front-matter

```yaml
---
description: "<one-line summary — usage syntax in brackets> — /<name> [args]"
---
```

The `description` is what shows in the `/` picker. Keep it to one line, lead with the value, and end with the invocation shape (e.g. `/flow [spec#|--ideas|--add|--clean|description]`). Match the style of the existing seven files.

## Structure every command follows

- **Open by starting fresh.** Every command begins with an explicit instruction to ignore prior conversation context and read only from the project files (`CLAUDE.md`, `SPECIFICATIONS.md`, `specs/`, `README.md`, …). This is what lets a user chain `/flow-init → /flow → /flow-lint` without a `/clear`. New commands must keep this.
- **Usage block** — the invocation forms, one per line, mirroring the front-matter.
- **Instructions** — numbered steps or clearly-headed sections. Be prescriptive; the file is the spec for the behavior.
- **Rules** — a closing list of hard invariants the command must never violate.

## The cross-artifact contract

Commands **emit** the exact file formats the hooks **enforce** and the README **documents**. These three move together:

- If a command changes the spec-model shape, status vocabulary, index-entry format, deferral front-matter, or commit convention → update the matching guard in `hooks/`, the shared checks in `hooks/flow-preflight.sh`, AND the README section that documents it, in the same change.
- A command must never emit a file the guards would reject. When in doubt, run the relevant guard against a scratch file.

## Verification

Commands have **no unit tests** — they're prompts. Verify a command by *running it* end-to-end against a scratch project or spec and confirming the real behavior. A change to a command's contract that a hook enforces should also be exercised against that hook.

## Rules

- No executable logic in a command file beyond instructions to Claude.
- Preserve the "start fresh, read only project files" opening.
- Keep `description` one line and consistent with siblings.
- Never let a command emit a format the hooks reject or the README doesn't describe.

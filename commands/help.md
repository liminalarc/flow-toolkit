---
description: "One-screen map of everything flow can do — /flow:help [specs|build|review|agents|hooks|ambient]"
---
# Help

The recall surface. Answers "what can I do right now, and what is already happening for me" **without** making the user go read the manual. Bare `/flow:help` prints the whole map on one screen; a topic noun drills into one area.

Usage: `/flow:help` · `/flow:help specs` · `/flow:help build` · `/flow:help review` · `/flow:help agents` · `/flow:help hooks` · `/flow:help ambient`

## Instructions

**Start fresh.** This command reads the installed toolkit and the current project — nothing from prior conversation.

**Generate the list; never recite one from memory.** A hand-maintained command list in this file would drift the moment a skill is added or renamed, and a help screen that lies is worse than none. Derive every entry point from the shipped files' own front-matter.

1. **Locate the toolkit.** The plugin bundles it at `${CLAUDE_PLUGIN_ROOT}` — **try that first** — then fall back to the legacy installer locations (`$CLAUDE_CONFIG_DIR`, then `~/.claude`, then `~/.claude-*`), checking for a `commands/` + `skills/` pair. If none is found, say the plugin isn't installed/enabled and stop.

2. **Enumerate, in one pass.** From the located root, read only the YAML front-matter — not the bodies:
   - `commands/*.md` → `description:` (thin, deliberate commands)
   - `skills/*/SKILL.md` → `name:` + `description:` (the heavy, path-routing skills)
   - `agents/*.md` → `name:` + `description:` (sub-agents — never invoked directly by the user)

   A single `grep -h` style pass over those globs is enough; do **not** read whole files, and do not read `reference/*`. If a glob comes back empty, report that area as unavailable rather than filling it in from memory.

3. **Read the project's current state** (cheap, local): does `SPECIFICATIONS.md` or `.flow/config.yml` exist (local vs ado vs not-a-flow-project)? Is anything `IN PROGRESS`? This decides the "next step" line in step 5.

4. **Print the map — one screen.** Aim for ~40 lines; this is a glance surface, not a manual. Group entry points by the **job**, not by whether they're a command or a skill (the user doesn't care which is which at recall time):
   - **Plan & build** · **Find work** · **Review & validate** · **Maintain & release**

   One line each: invocation, the useful flags, and a ≤8-word purpose taken from its own description. Mark skills that fan out to sub-agents with the agent they dispatch, so the fan-out is discoverable from the map itself.

5. **Close with two lines that are specific to right now**, not generic:
   - **You are here** — backend (local/ado), any `IN PROGRESS` spec, count of open specs.
   - **Likely next** — the one command that fits that state (nothing in progress → `/flow:run` to pick; spec in progress → `/flow:run <id>`; DONE work unshipped → `/flow:ship`; not a flow project → `/flow:init`).

6. **Topic mode** (`/flow:help <noun>`) — same sourcing rules, one area only, and go deeper than the map: include the flags, the file shapes involved, and a worked one-liner example. Topics:
   | Noun | Covers |
   |---|---|
   | `specs` | the index + detail-file model, status vocabulary, ids/filenames, deferrals |
   | `build` | `/flow:run`'s paths, autonomy (`checkpoint` vs `auto-build`), the implementer→verifier loop |
   | `review` | `/flow:review`, `/flow:pr`, `/flow:validate` — which lens answers which question |
   | `agents` | the sub-agent catalog: what each one sees, what it may write, who dispatches it |
   | `hooks` | the always-on guards + `flow-preflight.sh` checks |
   | `ambient` | **everything that fires without being invoked** (see below) |

   An unrecognized noun → print the topic list, don't guess.

## The `ambient` topic — the one users forget

Invocable features are self-reminding: you type them. These are not, so they are the ones that get lost. `/flow:help ambient` (and a compact 3-4 line callout on the main screen) must cover:

- **Deferral protocol** — narrowing scope mid-build stops and asks; each cut is recorded in `deferrals:` and mechanically gates `DONE`.
- **Verifier gating** — every implementer diff is checked by an independent `flow-verifier` before integration; blocking under `auto-build`, advisory under `checkpoint`.
- **Validation done-gate** — a spec carrying a `validate:` block dispatches `flow-ux-validator` per lens before `DONE`.
- **Archival** — a spec reaching `DONE`/`SUPERSEDED` moves itself to `specs/archive/`, index entry and all.
- **Rubric drift** — `.flow/validate/*.md` is fingerprinted against its `basis:` files; drift is surfaced, never silently applied.
- **The guards** — commit format + spec-id nudge, spec-file shape, CLAUDE.md line caps, session brief.

Keep this list short and current: it is the only hand-written inventory in this command, so it is the only part that can drift. When a new ambient behavior ships, it belongs here.

## Rules

- **Never invent an entry point.** Every command/skill/agent named must come from a file you just read. If the enumeration fails, say so — a plausible-looking wrong command is the failure mode this command exists to prevent.
- **One screen.** If the map doesn't fit, cut prose, not entries — the point is seeing the whole surface at once.
- **Read-only.** `/flow:help` never edits, never creates a spec, never changes state.
- Don't explain the toolkit's philosophy here; link to `docs/guide.md` for depth and stay a map.

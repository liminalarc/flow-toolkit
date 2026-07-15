---
description: "Audit CLAUDE.md hierarchy + spec index/detail integrity; migrate legacy specs or a flat spec to dir form — /flow:lint [--claude|--specs|--fix|--migrate [id]]"
---
# Lint

Audit a project's `CLAUDE.md` hierarchy and its **spec model** (the index + `specs/<id>.md` detail files) for structural violations. Reports findings grouped by severity and suggests or applies fixes. Also migrates a legacy inline `SPECIFICATIONS.md` to the index + detail-file model.

Usage:
- `/flow:lint` — full audit (CLAUDE.md hierarchy + spec model + README)
- `/flow:lint --claude` — CLAUDE.md hierarchy only
- `/flow:lint --specs` — spec model only (index + detail files)
- `/flow:lint --fix` — full audit, then auto-fix what's safe (status keyword casing, entry/heading format, archive migration)
- `/flow:lint --migrate` — convert a legacy inline `SPECIFICATIONS.md` to the index + `specs/<id>.md` model (dry-run by default; `--migrate --apply` writes)
- `/flow:lint --migrate <id>` — convert one flat spec `specs/<id>.md` → the directory form `specs/<id>/<id>.md` so it can hold task files (dry-run by default; add `--apply` to write)

## Instructions

**Start fresh.** Read only from the project files — `CLAUDE.md`, `.flow/config.yml`, `SPECIFICATIONS.md`, `specs/`, `README.md`. Do not build on prior conversation context.

**Resolve the backend** from `.flow/config.yml` (absent ⇒ `local`). In `local` mode the index is `SPECIFICATIONS.md`; in `ado` mode there is no `SPECIFICATIONS.md` (the board is the index) and the spec-model checks validate the `specs/` directory only.

### Step 1: Discover the project layout

Read the current directory: root `CLAUDE.md`, the index (`SPECIFICATIONS.md` if local), the `specs/` directory (and `specs/archive/`), `README.md`, and each primary source layer's `CLAUDE.md`.

### Step 2: CLAUDE.md hierarchy checks (skip if `--specs`)

Record for each finding: **severity** (`ERROR`/`WARNING`/`INFO`), **location** (file + line), **message**, **suggested fix**.

**Root CLAUDE.md:**

| Check | Severity | Condition |
|---|---|---|
| Root CLAUDE.md exists | ERROR | Missing — `/flow:run`/`/flow:init` have no anchor. |
| Root under the cap | WARNING | Exceeds the root cap (default 300; overridable via `rootMax` in `.flow-toolkit.json`). |
| Contains `## Architecture` | WARNING | Missing. |
| Contains `## Development Rules` | WARNING | Missing. |
| Contains `## Project Structure` | WARNING | Missing. |
| Contains `## Feature Completion Checklist` | INFO | Missing — recommended. |
| Pointer to subdirectory files | INFO | Absent while subdirectory CLAUDE.md files exist. |
| No layer-specific framework detail | WARNING | Root carries >2 code blocks or >3 framework-specific `##` sections — likely belongs in a subdirectory file. |

**Subdirectory CLAUDE.md files:**

| Check | Severity | Condition |
|---|---|---|
| Under the subdirectory cap | WARNING | Exceeds subdirectory cap (default 200; overridable via `subdirMax`). |
| Not referenced in root | INFO | Root doesn't mention this directory. |
| Duplicates a root `##` heading | ERROR | A `##` heading text matches one in root — loaded twice, drift risk. |
| Contains a root-level section | WARNING | `## Architecture`/`## Development Rules`/`## Project Structure` belong in root. |

**Missing subdirectory CLAUDE.md:** `INFO` if the layer is small, `WARNING` if it has 10+ source files.

### Step 3: Spec-model checks (skip if `--claude`)

**Index (local mode — `SPECIFICATIONS.md`):**

| Check | Severity | Condition |
|---|---|---|
| Index exists | WARNING | Missing — run `/flow:init`. (If inline `### Spec` blocks are found instead of index entries, this is a **legacy inline file** — run `/flow:lint --migrate`.) |
| Entry format | WARNING | Each backlog line matches `- **<id>** <Title> — \`STATUS\` — [detail](specs/<id>.md)`. |
| Status keyword valid | ERROR | Exactly one of `NOT STARTED · IN PROGRESS · PARTIAL · DONE · SUPERSEDED` (case-sensitive). |
| No duplicate ids | ERROR | An id appears more than once across the index + `specs/archive/`. |
| Archive section present | WARNING | No `## Archive` while DONE/SUPERSEDED specs exist. |
| Archive is last section | WARNING | `## Archive` must be the final `##` section. |
| No DONE spec left in active backlog | WARNING | A DONE entry not moved to `## Archive`. |
| No non-DONE/non-SUPERSEDED in archive | ERROR | An IN PROGRESS / NOT STARTED entry under `## Archive`. |

**Detail files (`<spec_dir>/*.md` + `<spec_dir>/archive/*.md`) — both modes:**

Detail files come in two shapes: **flat** `specs/<id>.md`, or a **directory** `specs/<id>/` holding an orchestrator `<id>.md` plus task files `<id>.T<n>.md` (a big spec's per-task "how"). Resolve an id's detail to whichever exists — flat `specs/<id>.md` first, then `specs/<id>/<id>.md`. Task files are **not** separate index entries: they belong to their orchestrator's id, so they are never orphans.

| Check | Severity | Condition |
|---|---|---|
| Every index entry has a detail file | ERROR | Index (or board) references `<id>` but neither `specs/<id>.md` nor `specs/<id>/<id>.md` exists. |
| Every detail file is indexed | WARNING | A flat `specs/<id>.md` or an orchestrator `specs/<id>/<id>.md` exists with no index entry / board item (orphan). Task files `<id>.T<n>.md` are never orphans. |
| Front-matter `id` matches filename | ERROR | `id:` in the file differs from `<id>` in the filename (for the orchestrator, `<id>`; for a task file, `<id>.T<n>`). |
| No `status` in the detail file | ERROR | Status is single-source (index/board) — a `status:`/`**Status:**` in any detail file (orchestrator or task) will drift. |
| Task file has a local AC | INFO | A `specs/<id>/<id>.T<n>.md` carries no `- [ ]` "done when" checkbox — the seam an implementer builds to and a verifier checks against. Advisory only (mirrors `flow-spec-guard.sh`'s soft nudge). |
| Required sections present | WARNING | Missing any of `## Problem`, `## Value`, `## Scope`, `## Acceptance criteria`, `## Plan`, `## Decisions`, `## Verification`, `## Progress log`. |
| Value is a user story | INFO | `## Value` should read `As a <role> I want <capability> so that <benefit>`. |
| Detail file under the line budget | INFO | `specs/<id>.md` exceeds the soft spec budget (default 120; overridable via `spec.maxLines` in `.flow-toolkit.json`). Same nudge `flow-spec-guard.sh` emits on edit — run `/flow:run --condense <id>` to rewrite it losslessly (or raise the budget). Never an ERROR; specs legitimately vary. |
| DONE spec has no unchecked AC | WARNING | Index says DONE but `specs/<id>.md` still has `- [ ]` acceptance criteria. |
| Non-DONE spec with all AC checked | INFO | All `- [x]` but status isn't DONE — probably needs a status update. |
| Deferrals front-matter well-formed | ERROR | A `deferrals:` entry is missing `what`, `why`, or `to`. Run `flow-preflight.sh wellformed <file>` per detail file. |
| DONE spec has no unreconciled deferral | ERROR | Index (local) / board (ado) says DONE but a `deferrals:` entry has an unresolved `to` (not `built`, and no spec with that id exists). Run `flow-preflight.sh resolved` — see below. |

**Deferral checks use the shared helper** (`flow-preflight.sh`) so the rule is identical to the commit guard and `/flow:ship`. Locate it in your Claude profile's hooks dir — try `$CLAUDE_CONFIG_DIR/hooks/flow-preflight.sh`, then `~/.claude/hooks/flow-preflight.sh`, then `~/.claude-*/hooks/flow-preflight.sh`. If none is found, say so and fall back to reading the front-matter yourself against the rule above — never silently skip the deferral checks.

- **Well-formedness** (both backends): `flow-preflight.sh wellformed specs/<id>.md` for each detail file.
- **DONE-gating**:
  - **local**: `flow-preflight.sh resolved --repo .` reads `SPECIFICATIONS.md` for the DONE set itself.
  - **ado**: the board owns status, so query the DONE work items first, then pass them: `flow-preflight.sh resolved --repo . --done <id,id,...>`.

### Step 3b: README.md (skip if `--claude` or `--specs`)

| Check | Severity | Condition |
|---|---|---|
| README.md exists | ERROR | Missing. |
| Local setup / getting started section | ERROR | No heading containing "setup"/"getting started"/"local"/"installation". |
| Prerequisites section | WARNING | No "prerequisites"/"requirements"/"dependencies" heading. |
| Test-running instructions | WARNING | Tests exist in the repo but README has no test section. |
| Setup commands are exact | INFO | Local-setup section has no code blocks (likely prose-only). |
| Greenfield skeleton implies setup docs | WARNING | Only if a Walking Skeleton (`0.1`) exists and is DONE: README must have a local-setup section. (Skip for brownfield projects — no skeleton.) |

### Step 3c: MARKETING.md consistency (if present)

Compare Feature Highlights against DONE specs in the index/archive; flag `INFO` if a clearly user-facing DONE spec has no marketing entry. Advisory only.

### Step 4: Report findings

```
## flow:lint Report

### Errors (must fix)
[file:line] MESSAGE
  → Suggested fix

### Warnings (should fix)
...

### Info (consider)
...

### Summary
X errors, Y warnings, Z info items
Files checked: [list]
```

If no findings: "All checks passed."

### Step 5: Auto-fix (only if `--fix`)

Safe, mechanical corrections only. **Always show a diff and confirm before writing** unless there are zero ambiguous cases.

Safe to auto-fix:
- Status keyword normalization in the index (`done` → `DONE`, etc.).
- Index entry format (spacing, backticks around status, link form).
- Archive: move DONE/SUPERSEDED entries to `## Archive` and relocate their detail — a flat `specs/<id>.md` → `specs/archive/<id>.md`, or a whole directory `specs/<id>/` → `specs/archive/<id>/` (orchestrator + every task file moved together).
- Trailing whitespace / double blank lines in the index.

Do **NOT** auto-fix: CLAUDE.md content, duplicate ids, missing sections/detail files (requires authoring), line-count issues, or moving a `status` out of a detail file (surface it; the human decides the true status).

### Step 6: Migrate (only if `--migrate`)

Two conversions share the flag; the presence of an `<id>` argument selects which:

#### 6a — `--migrate <id>`: flat spec → directory form

Convert one flat spec `specs/<id>.md` → `specs/<id>/<id>.md` so a big spec can grow task files (`specs/<id>/<id>.T<n>.md`). Use it when a spec crosses the breakout guideline (≥3 tasks, or a task carrying its own AC). **Dry-run by default;** add `--apply` to write.

1. Resolve `<id>`'s current detail. It may be active (`specs/<id>.md`) or archived (`specs/archive/<id>.md`) — migrate in place (an archived spec → `specs/archive/<id>/<id>.md`).
2. Create the directory and **move** the file with `git mv` (preserve history): `specs/<id>.md` → `specs/<id>/<id>.md` (or the archive equivalent). Do not rewrite the file's contents — the orchestrator *is* the former flat spec.
3. Update the index link for `<id>` to point at the new path (`[detail](specs/<id>/<id>.md)`), keeping the same id, title, status, and position.
4. Do **not** invent task files — breakout is a manual, decision-by-decision act (`/flow:run` adds tasks against an approved plan). Migration only reshapes the container.

**Safety:** dry-run prints the move + index-line change before any write; **idempotent** (if `specs/<id>/<id>.md` already exists, no-op with a note); halts if both flat and dir forms exist (ambiguous — the human resolves it). The id is unchanged, so every commit/PR citing `<id>` stays valid.

#### 6b — `--migrate` (no id): legacy inline → index + detail model

1. Parse each `### Spec X.Y — Title` block: `**Status:**`, description paragraph, `**User story:**`, `**Acceptance criteria:**`, and any extra prose.
2. Write `specs/<id>.md` per the detail template (see `/flow:run --add`): `## Problem` ← description; `## Value` ← user story (append a `so that …` **TODO** if absent); `## Acceptance criteria` ← the AC list; `## Scope / Plan / Decisions / Verification / Progress log` ← empty scaffolds with `<!-- TODO -->`; any unrecognized content → preserved verbatim under `## Migrated (unclassified)` and flagged. **No `status` field** in the detail file.
3. Rewrite `SPECIFICATIONS.md` as the index — same phase headings and order, one line per spec, status carried over into the entry.
4. Archived specs (an inline `## Archive` or a `SPECIFICATIONS-ARCHIVE.md` sidecar) → `specs/archive/<id>.md`, indexed under `## Archive`.

**Safety:** dry-run prints the full plan (files to create, index preview) before any write; leaves `SPECIFICATIONS.md.pre-migrate.bak`; **idempotent** (detects an already-migrated repo — index shape + `specs/` present — and no-ops); halts loudly on duplicate ids rather than clobbering.

**Report:**
```
flow:lint --migrate (dry run)
  12 specs → specs/*.md   (9 clean, 3 need review: 1.4 no user story, 2.1 unclassified prose, 3.0 dup-id CONFLICT)
   4 archived → specs/archive/*.md
  SPECIFICATIONS.md → index (12 active + 4 archived)
  Run with --apply to write. 3 items flagged for manual review.
```

## Rules

- Read-only by default — never modify files without `--fix` or `--migrate --apply`.
- Always diff before writing; confirm if any change is ambiguous.
- Report the line number for every finding when possible.
- Five precise findings beat a wall of nitpicks. Over 20 findings → group and summarize.
- `--migrate` (either mode) never runs destructively — dry-run first; the legacy conversion backs up and preserves every byte of unclassified content, and the flat→dir conversion uses `git mv` and never rewrites file contents.

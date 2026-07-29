---
description: "Audit CLAUDE.md hierarchy + spec index/detail integrity; migrate legacy specs, reshape a flat spec, or rename specs to <id>-<slug> — /flow:lint [--claude|--specs|--fix|--migrate [id]|--rename [id|--all]]"
---
# Lint

Audit a project's `CLAUDE.md` hierarchy and its **spec model** (the index + detail files) for structural violations. Reports findings grouped by severity and suggests or applies fixes. Also migrates a legacy inline `SPECIFICATIONS.md` to the index + detail-file model.

Usage:
- `/flow:lint` — full audit (CLAUDE.md hierarchy + spec model + README)
- `/flow:lint --claude` — CLAUDE.md hierarchy only
- `/flow:lint --specs` — spec model only (index + detail files)
- `/flow:lint --fix` — full audit, then auto-fix what's safe (status keyword casing, entry/heading format, archive migration)
- `/flow:lint --migrate` — convert a legacy inline `SPECIFICATIONS.md` to the index + detail-file model (dry-run by default; `--migrate --apply` writes)
- `/flow:lint --migrate <id>` — reshape one flat spec into the directory form so it can hold task files (dry-run by default; add `--apply` to write)
- `/flow:lint --rename [<id>|--all]` — rename bare `<id>.md` specs to the descriptive `<id>-<slug>.md` form and fix their index links (dry-run by default; add `--apply` to write)

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

Detail files come in two shapes — **flat** or a **directory** holding an orchestrator plus task files (a big spec's per-task "how") — and two name forms: descriptive `<id>-<slug>` or bare `<id>`. **Resolve an id to its detail file with `flow-preflight.sh spec-path <id> --repo .`** (located as described below): it covers every shape/name/location combination, so never guess a path or glob for one here. Exit 1 = no detail file; exit 2 = **two files claim one id** (report as the ERROR below). Task files are **not** separate index entries: they belong to their orchestrator's id, so they are never orphans.

| Check | Severity | Condition |
|---|---|---|
| Every index entry has a detail file | ERROR | Index (or board) references `<id>` but `spec-path <id>` finds nothing. |
| Every detail file is indexed | WARNING | A flat detail file or an orchestrator exists with no index entry / board item (orphan). Task files are never orphans. |
| One file per id | ERROR | `spec-path <id>` exits 2 — two detail files claim the same id (e.g. a leftover `1.4.md` beside a renamed `1.4-auto-tag-commits.md`). Report both paths; the human picks which to delete. |
| Front-matter `id` matches filename | ERROR | The filename stem doesn't match the file's `id:`. Legal stems: `<id>`, `<id>-<slug>`, and for a task file `<id>[-<slug>].T<n>[-<context>]`. Same rule as `flow-spec-guard.sh`'s `stem_matches_id`. |
| Index link points at the real file | WARNING | The entry's `[detail](…)` path isn't the path `spec-path` resolves — usually a rename that didn't update the index. `--rename` fixes it. |
| Descriptive filename | INFO | A bare `<id>.md` while `.flow/config.yml` has `flow.spec_filename: id-slug` (the default) — suggest `/flow:lint --rename <id>`. Advisory only; the bare form is permanently valid. |
| No `status` in the detail file | ERROR | Status is single-source (index/board) — a `status:`/`**Status:**` in any detail file (orchestrator or task) will drift. |
| Task file has a local AC | INFO | A `specs/<id>/<id>.T<n>.md` carries no `- [ ]` "done when" checkbox — the seam an implementer builds to and a verifier checks against. Advisory only (mirrors `flow-spec-guard.sh`'s soft nudge). |
| Required sections present | WARNING | Missing any of `## Problem`, `## Value`, `## Scope`, `## Acceptance criteria`, `## Plan`, `## Decisions`, `## Verification`, `## Progress log`. |
| Value is a user story | INFO | `## Value` should read `As a <role> I want <capability> so that <benefit>`. |
| Detail file under the line budget | INFO | `specs/<id>.md` exceeds the soft spec budget (default 120; overridable via `spec.maxLines` in `.flow-toolkit.json`). Same nudge `flow-spec-guard.sh` emits on edit — run `/flow:run --condense <id>` to rewrite it losslessly (or raise the budget). Never an ERROR; specs legitimately vary. |
| DONE spec has no unchecked AC | WARNING | Index says DONE but `specs/<id>.md` still has `- [ ]` acceptance criteria. |
| Non-DONE spec with all AC checked | INFO | All `- [x]` but status isn't DONE — probably needs a status update. |
| Deferrals front-matter well-formed | ERROR | A `deferrals:` entry is missing `what`, `why`, or `to`. Run `flow-preflight.sh wellformed <file>` per detail file. |
| DONE spec has no unreconciled deferral | ERROR | Index (local) / board (ado) says DONE but a `deferrals:` entry has an unresolved `to` (not `built`, and no spec with that id exists). Run `flow-preflight.sh resolved` — see below. |

**Deferral checks use the shared helper** (`flow-preflight.sh`) so the rule is identical to the commit guard and `/flow:ship`. Find it: the plugin bundles it at `${CLAUDE_PLUGIN_ROOT}/hooks/flow-preflight.sh` — **try that first** — then fall back to the legacy installer locations (`$CLAUDE_CONFIG_DIR/hooks/flow-preflight.sh`, then `~/.claude/hooks/flow-preflight.sh`, then `~/.claude-*/hooks/flow-preflight.sh`). If none is found, say so and fall back to reading the front-matter yourself against the rule above — never silently skip the deferral checks.

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

### Step 7: Rename to descriptive filenames (only if `--rename`)

Rename bare `<id>.md` detail files to the descriptive `<id>-<slug>.md` form so the backlog reads clearly in a file tree, an editor tab, a `git log --stat`, and a PR's changed-files list. This is the **one-time, opt-in retrofit** for a repo that predates the descriptive form — it never runs as part of an audit or `--fix`. **Dry-run by default;** add `--apply` to write.

`--rename <id>` does one spec; `--rename --all` does every spec, active and archived. Note the difference from `--migrate <id>`: that changes a spec's **shape** (flat → directory), this changes its **name**.

1. **Resolve** each target with `flow-preflight.sh spec-path <id> --repo .`. Exit 2 (two files claim the id) → skip that spec and report it; the human resolves it first.
2. **Get the text**: the index entry's Title (local) or the work item's `System.Title` (ado). Slugify it per the rule in the `/flow:run` skill's `reference/authoring.md` — lowercase, non-`[a-z0-9]` → `-`, collapse, trim, truncate at a word boundary to 40 chars (a task's context suffix: 20, from that task file's own `title:`).
3. **Compute the moves.** Flat: `specs/<id>.md` → `specs/<id>-<slug>.md`. Directory: the dir, its orchestrator, **and every task file** move together, since the dir is named for its orchestrator's stem:
   ```
   specs/1.4/            → specs/1.4-auto-tag-commits/
     1.4.md              →   1.4-auto-tag-commits.md
     1.4.T1.md           →   1.4-auto-tag-commits.T1-commit-guard.md
   ```
   An archived spec renames in place, under `specs/archive/`.
4. **Show the complete plan and confirm** — every `git mv` plus every index-link rewrite — before touching anything.
5. **Apply**: `git mv` each path (never delete + recreate — history must survive), then rewrite each `[detail](…)` link in the index to the new path, keeping the id, title, status, and position unchanged. File **contents** are never rewritten: the `id:` front-matter is the identity and does not change.

**Safety:**
- **Nothing moves before confirmation**, and nothing at all without `--apply`.
- **Idempotent** — an already-slugged spec reports "already descriptive" and moves nothing, so `--rename --all` is safe to re-run.
- **Refuses rather than forces**: a target path that already exists is reported as a collision and skipped; a title that slugifies to empty stays bare.
- **The id never changes**, so every commit subject, PR, and cross-spec `to:`/`links:` reference citing `<id>` stays valid — the guards and `spec-path` resolve the new name automatically.
- `flow.spec_filename: id` in `.flow/config.yml` means the project wants bare names: say so and do nothing.

**Report:**
```
flow:lint --rename --all (dry run)
  1.4  specs/1.4/ → specs/1.4-auto-tag-commits/   (+ 2 task files)
  1.5  specs/archive/1.5.md → specs/archive/1.5-ci-hook-tests.md
  1.6  already descriptive — skipped
  1.9  COLLISION: specs/1.9-migrate-pr-skill.md exists — skipped
  3 index links to rewrite. Run with --apply to write.
```

## Rules

- Read-only by default — never modify files without `--fix`, `--migrate --apply`, or `--rename --apply`.
- Always diff before writing; confirm if any change is ambiguous.
- Report the line number for every finding when possible.
- Five precise findings beat a wall of nitpicks. Over 20 findings → group and summarize.
- `--migrate` (either mode) never runs destructively — dry-run first; the legacy conversion backs up and preserves every byte of unclassified content, and the flat→dir conversion uses `git mv` and never rewrites file contents.
- `--rename` is opt-in and never part of an audit or `--fix`: dry-run first, `git mv` only, contents untouched, collisions skipped rather than overwritten.
- **Never resolve an id to a path by hand** — call `flow-preflight.sh spec-path`, so the audit and the guards agree on every filename form.

---
description: "Audit CLAUDE.md hierarchy and SPECIFICATIONS.md for violations — /flow-lint [--claude|--specs|--fix]"
---
# Lint

Audit a project's `CLAUDE.md` hierarchy and `SPECIFICATIONS.md` for structural violations. Reports findings grouped by severity and suggests or applies fixes.

Usage:
- `/flow-lint` — full audit (both CLAUDE.md hierarchy and SPECIFICATIONS.md)
- `/flow-lint --claude` — CLAUDE.md hierarchy only
- `/flow-lint --specs` — SPECIFICATIONS.md only
- `/flow-lint --fix` — full audit, then auto-fix what's safe (normalizes status keywords, fixes heading formats, removes obvious duplication flags)

## Instructions

**Start fresh.** Read only from the project files — `CLAUDE.md`, `SPECIFICATIONS.md`, `README.md`. Do not reference or build on prior conversation context. Treat this as a new session regardless of what preceded it.

### Step 1: Discover the project layout

Read the current directory:
- Is there a root `CLAUDE.md`? Read it in full.
- Is there a `SPECIFICATIONS.md`? Read it in full.
- What subdirectories exist? For each one that's a primary source layer (not `.git`, `node_modules`, `bin`, `obj`, `dist`, `.claude`, `.github`): check whether a `CLAUDE.md` exists inside it and read it if so.

### Step 2: Run CLAUDE.md hierarchy checks (skip if `--specs`)

For each finding, record: **severity** (`ERROR` / `WARNING` / `INFO`), **location** (file + line if applicable), **message**, and a **suggested fix**.

**Root CLAUDE.md:**

| Check | Severity | Condition |
|---|---|---|
| Root CLAUDE.md exists | ERROR | File is missing — without it, `/flow` and `/flow-init` have no anchor. Run `/flow-init` to create it. |
| Root is under 200 lines | WARNING | Line count > 200. Root loads in every session — bloat increases token cost and dilutes focus. |
| Contains `## Architecture` | WARNING | Section heading missing. |
| Contains `## Development Rules` | WARNING | Section heading missing. |
| Contains `## Project Structure` | WARNING | Section heading missing. |
| Contains `## Feature Completion Checklist` | INFO | Section heading missing — recommended but not required. |
| Contains pointer to subdirectory files | INFO | Look for "See subdirectory CLAUDE.md" or "subdirectory CLAUDE.md files". If absent and subdirectory CLAUDE.md files exist, the hierarchy is undocumented. |
| No layer-specific framework detail | WARNING | Heuristic: if root contains more than 2 code blocks or more than 3 `##` sections that name specific frameworks, libraries, or file paths — this content likely belongs in a subdirectory CLAUDE.md. Flag the section headings for review. |

**Subdirectory CLAUDE.md files:**

For each subdirectory CLAUDE.md found:

| Check | Severity | Condition |
|---|---|---|
| Under 150 lines | WARNING | Subdirectory files are additive on top of root; bloat compounds. |
| Not referenced in root | INFO | Root's pointer section or Project Structure doesn't mention this directory. |
| Duplicates a root `##` section heading | ERROR | Find all `##` headings in the subdirectory file. If any heading text exactly matches a `##` heading in the root, it's a duplication — this content will be loaded twice and may contradict the root over time. List the duplicated headings. |
| Contains `## Architecture` or `## Development Rules` or `## Project Structure` | WARNING | These are root-level sections. A subdirectory file should only have layer-specific patterns, not top-level structure. |

**Missing subdirectory CLAUDE.md files:**

For each primary source directory that has no CLAUDE.md: report as `INFO` if the directory is small or simple, `WARNING` if it has 10+ source files. Suggestion: run `/flow-init` or manually create a lean `CLAUDE.md` for that layer.

---

### Step 3: Run SPECIFICATIONS.md checks (skip if `--claude`)

**File-level:**

| Check | Severity | Condition |
|---|---|---|
| SPECIFICATIONS.md exists | WARNING | Missing — run `/flow-init` to create it. |
| Spec 0.1 (Walking Skeleton) is present | WARNING | Every project starts with the walking skeleton. |
| No duplicate spec numbers | ERROR | Find all `### Spec X.Y` headings across SPECIFICATIONS.md AND SPECIFICATIONS-ARCHIVE.md (if present), report any number that appears more than once. |
| Archive exists (either pattern) | WARNING | No `## Archive` section in `SPECIFICATIONS.md` and no `SPECIFICATIONS-ARCHIVE.md` sidecar exists, but DONE specs are present in the active backlog. Run `/flow-lint --fix` to create the appropriate archive. |
| Inline archive is last section | WARNING | If using `## Archive` in `SPECIFICATIONS.md`, it must be the final `##` section. |
| Inline archive not too large | WARNING | If using `## Archive` in `SPECIFICATIONS.md` and it contains more than 20 specs, the active backlog file is getting unwieldy. Migrate to a `SPECIFICATIONS-ARCHIVE.md` sidecar — run `/flow-lint --fix` to split automatically. |
| No active-section specs with status DONE | WARNING | A DONE spec that hasn't been archived yet. These accumulate and make the active backlog harder to scan. |
| No archive specs with non-DONE/non-SUPERSEDED status | ERROR | An IN PROGRESS or NOT STARTED spec in the archive is a mistake — specs only move there on completion or supersession. Check both `## Archive` and `SPECIFICATIONS-ARCHIVE.md`. |

**Per-spec:**

For each spec block (from `### Spec X.Y` to the next `###` heading or end of file):

| Check | Severity | Condition |
|---|---|---|
| Heading matches `### Spec X.Y — Title` | WARNING | Variations like `### Spec X.Y: Title` or `### X.Y — Title` are non-standard; `/flow` may not parse them correctly. |
| Contains exactly one `**Status:**` line | ERROR | Zero status lines = no tracking. Multiple status lines = ambiguous. |
| Status keyword is valid | ERROR | Status must be exactly one of: `DONE` · `IN PROGRESS` · `PARTIAL` · `NOT STARTED` · `SUPERSEDED` (case-sensitive). Report the actual value found. |
| Contains `**User story:**` | INFO | Recommended for clarity; not enforced. |
| Contains `**Acceptance criteria:**` | WARNING | Without criteria, "done" is subjective. |
| No acceptance criteria are unchecked on a DONE spec | WARNING | A spec marked `DONE` with `- [ ]` items still present is likely a mistake. |
| No acceptance criteria are all checked on a non-DONE spec | INFO | All `- [x]` but status isn't `DONE` — probably needs a status update. |

---

### Step 3b: Check README.md (skip if `--claude` or `--specs`)

The README is the day-1 guide — a new developer should be able to clone the repo and reach a running app by following it alone.

| Check | Severity | Condition |
|---|---|---|
| `README.md` exists at the project root | ERROR | Missing — every project must have one. Run `/flow-init` to generate it. |
| Has local setup / getting started section | ERROR | Look for a heading containing "setup", "getting started", "local", or "installation". Without it, a new developer has no path to running the project. |
| Has prerequisites section | WARNING | Look for "prerequisites", "requirements", or "dependencies" heading. Should list runtime versions, tools, and accounts needed before the first step. |
| Has test-running instructions | WARNING | Look for "test" in any heading. If tests exist in the repo (any `*.test.*`, `*.spec.*`, or `tests/` directory) but the README has no test section, new developers won't know how to run them. |
| Commands in setup sections are exact | INFO | Heuristic: look for code blocks in the local setup section. If the section has no code blocks at all, the instructions are likely prose-only and may be incomplete or ambiguous. |
| Spec 0.1 acceptance criterion satisfied | WARNING | If Spec 0.1 is marked DONE but README has no local setup section, the primary Spec 0.1 acceptance criterion ("Local setup documented in README") was likely not met. |

For monorepos or multi-app projects, also check that each major layer has its own `README.md` with app-specific setup instructions. Report as `INFO` for any layer with 5+ source files and no README.

### Step 3c: Check MARKETING.md consistency (if file exists)

If `MARKETING.md` is present, compare its Feature Highlights section against SPECIFICATIONS.md:
- Count specs marked `DONE` in the archive
- If DONE specs exist that clearly added user-facing features but MARKETING.md has no corresponding Feature Highlights entry, flag as `INFO`
- This is advisory only — not every spec produces a marketing bullet. Use judgment.

### Step 4: Report findings

Group by severity and location:

```
## flow-lint Report

### Errors (must fix)
[file:line] MESSAGE
  → Suggested fix

### Warnings (should fix)
[file:line] MESSAGE
  → Suggested fix

### Info (consider)
[file:line] MESSAGE
  → Suggested fix

### Summary
X errors, Y warnings, Z info items
Files checked: [list]
```

If no findings: "All checks passed."

---

### Step 5: Auto-fix (only if `--fix`)

Apply fixes only for safe, mechanical corrections. **Always show a diff and confirm before writing** unless there are zero ambiguous cases.

Safe to auto-fix:
- Status keyword normalization: `done` → `DONE`, `in progress` → `IN PROGRESS`, `not started` → `NOT STARTED`, etc.
- Spec heading format: `### Spec X.Y: Title` → `### Spec X.Y — Title`
- Trailing whitespace, double blank lines in SPECIFICATIONS.md
- **Archive migration**: when inline `## Archive` has more than 20 specs, offer to create `SPECIFICATIONS-ARCHIVE.md`, move all archived specs there (preserving phase groupings and spec content exactly), and replace the `## Archive` section in `SPECIFICATIONS.md` with a one-line pointer: `*Completed specs are in [SPECIFICATIONS-ARCHIVE.md](SPECIFICATIONS-ARCHIVE.md).*` — always show a diff and confirm before writing.

**Do NOT auto-fix:**
- CLAUDE.md content (too risky to modify architectural docs without review)
- Duplicate spec numbers (ambiguous which to keep)
- Missing sections (requires authoring, not just formatting)
- Line count issues (requires human judgment about what to trim)

For anything not auto-fixed, leave the full report so the user can address manually or with `/flow-init` (for CLAUDE.md gaps) or `/flow --clean` (for deeper SPECIFICATIONS.md cleanup).

## Rules

- Read-only by default — never modify files without `--fix`.
- With `--fix`: always diff before writing, confirm if any fix is ambiguous.
- Report the line number for every finding when possible — makes it actionable.
- Five precise findings beat a wall of nitpicks. If there are more than 20 findings, group and summarize rather than listing every instance.

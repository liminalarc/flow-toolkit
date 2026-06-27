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
| Under 100 lines | WARNING | Subdirectory files are additive on top of root; bloat compounds. |
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
| No duplicate spec numbers | ERROR | Find all `### Spec X.Y` headings across both active and archive sections, report any number that appears more than once. |
| Archive section exists | INFO | `## Archive` section should be present at the end of the file. If absent and there are any DONE specs in active phases, flag as WARNING — done specs should be archived. |
| Archive section is last | WARNING | `## Archive` must be the final `##` section. Anything after it won't be treated as active backlog, but the ordering signals intent. |
| No active-section specs with status DONE | WARNING | A DONE spec that hasn't been moved to Archive yet. These accumulate and make the active backlog harder to scan. |
| No Archive specs with non-DONE/non-SUPERSEDED status | ERROR | An IN PROGRESS or NOT STARTED spec in the Archive section is a mistake — specs only archive on completion or supersession. |

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

### Step 3b: Check MARKETING.md consistency (if file exists)

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

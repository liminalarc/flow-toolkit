#!/usr/bin/env bash
# hooks.test.sh — unit tests for the format-parsing hooks (flow-spec-guard.sh,
# flow-session-brief.sh) against the index + detail-file spec model.
# Run directly:  bash hooks/hooks.test.sh
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
GUARD="$HERE/flow-spec-guard.sh"
BRIEF="$HERE/flow-session-brief.sh"
PREFLIGHT="$HERE/flow-preflight.sh"

pass=0; fail=0
exit_is() { # desc expected actual
    if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: $1 — expected exit $2, got $3"; fi
}
out_has() { # desc needle haystack
    case "$3" in *"$2"*) pass=$((pass+1));; *) fail=$((fail+1)); echo "FAIL: $1 — output missing: $2"; echo "  got: $3";; esac
}
out_lacks() { # desc needle haystack
    case "$3" in *"$2"*) fail=$((fail+1)); echo "FAIL: $1 — output should not contain: $2"; echo "  got: $3";; *) pass=$((pass+1));; esac
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/specs/archive"

# ---- flow-spec-guard: index ----
cat > "$tmp/SPECIFICATIONS.md" <<'EOF'
# Proj — Specifications

## Phase 1 — Core
- **1.1** User Auth — `IN PROGRESS` — [detail](specs/1.1.md)
- **1.2** Password Reset — `NOT STARTED` — [detail](specs/1.2.md)

## Archive
- **0.1** Walking Skeleton — `DONE` — [detail](specs/archive/0.1.md)
EOF
bash "$GUARD" "$tmp/SPECIFICATIONS.md" 2>/dev/null; exit_is "valid index passes" 0 $?

# Flat / dashed / single-char ids (projects that don't use the Phase.Spec dotted
# scheme — e.g. "226", "21c", "T2", "BL-12", "N"). The header comment already
# lists "BL-12" as a valid id, so these must all pass.
cat > "$tmp/SPECIFICATIONS.md" <<'EOF'
# Proj — Specifications

## Backlog
- **10** Board templates — `NOT STARTED` — [detail](specs/10.md)
- **226** MCP Server — Foundation — `NOT STARTED` — [detail](specs/226.md)
- **21c** Design-Level — Refined Specs — `NOT STARTED` — [detail](specs/21c.md)
- **T2** API versioning — `PARTIAL` — [detail](specs/T2.md)
- **BL-12** Backlog item — `DONE` — [detail](specs/BL-12.md)
- **N** Template — `NOT STARTED` — [detail](specs/N.md)
EOF
bash "$GUARD" "$tmp/SPECIFICATIONS.md" 2>/dev/null; exit_is "flat/dashed/single-char ids pass" 0 $?

# Duplicate detection still works for flat ids.
cat > "$tmp/SPECIFICATIONS.md" <<'EOF'
- **226** X — `DONE` — [detail](specs/226.md)
- **226** Y — `NOT STARTED` — [detail](specs/226.md)
EOF
bash "$GUARD" "$tmp/SPECIFICATIONS.md" 2>/dev/null; exit_is "duplicate flat id blocks" 2 $?

cat > "$tmp/bad-status.md" <<'EOF'
- **1.1** X — `WIP` — [detail](specs/1.1.md)
EOF
mv "$tmp/bad-status.md" "$tmp/SPECIFICATIONS.md"
bash "$GUARD" "$tmp/SPECIFICATIONS.md" 2>/dev/null; exit_is "invalid status blocks" 2 $?

cat > "$tmp/SPECIFICATIONS.md" <<'EOF'
- **1.1** X — `DONE`
EOF
bash "$GUARD" "$tmp/SPECIFICATIONS.md" 2>/dev/null; exit_is "missing detail link blocks" 2 $?

cat > "$tmp/SPECIFICATIONS.md" <<'EOF'
- **1.1** X — `DONE` — [detail](specs/1.1.md)
- **1.1** Y — `NOT STARTED` — [detail](specs/1.1.md)
EOF
bash "$GUARD" "$tmp/SPECIFICATIONS.md" 2>/dev/null; exit_is "duplicate id blocks" 2 $?

cat > "$tmp/SPECIFICATIONS.md" <<'EOF'
# Proj — Specifications
## Phase 1
### Spec 1.1 — User Auth
**Status:** IN PROGRESS
EOF
bash "$GUARD" "$tmp/SPECIFICATIONS.md" 2>/dev/null; exit_is "legacy inline passes (advisory)" 0 $?

# ---- flow-spec-guard: detail files ----
cat > "$tmp/specs/1.1.md" <<'EOF'
---
id: 1.1
title: User Auth
---
## Problem
x
EOF
bash "$GUARD" "$tmp/specs/1.1.md" 2>/dev/null; exit_is "valid detail passes" 0 $?

cat > "$tmp/specs/1.2.md" <<'EOF'
---
id: 1.2
title: Reset
---
**Status:** DONE
EOF
bash "$GUARD" "$tmp/specs/1.2.md" 2>/dev/null; exit_is "detail with status blocks" 2 $?

cat > "$tmp/specs/1.3.md" <<'EOF'
---
id: 9.9
title: Mismatch
---
## Problem
x
EOF
bash "$GUARD" "$tmp/specs/1.3.md" 2>/dev/null; exit_is "detail id/filename mismatch blocks" 2 $?

echo "not a spec" > "$tmp/README.md"
bash "$GUARD" "$tmp/README.md" 2>/dev/null; exit_is "non-spec file ignored" 0 $?

# ---- flow-spec-guard: soft bloat warning (default budget 120 lines) ----
# Over budget must WARN but never block (exit 0). No .flow-toolkit.json here, so
# the default 120 applies (find_repo_root finds no .git in the temp dir).
{ printf -- '---\nid: 3.1\ntitle: Big\n---\n## Problem\n'; for i in $(seq 1 200); do echo "line $i"; done; } > "$tmp/specs/3.1.md"
bash "$GUARD" "$tmp/specs/3.1.md" 2>/dev/null; exit_is "over-budget detail warns but passes" 0 $?
bw=$(bash "$GUARD" "$tmp/specs/3.1.md" 2>&1 >/dev/null)
out_has "over-budget warning names the file" "3.1.md is" "$bw"
out_has "over-budget warning cites soft budget" "soft budget 120" "$bw"

# Under budget ⇒ silent pass (no warning text on stdout or stderr).
{ printf -- '---\nid: 3.2\ntitle: Small\n---\n## Problem\nx\n'; } > "$tmp/specs/3.2.md"
bash "$GUARD" "$tmp/specs/3.2.md" 2>/dev/null; exit_is "under-budget detail passes" 0 $?
uq=$(bash "$GUARD" "$tmp/specs/3.2.md" 2>&1)
out_lacks "under-budget is silent" "soft budget" "$uq"

# Hook mode (stdin JSON) emits an additionalContext note for an over-budget file.
hookout=$(printf '{"tool_input":{"file_path":"%s"}}' "$tmp/specs/3.1.md" | bash "$GUARD")
out_has "hook-mode over-budget emits additionalContext" "additionalContext" "$hookout"

# Configurable: spec.maxLines in .flow-toolkit.json raises the budget (git repo required
# so find_repo_root locates the config). A 200-line file under a 500 budget is silent.
cfgdir=$(mktemp -d); mkdir -p "$cfgdir/specs"; git -C "$cfgdir" init -q
echo '{ "spec": { "maxLines": 500 } }' > "$cfgdir/.flow-toolkit.json"
cp "$tmp/specs/3.1.md" "$cfgdir/specs/3.1.md"
cq=$(bash "$GUARD" "$cfgdir/specs/3.1.md" 2>&1)
out_lacks "configured budget suppresses warning" "soft budget" "$cq"
rm -rf "$cfgdir"

# ---- flow-spec-guard: dual-shape task files (1.6) ----
# A big spec earns specs/<id>/ = orchestrator <id>.md + task files <id>.T<n>.md.
# A task file keeps the no-status + id==stem checks and gains a SOFT local-AC
# nudge; the orchestrator must validate as an ordinary detail file (the .T<n>
# rule must not misfire on it).
mkdir -p "$tmp/specs/1.7"

# Orchestrator: ordinary detail file (id==stem, no status), no AC nudge even
# though it carries no checkbox — it is not a task file.
cat > "$tmp/specs/1.7/1.7.md" <<'EOF'
---
id: 1.7
title: Orchestrator
---
## Problem
x
## Acceptance criteria
- [ ] whole-spec AC
EOF
bash "$GUARD" "$tmp/specs/1.7/1.7.md" 2>/dev/null; exit_is "orchestrator dir detail passes" 0 $?
orch=$(bash "$GUARD" "$tmp/specs/1.7/1.7.md" 2>&1)
out_lacks "orchestrator gets no task-file AC nudge" "local AC" "$orch"

# Task file with a local AC (a Done-when checkbox) → clean, silent.
cat > "$tmp/specs/1.7/1.7.T1.md" <<'EOF'
---
id: 1.7.T1
title: Task one
---
## Goal
how
## Done when
- [ ] the seam works
EOF
bash "$GUARD" "$tmp/specs/1.7/1.7.T1.md" 2>/dev/null; exit_is "task file with local AC passes" 0 $?
t1=$(bash "$GUARD" "$tmp/specs/1.7/1.7.T1.md" 2>&1)
out_lacks "task file with AC is silent" "local AC" "$t1"

# Task file with NO local AC → soft nudge, but still exit 0 (never blocks).
cat > "$tmp/specs/1.7/1.7.T2.md" <<'EOF'
---
id: 1.7.T2
title: Task two
---
## Goal
how, but no done-when checkbox
EOF
bash "$GUARD" "$tmp/specs/1.7/1.7.T2.md" 2>/dev/null; exit_is "task file without AC still passes" 0 $?
t2=$(bash "$GUARD" "$tmp/specs/1.7/1.7.T2.md" 2>&1)
out_has "task file without AC nudges" "local AC" "$t2"

# Task file carrying a status → blocks (no-status rule still applies).
cat > "$tmp/specs/1.7/1.7.T3.md" <<'EOF'
---
id: 1.7.T3
title: Task three
---
**Status:** DONE
## Done when
- [ ] x
EOF
bash "$GUARD" "$tmp/specs/1.7/1.7.T3.md" 2>/dev/null; exit_is "task file with status blocks" 2 $?

# Task file id/stem mismatch → blocks.
cat > "$tmp/specs/1.7/1.7.T4.md" <<'EOF'
---
id: 1.7.T9
title: Wrong id
---
## Done when
- [ ] x
EOF
bash "$GUARD" "$tmp/specs/1.7/1.7.T4.md" 2>/dev/null; exit_is "task file id/stem mismatch blocks" 2 $?

# A flat spec whose name merely looks task-like (specs/2.T3.md, parent dir is
# "specs" not "2") must NOT get the task-file AC nudge.
cat > "$tmp/specs/2.T3.md" <<'EOF'
---
id: 2.T3
title: Not a task
---
## Problem
x
EOF
flat=$(bash "$GUARD" "$tmp/specs/2.T3.md" 2>&1)
out_lacks "flat task-looking name gets no AC nudge" "local AC" "$flat"

# ---- flow-session-brief: index + legacy ----
cat > "$tmp/SPECIFICATIONS.md" <<'EOF'
# Proj — Specifications
## Phase 1 — Core
- **1.1** User Auth — `IN PROGRESS` — [detail](specs/1.1.md)
- **1.2** Password Reset — `NOT STARTED` — [detail](specs/1.2.md)
## Archive
- **0.1** Walking Skeleton — `DONE` — [detail](specs/archive/0.1.md)
EOF
brief=$(printf '{"cwd":"%s"}' "$tmp" | bash "$BRIEF")
out_has "brief names IN PROGRESS spec" "User Auth is IN PROGRESS" "$brief"
out_has "brief counts NOT STARTED" "1 NOT STARTED" "$brief"
out_has "brief counts DONE" "1 DONE" "$brief"

cat > "$tmp/SPECIFICATIONS.md" <<'EOF'
### Spec 1.1 — User Auth
**Status:** IN PROGRESS
### Spec 1.2 — Reset
**Status:** NOT STARTED
EOF
brief=$(printf '{"cwd":"%s"}' "$tmp" | bash "$BRIEF")
out_has "brief legacy fallback names IN PROGRESS" "User Auth is IN PROGRESS" "$brief"
out_has "brief legacy fallback counts" "1 NOT STARTED" "$brief"

# ---- flow-preflight: deferral wellformedness ----
pf=$(mktemp -d); mkdir -p "$pf/specs/archive"

cat > "$pf/specs/2.1.md" <<'EOF'
---
id: 2.1
title: Import
deferrals:
  - what: "file import"
    why: "scope"
    to: 2.6
  - what: "dedupe"
    why: "done here"
    to: built
---
## Problem
x
EOF
bash "$PREFLIGHT" wellformed "$pf/specs/2.1.md" 2>/dev/null; exit_is "wellformed: complete entries pass" 0 $?

cat > "$pf/specs/2.2.md" <<'EOF'
---
id: 2.2
title: Plain
---
## Problem
x
EOF
bash "$PREFLIGHT" wellformed "$pf/specs/2.2.md" 2>/dev/null; exit_is "wellformed: no deferrals key passes" 0 $?

cat > "$pf/specs/2.3.md" <<'EOF'
---
id: 2.3
title: Bad
deferrals:
  - what: "export"
    to: 9.9
  - what: "csv"
    why: "later"
---
## Problem
x
EOF
wf=$(bash "$PREFLIGHT" wellformed "$pf/specs/2.3.md" 2>&1); exit_is "wellformed: missing why/to blocks" 2 $?
out_has "wellformed: names missing why" 'deferral #1: missing "why"' "$wf"
out_has "wellformed: names missing to" 'deferral #2: missing "to"' "$wf"

# spec-guard delegates wellformedness on edit
bash "$GUARD" "$pf/specs/2.3.md" 2>/dev/null; exit_is "spec-guard blocks malformed deferral on edit" 2 $?

# ---- flow-preflight: DONE-gating (resolved) ----
cat > "$pf/specs/2.6.md" <<'EOF'
---
id: 2.6
title: File import
---
## Problem
x
EOF
cat > "$pf/SPECIFICATIONS.md" <<'EOF'
# Proj
## Phase 2
- **2.1** Import — `DONE` — [detail](specs/2.1.md)
- **2.3** Bad — `DONE` — [detail](specs/2.3.md)
- **2.6** File import — `NOT STARTED` — [detail](specs/2.6.md)
EOF
res=$(bash "$PREFLIGHT" resolved --repo "$pf" 2>&1); exit_is "resolved: unreconciled DONE spec blocks" 2 $?
out_has "resolved: flags unknown receiving id" "to: 9.9 — no such spec" "$res"
out_has "resolved: flags missing to" '"csv" has no `to`' "$res"

# 2.1 alone is fully resolved (to: 2.6 exists, to: built)
bash "$PREFLIGHT" resolved --repo "$pf" --done "2.1" 2>/dev/null; exit_is "resolved: fully-reconciled spec passes" 0 $?
# index with no DONE specs ⇒ nothing to gate
cat > "$pf/SPECIFICATIONS.md" <<'EOF'
# Proj
## Phase 2
- **2.1** Import — `IN PROGRESS` — [detail](specs/2.1.md)
EOF
bash "$PREFLIGHT" resolved --repo "$pf" 2>/dev/null; exit_is "resolved: no DONE specs passes" 0 $?

# ---- flow-preflight: dual-shape specs/<id>/ (1.6) ----
# The DONE-gate + `to`-resolution must both accept the directory form
# specs/<id>/<id>.md (orchestrator) and specs/archive/<id>/<id>.md.
df=$(mktemp -d); mkdir -p "$df/specs/archive"

# (A) to_resolves: a flat DONE spec's deferral points to a DIR-form receiving
# spec — isolates to_resolves() (the DONE spec itself is found the old way).
mkdir -p "$df/specs/3.2"
cat > "$df/specs/3.2/3.2.md" <<'EOF'
---
id: 3.2
title: Receiver
---
## Problem
x
EOF
cat > "$df/specs/3.1.md" <<'EOF'
---
id: 3.1
title: Deferrer
deferrals:
  - what: "task split"
    why: "scope"
    to: 3.2
---
## Problem
x
EOF
bash "$PREFLIGHT" resolved --repo "$df" --done "3.1" 2>/dev/null; exit_is "resolved: to a dir-form spec resolves" 0 $?

# (B) to_resolves: deferral points to an ARCHIVED dir-form spec.
mkdir -p "$df/specs/archive/3.4"
cat > "$df/specs/archive/3.4/3.4.md" <<'EOF'
---
id: 3.4
title: Archived receiver
---
## Problem
x
EOF
cat > "$df/specs/3.3.md" <<'EOF'
---
id: 3.3
title: Deferrer 2
deferrals:
  - what: "later bit"
    why: "scope"
    to: 3.4
---
## Problem
x
EOF
bash "$PREFLIGHT" resolved --repo "$df" --done "3.3" 2>/dev/null; exit_is "resolved: to an archived dir-form spec resolves" 0 $?

# (C) DONE-set lookup: the DONE spec's OWN detail is a dir-form orchestrator.
# It has an unresolved deferral, so a found file must block — if the lookup
# missed specs/3.5/3.5.md it would silently pass (exit 0).
mkdir -p "$df/specs/3.5"
cat > "$df/specs/3.5/3.5.md" <<'EOF'
---
id: 3.5
title: Dir orchestrator
deferrals:
  - what: "dangling"
    why: "scope"
    to: 9.9
---
## Problem
x
EOF
bash "$PREFLIGHT" resolved --repo "$df" --done "3.5" 2>/dev/null; exit_is "resolved: dir-form orchestrator lookup gates" 2 $?

# (D) DONE-set lookup: the DONE spec is an ARCHIVED dir-form orchestrator.
mkdir -p "$df/specs/archive/3.6"
cat > "$df/specs/archive/3.6/3.6.md" <<'EOF'
---
id: 3.6
title: Archived dir orchestrator
deferrals:
  - what: "dangling"
    why: "scope"
    to: 9.9
---
## Problem
x
EOF
bash "$PREFLIGHT" resolved --repo "$df" --done "3.6" 2>/dev/null; exit_is "resolved: archived dir-form orchestrator lookup gates" 2 $?

# ---- flow-commit-guard: [id] subject-tag nudge (check 3b) ----
CGUARD="$HERE/flow-commit-guard.sh"
cg="$tmp/cg"; mkdir -p "$cg/specs"
cg_json() { printf '{"cwd":"%s","tool_input":{"command":"%s"}}' "$1" "$2"; }

# One spec IN PROGRESS, untagged subject → soft nudge with the exact [id], exit 0.
cat > "$cg/SPECIFICATIONS.md" <<'EOF'
# Proj
## Phase 1
- **1.4** Auto-tag — `IN PROGRESS` — [detail](specs/1.4.md)
EOF
out=$(cg_json "$cg" 'git commit -m \"docs: no tag here\"' | bash "$CGUARD" 2>/dev/null); rc=$?
exit_is "commit-guard: untagged commit is allowed (soft)" 0 "$rc"
out_has "commit-guard: nudges the exact [id]" "[1.4]" "$out"

# Already-tagged subject → silent (no nudge).
out=$(cg_json "$cg" 'git commit -m \"[1.4] docs: tagged\"' | bash "$CGUARD" 2>/dev/null); rc=$?
exit_is "commit-guard: tagged commit passes" 0 "$rc"
out_lacks "commit-guard: no nudge when already tagged" "no [id] tag" "$out"

# >1 spec IN PROGRESS → ambiguous, no id nudge.
cat > "$cg/SPECIFICATIONS.md" <<'EOF'
# Proj
## Phase 1
- **1.4** Auto-tag — `IN PROGRESS` — [detail](specs/1.4.md)
- **1.5** CI — `IN PROGRESS` — [detail](specs/1.5.md)
EOF
out=$(cg_json "$cg" 'git commit -m \"docs: no tag here\"' | bash "$CGUARD" 2>/dev/null); rc=$?
exit_is "commit-guard: >1 IN PROGRESS still passes" 0 "$rc"
out_lacks "commit-guard: silent when >1 IN PROGRESS" "no [id] tag" "$out"

# Non-conventional subject still blocks (check 1 sanity).
out=$(cg_json "$cg" 'git commit -m \"random message\"' | bash "$CGUARD" 2>&1); rc=$?
exit_is "commit-guard: non-conventional subject blocks" 2 "$rc"

# Commit-guard inherits the dir-form DONE-gate via preflight (no inline path
# assumption): a DONE spec whose detail is a dir-form orchestrator with a
# dangling deferral must block the commit.
cgd="$tmp/cgd"; mkdir -p "$cgd/specs/9.1"
cat > "$cgd/specs/9.1/9.1.md" <<'EOF'
---
id: 9.1
title: Dir spec
deferrals:
  - what: "dangling"
    why: "scope"
    to: 9.9
---
## Problem
x
EOF
cat > "$cgd/SPECIFICATIONS.md" <<'EOF'
# Proj
## Archive
- **9.1** Dir spec — `DONE` — [detail](specs/9.1/9.1.md)
EOF
out=$(cg_json "$cgd" 'git commit -m \"[9.1] feat: x\"' | bash "$CGUARD" 2>&1); rc=$?
exit_is "commit-guard: dir-form DONE spec with dangling deferral blocks" 2 "$rc"

# ---- flow-preflight: autonomy resolution (1.7) ----
# Precedence: autonomy.force > per-spec front-matter > autonomy.default >
# builtin checkpoint. force is a hard project override; default is only the
# fallback when the spec is silent; a spec's own autonomy: beats the default.
au=$(mktemp -d); mkdir -p "$au/specs"; git -C "$au" init -q

spec_fm() { # <id> <autonomy-value|"">   writes specs/<id>.md, omitting the key if empty
    if [ -n "$2" ]; then
        printf -- '---\nid: %s\ntitle: T\nautonomy: %s\n---\n## Problem\nx\n' "$1" "$2" > "$au/specs/$1.md"
    else
        printf -- '---\nid: %s\ntitle: T\n---\n## Problem\nx\n' "$1" > "$au/specs/$1.md"
    fi
}
cfg() { printf '%s\n' "$1" > "$au/.flow-toolkit.json"; }   # write .flow-toolkit.json
nocfg() { rm -f "$au/.flow-toolkit.json"; }

# No config, no front-matter → builtin default checkpoint.
nocfg; spec_fm 1.1 ""
r=$(bash "$PREFLIGHT" autonomy "$au/specs/1.1.md" --repo "$au" 2>/dev/null); exit_is "autonomy: bare spec exit 0" 0 $?
out_has "autonomy: bare spec → checkpoint" "checkpoint" "$r"

# Per-spec front-matter with no config → the spec's own value wins.
spec_fm 1.2 "auto-build"
r=$(bash "$PREFLIGHT" autonomy "$au/specs/1.2.md" --repo "$au" 2>/dev/null)
out_has "autonomy: per-spec auto-build wins (no config)" "auto-build" "$r"

# Repo default applies only when the spec is silent.
cfg '{ "autonomy": { "default": "auto-build" } }'; spec_fm 1.3 ""
r=$(bash "$PREFLIGHT" autonomy "$au/specs/1.3.md" --repo "$au" 2>/dev/null)
out_has "autonomy: repo default fills a silent spec" "auto-build" "$r"

# Per-spec BEATS repo default (spec says checkpoint, default says auto-build).
cfg '{ "autonomy": { "default": "auto-build" } }'; spec_fm 1.4 "checkpoint"
r=$(bash "$PREFLIGHT" autonomy "$au/specs/1.4.md" --repo "$au" 2>/dev/null)
out_has "autonomy: per-spec beats repo default" "checkpoint" "$r"

# force OVERRIDES a per-spec value (spec auto-build, force checkpoint → checkpoint).
cfg '{ "autonomy": { "force": "checkpoint", "default": "auto-build" } }'; spec_fm 1.5 "auto-build"
r=$(bash "$PREFLIGHT" autonomy "$au/specs/1.5.md" --repo "$au" 2>/dev/null)
out_has "autonomy: force overrides per-spec" "checkpoint" "$r"

# force wins even over a silent spec + opposite default.
cfg '{ "autonomy": { "force": "auto-build", "default": "checkpoint" } }'; spec_fm 1.6 ""
r=$(bash "$PREFLIGHT" autonomy "$au/specs/1.6.md" --repo "$au" 2>/dev/null)
out_has "autonomy: force wins over silent spec" "auto-build" "$r"

# Unknown per-spec value → advisory on stderr + safe default checkpoint, exit 0.
nocfg; spec_fm 1.7 "yolo"
r=$(bash "$PREFLIGHT" autonomy "$au/specs/1.7.md" --repo "$au" 2>/dev/null); exit_is "autonomy: unknown value exit 0" 0 $?
out_has "autonomy: unknown value falls back to checkpoint" "checkpoint" "$r"
adv=$(bash "$PREFLIGHT" autonomy "$au/specs/1.7.md" --repo "$au" 2>&1 >/dev/null)
out_has "autonomy: unknown value warns on stderr" "yolo" "$adv"
rm -rf "$au"

echo "hooks.test.sh: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

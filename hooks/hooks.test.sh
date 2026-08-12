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

# ---- flow-spec-guard: slugged filenames (1.17) ----
# A descriptive slug may follow the id in any detail-file stem: <id>-<slug>.md,
# <id>-<slug>/<id>-<slug>.md, and <id>-<slug>.T<n>-<ctx>.md. Identity stays the
# front-matter `id:` — never parsed out of the name — so the guard validates the
# stem AGAINST the id, and a genuine mismatch must still block.

# Flat slugged spec.
cat > "$tmp/specs/4.1-user-facing-slugs.md" <<'EOF'
---
id: 4.1
title: User facing slugs
---
## Problem
x
EOF
bash "$GUARD" "$tmp/specs/4.1-user-facing-slugs.md" 2>/dev/null; exit_is "flat slugged stem passes" 0 $?

# Slugged dir form: dir, orchestrator, and task files all carry the slug.
mkdir -p "$tmp/specs/4.2-slug-everywhere"
cat > "$tmp/specs/4.2-slug-everywhere/4.2-slug-everywhere.md" <<'EOF'
---
id: 4.2
title: Slug everywhere
---
## Problem
x
EOF
bash "$GUARD" "$tmp/specs/4.2-slug-everywhere/4.2-slug-everywhere.md" 2>/dev/null; exit_is "slugged orchestrator passes" 0 $?
so=$(bash "$GUARD" "$tmp/specs/4.2-slug-everywhere/4.2-slug-everywhere.md" 2>&1)
out_lacks "slugged orchestrator gets no task nudge" "local AC" "$so"

# Slugged task file with its own context suffix + a local AC → clean, silent.
cat > "$tmp/specs/4.2-slug-everywhere/4.2-slug-everywhere.T1-guard-relax.md" <<'EOF'
---
id: 4.2.T1
title: Guard relax
---
## Goal
how
## Done when
- [ ] the seam works
EOF
bash "$GUARD" "$tmp/specs/4.2-slug-everywhere/4.2-slug-everywhere.T1-guard-relax.md" 2>/dev/null; exit_is "slugged task file passes" 0 $?
st=$(bash "$GUARD" "$tmp/specs/4.2-slug-everywhere/4.2-slug-everywhere.T1-guard-relax.md" 2>&1)
out_lacks "slugged task file with AC is silent" "local AC" "$st"

# Slugged task file with NO local AC → the soft nudge still fires (exit 0).
cat > "$tmp/specs/4.2-slug-everywhere/4.2-slug-everywhere.T2-no-ac.md" <<'EOF'
---
id: 4.2.T2
title: No AC
---
## Goal
no done-when checkbox
EOF
bash "$GUARD" "$tmp/specs/4.2-slug-everywhere/4.2-slug-everywhere.T2-no-ac.md" 2>/dev/null; exit_is "slugged task without AC still passes" 0 $?
sn=$(bash "$GUARD" "$tmp/specs/4.2-slug-everywhere/4.2-slug-everywhere.T2-no-ac.md" 2>&1)
out_has "slugged task without AC nudges" "local AC" "$sn"

# A slug on the dir but a bare task stem (or vice versa) is still a mismatch of
# neither kind — the task id/stem rule allows the slug to be present or absent
# on each segment independently.
cat > "$tmp/specs/4.2-slug-everywhere/4.2-slug-everywhere.T3.md" <<'EOF'
---
id: 4.2.T3
title: No context suffix
---
## Done when
- [ ] x
EOF
bash "$GUARD" "$tmp/specs/4.2-slug-everywhere/4.2-slug-everywhere.T3.md" 2>/dev/null; exit_is "slugged spec with bare task stem passes" 0 $?

# An id that itself contains a dash (BL-12) stays unambiguous — the slug is the
# remainder after "<id>-", so identity never has to be parsed out of the name.
cat > "$tmp/specs/BL-12-backlog-item.md" <<'EOF'
---
id: BL-12
title: Backlog item
---
## Problem
x
EOF
bash "$GUARD" "$tmp/specs/BL-12-backlog-item.md" 2>/dev/null; exit_is "dashed id with slug passes" 0 $?

# A GENUINE mismatch must still block, and the message must name both legal forms.
cat > "$tmp/specs/4.3-wrong-id.md" <<'EOF'
---
id: 9.9
title: Wrong id
---
## Problem
x
EOF
bash "$GUARD" "$tmp/specs/4.3-wrong-id.md" 2>/dev/null; exit_is "slugged stem with wrong id blocks" 2 $?
me=$(bash "$GUARD" "$tmp/specs/4.3-wrong-id.md" 2>&1)
out_has "mismatch message names the slugged form" "<id>-<slug>" "$me"

# The relaxation must not become a loose prefix match: id 4.1 in file 4.15.md is
# a mismatch (4.15 does not start with "4.1-"), not a slug.
cat > "$tmp/specs/4.15.md" <<'EOF'
---
id: 4.1
title: Prefix collision
---
## Problem
x
EOF
bash "$GUARD" "$tmp/specs/4.15.md" 2>/dev/null; exit_is "id that is a bare prefix of the stem blocks" 2 $?

# Likewise for the task form: id 4.2.T1 must not accept a different task number.
cat > "$tmp/specs/4.2-slug-everywhere/4.2-slug-everywhere.T9-mismatch.md" <<'EOF'
---
id: 4.2.T1
title: Wrong task number
---
## Done when
- [ ] x
EOF
bash "$GUARD" "$tmp/specs/4.2-slug-everywhere/4.2-slug-everywhere.T9-mismatch.md" 2>/dev/null; exit_is "slugged task with wrong task number blocks" 2 $?

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

# ---- flow-preflight: spec-path resolver (1.17) ----
# One subcommand owns id -> path for every combination of shape (flat|dir),
# name (plain|slugged) and location (active|archive). to_resolves and
# cmd_resolved both delegate to it, so the rule exists in exactly one place.
sp=$(mktemp -d); mkdir -p "$sp/specs/archive"

path_is() { # desc id expected-relative-path
    _got=$(bash "$PREFLIGHT" spec-path "$2" --repo "$sp" 2>/dev/null)
    _rc=$?
    if [ "$_rc" -ne 0 ]; then
        fail=$((fail+1)); echo "FAIL: $1 — exit $_rc, expected to resolve to $3"
    else
        out_has "$1" "$3" "$_got"
    fi
}
mkspec() { mkdir -p "$(dirname "$sp/$1")"; printf -- '---\nid: %s\ntitle: T\n---\n## Problem\nx\n' "$2" > "$sp/$1"; }

mkspec specs/5.1.md 5.1                                  # flat plain active
mkspec specs/5.2-flat-slug.md 5.2                        # flat slugged active
mkspec specs/5.3/5.3.md 5.3                              # dir plain active
mkspec specs/5.4-dir-slug/5.4-dir-slug.md 5.4            # dir slugged active
mkspec specs/archive/5.5.md 5.5                          # flat plain archive
mkspec specs/archive/5.6-arch-slug.md 5.6                # flat slugged archive
mkspec specs/archive/5.7/5.7.md 5.7                      # dir plain archive
mkspec specs/archive/5.8-arch-dir/5.8-arch-dir.md 5.8    # dir slugged archive

path_is "spec-path: flat plain active"    5.1 "specs/5.1.md"
path_is "spec-path: flat slugged active"  5.2 "specs/5.2-flat-slug.md"
path_is "spec-path: dir plain active"     5.3 "specs/5.3/5.3.md"
path_is "spec-path: dir slugged active"   5.4 "specs/5.4-dir-slug/5.4-dir-slug.md"
path_is "spec-path: flat plain archive"   5.5 "specs/archive/5.5.md"
path_is "spec-path: flat slugged archive" 5.6 "specs/archive/5.6-arch-slug.md"
path_is "spec-path: dir plain archive"    5.7 "specs/archive/5.7/5.7.md"
path_is "spec-path: dir slugged archive"  5.8 "specs/archive/5.8-arch-dir/5.8-arch-dir.md"

# An id containing a dash resolves through the slug form.
mkspec specs/BL-13-dashed-id.md BL-13
path_is "spec-path: dashed id with slug" BL-13 "specs/BL-13-dashed-id.md"

# Not found: exit 1, and NOTHING on stdout (callers decide if absence is an error).
nf=$(bash "$PREFLIGHT" spec-path 9.9 --repo "$sp" 2>/dev/null); exit_is "spec-path: not found exits 1" 1 $?
out_lacks "spec-path: not found prints nothing" "specs/" "$nf"

# The slug glob must not become a loose prefix match: id 5.9 does not resolve to
# specs/5.95-other.md (the "-" after the id is required).
mkspec specs/5.95-other.md 5.95
bash "$PREFLIGHT" spec-path 5.9 --repo "$sp" >/dev/null 2>&1; exit_is "spec-path: id is not a loose prefix" 1 $?
path_is "spec-path: the longer id still resolves" 5.95 "specs/5.95-other.md"

# Ambiguity is a real authoring bug (two slugged files for one id) — exit 2, and
# the message must name both candidates rather than silently picking one.
mkspec specs/6.1-first-name.md 6.1
mkspec specs/6.1-second-name.md 6.1
amb=$(bash "$PREFLIGHT" spec-path 6.1 --repo "$sp" 2>&1); exit_is "spec-path: ambiguous resolution exits 2" 2 $?
out_has "spec-path: ambiguity names first candidate"  "6.1-first-name.md"  "$amb"
out_has "spec-path: ambiguity names second candidate" "6.1-second-name.md" "$amb"

# A plain <id>.md wins over a slugged sibling — an exact name is never ambiguous.
mkspec specs/6.2.md 6.2
mkspec specs/6.2-also-here.md 6.2
path_is "spec-path: exact name beats slugged sibling" 6.2 "specs/6.2.md"

# --spec-dir is honoured.
mkdir -p "$sp/plans"; mkspec plans/7.1-elsewhere.md 7.1
sd=$(bash "$PREFLIGHT" spec-path 7.1 --repo "$sp" --spec-dir plans 2>/dev/null); exit_is "spec-path: --spec-dir honoured" 0 $?
out_has "spec-path: --spec-dir resolves" "plans/7.1-elsewhere.md" "$sd"

# The DONE-gate now reaches slugged specs — both the DONE spec's own lookup and
# `to`-resolution. A dangling deferral on a slugged DONE spec must block.
mkspec specs/8.2-receiver.md 8.2
cat > "$sp/specs/8.1-deferrer.md" <<'EOF'
---
id: 8.1
title: Slugged deferrer
deferrals:
  - what: "dangling"
    why: "scope"
    to: 9.9
---
## Problem
x
EOF
bash "$PREFLIGHT" resolved --repo "$sp" --done "8.1" 2>/dev/null; exit_is "resolved: slugged DONE spec is found and gates" 2 $?
cat > "$sp/specs/8.3-resolved.md" <<'EOF'
---
id: 8.3
title: Points at a slugged receiver
deferrals:
  - what: "split out"
    why: "scope"
    to: 8.2
---
## Problem
x
EOF
bash "$PREFLIGHT" resolved --repo "$sp" --done "8.3" 2>/dev/null; exit_is "resolved: to a slugged spec resolves" 0 $?

# Regression (pre-existing bug found while refactoring): the DONE-set grep read
# from SPECIFICATIONS.md required a DOTTED id, so ado's flat work-item ids
# (642103) never matched and the deferral DONE-gate was silently inert for them.
mkspec specs/642103-add-user-login.md 642103
cat > "$sp/specs/642103-add-user-login.md" <<'EOF'
---
id: 642103
title: Add user login
deferrals:
  - what: "sso"
    why: "scope"
    to: 9.9
---
## Problem
x
EOF
cat > "$sp/SPECIFICATIONS.md" <<'EOF'
# Proj
## Backlog
- **642103** Add user login — `DONE` — [detail](specs/642103-add-user-login.md)
EOF
bash "$PREFLIGHT" resolved --repo "$sp" 2>/dev/null; exit_is "resolved: flat (ado) id in the DONE set gates" 2 $?

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

# ---- flow-preflight: rubric-basis + rubric-drift (spec 1.16) ----
rb=$(mktemp -d)
mkdir -p "$rb/design" "$rb/.flow/validate"
printf ':root{--c:#111}\n' > "$rb/design/tokens.css"
printf 'module.exports={}\n' > "$rb/tailwind.config.js"

# rubric-basis emits a YAML basis: block with a path + sha per file.
r=$(cd "$rb" && bash "$PREFLIGHT" rubric-basis design/tokens.css tailwind.config.js 2>/dev/null); exit_is "rubric-basis exit 0" 0 $?
out_has "rubric-basis: header" "basis:" "$r"
out_has "rubric-basis: path 1" "path: design/tokens.css" "$r"
out_has "rubric-basis: path 2" "path: tailwind.config.js" "$r"
out_has "rubric-basis: sha key present" "sha:" "$r"
# A missing file is a hard error (can't stamp a basis on a nonexistent file).
bash "$PREFLIGHT" rubric-basis "$rb/nope.css" 2>/dev/null; exit_is "rubric-basis: missing file exit 2" 2 $?

# Stamp a rubric using the emitted basis block, then check drift = in sync.
sha1=$(sha256sum "$rb/design/tokens.css" | cut -c1-12)
sha2=$(sha256sum "$rb/tailwind.config.js" | cut -c1-12)
cat > "$rb/.flow/validate/ui.md" <<EOF
---
generated: 2026-07-18
basis:
  - path: design/tokens.css
    sha: $sha1
  - path: tailwind.config.js
    sha: $sha2
---

## Project UI rubric
- use the token scale
EOF
bash "$PREFLIGHT" rubric-drift "$rb/.flow/validate/ui.md" --repo "$rb" 2>/dev/null; exit_is "rubric-drift: in sync exit 0" 0 $?

# Change a basis file → drift detected (exit 2) and the changed file is named.
printf ':root{--c:#222}\n' > "$rb/design/tokens.css"
bash "$PREFLIGHT" rubric-drift "$rb/.flow/validate/ui.md" --repo "$rb" 2>/dev/null; exit_is "rubric-drift: changed file exit 2" 2 $?
d=$(bash "$PREFLIGHT" rubric-drift "$rb/.flow/validate/ui.md" --repo "$rb" 2>&1)
out_has "rubric-drift: names the changed file" "design/tokens.css" "$d"
out_has "rubric-drift: reports CHANGED" "CHANGED" "$d"

# A recorded basis file that no longer exists → drift (exit 2), reported MISSING.
rm -f "$rb/tailwind.config.js"
bash "$PREFLIGHT" rubric-drift "$rb/.flow/validate/ui.md" --repo "$rb" 2>/dev/null; exit_is "rubric-drift: missing basis file exit 2" 2 $?
m=$(bash "$PREFLIGHT" rubric-drift "$rb/.flow/validate/ui.md" --repo "$rb" 2>&1)
out_has "rubric-drift: reports MISSING" "MISSING" "$m"

# A rubric with no basis: block → clean no-op (exit 0), nothing to check.
cat > "$rb/.flow/validate/ux.md" <<'EOF'
---
generated: 2026-07-18
---

## Project UX rubric
EOF
bash "$PREFLIGHT" rubric-drift "$rb/.flow/validate/ux.md" --repo "$rb" 2>/dev/null; exit_is "rubric-drift: no basis exit 0" 0 $?

# A nonexistent rubric file → clean no-op (exit 0); the gate is opt-in.
bash "$PREFLIGHT" rubric-drift "$rb/.flow/validate/none.md" --repo "$rb" 2>/dev/null; exit_is "rubric-drift: absent rubric exit 0" 0 $?
rm -rf "$rb"

# ---- flow-session-brief: the contextual nudge ladder (1.19) ----
# Exactly one nudge is printed and the highest true tier wins, so each tier
# asserts both its own text AND the absence of the tier below it.
sb="$tmp/sb"; mkdir -p "$sb/specs"
brief_for() { printf '{"cwd":"%s"}' "$1" | bash "$BRIEF"; }

# T4 (fallback) — nothing in flight keeps today's exact line.
cat > "$sb/SPECIFICATIONS.md" <<'EOF'
# Proj — Specifications
## Phase 1
- **1.1** Alpha — `NOT STARTED` — [detail](specs/1.1.md)
EOF
b=$(brief_for "$sb")
out_has "T4 idle keeps the board line" "run /flow:run for the board" "$b"
out_has "T4 still reports state" "no spec IN PROGRESS" "$b"

# T2 — an IN PROGRESS spec names itself and how to resume, and drops T4's line.
cat > "$sb/SPECIFICATIONS.md" <<'EOF'
# Proj — Specifications
## Phase 1
- **1.2** Beta — `IN PROGRESS` — [detail](specs/1.2.md)
- **1.1** Alpha — `NOT STARTED` — [detail](specs/1.1.md)
EOF
b=$(brief_for "$sb")
out_has "T2 names the resume command" "/flow:run 1.2 resumes" "$b"
out_lacks "T2 outranks T4" "for the board" "$b"

# T1 — a DONE spec with an unresolved deferral outranks the IN PROGRESS nudge.
cat > "$sb/SPECIFICATIONS.md" <<'EOF'
# Proj — Specifications
## Phase 1
- **1.2** Beta — `IN PROGRESS` — [detail](specs/1.2.md)
## Archive
- **1.3** Gamma — `DONE` — [detail](specs/1.3.md)
EOF
cat > "$sb/specs/1.3.md" <<'EOF'
---
id: 1.3
title: Gamma
deferrals:
  - what: "file import"
    why: "scope"
    to: 9.9
---
## Problem
x
EOF
b=$(brief_for "$sb")
out_has "T1 names the blocked spec" "1.3" "$b"
out_has "T1 says why it blocks" "open deferral" "$b"
out_lacks "T1 outranks T2" "resumes" "$b"

# T3 — DONE specs tagged since the last tag, clean tree, nothing in progress.
sbg="$tmp/sbgit"; mkdir -p "$sbg/specs"
git init -q "$sbg" 2>/dev/null
git -C "$sbg" config user.email flow@test.local
git -C "$sbg" config user.name "flow test"
git -C "$sbg" config commit.gpgsign false
cat > "$sbg/SPECIFICATIONS.md" <<'EOF'
# Proj — Specifications
## Archive
- **1.1** Alpha — `DONE` — [detail](specs/1.1.md)
EOF
git -C "$sbg" add -A >/dev/null 2>&1
git -C "$sbg" commit -qm "chore: init" >/dev/null 2>&1
git -C "$sbg" tag v0.1.0 >/dev/null 2>&1
echo "x" > "$sbg/specs/1.1.md"
git -C "$sbg" add -A >/dev/null 2>&1
git -C "$sbg" commit -qm "[1.1] feat: alpha" >/dev/null 2>&1
b=$(brief_for "$sbg")
out_has "T3 names the last tag" "since v0.1.0" "$b"
out_has "T3 offers the release" "/flow:ship" "$b"
out_lacks "T3 outranks T4" "for the board" "$b"

# A dirty tree is mid-work, not a release candidate → fall back to T4.
echo "dirty" > "$sbg/scratch.txt"
b=$(brief_for "$sbg")
out_has "T3 defers to T4 on a dirty tree" "for the board" "$b"
rm -f "$sbg/scratch.txt"

# ado — no index at all, but a config: orient instead of staying silent.
sba="$tmp/sbado"; mkdir -p "$sba/.flow"
cat > "$sba/.flow/config.yml" <<'EOF'
flow:
  lifecycle_authority: ado
  ado:
    project: "Contoso"
    area: "Contoso\\Web"
EOF
b=$(brief_for "$sba")
out_has "ado brief names the backend" "ado" "$b"
out_has "ado brief names the project" "Contoso" "$b"

# Fast exit — a project with neither index nor config stays silent.
sbn="$tmp/sbnone"; mkdir -p "$sbn"
b=$(brief_for "$sbn")
out_lacks "non-flow project prints nothing" "flow-toolkit" "$b"
printf '{"cwd":"%s"}' "$sbn" | bash "$BRIEF" >/dev/null 2>&1; exit_is "non-flow project exits 0" 0 $?

# Cost — the brief runs in every project at every session start, so what matters
# is that it does NOT scale with backlog size. Absolute wall clock is dominated
# by process startup (~100ms per subprocess under Git Bash — the pre-1.19 script
# already cost ~400ms/run), so pinning an absolute per-run budget would test the
# platform, not this code. Assert the two things that are actually ours:
#   1. a 100-DONE index costs no more than a 1-DONE index (no O(n) blowup)
#   2. a generous ceiling that still catches a gross regression
# Integer SECONDS keeps this portable across Git Bash / macOS / Linux.
sbp="$tmp/sbperf"; mkdir -p "$sbp/specs"
{
    echo "# Proj — Specifications"
    echo "## Archive"
    i=1
    while [ "$i" -le 100 ]; do
        echo "- **9.$i** Spec $i — \`DONE\` — [detail](specs/9.$i.md)"
        i=$((i + 1))
    done
} > "$sbp/SPECIFICATIONS.md"
sbs="$tmp/sbsmall"; mkdir -p "$sbs/specs"
printf '# Proj — Specifications\n## Archive\n- **9.1** Spec 1 — `DONE` — [detail](specs/9.1.md)\n' > "$sbs/SPECIFICATIONS.md"

time_10() { # dir -> seconds for 10 runs
    _s=$SECONDS; _i=0
    while [ "$_i" -lt 10 ]; do brief_for "$1" >/dev/null 2>&1; _i=$((_i + 1)); done
    echo $((SECONDS - _s))
}
big=$(time_10 "$sbp")
small=$(time_10 "$sbs")
if [ $((big - small)) -le 1 ]; then
    pass=$((pass+1))
else
    fail=$((fail+1)); echo "FAIL: brief scales with backlog size — 100 specs ${big}s vs 1 spec ${small}s over 10 runs"
fi
if [ "$big" -le 8 ]; then
    pass=$((pass+1))
else
    fail=$((fail+1)); echo "FAIL: brief exceeded the gross-regression ceiling — 10 runs took ${big}s (ceiling 8s)"
fi

# T1 narrowing — when ONE spec in a 100-DONE backlog carries a `deferrals:`
# key, the helper must be handed that one id, not all 100. Measured against the
# same backlog with no deferrals at all: the delta is the narrowed helper call,
# and it must not grow with the backlog. (Unnarrowed this took 3s per run on an
# 18-spec repo and scaled from there.)
sbd="$tmp/sbdefer"; mkdir -p "$sbd/specs"
cp "$sbp/SPECIFICATIONS.md" "$sbd/SPECIFICATIONS.md"
cat > "$sbd/specs/9.1.md" <<'EOF'
---
id: 9.1
title: Spec 1
deferrals:
  - what: "a cut"
    why: "scope"
    to: built
---
## Problem
x
EOF
# Compare like with like: ONE deferral-carrying spec in each, 100 DONE vs 1
# DONE. Both hand the helper exactly one id, so the delta isolates backlog
# scaling from the fixed cost of spawning the helper at all.
sbd1="$tmp/sbdefer1"; mkdir -p "$sbd1/specs"
printf '# Proj — Specifications\n## Archive\n- **9.1** Spec 1 — `DONE` — [detail](specs/9.1.md)\n' > "$sbd1/SPECIFICATIONS.md"
cp "$sbd/specs/9.1.md" "$sbd1/specs/9.1.md"
deferred=$(time_10 "$sbd")
deferred1=$(time_10 "$sbd1")
if [ $((deferred - deferred1)) -le 1 ]; then
    pass=$((pass+1))
else
    fail=$((fail+1)); echo "FAIL: T1 not narrowed — 1-of-100 backlog ${deferred}s vs 1-of-1 ${deferred1}s over 10 runs"
fi
b=$(brief_for "$sbd")
out_lacks "a resolved deferral (to: built) raises no warning" "open deferral" "$b"

# The cheap prefilter is what keeps T1 off the hot path: with no `deferrals:`
# anywhere in the spec tree, the helper must never be invoked at all.
sbf="$tmp/sbfilter"; mkdir -p "$sbf/specs"
printf '# Proj — Specifications\n## Archive\n- **1.1** A — `DONE` — [detail](specs/1.1.md)\n' > "$sbf/SPECIFICATIONS.md"
printf -- '---\nid: 1.1\ntitle: A\n---\n## Problem\nx\n' > "$sbf/specs/1.1.md"
b=$(brief_for "$sbf")
out_lacks "no deferrals anywhere → T1 never fires" "open deferral" "$b"

echo "hooks.test.sh: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

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

echo "hooks.test.sh: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

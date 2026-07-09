#!/usr/bin/env bash
# hooks.test.sh — unit tests for the format-parsing hooks (flow-spec-guard.sh,
# flow-session-brief.sh) against the index + detail-file spec model.
# Run directly:  bash hooks/hooks.test.sh
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
GUARD="$HERE/flow-spec-guard.sh"
BRIEF="$HERE/flow-session-brief.sh"

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

echo "hooks.test.sh: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

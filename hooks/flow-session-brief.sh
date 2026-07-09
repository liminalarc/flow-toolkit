#!/usr/bin/env bash
# flow-session-brief.sh — Claude Code SessionStart hook.
#
# If the project has a SPECIFICATIONS.md index, prints a one-line backlog
# orientation to stdout, which Claude Code injects into the session context.
# ~30 tokens of pure signal: what's in flight, what's queued.
#
# Reads the index model first ("- **<id>** Title — `STATUS` — [detail](...)").
# Falls back to the legacy inline format (### Spec + **Status:**) so a
# pre-migration repo still gets a brief. ADO-backed projects (no local
# SPECIFICATIONS.md) produce no output. Always exits 0.

set -u

INPUT=$(cat 2>/dev/null || true)

CWD_RAW=$(printf '%s' "$INPUT" | grep -oE '"cwd"[[:space:]]*:[[:space:]]*"(\\.|[^"\\])*"' | head -n 1)
[ -z "$CWD_RAW" ] && exit 0
CWD=$(printf '%s' "$CWD_RAW" | sed -E 's/^"cwd"[[:space:]]*:[[:space:]]*"//; s/"$//')
CWD=$(printf '%s' "$CWD" | sed -e 's/\\"/"/g' -e 's/\\\//\//g' -e 's/\\\\/\\/g' | tr '\\' '/')

SPEC="$CWD/SPECIFICATIONS.md"
[ -f "$SPEC" ] || exit 0

awk '
# New index format: "- **<id>** <Title> — `STATUS` — [detail](...)"
match($0, /^- \*\*[A-Za-z0-9][A-Za-z0-9]*[.][A-Za-z0-9-]+\*\* .+ — `(NOT STARTED|IN PROGRESS|PARTIAL|DONE|SUPERSEDED)` —/) {
    entries++
    # title = between "** " and " — `"
    t = $0
    sub(/^- \*\*[A-Za-z0-9][A-Za-z0-9]*[.][A-Za-z0-9-]+\*\* /, "", t)
    sub(/ — `.*/, "", t)
    # status = inside the first backtick pair
    s = $0
    sub(/^.*— `/, "", s)
    sub(/`.*/, "", s)
    count[s]++
    if (s == "IN PROGRESS") inprog = (inprog == "" ? t : inprog ", " t)
    next
}
# Legacy fallback: ### Spec heading + **Status:** line
/^### Spec / { legacy_head = $0; sub(/^### /, "", legacy_head); next }
/^\*\*Status:\*\*/ {
    v = $0; sub(/^\*\*Status:\*\*[[:space:]]*/, "", v); sub(/[[:space:]]+$/, "", v)
    legacy_count[v]++
    if (v == "IN PROGRESS" && legacy_head != "") legacy_inprog = (legacy_inprog == "" ? legacy_head : legacy_inprog ", " legacy_head)
    legacy_head = ""
    next
}
END {
    if (entries == 0) { inprog = legacy_inprog; for (k in legacy_count) count[k] = legacy_count[k] }
    line = "flow-toolkit: "
    line = line (inprog != "" ? inprog " is IN PROGRESS" : "no spec IN PROGRESS")
    if (count["NOT STARTED"] > 0) line = line " · " count["NOT STARTED"] " NOT STARTED"
    if (count["PARTIAL"] > 0)     line = line " · " count["PARTIAL"] " PARTIAL"
    if (count["DONE"] > 0)        line = line " · " count["DONE"] " DONE"
    line = line " — run /flow for the board"
    print line
}
' "$SPEC"

exit 0

#!/usr/bin/env bash
# flow-session-brief.sh — Claude Code SessionStart hook.
#
# If the project has a SPECIFICATIONS.md, prints a one-line backlog
# orientation to stdout, which Claude Code injects into the session context.
# ~30 tokens of pure signal: what's in flight, what's queued.
#
# Projects without a spec file produce no output. Always exits 0.

set -u

INPUT=$(cat 2>/dev/null || true)

CWD_RAW=$(printf '%s' "$INPUT" | grep -oE '"cwd"[[:space:]]*:[[:space:]]*"(\\.|[^"\\])*"' | head -n 1)
[ -z "$CWD_RAW" ] && exit 0
CWD=$(printf '%s' "$CWD_RAW" | sed -E 's/^"cwd"[[:space:]]*:[[:space:]]*"//; s/"$//')
CWD=$(printf '%s' "$CWD" | sed -e 's/\\"/"/g' -e 's/\\\//\//g' -e 's/\\\\/\\/g' | tr '\\' '/')

SPEC="$CWD/SPECIFICATIONS.md"
[ -f "$SPEC" ] || exit 0

awk '
/^### Spec / {
    heading = $0
    sub(/^### /, "", heading)
    next
}
/^\*\*Status:\*\*/ {
    val = $0
    sub(/^\*\*Status:\*\*[[:space:]]*/, "", val)
    sub(/[[:space:]]+$/, "", val)
    count[val]++
    if (val == "IN PROGRESS" && heading != "") {
        inprog = (inprog == "" ? heading : inprog ", " heading)
    }
    heading = ""
}
END {
    line = "flow-toolkit: "
    if (inprog != "")
        line = line inprog " is IN PROGRESS"
    else
        line = line "no spec IN PROGRESS"
    if (count["NOT STARTED"] > 0) line = line " · " count["NOT STARTED"] " NOT STARTED"
    if (count["PARTIAL"] > 0)     line = line " · " count["PARTIAL"] " PARTIAL"
    if (count["DONE"] > 0)        line = line " · " count["DONE"] " DONE"
    line = line " — run /flow for the board"
    print line
}
' "$SPEC"

exit 0

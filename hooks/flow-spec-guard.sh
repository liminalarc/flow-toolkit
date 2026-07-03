#!/usr/bin/env bash
# flow-spec-guard.sh — Claude Code PostToolUse hook (matcher: Edit|Write).
#
# Fires after every file edit. If the edited file is SPECIFICATIONS.md or
# SPECIFICATIONS-ARCHIVE.md, validates the flow-toolkit spec format:
#   - headings match "### Spec X.Y — Title" (em dash, title required)
#   - every spec has exactly one **Status:** line
#   - status is one of: DONE, IN PROGRESS, PARTIAL, NOT STARTED, SUPERSEDED
#   - no duplicate spec numbers (within the file and across the archive sidecar)
#   - DONE specs have no unchecked "- [ ]" acceptance criteria
#
# Exit 0 = file is fine (or not a spec file — the common case, costs nothing).
# Exit 2 = validation failed; errors on stderr are fed back to Claude so it
#          fixes the file in the same turn.
#
# Can also be invoked directly with a file argument (used by flow-commit-guard.sh):
#   flow-spec-guard.sh path/to/SPECIFICATIONS.md

set -u

if [ $# -ge 1 ]; then
    FILE="$1"
else
    INPUT=$(cat 2>/dev/null || true)

    # Extract tool_input.file_path from the hook JSON (first occurrence).
    RAW=$(printf '%s' "$INPUT" | grep -oE '"file_path"[[:space:]]*:[[:space:]]*"(\\.|[^"\\])*"' | head -n 1)
    [ -z "$RAW" ] && exit 0

    FILE=$(printf '%s' "$RAW" | sed -E 's/^"file_path"[[:space:]]*:[[:space:]]*"//; s/"$//')
    # Unescape JSON string: \" -> ", \/ -> /, \\ -> \  (order matters: \\ last)
    FILE=$(printf '%s' "$FILE" | sed -e 's/\\"/"/g' -e 's/\\\//\//g' -e 's/\\\\/\\/g')
fi
# Normalize Windows backslashes so basename/dirname and -f work under Git Bash.
FILE=$(printf '%s' "$FILE" | tr '\\' '/')

base=$(basename "$FILE")
case "$base" in
    SPECIFICATIONS.md|SPECIFICATIONS-ARCHIVE.md) ;;
    *) exit 0 ;;
esac

[ -f "$FILE" ] || exit 0

# Spec numbers in the sibling file (active <-> archive), for cross-file duplicates.
dir=$(dirname "$FILE")
if [ "$base" = "SPECIFICATIONS.md" ]; then
    other="$dir/SPECIFICATIONS-ARCHIVE.md"
else
    other="$dir/SPECIFICATIONS.md"
fi
othernums=""
if [ -f "$other" ]; then
    othernums=$(sed -nE 's/^### Spec ([0-9]+\.[0-9]+).*/\1/p' "$other" | tr '\n' ' ')
fi

errors=$(awk -v othernums="$othernums" '
function flush_spec() {
    if (!in_spec) return
    if (status_count == 0)
        errs = errs sprintf("  line %d: Spec %s has no **Status:** line\n", spec_line, spec_id)
    else if (status_count > 1)
        errs = errs sprintf("  line %d: Spec %s has %d **Status:** lines — must have exactly one\n", spec_line, spec_id, status_count)
    if (status_count >= 1 && !(status_val in VALID))
        errs = errs sprintf("  line %d: invalid status \"%s\" — must be exactly one of: DONE, IN PROGRESS, PARTIAL, NOT STARTED, SUPERSEDED\n", status_line, status_val)
    if (status_count >= 1 && status_val == "DONE" && unchecked > 0)
        errs = errs sprintf("  line %d: Spec %s is DONE but still has %d unchecked \"- [ ]\" acceptance criteria\n", spec_line, spec_id, unchecked)
}
BEGIN {
    VALID["DONE"]; VALID["IN PROGRESS"]; VALID["PARTIAL"]; VALID["NOT STARTED"]; VALID["SUPERSEDED"]
    n = split(othernums, arr, " ")
    for (i = 1; i <= n; i++) if (arr[i] != "") OTHER[arr[i]]
    in_spec = 0; errs = ""
}
/^### Spec/ {
    flush_spec()
    in_spec = 1; spec_line = NR; status_count = 0; status_val = ""; status_line = 0; unchecked = 0
    if ($0 ~ /^### Spec [0-9]+\.[0-9]+ — .+/) {
        match($0, /[0-9]+\.[0-9]+/)
        spec_id = substr($0, RSTART, RLENGTH)
        if (spec_id in SEEN)
            errs = errs sprintf("  line %d: duplicate spec number %s (first used at line %d)\n", NR, spec_id, SEEN[spec_id])
        else
            SEEN[spec_id] = NR
        if (spec_id in OTHER)
            errs = errs sprintf("  line %d: spec number %s already exists in the sibling specifications file — spec numbers are never reused\n", NR, spec_id)
    } else {
        spec_id = sprintf("(line %d)", NR)
        errs = errs sprintf("  line %d: malformed spec heading — expected \"### Spec X.Y — Title\" (em dash, title required): %s\n", NR, $0)
    }
    next
}
/^\*\*Status:\*\*/ {
    if (in_spec) {
        status_count++
        if (status_count == 1) {
            status_line = NR
            val = $0
            sub(/^\*\*Status:\*\*[[:space:]]*/, "", val)
            sub(/[[:space:]]+$/, "", val)
            status_val = val
        }
    }
    next
}
/^[[:space:]]*- \[ \]/ { if (in_spec) unchecked++ }
END {
    flush_spec()
    printf "%s", errs
}
' "$FILE")

if [ -n "$errors" ]; then
    {
        echo "flow-toolkit spec guard: $base failed validation:"
        printf '%s\n' "$errors"
        echo "Fix these issues in $FILE now. Reference format: heading \"### Spec X.Y — Title\", one \"**Status:**\" line per spec with exactly one of DONE, IN PROGRESS, PARTIAL, NOT STARTED, SUPERSEDED."
    } >&2
    exit 2
fi

exit 0

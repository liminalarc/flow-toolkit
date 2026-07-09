#!/usr/bin/env bash
# flow-spec-guard.sh — Claude Code PostToolUse hook (matcher: Edit|Write).
#
# Fires after every file edit. Validates the flow-toolkit spec model:
#
#   * SPECIFICATIONS.md / SPECIFICATIONS-ARCHIVE.md (the INDEX): every backlog
#     entry line matches
#         - **<id>** <Title> — `STATUS` — [detail](<path>)
#     where <id> is alphanumeric (e.g. "1.2", "0.1", "2.37a", "P.10", "BL-12"),
#     STATUS is one of NOT STARTED / IN PROGRESS / PARTIAL / DONE / SUPERSEDED,
#     and no id is duplicated within the file.
#
#   * <spec_dir>/<id>.md (a DETAIL file, default dir "specs"): carries NO status
#     field (status is single-source in the index — a status here would drift),
#     and its front-matter `id:` matches the filename stem.
#
# A legacy inline SPECIFICATIONS.md (### Spec blocks, **Status:** lines) is
# detected and PASSED with a one-line advisory to run `/flow-lint --migrate` —
# it is never blocked, so a pre-migration repo stays editable.
#
# Exit 0 = fine / not a spec file / legacy (advisory on stderr).
# Exit 2 = validation failed; errors on stderr are fed back to Claude so it
#          fixes the file in the same turn.
#
# Direct-invocation form (used by flow-commit-guard.sh): flow-spec-guard.sh <file>

set -u

if [ $# -ge 1 ]; then
    FILE="$1"
else
    INPUT=$(cat 2>/dev/null || true)
    RAW=$(printf '%s' "$INPUT" | grep -oE '"file_path"[[:space:]]*:[[:space:]]*"(\\.|[^"\\])*"' | head -n 1)
    [ -z "$RAW" ] && exit 0
    FILE=$(printf '%s' "$RAW" | sed -E 's/^"file_path"[[:space:]]*:[[:space:]]*"//; s/"$//')
    FILE=$(printf '%s' "$FILE" | sed -e 's/\\"/"/g' -e 's/\\\//\//g' -e 's/\\\\/\\/g')
fi
# Normalize Windows backslashes so basename/dirname and -f work under Git Bash.
FILE=$(printf '%s' "$FILE" | tr '\\' '/')

base=$(basename "$FILE")

# Classify the file: index, detail, or neither.
kind=""
case "$base" in
    SPECIFICATIONS.md|SPECIFICATIONS-ARCHIVE.md) kind="index" ;;
    *.md)
        # A detail file lives under a "specs/" path segment (the default spec_dir).
        case "/$FILE" in
            */specs/*) kind="detail" ;;
        esac
        ;;
esac
[ -z "$kind" ] && exit 0
[ -f "$FILE" ] || exit 0

# --- Detail file: no status field, id matches filename ------------------------
if [ "$kind" = "detail" ]; then
    derr=""
    if grep -qE '^\*\*Status:\*\*|^[[:space:]]*status:[[:space:]]*[^[:space:]]' "$FILE"; then
        derr="${derr}  a detail file must not carry a status field — status is single-source in the index (remove the \`status:\`/\`**Status:**\` line)\n"
    fi
    stem=${base%.md}
    idval=$(sed -nE 's/^id:[[:space:]]*"?([^"[:space:]]+)"?[[:space:]]*$/\1/p' "$FILE" | head -n 1)
    if [ -n "$idval" ] && [ "$idval" != "$stem" ]; then
        derr="${derr}  front-matter id \"$idval\" does not match filename \"$stem\" (specs/<id>.md)\n"
    fi
    if [ -n "$derr" ]; then
        {
            echo "flow-toolkit spec guard: $base failed detail-file validation:"
            printf '%b' "$derr"
            echo "Reference: specs/<id>.md carries id/title front-matter and the sections Problem/Value/Scope/Acceptance criteria/Plan/Decisions/Verification/Progress log — but NEVER a status (that lives only in the index)."
        } >&2
        exit 2
    fi
    exit 0
fi

# --- Index file ---------------------------------------------------------------

# Legacy inline format: ### Spec blocks and no new-style "- **<id>**" entries.
# Advise migration; do not block (migration is a deliberate action).
if grep -q '^### Spec ' "$FILE" && ! grep -qE '^- \*\*[A-Za-z0-9]' "$FILE"; then
    echo "flow-toolkit spec guard: $base looks like a legacy inline spec file (### Spec blocks). Run \`/flow-lint --migrate\` to convert it to the index + specs/<id>.md model. (Not blocking.)" >&2
    exit 0
fi

errors=$(awk '
BEGIN {
    VALID["NOT STARTED"]; VALID["IN PROGRESS"]; VALID["PARTIAL"]; VALID["DONE"]; VALID["SUPERSEDED"]
    errs = ""
}
/^- \*\*/ {
    line = $0
    if (line ~ /^- \*\*[A-Za-z0-9][A-Za-z0-9]*[.][A-Za-z0-9-]+\*\* .+ — `(NOT STARTED|IN PROGRESS|PARTIAL|DONE|SUPERSEDED)` — \[[^]]+\]\(.+\)$/) {
        s = line; sub(/^- \*\*/, "", s)
        match(s, /^[A-Za-z0-9][A-Za-z0-9]*[.][A-Za-z0-9-]+/)
        id = substr(s, RSTART, RLENGTH)
        if (id in SEEN)
            errs = errs sprintf("  line %d: duplicate id %s (first used at line %d)\n", NR, id, SEEN[id])
        else
            SEEN[id] = NR
    } else {
        errs = errs sprintf("  line %d: malformed index entry — expected \"- **<id>** <Title> — `STATUS` — [detail](specs/<id>.md)\" with STATUS one of NOT STARTED, IN PROGRESS, PARTIAL, DONE, SUPERSEDED: %s\n", NR, line)
    }
    next
}
END { printf "%s", errs }
' "$FILE")

if [ -n "$errors" ]; then
    {
        echo "flow-toolkit spec guard: $base failed index validation:"
        printf '%s\n' "$errors"
        echo "Reference entry: \"- **<id>** <Title> — \`STATUS\` — [detail](specs/<id>.md)\" (alphanumeric id, em dash separators, valid STATUS, unique ids)."
    } >&2
    exit 2
fi

exit 0

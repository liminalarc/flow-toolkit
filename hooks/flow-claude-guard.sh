#!/usr/bin/env bash
# flow-claude-guard.sh — Claude Code PostToolUse hook (matcher: Edit|Write).
#
# Fires after every file edit. If the edited file is a project CLAUDE.md,
# enforces the flow-toolkit line caps: 300 lines for the root file, 200 for
# subdirectory files. A bloated guardrail file is wasted context on every
# session, forever — this catches it at the moment of creation.
#
# Caps are configurable per project via a `.flow-toolkit.json` at the repo
# root (next to `.git`):
#
#     { "claudeMd": { "rootMax": 400, "subdirMax": 250 } }
#
# Either key may be omitted to keep its default. Non-numeric or missing values
# fall back to the built-in defaults below.
#
# Exit 0 = within limits (or not a CLAUDE.md — the common case, costs nothing).
# Exit 2 = over the cap; message on stderr tells Claude to trim it now.

set -u

ROOT_DEFAULT=300
SUBDIR_DEFAULT=200

INPUT=$(cat 2>/dev/null || true)

RAW=$(printf '%s' "$INPUT" | grep -oE '"file_path"[[:space:]]*:[[:space:]]*"(\\.|[^"\\])*"' | head -n 1)
[ -z "$RAW" ] && exit 0

FILE=$(printf '%s' "$RAW" | sed -E 's/^"file_path"[[:space:]]*:[[:space:]]*"//; s/"$//')
FILE=$(printf '%s' "$FILE" | sed -e 's/\\"/"/g' -e 's/\\\//\//g' -e 's/\\\\/\\/g')
FILE=$(printf '%s' "$FILE" | tr '\\' '/')

[ "$(basename "$FILE")" = "CLAUDE.md" ] || exit 0
[ -f "$FILE" ] || exit 0

# Global memory files (~/.claude/CLAUDE.md etc.) are not project guardrails.
case "$FILE" in
    */.claude/*|*/.claude-company/*) exit 0 ;;
esac

lines=$(wc -l < "$FILE" | tr -d '[:space:]')

dir=$(dirname "$FILE")

# Walk up from the file's directory to find the repo root (the dir holding
# `.git`). Stops when dirname stops changing, so it terminates at / or a
# drive root on Windows even if no .git is ever found.
find_repo_root() {
    d=$1; prev=""
    while [ -n "$d" ] && [ "$d" != "$prev" ]; do
        [ -e "$d/.git" ] && { printf '%s' "$d"; return 0; }
        prev=$d
        d=$(dirname "$d")
    done
    return 1
}

# Extract an integer value for a top-level-ish JSON key. Keys (rootMax,
# subdirMax) are unique in our schema, so a flat grep is robust regardless of
# nesting and avoids a jq dependency.
read_cap() {
    grep -oE "\"$2\"[[:space:]]*:[[:space:]]*[0-9]+" "$1" 2>/dev/null | head -n 1 | grep -oE '[0-9]+'
}

repo_root=$(find_repo_root "$dir" || true)
config=""
[ -n "$repo_root" ] && [ -f "$repo_root/.flow-toolkit.json" ] && config="$repo_root/.flow-toolkit.json"

# Root CLAUDE.md lives next to .git; anything else is a subdirectory file.
if [ -e "$dir/.git" ]; then
    limit=$ROOT_DEFAULT; kind="root"; key="rootMax"
else
    limit=$SUBDIR_DEFAULT; kind="subdirectory"; key="subdirMax"
fi

source_note=""
if [ -n "$config" ]; then
    cv=$(read_cap "$config" "$key")
    if [ -n "$cv" ]; then
        limit=$cv
        source_note=" (configured in $config)"
    fi
fi

if [ "$lines" -gt "$limit" ]; then
    {
        echo "flow-toolkit CLAUDE.md guard: $FILE is $lines lines — the cap for a $kind CLAUDE.md is $limit$source_note."
        echo "Trim it now: move layer-specific detail to a subdirectory CLAUDE.md, delete content derivable from the code, and remove anything duplicated from the root file. Every line here is loaded into context in every session."
        [ -z "$source_note" ] && echo "If this project genuinely needs more room, set { \"claudeMd\": { \"$key\": <n> } } in .flow-toolkit.json at the repo root."
    } >&2
    exit 2
fi

exit 0

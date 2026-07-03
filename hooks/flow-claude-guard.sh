#!/usr/bin/env bash
# flow-claude-guard.sh — Claude Code PostToolUse hook (matcher: Edit|Write).
#
# Fires after every file edit. If the edited file is a project CLAUDE.md,
# enforces the flow-toolkit line caps: 200 lines for the root file, 150 for
# subdirectory files. A bloated guardrail file is wasted context on every
# session, forever — this catches it at the moment of creation.
#
# Exit 0 = within limits (or not a CLAUDE.md — the common case, costs nothing).
# Exit 2 = over the cap; message on stderr tells Claude to trim it now.

set -u

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

# Root CLAUDE.md lives next to .git; anything else is a subdirectory file.
dir=$(dirname "$FILE")
if [ -e "$dir/.git" ]; then
    limit=200; kind="root"
else
    limit=150; kind="subdirectory"
fi

if [ "$lines" -gt "$limit" ]; then
    {
        echo "flow-toolkit CLAUDE.md guard: $FILE is $lines lines — the cap for a $kind CLAUDE.md is $limit."
        echo "Trim it now: move layer-specific detail to a subdirectory CLAUDE.md, delete content derivable from the code, and remove anything duplicated from the root file. Every line here is loaded into context in every session."
    } >&2
    exit 2
fi

exit 0

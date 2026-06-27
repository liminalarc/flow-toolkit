#!/usr/bin/env bash
# install.sh — Install flow-toolkit commands into Claude Code's global commands directory
# Run from the repo root: ./install.sh

set -e

TARGET="$HOME/.claude/commands"

mkdir -p "$TARGET"

count=0
for file in commands/*.md; do
    cp "$file" "$TARGET/"
    echo "Installed $(basename "$file")"
    count=$((count + 1))
done

echo ""
echo "Done. $count commands installed to $TARGET"
echo "Restart Claude Code (or start a new session) for changes to take effect."

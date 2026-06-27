#!/usr/bin/env bash
# install.sh — Install flow-toolkit commands into Claude Code's global commands directory
# Run from the repo root: ./install.sh

set -e

TARGETS=(
    "$HOME/.claude/commands"
    "$HOME/.claude-company/commands"
)

count=$(ls commands/*.md 2>/dev/null | wc -l)

for target in "${TARGETS[@]}"; do
    profile=$(basename "$(dirname "$target")")
    parent=$(dirname "$target")
    if [ ! -d "$parent" ]; then
        echo "Skipping $profile (profile directory does not exist)"
        continue
    fi
    mkdir -p "$target"
    for file in commands/*.md; do
        cp "$file" "$target/"
    done
    echo "Installed $count commands to $target"
done

echo ""
echo "Done. Restart Claude Code (or start a new session) for changes to take effect."

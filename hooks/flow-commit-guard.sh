#!/usr/bin/env bash
# flow-commit-guard.sh — Claude Code PreToolUse hook (matcher: Bash).
#
# Fires before every Bash command; acts only on `git commit`. Three checks:
#   1. Commit message follows Conventional Commits — /flow-ship derives
#      version bumps from commit types, so a malformed message silently
#      breaks release versioning.
#   2. SPECIFICATIONS.md (if present) passes format validation, so a broken
#      spec file can't be committed — catches hand edits that bypassed the
#      PostToolUse guard.
#   3. Soft nudge (never blocks): committing source changes while no spec is
#      IN PROGRESS suggests untracked work.
#
# Exit 0 = allow (non-commit commands, or all checks pass).
# Exit 2 = block the commit; reason on stderr is fed back to Claude.

set -u

INPUT=$(cat 2>/dev/null || true)

# Extract tool_input.command from the hook JSON and unescape it.
RAW=$(printf '%s' "$INPUT" | grep -oE '"command"[[:space:]]*:[[:space:]]*"(\\.|[^"\\])*"' | head -n 1)
[ -z "$RAW" ] && exit 0
CMD=$(printf '%s' "$RAW" | sed -E 's/^"command"[[:space:]]*:[[:space:]]*"//; s/"$//')
CMD=$(printf '%s' "$CMD" | awk '{ gsub(/\\"/, "\""); gsub(/\\n/, "\n"); gsub(/\\t/, "\t"); gsub(/\\\\/, "\\"); print }')

# Only act on git commit.
printf '%s' "$CMD" | grep -qE 'git[[:space:]]+commit' || exit 0

# --- Check 1: Conventional Commit message format -----------------------------

# Extract the subject line from the first -m. Handles both inline
# (-m "feat: thing") and heredoc (-m "$(cat <<'EOF' ... )") styles.
# If no message can be found (e.g. --amend without -m), skip this check.
subject=""
mline=$(printf '%s\n' "$CMD" | grep -m1 -E -- '-m[[:space:]]' || true)
if [ -n "$mline" ]; then
    if printf '%s' "$mline" | grep -q '<<'; then
        # Heredoc: subject is the first line after the heredoc opener.
        subject=$(printf '%s\n' "$CMD" | awk '/<<-?['"'"'"]?[A-Za-z_]+/ { getline; print; exit }')
    else
        subject=$(printf '%s' "$mline" | sed -E "s/.*-m[[:space:]]+//; s/^[\"']//; s/[\"']?[[:space:]]*$//")
    fi
fi

if [ -n "$subject" ]; then
    case "$subject" in
        Merge\ *|Revert\ *|fixup!*|squash!*) : ;;  # git-generated prefixes pass
        *)
            if ! printf '%s' "$subject" | grep -qE '^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([^)]+\))?!?: .+'; then
                {
                    echo "flow-toolkit commit guard: commit message does not follow Conventional Commits:"
                    echo "  \"$subject\""
                    echo "Use: <type>(<optional scope>): <subject> — where type is one of feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert."
                    echo "This matters: /flow-ship derives the version bump (major/minor/patch) from commit types."
                } >&2
                exit 2
            fi
            ;;
    esac
fi

# --- Check 2: SPECIFICATIONS.md must be valid at commit time ------------------

CWD_RAW=$(printf '%s' "$INPUT" | grep -oE '"cwd"[[:space:]]*:[[:space:]]*"(\\.|[^"\\])*"' | head -n 1)
CWD=$(printf '%s' "$CWD_RAW" | sed -E 's/^"cwd"[[:space:]]*:[[:space:]]*"//; s/"$//')
CWD=$(printf '%s' "$CWD" | sed -e 's/\\"/"/g' -e 's/\\\//\//g' -e 's/\\\\/\\/g' | tr '\\' '/')

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
if [ -n "$CWD" ] && [ -f "$CWD/SPECIFICATIONS.md" ]; then
    if ! bash "$SCRIPT_DIR/flow-spec-guard.sh" "$CWD/SPECIFICATIONS.md"; then
        echo "flow-toolkit commit guard: fix SPECIFICATIONS.md (errors above) before committing." >&2
        exit 2
    fi

    # --- Check 3 (soft, never blocks): source work with no spec IN PROGRESS ---
    if ! grep -q '^\*\*Status:\*\* IN PROGRESS' "$CWD/SPECIFICATIONS.md"; then
        staged_src=$(cd "$CWD" && git diff --cached --name-only 2>/dev/null | grep -vE '\.md$' | head -n 1 || true)
        if [ -n "$staged_src" ]; then
            printf '%s' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"flow-toolkit: this commit stages source changes but no spec in SPECIFICATIONS.md is IN PROGRESS. If this implements a spec, set its status; if it is unplanned work, consider capturing it with /flow --add. Proceeding with the commit."}}'
        fi
    fi
fi

exit 0

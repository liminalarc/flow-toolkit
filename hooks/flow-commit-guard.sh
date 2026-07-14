#!/usr/bin/env bash
# flow-commit-guard.sh — Claude Code PreToolUse hook (matcher: Bash).
#
# Fires before every Bash command; acts only on `git commit`. Three checks:
#   1. Commit message follows Conventional Commits — /flow-ship derives
#      version bumps from commit types, so a malformed message silently
#      breaks release versioning.
#   2. SPECIFICATIONS.md (if present) passes index validation, so a broken
#      spec file can't be committed — catches hand edits that bypassed the
#      PostToolUse guard.
#   3. Soft nudge (never blocks): committing source changes while no spec is
#      IN PROGRESS in the index suggests untracked work.
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

# Only act on an actual `git commit` invocation — not any command that merely
# contains the text "git commit" (a PR body, an echo, a grep pattern). Require
# `git` at a command boundary (start of line, or after ; & |), allow git's
# global options (-C <path>, -c <kv>, --opt[=val]) before the subcommand, and
# require `commit` as a whole word. grep is line-oriented, so `^` also covers a
# git-commit on its own line. This additionally catches `git -C <path> commit`,
# which the old bare-substring match missed.
# Residual (documented, not worth chasing): a heredoc/quoted line that itself
# starts with `git commit`, and `git -c key="a b" commit` (a quoted space in an
# option value), are edge cases this heuristic does not perfectly classify.
git_commit_re='(^|[;&|])[[:space:]]*git([[:space:]]+-[^[:space:]]+([[:space:]]+[^-[:space:]][^[:space:]]*)?)*[[:space:]]+commit([[:space:]]|$)'
printf '%s' "$CMD" | grep -qE "$git_commit_re" || exit 0

# --- Check 1: Conventional Commit message format -----------------------------

# Extract the subject line from the FIRST -m. Handles both inline
# (-m "feat: thing") and heredoc (-m "$(cat <<'EOF' ... )") styles.
# The prefix strip below is written to stop at the first -m (not a greedy
# .* that runs to the last one), so a multi-paragraph commit
# (-m subject -m body -m trailer) validates the subject, not the trailer.
# If no message can be found (e.g. --amend without -m), skip this check.
subject=""
mline=$(printf '%s\n' "$CMD" | grep -m1 -E -- '-m[[:space:]]' || true)
if [ -n "$mline" ]; then
    if printf '%s' "$mline" | grep -q '<<'; then
        # Heredoc: subject is the first line after the heredoc opener.
        subject=$(printf '%s\n' "$CMD" | awk '/<<-?['"'"'"]?[A-Za-z_]+/ { getline; print; exit }')
    else
        subject=$(printf '%s' "$mline" | sed -E "s/^([^-]|-[^m])*-m[[:space:]]+//; s/^[\"']//; s/[\"']?[[:space:]]*$//")
    fi
fi

if [ -n "$subject" ]; then
    case "$subject" in
        Merge\ *|Revert\ *|fixup!*|squash!*) : ;;  # git-generated prefixes pass
        *)
            if ! printf '%s' "$subject" | grep -qE '^(\[[^]]+\] )?(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([^)]+\))?!?: .+'; then
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

    # --- Check 2b: no DONE spec may carry an unreconciled deferral ------------
    # The deferral DONE-gating rule, enforced at commit time in local mode (the
    # index tells us which specs are DONE). Same helper /flow-lint and /flow-ship
    # use, so the rule is defined once. (ado mode has no SPECIFICATIONS.md here,
    # so status lives on the board — gating falls to /flow-lint and /flow-ship.)
    if [ -f "$SCRIPT_DIR/flow-preflight.sh" ]; then
        if ! bash "$SCRIPT_DIR/flow-preflight.sh" resolved --repo "$CWD"; then
            echo "flow-toolkit commit guard: reconcile the deferral(s) above (or change the spec's status) before committing." >&2
            exit 2
        fi
    fi

    # --- Check 3 (soft, never blocks): source work with no spec IN PROGRESS ---
    # Match the index entry form ("- **id** Title — `IN PROGRESS` — ...") and the
    # legacy inline form ("**Status:** IN PROGRESS") so the nudge works pre/post migration.
    if ! grep -qE '(`IN PROGRESS`|^\*\*Status:\*\* IN PROGRESS)' "$CWD/SPECIFICATIONS.md"; then
        staged_src=$(cd "$CWD" && git diff --cached --name-only 2>/dev/null | grep -vE '\.md$' | head -n 1 || true)
        if [ -n "$staged_src" ]; then
            printf '%s' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"flow-toolkit: this commit stages source changes but no spec in SPECIFICATIONS.md is IN PROGRESS. If this implements a spec, set its status; if it is unplanned work, consider capturing it with /flow --add. Proceeding with the commit."}}'
        fi
    else
        # --- Check 3b (soft, never blocks): tag the subject with [#id] --------
        # When exactly ONE spec is IN PROGRESS (local) and the subject carries no
        # bracket tag, nudge with the exact [#<id>] so /flow-ship derives the
        # release set from `git log`. Mutually exclusive with check 3 (that fires
        # only when NO spec is IN PROGRESS), so at most one stdout note is emitted.
        # Silent when the subject is already tagged, or when >1 specs are IN PROGRESS
        # (ambiguous), or on git-generated Merge/Revert/fixup/squash subjects.
        if [ -n "$subject" ]; then
            case "$subject" in
                Merge\ *|Revert\ *|fixup!*|squash!*) : ;;
                *)
                    if ! printf '%s' "$subject" | grep -qE '\[[^]]+\]'; then
                        inprog_ids=$(grep -E '^- \*\*[^*]+\*\* .+ `IN PROGRESS` ' "$CWD/SPECIFICATIONS.md" | sed -nE 's/^- \*\*([^*]+)\*\*.*/\1/p')
                        n=$(printf '%s\n' "$inprog_ids" | grep -c . || true)
                        if [ "$n" -eq 1 ]; then
                            id=$(printf '%s' "$inprog_ids" | tr -d '[:space:]')
                            printf '%s' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"additionalContext\":\"flow-toolkit: spec ${id} is IN PROGRESS but this commit's subject has no [#id] tag. Prefix the subject with [#${id}] (e.g. [#${id}] feat: ...) so /flow-ship derives the release set from git log. Proceeding with the commit.\"}}"
                        fi
                    fi
                    ;;
            esac
        fi
    fi
fi

exit 0

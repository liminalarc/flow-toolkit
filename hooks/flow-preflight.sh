#!/usr/bin/env bash
# flow-preflight.sh — shared, deterministic pre-ship / spec checks.
#
# This is the SOURCE OF TRUTH for three machine-checkable rules that both a
# human and the flow skills call, so a check is defined once and can never be a
# green run that silently skipped it:
#
#   git-state [--repo DIR] [--no-fetch]
#       Validates release-branch hygiene: on the default branch, a clean tree,
#       and up to date with origin. Prints one ✅/❌/⚠️ line per check and, on a
#       fixable failure, the exact remediation command sequence — but NEVER runs
#       it (merging a feature branch / choosing what to stash is a human call).
#       Exit 0 = all pass · 2 = a check failed or could not be verified.
#
#   resolved [--repo DIR] [--spec-dir specs] [--done ID,ID,...]
#       The deferral DONE-gating rule: no spec may be DONE while any `deferrals:`
#       front-matter entry is unresolved. An entry is resolved iff `to` is
#       `built` or an id whose detail file exists — flat specs/<to>.md or
#       archived specs/archive/<to>.md, and the directory form
#       specs/<to>/<to>.md / specs/archive/<to>/<to>.md (a big spec's
#       orchestrator). A backend-neutral proxy for "the receiving spec exists"
#       that needs no board access. The DONE set comes from --done
#       (ado / caller-supplied) or, if omitted, from SPECIFICATIONS.md (local).
#       Exit 0 = all DONE specs clean · 2 = an unresolved deferral exists.
#
#   wellformed <detail.md>
#       Validates one detail file's `deferrals:` shape: every entry has a
#       non-empty what, why, and to. Called by flow-spec-guard.sh on each edit.
#       Exit 0 = fine / no deferrals · 2 = a malformed entry.
#
# Backend-neutral by construction: every rule reads only the repo's own files
# (index + specs/<id>.md front-matter), so it behaves identically in local and
# ado mode. The one thing it cannot know in ado mode — which specs are DONE —
# is supplied by the caller via --done.

set -u

# Field separator between parsed columns. A unit separator (0x1F, non-whitespace)
# so `read` preserves empty fields — tab would collapse, dropping a blank column.
US=$(printf '\037')

# --- shared: emit the parsed deferrals of a detail file --------------------
# Prints one record per entry: <what><US><why><US><to>
# (empty fields kept so callers can detect "missing"). Only reads front-matter.
parse_deferrals() {
    awk '
    function unq(v) {
        sub(/\r$/, "", v)
        if (v ~ /^"/)   { sub(/^"/, "", v);       sub(/".*$/, "", v);       return v }
        if (v ~ /^\047/) { sub(/^\047/, "", v);   sub(/\047.*$/, "", v);    return v }  # \047 = single quote
        sub(/[[:space:]]*#.*$/, "", v)   # strip inline comment on a bare scalar
        sub(/[[:space:]]+$/, "", v)
        return v
    }
    function assign(s, idx) {
        if (s ~ /^what:/) { v = s; sub(/^what:[[:space:]]*/, "", v); what[idx] = unq(v) }
        else if (s ~ /^why:/) { v = s; sub(/^why:[[:space:]]*/, "", v); why[idx] = unq(v) }
        else if (s ~ /^to:/)  { v = s; sub(/^to:[[:space:]]*/,  "", v); to[idx]  = unq(v) }
    }
    BEGIN { fm = 0; indef = 0; n = 0 }
    {
        line = $0
        sub(/\r$/, "", line)
        # Front-matter boundaries: a --- on line 1 opens it, the next --- closes.
        if (fm == 0 && NR == 1 && line ~ /^---[[:space:]]*$/) { fm = 1; next }
        if (fm == 1 && line ~ /^---[[:space:]]*$/) { fm = 2; next }
        if (fm != 1) next
        # Inside front-matter body:
        if (line ~ /^deferrals:[[:space:]]*$/) { indef = 1; next }
        if (indef == 1 && line ~ /^[^[:space:]-]/) indef = 0   # a new top-level key ends the list
        if (indef != 1) next
        if (line ~ /^[[:space:]]*-[[:space:]]/) {          # entry start "  - ..."
            n++; what[n] = ""; why[n] = ""; to[n] = ""
            rest = line; sub(/^[[:space:]]*-[[:space:]]*/, "", rest)
            if (rest != "") assign(rest, n)
        } else if (n > 0) {                                 # continuation "    key: val"
            s = line; sub(/^[[:space:]]+/, "", s)
            assign(s, n)
        }
    }
    END { for (i = 1; i <= n; i++) printf "%s%s%s%s%s\n", what[i], US, why[i], US, to[i] }
    ' US="$US" "$1"
}

# --- subcommand: wellformed <file> -----------------------------------------
cmd_wellformed() {
    file="$1"
    [ -f "$file" ] || exit 0
    base=$(basename "$file")
    records=$(parse_deferrals "$file")
    [ -z "$records" ] && exit 0   # no deferrals ⇒ no ceremony
    errs=""
    idx=0
    while IFS="$US" read -r what why to; do
        idx=$((idx + 1))
        [ -z "$what" ] && errs="${errs}  deferral #$idx: missing \"what\" (name what was deferred)\n"
        [ -z "$why" ]  && errs="${errs}  deferral #$idx: missing \"why\" (state the reason it was deferred)\n"
        [ -z "$to" ]   && errs="${errs}  deferral #$idx: missing \"to\" (\`built\`, or the spec id that owns it now)\n"
    done <<EOF
$records
EOF
    if [ -n "$errs" ]; then
        {
            echo "flow-toolkit preflight: $base has a malformed deferrals entry:"
            printf '%b' "$errs"
            echo "Each deferrals entry needs: what (what was cut), why (the reason), to (\`built\` or a spec id)."
        } >&2
        exit 2
    fi
    exit 0
}

# --- subcommand: resolved --------------------------------------------------
# Does a `to` value resolve? built, or a detail file exists for that id.
to_resolves() { # <to> <spec_dir_abs>
    _to="$1"; _dir="$2"
    [ "$_to" = "built" ] && return 0
    # Flat form, then the directory form specs/<id>/<id>.md (orchestrator) — both
    # active and archived. One place fixes both the DONE-gate and `to`-resolution.
    [ -f "$_dir/$_to.md" ] && return 0
    [ -f "$_dir/$_to/$_to.md" ] && return 0
    [ -f "$_dir/archive/$_to.md" ] && return 0
    [ -f "$_dir/archive/$_to/$_to.md" ] && return 0
    return 1
}

cmd_resolved() {
    repo="."; spec_dir="specs"; done_ids=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --repo) repo="$2"; shift 2 ;;
            --spec-dir) spec_dir="$2"; shift 2 ;;
            --done) done_ids="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    dir="$repo/$spec_dir"

    # Resolve the DONE set. --done wins (ado / caller-supplied); otherwise read
    # the local index. If neither is available we cannot know what's DONE — that
    # is a "could not verify", never a silent pass.
    if [ -z "$done_ids" ]; then
        idx="$repo/SPECIFICATIONS.md"
        if [ ! -f "$idx" ]; then
            echo "flow-toolkit preflight: no --done set given and no SPECIFICATIONS.md at $repo — cannot determine which specs are DONE. Pass --done <ids> (e.g. from the board)." >&2
            exit 2
        fi
        done_ids=$(grep -oE '^- \*\*[A-Za-z0-9][A-Za-z0-9]*[.][A-Za-z0-9-]+\*\* .+ — `DONE` —' "$idx" \
                   | sed -E 's/^- \*\*([^*]+)\*\*.*/\1/' | paste -sd, - 2>/dev/null || true)
    fi

    # Normalize comma/space separated ids into a newline list.
    done_list=$(printf '%s' "$done_ids" | tr ', ' '\n\n' | grep -v '^$' || true)
    [ -z "$done_list" ] && exit 0   # nothing DONE ⇒ nothing to gate

    unresolved=""
    while IFS= read -r id; do
        [ -z "$id" ] && continue
        f="$dir/$id.md"
        [ -f "$f" ] || f="$dir/$id/$id.md"              # dir-form orchestrator
        [ -f "$f" ] || f="$dir/archive/$id.md"
        [ -f "$f" ] || f="$dir/archive/$id/$id.md"      # archived dir-form
        [ -f "$f" ] || continue     # missing detail file is flow-lint's job, not this rule's
        records=$(parse_deferrals "$f")
        [ -z "$records" ] && continue
        idx=0
        while IFS="$US" read -r what why to; do
            idx=$((idx + 1))
            label="${what:-deferral #$idx}"
            if [ -z "$to" ]; then
                unresolved="${unresolved}  $id: \"$label\" has no \`to\` — set it to \`built\` or the spec id that owns it\n"
            elif ! to_resolves "$to" "$dir"; then
                unresolved="${unresolved}  $id: \"$label\" → to: $to — no such spec (create it, or set to \`built\`)\n"
            fi
        done <<EOF
$records
EOF
    done <<EOF
$done_list
EOF

    if [ -n "$unresolved" ]; then
        {
            echo "flow-toolkit preflight: DONE spec(s) with unreconciled deferrals — a spec cannot be DONE with an open deferral:"
            printf '%b' "$unresolved"
            echo "Resolve each via the deferral protocol: build it here (to: built) or re-home it to a spec that exists (to: <id>)."
        } >&2
        exit 2
    fi
    exit 0
}

# --- subcommand: git-state -------------------------------------------------
cmd_git_state() {
    repo="."; fetch=1
    while [ $# -gt 0 ]; do
        case "$1" in
            --repo) repo="$2"; shift 2 ;;
            --no-fetch) fetch=0; shift ;;
            *) shift ;;
        esac
    done
    git() { command git -C "$repo" "$@"; }

    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo "❌ Not a git repository ($repo)" >&2
        exit 2
    fi

    fail=0

    # Default branch: prefer origin/HEAD, fall back to main.
    default=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')
    [ -z "$default" ] && default="main"
    branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null || echo "(detached)")

    if [ "$branch" = "$default" ]; then
        echo "✅ On $default"
    else
        ahead=$(git rev-list --count "$default..HEAD" 2>/dev/null || echo "?")
        echo "❌ On branch '$branch', not '$default' (${ahead} commit(s) ahead of $default)"
        echo "   FIX (confirm first — is '$branch' reviewed and merge-ready?):"
        echo "     git checkout $default && git merge --no-ff $branch && git push"
        fail=1
    fi

    # Up to date with origin (needs a fetch to be truthful).
    fetched=1
    if [ "$fetch" -eq 1 ]; then
        git fetch --quiet 2>/dev/null || fetched=0
    else
        fetched=0
    fi
    upstream="origin/$default"
    if git rev-parse --verify --quiet "$upstream" >/dev/null 2>&1; then
        behind=$(git rev-list --count "HEAD..$upstream" 2>/dev/null || echo 0)
        ahead=$(git rev-list --count "$upstream..HEAD" 2>/dev/null || echo 0)
        stale=""
        [ "$fetched" -eq 0 ] && stale=" (fetch skipped/failed — compared against last-known $upstream)"
        if [ "$behind" = "0" ] && [ "$ahead" = "0" ]; then
            if [ "$fetched" -eq 0 ]; then
                echo "⚠️  Up to date with $upstream — but could not fetch$stale"
                fail=1
            else
                echo "✅ Up to date with $upstream"
            fi
        else
            echo "❌ Not in sync with $upstream — $ahead ahead, $behind behind$stale"
            [ "$behind" != "0" ] && echo "     FIX: git pull --ff-only"
            [ "$ahead" != "0" ]  && echo "     (unpushed commits — push after review: git push)"
            fail=1
        fi
    else
        echo "⚠️  No upstream $upstream to compare against"
        fail=1
    fi

    # Clean working tree.
    if [ -z "$(git status --porcelain 2>/dev/null)" ]; then
        echo "✅ Clean tree"
    else
        n=$(git status --porcelain 2>/dev/null | grep -c '' || echo '?')
        echo "❌ Uncommitted changes — $n path(s) dirty"
        echo "   FIX (confirm first): commit the work, or 'git stash' if it should not ship"
        fail=1
    fi

    [ "$fail" -eq 0 ] || exit 2
    exit 0
}

# --- dispatch --------------------------------------------------------------
sub="${1:-}"
[ $# -gt 0 ] && shift
case "$sub" in
    git-state)  cmd_git_state "$@" ;;
    resolved)   cmd_resolved "$@" ;;
    wellformed) cmd_wellformed "$@" ;;
    *)
        echo "usage: flow-preflight.sh <git-state|resolved|wellformed> [args]" >&2
        exit 64 ;;
esac

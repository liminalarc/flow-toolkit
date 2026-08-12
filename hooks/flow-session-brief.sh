#!/usr/bin/env bash
# flow-session-brief.sh — Claude Code SessionStart hook.
#
# If the project has a SPECIFICATIONS.md index, prints a one-line backlog
# orientation to stdout, which Claude Code injects into the session context.
# ~30 tokens of pure signal: what's in flight, what's queued, and the ONE thing
# worth doing next.
#
# Reads the index model first ("- **<id>** Title — `STATUS` — [detail](...)").
# Falls back to the legacy inline format (### Spec + **Status:**) so a
# pre-migration repo still gets a brief. An ado project (no local index) gets a
# minimal backend orientation from .flow/config.yml. Always exits 0.
#
# The closing clause is a PRIORITY LADDER (1.19) — highest true tier wins and
# only one ever prints; a brief that suggests three things trains the reader to
# skip it, which costs the tier-1 warning its credibility:
#   T1  a DONE spec with an unresolved deferral (blocks the release)
#   T2  a spec IN PROGRESS (resume it)
#   T3  DONE specs tagged since the last tag, clean tree (ship them)
#   T4  nothing in flight (the board)
#
# This output lands in Claude's context, not just the user's eyes, so every
# nudge is phrased as state + an available option — never an imperative, which
# would read as an instruction to act before the user has said anything.
#
# NEVER query a board/network here: this runs at every session start in every
# project. Cost is dominated by process startup, so the ladder adds work only
# on the tier that is actually reached, and nothing scales with backlog size.

set -u

INPUT=$(cat 2>/dev/null || true)

CWD_RAW=$(printf '%s' "$INPUT" | grep -oE '"cwd"[[:space:]]*:[[:space:]]*"(\\.|[^"\\])*"' | head -n 1)
[ -z "$CWD_RAW" ] && exit 0
CWD=$(printf '%s' "$CWD_RAW" | sed -E 's/^"cwd"[[:space:]]*:[[:space:]]*"//; s/"$//')
CWD=$(printf '%s' "$CWD" | sed -e 's/\\"/"/g' -e 's/\\\//\//g' -e 's/\\\\/\\/g' | tr '\\' '/')

SPEC="$CWD/SPECIFICATIONS.md"

# No local index: an ado project still deserves orientation (it used to get
# nothing at all). Read the config only — the board is never queried here.
if [ ! -f "$SPEC" ]; then
    CFG="$CWD/.flow/config.yml"
    [ -f "$CFG" ] || exit 0
    grep -q 'lifecycle_authority:[[:space:]]*ado' "$CFG" 2>/dev/null || exit 0
    coord=$(tr -d '\r' < "$CFG" | awk '
        /^[[:space:]]*project:[[:space:]]*/ && p == "" {
            p = $0; sub(/^[[:space:]]*project:[[:space:]]*/, "", p); gsub(/"/, "", p)
        }
        /^[[:space:]]*area:[[:space:]]*/ && a == "" {
            a = $0; sub(/^[[:space:]]*area:[[:space:]]*/, "", a); gsub(/"/, "", a)
        }
        END { if (p != "" && a != "") print p " · " a; else print p a }
    ')
    if [ -n "$coord" ]; then
        echo "flow-toolkit: ado backend — $coord — /flow:run for the board"
    else
        echo "flow-toolkit: ado backend — /flow:run for the board"
    fi
    exit 0
fi

# Pass 1 — parse the index into three lines: the state summary, the IN PROGRESS
# id (empty if none), and the DONE count. The summary is what the brief has
# always printed; the ladder below chooses only the clause that follows it.
STATE=$(awk '
# New index format: "- **<id>** <Title> — `STATUS` — [detail](...)"
match($0, /^- \*\*[A-Za-z0-9][A-Za-z0-9]*[.][A-Za-z0-9-]+\*\* .+ — `(NOT STARTED|IN PROGRESS|PARTIAL|DONE|SUPERSEDED)` —/) {
    entries++
    # title = between "** " and " — `"
    t = $0
    sub(/^- \*\*[A-Za-z0-9][A-Za-z0-9]*[.][A-Za-z0-9-]+\*\* /, "", t)
    sub(/ — `.*/, "", t)
    # status = inside the first backtick pair
    s = $0
    sub(/^.*— `/, "", s)
    sub(/`.*/, "", s)
    # id = between "- **" and "**" — the ladder needs it to name a resume target
    id = $0
    sub(/^- \*\*/, "", id)
    sub(/\*\*.*/, "", id)
    count[s]++
    if (s == "IN PROGRESS") {
        inprog = (inprog == "" ? t : inprog ", " t)
        if (inprog_id == "") inprog_id = id
    }
    if (s == "DONE") done_ids = (done_ids == "" ? id : done_ids "," id)
    next
}
# Legacy fallback: ### Spec heading + **Status:** line
/^### Spec / { legacy_head = $0; sub(/^### /, "", legacy_head); next }
/^\*\*Status:\*\*/ {
    v = $0; sub(/^\*\*Status:\*\*[[:space:]]*/, "", v); sub(/[[:space:]]+$/, "", v)
    legacy_count[v]++
    if (v == "IN PROGRESS" && legacy_head != "") legacy_inprog = (legacy_inprog == "" ? legacy_head : legacy_inprog ", " legacy_head)
    legacy_head = ""
    next
}
END {
    if (entries == 0) { inprog = legacy_inprog; for (k in legacy_count) count[k] = legacy_count[k] }
    line = "flow-toolkit: "
    line = line (inprog != "" ? inprog " is IN PROGRESS" : "no spec IN PROGRESS")
    if (count["NOT STARTED"] > 0) line = line " · " count["NOT STARTED"] " NOT STARTED"
    if (count["PARTIAL"] > 0)     line = line " · " count["PARTIAL"] " PARTIAL"
    if (count["DONE"] > 0)        line = line " · " count["DONE"] " DONE"
    print line
    print inprog_id
    print count["DONE"] + 0
    print done_ids
}
' "$SPEC")

[ -z "$STATE" ] && exit 0

# No subshells: read the three lines straight into variables.
{ IFS= read -r summary; IFS= read -r inprog_id; IFS= read -r done_count; IFS= read -r done_ids; } <<EOF
$STATE
EOF

HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
nudge=""

# T1 — a DONE spec with an unresolved deferral. The rule lives in the shared
# helper (never re-implemented here); if the helper is missing we simply skip
# the tier rather than guess.
#
# The helper resolves a path and parses front-matter for EVERY done id, which
# on a large backlog costs seconds — unacceptable in a session-start hook. So
# gate it on a single cheap grep first: no `deferrals:` key anywhere in the
# spec tree ⇒ the helper cannot possibly report one. That is a strict superset
# of what the helper checks, so the tier stays exact, and the common case
# (no deferrals at all) costs one grep instead of N file parses.
SPECS_DIR="specs"
if [ -f "$CWD/.flow/config.yml" ]; then
    cfg_dir=$(awk '/^[[:space:]]*spec_dir:[[:space:]]*/ {
        d = $0; sub(/^[[:space:]]*spec_dir:[[:space:]]*/, "", d)
        gsub(/"/, "", d); sub(/[[:space:]]*#.*/, "", d); sub(/\r$/, "", d); print d; exit
    }' "$CWD/.flow/config.yml" 2>/dev/null)
    [ -n "$cfg_dir" ] && SPECS_DIR="$cfg_dir"
fi
if [ "${done_count:-0}" -gt 0 ] && [ -f "$HERE/flow-preflight.sh" ] && [ -d "$CWD/$SPECS_DIR" ]; then
    # Narrow the helper's input to the DONE specs that actually carry a
    # `deferrals:` key: one grep finds the candidate files, their ids are read
    # with shell builtins (no subprocess per file), and only the intersection
    # with the index's DONE set is handed to the helper. Without this the
    # helper resolves a path and parses front-matter for EVERY done id, which
    # measured 3s on an 18-spec backlog and grows with it.
    candidates=""
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        fid=""
        while IFS= read -r line; do
            case "$line" in
                ---*) [ -n "$fid" ] && break ;;
                id:*)
                    fid=${line#id:}
                    while [ "${fid# }" != "$fid" ]; do fid=${fid# }; done
                    fid=${fid%$'\r'}
                    break ;;
            esac
        done < "$f"
        # Only ids the index calls DONE can be gated — a deferral on an
        # in-flight spec is normal, not a warning.
        case ",${done_ids}," in
            *",$fid,"*) candidates="${candidates:+$candidates,}$fid" ;;
        esac
    done <<EOF
$(grep -rl 'deferrals:' "$CWD/$SPECS_DIR" 2>/dev/null)
EOF

    if [ -n "$candidates" ]; then
        if pf_out=$(bash "$HERE/flow-preflight.sh" resolved --repo "$CWD" --done "$candidates" 2>&1); then
            : # exit 0 — nothing unreconciled
        else
            blocked=$(printf '%s\n' "$pf_out" | awk '/^  [A-Za-z0-9]/ { sub(/^ +/, ""); sub(/:.*/, ""); print; exit }')
            [ -n "$blocked" ] && nudge="⚠ $blocked is DONE with an open deferral; /flow:run $blocked reconciles it"
        fi
    fi
fi

# T2 — work in flight. Naming the id saves the user a board lookup.
if [ -z "$nudge" ] && [ -n "${inprog_id:-}" ]; then
    nudge="/flow:run $inprog_id resumes it"
fi

# T3 — DONE specs tagged since the last release, on a clean tree. A dirty tree
# is mid-work, not a release candidate. No fetch, ever — local refs only.
if [ -z "$nudge" ] && [ -d "$CWD/.git" ] && command -v git >/dev/null 2>&1; then
    if [ -z "$(git -C "$CWD" status --porcelain 2>/dev/null)" ]; then
        last_tag=$(git -C "$CWD" describe --tags --abbrev=0 2>/dev/null)
        if [ -n "$last_tag" ]; then
            shipped=0
            for id in $(git -C "$CWD" log "$last_tag..HEAD" --format=%B 2>/dev/null \
                        | grep -oE '^\[#?[A-Za-z0-9][A-Za-z0-9.-]*\]' | tr -d '[]#' | sort -u); do
                esc=$(printf '%s' "$id" | sed 's/[.]/\\./g')
                if grep -qE "^- \*\*$esc\*\* .+ \`DONE\` —" "$SPEC" 2>/dev/null; then
                    shipped=$((shipped + 1))
                fi
            done
            if [ "$shipped" -gt 1 ]; then
                nudge="$shipped specs DONE since $last_tag; /flow:ship when ready"
            elif [ "$shipped" -eq 1 ]; then
                nudge="1 spec DONE since $last_tag; /flow:ship when ready"
            fi
        fi
    fi
fi

# T4 — nothing to single out; the board is the useful default.
[ -z "$nudge" ] && nudge="run /flow:run for the board"

echo "$summary — $nudge"

exit 0

#!/usr/bin/env bash
# flow-spec-guard.sh — Claude Code PostToolUse hook (matcher: Edit|Write).
#
# Fires after every file edit. Validates the flow-toolkit spec model:
#
#   * SPECIFICATIONS.md / SPECIFICATIONS-ARCHIVE.md (the INDEX): every backlog
#     entry line matches
#         - **<id>** <Title> — `STATUS` — [detail](<path>)
#     where <id> is alphanumeric — either the dotted Phase.Spec scheme
#     ("1.2", "0.1", "2.37a", "P.10") or a flat id ("10", "226", "21c", "T2",
#     "BL-12", "N"); the leading dotted segment is optional,
#     STATUS is one of NOT STARTED / IN PROGRESS / PARTIAL / DONE / SUPERSEDED,
#     and no id is duplicated within the file.
#
#   * <spec_dir>/<id>.md (a DETAIL file, default dir "specs"): carries NO status
#     field (status is single-source in the index — a status here would drift),
#     and its front-matter `id:` matches the filename stem. A big spec may use
#     the directory form <spec_dir>/<id>/ = orchestrator <id>.md + task files
#     <id>.T<n>.md; both the orchestrator and each task file are detail files
#     (same no-status + id==stem rules). A task file (stem .T<n> whose parent
#     dir is named for the spec id) also gets a SOFT local-AC nudge — never a
#     block — if it has no 'done when' checkbox.
#
# A legacy inline SPECIFICATIONS.md (### Spec blocks, **Status:** lines) is
# detected and PASSED with a one-line advisory to run `/flow:lint --migrate` —
# it is never blocked, so a pre-migration repo stays editable.
#
# Exit 0 = fine / not a spec file / legacy (advisory on stderr).
# Exit 2 = validation failed; errors on stderr are fed back to Claude so it
#          fixes the file in the same turn.
#
# Direct-invocation form (used by flow-commit-guard.sh): flow-spec-guard.sh <file>

set -u

# Direct-arg invocation (from flow-commit-guard.sh or a human) vs. PostToolUse
# hook (stdin JSON). The soft bloat warning emits a stdout hook note ONLY in
# hook mode; in direct mode it goes to stderr so it never corrupts a caller's
# stdout contract.
if [ $# -ge 1 ]; then
    INVOKED_DIRECT=1
    FILE="$1"
else
    INVOKED_DIRECT=0
    INPUT=$(cat 2>/dev/null || true)
    RAW=$(printf '%s' "$INPUT" | grep -oE '"file_path"[[:space:]]*:[[:space:]]*"(\\.|[^"\\])*"' | head -n 1)
    [ -z "$RAW" ] && exit 0
    FILE=$(printf '%s' "$RAW" | sed -E 's/^"file_path"[[:space:]]*:[[:space:]]*"//; s/"$//')
    FILE=$(printf '%s' "$FILE" | sed -e 's/\\"/"/g' -e 's/\\\//\//g' -e 's/\\\\/\\/g')
fi
# Normalize Windows backslashes so basename/dirname and -f work under Git Bash.
FILE=$(printf '%s' "$FILE" | tr '\\' '/')

base=$(basename "$FILE")

# Walk up from a directory to the repo root (the dir holding `.git`). Used to
# locate an optional .flow-toolkit.json for the soft spec-line budget. Mirrors
# the same helper in flow-claude-guard.sh. Terminates at the filesystem root.
find_repo_root() {
    d=$1; prev=""
    while [ -n "$d" ] && [ "$d" != "$prev" ]; do
        [ -e "$d/.git" ] && { printf '%s' "$d"; return 0; }
        prev=$d
        d=$(dirname "$d")
    done
    return 1
}

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
    # Deferral front-matter must be well-formed (each entry has what/why/to).
    # Delegated to the shared helper so the rule is defined once; its stderr
    # passes through and Claude fixes the file in the same turn.
    SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
    if [ -f "$SCRIPT_DIR/flow-preflight.sh" ]; then
        bash "$SCRIPT_DIR/flow-preflight.sh" wellformed "$FILE" || exit 2
    fi

    # --- Soft nudges (a nudge, NEVER a block) ---------------------------------
    # Accumulate into one message so hook mode emits a single valid JSON note.
    # All quote-free so they embed safely in the hook-note JSON string below.
    soft=""

    # Task-file local-AC presence. A big spec earns specs/<id>/ = orchestrator
    # <id>.md + task files <id>.T<n>.md; a task file carries the "how" plus a
    # local 'done when' contract (a checkbox) — the seam a per-task implementer
    # builds to and a verifier checks against (D2). Nudge if it has none.
    # Detection: stem ends .T<n> AND the parent dir is named for the spec id, so
    # a flat specs/2.T3.md and the orchestrator specs/<id>/<id>.md never trip it.
    stem_prefix=$(printf '%s' "$stem" | sed -nE 's/^(.+)\.T[0-9][0-9]*$/\1/p')
    parent=$(basename "$(dirname "$FILE")")
    if [ -n "$stem_prefix" ] && [ "$stem_prefix" = "$parent" ]; then
        if ! grep -qE '^[[:space:]]*-[[:space:]]\[[ xX]\]' "$FILE"; then
            soft="${soft}task file $base has no local AC — add a 'Done when' checkbox (- [ ] ...) so a per-task implementer/verifier has a seam to build and check against. "
        fi
    fi

    # Bloat: a terse spec keeps the working set lean — the same principle behind
    # the CLAUDE.md line caps, applied to detail files. Default budget 120 lines;
    # override per project with { "spec": { "maxLines": <n> } } in
    # .flow-toolkit.json at the repo root.
    dlines=$(wc -l < "$FILE" | tr -d '[:space:]')
    smax=120
    droot=$(find_repo_root "$(dirname "$FILE")" || true)
    if [ -n "$droot" ] && [ -f "$droot/.flow-toolkit.json" ]; then
        cv=$(grep -oE '"maxLines"[[:space:]]*:[[:space:]]*[0-9]+' "$droot/.flow-toolkit.json" 2>/dev/null | head -n 1 | grep -oE '[0-9]+')
        [ -n "$cv" ] && smax=$cv
    fi
    if [ "$dlines" -gt "$smax" ]; then
        soft="${soft}$base is $dlines lines (soft budget $smax) — tighten it: one job per section, no cross-section restatement, prose to bullets. terse != lossy. Raise spec.maxLines in .flow-toolkit.json if this spec genuinely needs the room."
    fi

    if [ -n "$soft" ]; then
        msg="flow-toolkit spec guard: $soft"
        if [ "$INVOKED_DIRECT" -eq 1 ]; then
            echo "$msg" >&2
        else
            printf '%s' "{\"hookSpecificOutput\":{\"hookEventName\":\"PostToolUse\",\"additionalContext\":\"$msg\"}}"
        fi
    fi
    exit 0
fi

# --- Index file ---------------------------------------------------------------

# Legacy inline format: ### Spec blocks and no new-style "- **<id>**" entries.
# Advise migration; do not block (migration is a deliberate action).
if grep -q '^### Spec ' "$FILE" && ! grep -qE '^- \*\*[A-Za-z0-9]' "$FILE"; then
    echo "flow-toolkit spec guard: $base looks like a legacy inline spec file (### Spec blocks). Run \`/flow:lint --migrate\` to convert it to the index + specs/<id>.md model. (Not blocking.)" >&2
    exit 0
fi

errors=$(awk '
BEGIN {
    VALID["NOT STARTED"]; VALID["IN PROGRESS"]; VALID["PARTIAL"]; VALID["DONE"]; VALID["SUPERSEDED"]
    errs = ""
}
/^- \*\*/ {
    line = $0
    if (line ~ /^- \*\*[A-Za-z0-9][A-Za-z0-9.-]*\*\* .+ — `(NOT STARTED|IN PROGRESS|PARTIAL|DONE|SUPERSEDED)` — \[[^]]+\]\(.+\)$/) {
        s = line; sub(/^- \*\*/, "", s)
        match(s, /^[A-Za-z0-9][A-Za-z0-9.-]*/)
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

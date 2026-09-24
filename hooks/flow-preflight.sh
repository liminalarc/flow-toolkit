#!/usr/bin/env bash
# flow-preflight.sh — shared, deterministic pre-ship / spec checks.
#
# This is the SOURCE OF TRUTH for the machine-checkable rules that both a
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
#       `built` or an id whose detail file exists — resolved via spec-path, so
#       every shape and name form is covered without a second lookup here. A
#       backend-neutral proxy for "the receiving spec exists" that needs no board
#       access. The DONE set comes from --done (ado / caller-supplied) or, if
#       omitted, from SPECIFICATIONS.md (local; dotted and flat ids alike).
#       Exit 0 = all DONE specs clean · 2 = an unresolved deferral exists.
#
#   wellformed <detail.md>
#       Validates one detail file's `deferrals:` shape: every entry has a
#       non-empty what, why, and to. Called by flow-spec-guard.sh on each edit.
#       Exit 0 = fine / no deferrals · 2 = a malformed entry.
#
#   spec-path <id> [--repo DIR] [--spec-dir specs]
#       Resolve a spec id to its detail file and print the path. THE one place
#       that knows id -> path, across all eight combinations of shape
#       (flat <id>.md | directory <id>/<id>.md), name (plain | slugged
#       <id>-<slug>, 1.17) and location (active | archive). Exact names are
#       preferred over slugged ones. Exit 0 = resolved (path on stdout) · 1 = no
#       such spec (silent — the caller decides whether that is an error) ·
#       2 = ambiguous, i.e. two files claim one id (both named on stderr).
#
#   autonomy <spec.md> [--repo DIR]
#       Resolves a spec's autonomy mode (whether /flow:run pauses for plan approval)
#       and prints `checkpoint` or `auto-build`. Precedence:
#           autonomy.force  (.flow-toolkit.json)  — hard project override
#         > per-spec `autonomy:` front-matter      — the spec's own choice
#         > autonomy.default (.flow-toolkit.json)  — fallback when spec is silent
#         > builtin `checkpoint`.
#       An unrecognized value warns on stderr and falls back to `checkpoint`
#       (never a silent wrong mode). Consumed by /flow:run's build loop. Always
#       exit 0 — resolution never fails; the worst case is the safe default.
#
#   rubric-basis <file>...
#       Emit a YAML `basis:` block (path + 12-char sha256 each) for the given
#       source files. Used when saving/refreshing a persisted project rubric
#       (.flow/validate/{ui,ux}.md) so stamping and drift-checking share one
#       fingerprint definition. A missing file is a hard error. Exit 0 / 2.
#
#   rubric-drift <rubric.md> [--repo DIR]
#       Re-hash each source file recorded in a rubric's `basis:` block and
#       compare to the stored sha. Prints ✅/❌/⚠️ per basis entry. Exit 0 = all
#       in sync (also when the rubric or its basis is absent — a clean opt-in
#       no-op) · 2 = a basis file CHANGED or went MISSING (design system drifted).
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

# --- shared: resolve a spec id to its detail file ---------------------------
# ONE place owns id -> path, for every combination of shape (flat | directory),
# name (plain <id> | slugged <id>-<slug>, 1.17) and location (active | archive).
# Prints each candidate on its own line, exact names first — an exact <id>.md is
# returned alone and is never ambiguous, while slugged matches are ALL returned
# so a caller can report ambiguity instead of silently picking one.
# The "-" after the id is required, so id 5.9 never matches 5.95-other.md.
spec_path_candidates() { # <id> <spec_dir>
    _id="$1"; _d="$2"
    for _p in "$_d/$_id.md" "$_d/$_id/$_id.md" "$_d/archive/$_id.md" "$_d/archive/$_id/$_id.md"; do
        if [ -f "$_p" ]; then printf '%s\n' "$_p"; return 0; fi
    done
    # Slugged forms. Globbed rather than pattern-matched, and each hit is tested
    # with -f/-d so an unmatched glob (which POSIX leaves literal) is skipped.
    _found=""
    for _base in "$_d" "$_d/archive"; do
        [ -d "$_base" ] || continue
        for _p in "$_base/$_id"-*.md; do
            [ -f "$_p" ] && _found="$_found$_p
"
        done
        for _sd in "$_base/$_id"-*/; do
            [ -d "$_sd" ] || continue
            _stem=$(basename "$_sd")                 # the dir is named for its orchestrator
            [ -f "$_sd$_stem.md" ] && _found="$_found$_sd$_stem.md
"
        done
    done
    printf '%s' "$_found"
}

# Single-answer form for internal callers: first candidate wins. Exit 1 = no such
# spec (callers decide whether absence is an error). Ambiguity is not fatal here —
# `spec-path` is the subcommand that surfaces it.
resolve_spec_path() { # <id> <spec_dir>
    _c=$(spec_path_candidates "$1" "$2")
    [ -n "$_c" ] || return 1
    printf '%s\n' "$_c" | head -n 1
}

# --- subcommand: spec-path -------------------------------------------------
cmd_spec_path() {
    id=""; repo="."; spec_dir="specs"
    while [ $# -gt 0 ]; do
        case "$1" in
            --repo) repo="$2"; shift 2 ;;
            --spec-dir) spec_dir="$2"; shift 2 ;;
            *) [ -z "$id" ] && id="$1"; shift ;;
        esac
    done
    if [ -z "$id" ]; then
        echo "usage: flow-preflight.sh spec-path <id> [--repo DIR] [--spec-dir specs]" >&2
        exit 64
    fi
    cands=$(spec_path_candidates "$id" "$repo/$spec_dir")
    [ -z "$cands" ] && exit 1        # silent: not-found is the caller's call
    n=$(printf '%s\n' "$cands" | grep -c . || true)
    if [ "$n" -gt 1 ]; then
        {
            echo "flow-toolkit preflight: spec id $id is ambiguous — $n detail files match:"
            printf '%s\n' "$cands" | grep . | sed 's/^/  /'
            echo "Exactly one file may own an id — rename or remove the duplicates."
        } >&2
        exit 2
    fi
    printf '%s\n' "$cands" | grep .
    exit 0
}

# --- subcommand: resolved --------------------------------------------------
# Does a `to` value resolve? built, or a detail file exists for that id.
to_resolves() { # <to> <spec_dir_abs>
    [ "$1" = "built" ] && return 0
    resolve_spec_path "$1" "$2" >/dev/null
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
        # Id pattern matches the spec guard's: the leading dotted segment is
        # OPTIONAL, so ado's flat work-item ids (642103) are in the DONE set too.
        # Requiring a dot here left the gate silently inert for every flat id.
        done_ids=$(grep -oE '^- \*\*[A-Za-z0-9][A-Za-z0-9.-]*\*\* .+ — `DONE` —' "$idx" \
                   | sed -E 's/^- \*\*([^*]+)\*\*.*/\1/' | paste -sd, - 2>/dev/null || true)
    fi

    # Normalize comma/space separated ids into a newline list.
    done_list=$(printf '%s' "$done_ids" | tr ', ' '\n\n' | grep -v '^$' || true)
    [ -z "$done_list" ] && exit 0   # nothing DONE ⇒ nothing to gate

    unresolved=""
    while IFS= read -r id; do
        [ -z "$id" ] && continue
        # Missing detail file is flow-lint's job, not this rule's.
        f=$(resolve_spec_path "$id" "$dir") || continue
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

# --- shared: emit the parsed spawns of a detail file (spec 1.22) -----------
# Prints one record per entry: <id><US><space-separated after ids><US><index>
# A missing key is emitted as \002 so the caller can tell "absent" from "empty".
# `after` is a SCALAR, split on [ ] , and whitespace. It is deliberately not a
# nested YAML sequence: parse_deferrals treats any `^[[:space:]]*-[[:space:]]`
# line inside a block as a NEW entry, so a nested list would be misread as
# extra spawn entries. Keeping it scalar leaves that parser untouched.
parse_spawns() {
    awk '
    function unq(v) {
        sub(/\r$/, "", v)
        if (v ~ /^"/)    { sub(/^"/, "", v);     sub(/".*$/, "", v);    return v }
        if (v ~ /^\047/) { sub(/^\047/, "", v);  sub(/\047.*$/, "", v); return v }
        sub(/[[:space:]]*#.*$/, "", v)
        sub(/[[:space:]]+$/, "", v)
        return v
    }
    function idlist(v,   t) {
        t = unq(v)
        gsub(/[\[\],]/, " ", t)
        gsub(/[[:space:]]+/, " ", t)
        sub(/^ /, "", t); sub(/ $/, "", t)
        return t
    }
    function assign(str, idx,   v) {
        if (str ~ /^id:/)         { v = str; sub(/^id:[[:space:]]*/, "", v);    sid[idx] = unq(v);    seenid[idx] = 1 }
        else if (str ~ /^after:/) { v = str; sub(/^after:[[:space:]]*/, "", v); aft[idx] = idlist(v); seenaf[idx] = 1 }
    }
    BEGIN { fm = 0; insp = 0; n = 0; MISS = sprintf("%c", 2) }
    {
        line = $0; sub(/\r$/, "", line)
        if (fm == 0 && NR == 1 && line ~ /^---[[:space:]]*$/) { fm = 1; next }
        if (fm == 1 && line ~ /^---[[:space:]]*$/) { fm = 2; next }
        if (fm != 1) next
        if (line ~ /^spawns:[[:space:]]*$/) { insp = 1; next }
        if (insp == 1 && line ~ /^[^[:space:]-]/) insp = 0
        if (insp != 1) next
        if (line ~ /^[[:space:]]*-[[:space:]]/) {
            n++; sid[n] = ""; aft[n] = ""; seenid[n] = 0; seenaf[n] = 0
            rest = line; sub(/^[[:space:]]*-[[:space:]]*/, "", rest)
            if (rest != "") assign(rest, n)
        } else if (n > 0) {
            t = line; sub(/^[[:space:]]+/, "", t); assign(t, n)
        }
    }
    END {
        for (i = 1; i <= n; i++)
            printf "%s%s%s%s%d\n", (seenid[i] ? sid[i] : MISS), US, (seenaf[i] ? aft[i] : MISS), US, i
    }
    ' US="$US" "$1"
}

# Resolve the DONE set exactly as cmd_resolved does: --done wins (ado /
# caller-supplied), else the local index, else "cannot determine" — never a
# silent pass. Echoes a newline list; returns 2 when it cannot determine.
spawn_done_set() { # <repo> <done_ids>
    _d="$2"
    if [ -z "$_d" ]; then
        _idx="$1/SPECIFICATIONS.md"
        if [ ! -f "$_idx" ]; then
            echo "flow-toolkit preflight: no --done set given and no SPECIFICATIONS.md at $1 — cannot determine which specs are DONE. Pass --done <ids> (e.g. from the board)." >&2
            return 2
        fi
        _d=$(grep -oE '^- \*\*[A-Za-z0-9][A-Za-z0-9.-]*\*\* .+ — `DONE` —' "$_idx" \
             | sed -E 's/^- \*\*([^*]+)\*\*.*/\1/' | paste -sd, - 2>/dev/null || true)
    fi
    printf '%s' "$_d" | tr ', ' '\n\n' | grep -v '^$' || true
}

# --- subcommand: spawns ----------------------------------------------------
# Validates a `spawns:` block: entry shape, id resolution, and acyclicity.
# Kept cheap because flow-spec-guard.sh calls it on every save of a spec that
# carries the key: ONE awk parse, ONE directory listing, and cycle detection
# in awk — no per-entry subprocess (that cost 2.5s on a 4-node graph).
# --- shared: every spec id in the tree, from front-matter ------------------
# Ids come from each file's `id:` key, NEVER from its filename. A descriptive
# name (<id>-<slug>.md) and a dashed id (BL-12) are mutually ambiguous — no
# regex can split `BL-12-dashed-title` correctly without knowing the id first —
# which is exactly why root CLAUDE.md says the id "is never parsed back out of
# the filename". One awk pass over one file list keeps this at the single-
# subprocess cost the spec guard budgets for on every save.
spec_ids() { # <spec dir>
    d="$1"; set --
    for f in "$d"/*.md "$d"/*/*.md "$d"/archive/*.md "$d"/archive/*/*.md; do
        [ -f "$f" ] && set -- "$@" "$f"
    done
    [ $# -gt 0 ] || return 0
    awk '
    FNR == 1 { fm = 0; got = 0 }
    got { next }
    {
        line = $0; sub(/\r$/, "", line)
        if (FNR == 1) { if (line ~ /^---[[:space:]]*$/) fm = 1; next }
        if (fm != 1) next
        if (line ~ /^---[[:space:]]*$/) { got = 1; next }   # front-matter closed
        if (line ~ /^id:[[:space:]]*/) {
            v = line; sub(/^id:[[:space:]]*/, "", v)
            sub(/[[:space:]]*#.*$/, "", v)
            sub(/^"/, "", v);    sub(/"[[:space:]]*$/, "", v)
            sub(/^\047/, "", v); sub(/\047[[:space:]]*$/, "", v)
            sub(/[[:space:]]+$/, "", v)
            if (v != "") print v
            got = 1
        }
    }' "$@" | sort -u
}

cmd_spawns() {
    file=""; repo="."; spec_dir="specs"
    while [ $# -gt 0 ]; do
        case "$1" in
            --repo) repo="$2"; shift 2 ;;
            --spec-dir) spec_dir="$2"; shift 2 ;;
            --done) shift 2 ;;
            *) [ -z "$file" ] && file="$1"; shift ;;
        esac
    done
    if [ -z "$file" ] || [ ! -f "$file" ]; then
        echo "usage: flow-preflight.sh spawns <spec.md> [--repo DIR] [--spec-dir specs]" >&2
        exit 64
    fi
    recs=$(parse_spawns "$file")
    [ -n "$recs" ] || exit 0

    # Every id that exists in the spec tree, read from each file's `id:` key.
    dir="$repo/$spec_dir"
    known=$(spec_ids "$dir")

    errs=$(printf '%s\n' "$recs" | awk -v US="$US" -v known="$known" '
        BEGIN {
            FS = US; MISS = sprintf("%c", 2)
            n = split(known, K, "\n"); for (i = 1; i <= n; i++) have[K[i]] = 1
            m = 0
        }
        {
            id = $1; aft = $2; idx = $3
            if (id == MISS)  { err[++e] = "  entry " idx ": missing `id`"; next }
            if (aft == MISS) { err[++e] = "  entry " idx " (id: " id "): missing `after` — use `after: []` for none"; next }
            if (!(id in have)) err[++e] = "  entry " idx ": spawned id " id " — no detail file"
            m++; node[m] = id; deps[m] = aft
            k = split(aft, A, " ")
            for (i = 1; i <= k; i++)
                if (A[i] != "" && !(A[i] in have))
                    err[++e] = "  entry " idx " (id: " id "): after id " A[i] " — no detail file; a typo here would become a permanent silent blocker"
        }
        END {
            # Cycle detection by iterative peeling: drop each node whose deps
            # are all outside the remaining set. Survivors are in, or
            # downstream of, a cycle.
            for (i = 1; i <= m; i++) live[node[i]] = i
            do {
                removed = 0
                for (i = 1; i <= m; i++) {
                    if (!(node[i] in live)) continue
                    blocked = 0
                    k = split(deps[i], A, " ")
                    for (j = 1; j <= k; j++) if (A[j] != "" && (A[j] in live)) blocked = 1
                    if (!blocked) { delete live[node[i]]; removed = 1 }
                }
            } while (removed)
            cyc = ""
            for (i = 1; i <= m; i++)
                if (node[i] in live) cyc = cyc (cyc == "" ? "" : ", ") node[i]
            if (cyc != "") err[++e] = "  dependency cycle among: " cyc
            for (i = 1; i <= e; i++) print err[i]
        }
    ')

    if [ -n "$errs" ]; then
        {
            echo "flow-toolkit preflight: malformed \`spawns:\` in $file"
            printf '%s\n' "$errs"
        } >&2
        exit 2
    fi
    exit 0
}

# --- subcommand: blocking --------------------------------------------------
# Reverse lookup: given a MEMBER id, print the after-ids not yet DONE, one per
# line. `after` lives on the ORCHESTRATOR, so a caller holding only a member id
# (the spec-review gate, for one) cannot see its blockers without this.
cmd_blocking() {
    id=""; repo="."; spec_dir="specs"; done_ids=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --repo) repo="$2"; shift 2 ;;
            --spec-dir) spec_dir="$2"; shift 2 ;;
            --done) done_ids="$2"; shift 2 ;;
            *) [ -z "$id" ] && id="$1"; shift ;;
        esac
    done
    if [ -z "$id" ]; then
        echo "usage: flow-preflight.sh blocking <id> [--repo DIR] [--done ids]" >&2
        exit 64
    fi
    dir="$repo/$spec_dir"
    [ -d "$dir" ] || exit 0
    done_list=$(spawn_done_set "$repo" "$done_ids") || exit 2
    MISS=$(printf '\002')
    out=""
    for f in "$dir"/*.md "$dir"/*/*.md "$dir"/archive/*.md "$dir"/archive/*/*.md; do
        [ -f "$f" ] || continue
        grep -q '^spawns:' "$f" 2>/dev/null || continue
        recs=$(parse_spawns "$f")
        while IFS= read -r rec; do
            [ -n "$rec" ] || continue
            sid=$(printf '%s' "$rec" | cut -d"$US" -f1)
            [ "$sid" = "$id" ] || continue
            aft=$(printf '%s' "$rec" | cut -d"$US" -f2)
            [ "$aft" = "$MISS" ] && continue
            for a in $aft; do
                if ! printf '%s\n' "$done_list" | grep -qx "$a"; then
                    out="$out$a
"
                fi
            done
        done <<EOF
$recs
EOF
    done
    if [ -n "$out" ]; then
        printf '%s' "$out" | grep . | sort -u
    fi
    exit 0
}

# --- subcommand: autonomy --------------------------------------------------
# Read a scalar from the FIRST front-matter block only (between the opening ---
# on line 1 and the next ---), stripping quotes and any inline comment.
fm_scalar() { # <file> <key>
    awk -v key="$2" '
    BEGIN { fm = 0 }
    {
        line = $0; sub(/\r$/, "", line)
        if (fm == 0 && NR == 1 && line ~ /^---[[:space:]]*$/) { fm = 1; next }
        if (fm == 1 && line ~ /^---[[:space:]]*$/) { fm = 2; next }
        if (fm != 1) next
        if (line ~ ("^" key ":")) {
            v = line; sub(("^" key ":[[:space:]]*"), "", v)
            sub(/[[:space:]]*#.*$/, "", v)                 # strip inline comment
            sub(/^"/, "", v);    sub(/"[[:space:]]*$/, "", v)
            sub(/^\047/, "", v); sub(/\047[[:space:]]*$/, "", v)   # \047 = single quote
            sub(/[[:space:]]+$/, "", v)
            print v; exit
        }
    }' "$1"
}

# Read a string value for a key from .flow-toolkit.json. The schema only defines
# `force`/`default` under the `autonomy` object, so a naive key match is
# unambiguous — same pragmatic JSON handling as the spec.maxLines reader.
json_str_val() { # <file> <key>
    grep -oE "\"$2\"[[:space:]]*:[[:space:]]*\"[A-Za-z-]+\"" "$1" 2>/dev/null \
        | head -n 1 | sed -E "s/.*:[[:space:]]*\"([A-Za-z-]+)\"/\1/"
}

cmd_autonomy() {
    spec=""; repo="."
    while [ $# -gt 0 ]; do
        case "$1" in
            --repo) repo="$2"; shift 2 ;;
            --*) shift ;;
            *) [ -z "$spec" ] && spec="$1"; shift ;;
        esac
    done
    if [ -z "$spec" ]; then
        echo "usage: flow-preflight.sh autonomy <spec-file> [--repo DIR]" >&2
        exit 64
    fi

    force=""; default=""
    cfg="$repo/.flow-toolkit.json"
    if [ -f "$cfg" ]; then
        force=$(json_str_val "$cfg" force)
        default=$(json_str_val "$cfg" default)
    fi
    fm=""
    [ -f "$spec" ] && fm=$(fm_scalar "$spec" autonomy)

    # Precedence: force > per-spec > default > builtin checkpoint.
    if [ -n "$force" ];   then mode="$force";   src="autonomy.force"
    elif [ -n "$fm" ];    then mode="$fm";       src="per-spec front-matter"
    elif [ -n "$default" ]; then mode="$default"; src="autonomy.default"
    else                       mode="checkpoint"; src="builtin default"
    fi

    case "$mode" in
        checkpoint|auto-build) ;;
        *)
            echo "flow-toolkit preflight: autonomy value \"$mode\" (from $src) is not one of checkpoint|auto-build — using checkpoint." >&2
            mode="checkpoint"
            ;;
    esac
    printf '%s\n' "$mode"
    exit 0
}

# --- subcommand: rubric-basis / rubric-drift (spec 1.16) -------------------
# The persisted project rubric (.flow/validate/{ui,ux}.md) records the source
# files it was derived from ("basis") + a cheap fingerprint each, so a later run
# can detect the design system drifted without re-inferring it. Defined once
# here; consumed by flow-ux-validator, /flow:validate, and /flow:run's done-gate.

# 12-char sha256 fingerprint of a file (portable across Git Bash / macOS / Linux).
rubric_fingerprint() { # <file>
    sha256sum "$1" 2>/dev/null | cut -c1-12
}

# Parse a rubric's front-matter `basis:` list → one <path><US><sha> per entry.
# Same front-matter/list handling as parse_deferrals (keeps empty fields).
parse_basis() {
    awk '
    function unq(v) {
        sub(/\r$/, "", v)
        if (v ~ /^"/)    { sub(/^"/, "", v);     sub(/".*$/, "", v);     return v }
        if (v ~ /^\047/) { sub(/^\047/, "", v);  sub(/\047.*$/, "", v);  return v }
        sub(/[[:space:]]*#.*$/, "", v)
        sub(/[[:space:]]+$/, "", v)
        return v
    }
    function assign(s, idx) {
        if (s ~ /^path:/)     { v = s; sub(/^path:[[:space:]]*/, "", v); path[idx] = unq(v) }
        else if (s ~ /^sha:/) { v = s; sub(/^sha:[[:space:]]*/,  "", v); sha[idx]  = unq(v) }
    }
    BEGIN { fm = 0; inb = 0; n = 0 }
    {
        line = $0; sub(/\r$/, "", line)
        if (fm == 0 && NR == 1 && line ~ /^---[[:space:]]*$/) { fm = 1; next }
        if (fm == 1 && line ~ /^---[[:space:]]*$/) { fm = 2; next }
        if (fm != 1) next
        if (line ~ /^basis:[[:space:]]*$/) { inb = 1; next }
        if (inb == 1 && line ~ /^[^[:space:]-]/) inb = 0
        if (inb != 1) next
        if (line ~ /^[[:space:]]*-[[:space:]]/) {
            n++; path[n] = ""; sha[n] = ""
            rest = line; sub(/^[[:space:]]*-[[:space:]]*/, "", rest)
            if (rest != "") assign(rest, n)
        } else if (n > 0) {
            s = line; sub(/^[[:space:]]+/, "", s)
            assign(s, n)
        }
    }
    END { for (i = 1; i <= n; i++) printf "%s%s%s\n", path[i], US, sha[i] }
    ' US="$US" "$1"
}

# rubric-basis <file>... — emit a YAML `basis:` block (path + fresh sha) for the
# given source files. Used by the caller at save/refresh time so stamping and
# checking share one fingerprint definition. A missing file is a hard error.
cmd_rubric_basis() {
    [ $# -ge 1 ] || { echo "usage: flow-preflight.sh rubric-basis <file>..." >&2; exit 64; }
    missing=""
    for f in "$@"; do [ -f "$f" ] || missing="${missing} $f"; done
    if [ -n "$missing" ]; then
        echo "flow-toolkit preflight: rubric-basis — file(s) not found:$missing" >&2
        exit 2
    fi
    echo "basis:"
    for f in "$@"; do
        printf '  - path: %s\n    sha: %s\n' "$f" "$(rubric_fingerprint "$f")"
    done
    exit 0
}

# rubric-drift <rubric.md> [--repo DIR] — re-hash each recorded basis file and
# compare to the stored sha. Prints one line per basis entry; exit 0 = all in
# sync (or no basis / no rubric — a clean opt-in no-op), 2 = any CHANGED/MISSING.
cmd_rubric_drift() {
    rubric=""; repo="."
    while [ $# -gt 0 ]; do
        case "$1" in
            --repo) repo="$2"; shift 2 ;;
            --*) shift ;;
            *) [ -z "$rubric" ] && rubric="$1"; shift ;;
        esac
    done
    [ -n "$rubric" ] || { echo "usage: flow-preflight.sh rubric-drift <rubric.md> [--repo DIR]" >&2; exit 64; }
    [ -f "$rubric" ] || exit 0     # absent rubric ⇒ opt-in no-op

    records=$(parse_basis "$rubric")
    if [ -z "$records" ]; then
        echo "no basis recorded in $(basename "$rubric") — nothing to drift-check"
        exit 0
    fi

    drift=0
    while IFS="$US" read -r path sha; do
        [ -z "$path" ] && continue
        f="$repo/$path"
        if [ ! -f "$f" ]; then
            echo "⚠️  $path MISSING (recorded in basis, not found)"
            drift=1
        else
            now=$(rubric_fingerprint "$f")
            if [ "$now" = "$sha" ]; then
                echo "✅ $path unchanged"
            else
                echo "❌ $path CHANGED (was ${sha:-?}, now $now)"
                drift=1
            fi
        fi
    done <<EOF
$records
EOF

    [ "$drift" -eq 0 ] || exit 2
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


# --- shared: parse `flow.related_repos` from a config file ------------------
# Emits R<US><repo_name> when `flow.repo_name` is declared, then one
# E<US><name><US><space-separated keys> per sibling entry. Indentation-aware:
# the block is nested under `flow:`, so the list ends at the first non-list
# line indented no deeper than `related_repos:` itself.
parse_related() { # <config file>
    [ -f "$1" ] || return 0
    awk -v US="$US" '
    function ind(s,   i) { i = match(s, /[^ \t]/); return i ? i - 1 : 999 }
    function unq(v) {
        sub(/\r$/, "", v)
        sub(/[[:space:]]*#.*$/, "", v)
        sub(/^"/, "", v);    sub(/"[[:space:]]*$/, "", v)
        sub(/^\047/, "", v); sub(/\047[[:space:]]*$/, "", v)
        sub(/[[:space:]]+$/, "", v)
        return v
    }
    function assignkv(s, idx,   k, v) {
        if (s !~ /^[A-Za-z_][A-Za-z0-9_-]*:/) return
        k = s; sub(/:.*$/, "", k)
        v = s; sub(/^[^:]*:[[:space:]]*/, "", v)
        if (k == "name") nm[idx] = unq(v)
        ks[idx] = ks[idx] (ks[idx] == "" ? "" : " ") k
    }
    BEGIN { inrr = 0; n = 0; rn = "" }
    {
        line = $0; sub(/\r$/, "", line)
        if (line !~ /[^[:space:]]/) next
        i = ind(line)
        if (inrr && i <= rrind && line !~ /^[[:space:]]*-/) inrr = 0
        if (line ~ /^[[:space:]]*related_repos:[[:space:]]*$/) { inrr = 1; rrind = i; next }
        if (!inrr) {
            if (line ~ /^[[:space:]]*repo_name:/) {
                v = line; sub(/^[[:space:]]*repo_name:[[:space:]]*/, "", v); rn = unq(v)
            }
            next
        }
        if (line ~ /^[[:space:]]*-[[:space:]]*/) {
            n++; nm[n] = ""; ks[n] = ""
            rest = line; sub(/^[[:space:]]*-[[:space:]]*/, "", rest)
            if (rest != "") assignkv(rest, n)
        } else if (n > 0) {
            s = line; sub(/^[[:space:]]+/, "", s)
            assignkv(s, n)
        }
    }
    END {
        if (rn != "") print "R" US rn US ""
        for (j = 1; j <= n; j++) print "E" US nm[j] US ks[j]
    }
    ' "$1"
}

# --- subcommand: repos <detail.md> -----------------------------------------
# Validate a spec's declared cross-repo footprint against the project's
# declared siblings (spec 1.25). LOCAL ONLY — it never reads a sibling repo;
# resolving the footprint is 1.29's job. Errors exit 2; advisory findings go to
# stderr and exit 0, so a typo surfaces without blocking the save.
cmd_repos() {
    file=""; repo=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --repo) repo="$2"; shift 2 ;;
            *) [ -z "$file" ] && file="$1"; shift ;;
        esac
    done
    if [ -z "$file" ] || [ ! -f "$file" ]; then
        echo "usage: flow-preflight.sh repos <detail.md> [--repo DIR]" >&2
        exit 64
    fi
    # No key, no opinion — the cheap exit every guard-called check owes.
    grep -q '^repos:' "$file" 2>/dev/null || exit 0

    # Derive the repo root by walking up for .flow/.git rather than assuming a
    # flat spec: `specs/<id>/<id>.md` would otherwise resolve to `specs/`.
    if [ -z "$repo" ]; then
        d=$(cd "$(dirname "$file")" && pwd)
        while [ "$d" != "/" ] && [ -n "$d" ]; do
            if [ -d "$d/.flow" ] || [ -d "$d/.git" ]; then repo="$d"; break; fi
            d=$(dirname "$d")
        done
        [ -n "$repo" ] || repo="."
    fi

    cfg="$repo/.flow/config.yml"
    local_cfg="$repo/.flow/config.local.yml"
    errs=""; warns=""

    declared=$(parse_related "$cfg")
    repo_name=$(printf '%s\n' "$declared" | awk -F"$US" '$1 == "R" { print $2; exit }')
    known=$(printf '%s\n' "$declared" | awk -F"$US" '$1 == "E" && $2 != "" { print $2 }')
    [ -n "$repo_name" ] && known="$repo_name
$known"

    # `local_path` is a per-machine path: it belongs in the gitignored override,
    # never in the file everyone shares.
    bad_lp=$(printf '%s\n' "$declared" | awk -F"$US" -v q="'" '
        $1 == "E" { n = split($3, k, " "); for (i = 1; i <= n; i++) if (k[i] == "local_path") print $2 }')
    for b in $bad_lp; do
        errs="${errs}  sibling ${b}: local_path belongs in .flow/config.local.yml (gitignored), not the committed config
"
    done
    # Anything else under an entry is a typo that would silently do nothing.
    unknown=$(printf '%s\n' "$declared" | awk -F"$US" '
        $1 == "E" {
            n = split($3, k, " ")
            for (i = 1; i <= n; i++)
                if (k[i] != "name" && k[i] != "project" && k[i] != "repo" && k[i] != "clone" && k[i] != "local_path")
                    print $2 ": " k[i]
        }')
    [ -n "$unknown" ] && warns="${warns}$(printf '%s\n' "$unknown" | sed 's/^/  unknown key under sibling /')
"
    # An override that is not ignored will be committed by the next `git add`.
    if [ -f "$local_cfg" ] && ! grep -q 'config\.local\.yml' "$repo/.gitignore" 2>/dev/null; then
        warns="${warns}  .flow/config.local.yml exists but is not in .gitignore — it carries per-machine paths and must not be committed
"
    fi

    names=$(fm_scalar "$file" repos | tr '[],' '   ' | tr -s ' ' | sed 's/^ *//; s/ *$//')
    canon=$(fm_scalar "$file" canonical_repo)
    has_wi=$(awk 'NR==1 && /^---/ {fm=1; next} fm==1 && /^---/ {exit} fm==1 && /^work_item:/ {print "y"; exit}' "$file")
    wi=$(fm_scalar "$file" work_item)

    if [ -n "$names" ] && [ -z "$repo_name" ]; then
        errs="${errs}  flow.repo_name is not declared in .flow/config.yml — a footprint cannot name this repo without it
"
    fi
    for n in $names; do
        printf '%s\n' "$known" | grep -qx "$n" || \
            errs="${errs}  ${n} is neither flow.repo_name nor a declared flow.related_repos entry
"
    done
    # `work_item:` defaults to `id:` (1.24 D7), so absent is fine — blank is not.
    if [ -n "$has_wi" ] && [ -z "$wi" ]; then
        errs="${errs}  work_item is present but empty — omit it to default to id, or give it a value
"
    fi
    # More than this repo means a canonical holder has to be named.
    others=$(printf '%s\n' $names | grep -vx "${repo_name:-__none__}" | grep . | wc -l | tr -d ' ')
    if [ "${others:-0}" -gt 0 ]; then
        if [ -z "$canon" ]; then
            errs="${errs}  canonical_repo is required when repos names a repo beyond this one
"
        elif ! printf '%s\n' $names | grep -qx "$canon"; then
            errs="${errs}  canonical_repo ${canon} is not one of the repos: names
"
        fi
    fi

    if [ -n "$errs" ]; then
        { echo "flow-toolkit preflight: invalid cross-repo declaration in $file"; printf '%s' "$errs"
          [ -n "$warns" ] && printf '%s' "$warns"; } >&2
        exit 2
    fi
    [ -n "$warns" ] && { echo "flow-toolkit preflight: cross-repo declaration notes for $file" >&2; printf '%s' "$warns" >&2; }
    exit 0
}

# --- dispatch --------------------------------------------------------------
sub="${1:-}"
[ $# -gt 0 ] && shift
case "$sub" in
    git-state)     cmd_git_state "$@" ;;
    resolved)      cmd_resolved "$@" ;;
    wellformed)    cmd_wellformed "$@" ;;
    spec-path)     cmd_spec_path "$@" ;;
    spawns)        cmd_spawns "$@" ;;
    repos)         cmd_repos "$@" ;;
    blocking)      cmd_blocking "$@" ;;
    autonomy)      cmd_autonomy "$@" ;;
    rubric-basis)  cmd_rubric_basis "$@" ;;
    rubric-drift)  cmd_rubric_drift "$@" ;;
    *)
        echo "usage: flow-preflight.sh <git-state|resolved|wellformed|spec-path|spawns|blocking|repos|autonomy|rubric-basis|rubric-drift> [args]" >&2
        exit 64 ;;
esac

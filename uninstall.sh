#!/usr/bin/env bash
# uninstall.sh — Purge a *manual* flow-toolkit install so the `flow` plugin can
# stand alone. Removes the toolkit files the old installer force-copied into each
# Claude profile (commands/skills/agents/hooks) and deregisters its hooks from
# settings.json. It does NOT touch the plugin (use `claude plugin uninstall
# flow@flow-toolkit` for that) and never removes non-toolkit files.
#
# Migrating to the plugin? Install it, restart, then run this. See README.
# Run from the repo root: ./uninstall.sh

set -e

# --- Profile detection (kept identical to install.sh — lockstep) ---
PROFILES=()
add_profile() {
    local d="$1"
    [ -d "$d" ] || return 0
    d=$(cd "$d" 2>/dev/null && pwd) || return 0
    local p
    for p in "${PROFILES[@]}"; do [ "$p" = "$d" ] && return 0; done
    if [ "$(basename "$d")" = ".claude" ] || [ -f "$d/settings.json" ] || [ -d "$d/commands" ] || [ -d "$d/projects" ]; then
        PROFILES+=("$d")
    fi
    return 0
}
[ -n "$CLAUDE_CONFIG_DIR" ] && add_profile "$CLAUDE_CONFIG_DIR"
for d in "$HOME"/.claude "$HOME"/.claude-*; do
    add_profile "$d"
done
if [ "${#PROFILES[@]}" -eq 0 ]; then
    echo "No Claude config directories found under $HOME."
    exit 1
fi
echo "Detected Claude profile(s): $(for p in "${PROFILES[@]}"; do basename "$p"; done | paste -sd, -)"
echo ""

# The exact toolkit artifacts a manual install created (old bare + renamed set).
# Exact-name only — never a glob that could catch a user's own commands/skills.
STALE_COMMANDS="flow.md flow-hunt.md flow-init.md flow-lint.md flow-ship.md flow-pr.md flow-review.md init.md lint.md ship.md"
STALE_SKILLS="flow flow-hunt flow-review flow-pr run hunt review pr"
STALE_AGENTS="flow-implementer.md flow-verifier.md flow-researcher.md flow-reviewer.md flow-pr-reviewer.md"

deregister_hooks() {
    local settings="$1"
    [ -f "$settings" ] || return 0
    command -v python3 >/dev/null 2>&1 || { echo "  python3 not found — remove flow-*.sh hook entries from $settings by hand"; return 0; }
    python3 - "$settings" <<'PY'
import json, os, re, shutil, sys
p = sys.argv[1]
try:
    data = json.loads(open(p).read() or "{}")
except Exception:
    print("  (could not parse settings.json — skipped)"); sys.exit(0)
hooks = data.get("hooks", {})
removed = []
for event in list(hooks.keys()):
    kept_entries = []
    for entry in hooks.get(event, []):
        kept = []
        for h in entry.get("hooks", []):
            m = re.search(r"flow-[a-z-]+\.sh", h.get("command",""))
            if m:
                removed.append(m.group(0))
            else:
                kept.append(h)
        if kept:
            e = dict(entry); e["hooks"] = kept; kept_entries.append(e)
    if kept_entries:
        hooks[event] = kept_entries
    else:
        del hooks[event]
if removed:
    shutil.copy(p, p + ".bak")
    open(p, "w").write(json.dumps(data, indent=2) + "\n")
    print("  deregistered hooks: %s (backup: settings.json.bak)" % ", ".join(sorted(set(removed))))
else:
    print("  no flow hooks in settings.json")
PY
}

for profile in "${PROFILES[@]}"; do
    name=$(basename "$profile")
    echo "-- $name --"
    for f in $STALE_COMMANDS; do rm -f "$profile/commands/$f"; done
    for s in $STALE_SKILLS; do rm -rf "$profile/skills/$s"; done
    for a in $STALE_AGENTS; do rm -f "$profile/agents/$a"; done
    rm -f "$profile"/hooks/flow-*.sh
    echo "  removed manual-install commands/skills/agents/hook scripts (toolkit-only)"
    deregister_hooks "$profile/settings.json"
done

echo ""
echo "Done. The manual install is purged. If the flow plugin is installed and enabled,"
echo "it is now the sole source. Restart Claude Code. (A leftover commands/CLAUDE.md, if"
echo "any, is left untouched — delete it by hand only if it was the toolkit's.)"

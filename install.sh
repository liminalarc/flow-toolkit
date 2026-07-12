#!/usr/bin/env bash
# install.sh — Install flow-toolkit commands and hooks into Claude Code's global config
# Run from the repo root: ./install.sh

set -e

# Discover Claude profile directories instead of hardcoding account names.
# A machine set up with multiple Claude accounts keeps each account's config in
# its own dir — the canonical ~/.claude plus siblings like ~/.claude-work, and/or
# whatever $CLAUDE_CONFIG_DIR points at. We install into every one that exists and
# looks like a real Claude config dir, so adding/removing an account needs no edit here.
PROFILES=()
add_profile() {
    local d="$1"
    [ -d "$d" ] || return
    # Canonicalize so the same dir reached two ways (e.g. $CLAUDE_CONFIG_DIR as a
    # Windows path vs. the glob's Unix path under Git Bash) compares and serializes
    # as one form — this also keeps backslashes out of the JSON we later emit.
    d=$(cd "$d" 2>/dev/null && pwd) || return
    local p
    for p in "${PROFILES[@]}"; do [ "$p" = "$d" ] && return; done
    # keep the canonical ~/.claude, or any dir that looks like a Claude config dir
    if [ "$(basename "$d")" = ".claude" ] || [ -f "$d/settings.json" ] || [ -d "$d/commands" ] || [ -d "$d/projects" ]; then
        PROFILES+=("$d")
    fi
}

[ -n "$CLAUDE_CONFIG_DIR" ] && add_profile "$CLAUDE_CONFIG_DIR"
for d in "$HOME"/.claude "$HOME"/.claude-*; do
    add_profile "$d"
done

if [ "${#PROFILES[@]}" -eq 0 ]; then
    echo "No Claude config directories found under $HOME (looked for .claude and .claude-*)."
    exit 1
fi
echo "Detected Claude profile(s): $(for p in "${PROFILES[@]}"; do basename "$p"; done | paste -sd, -)"
echo ""

count=$(ls commands/*.md 2>/dev/null | wc -l)
hook_count=$(ls hooks/*.sh 2>/dev/null | wc -l)

register_hooks() {
    # Additive merge of hooks/hooks.json into settings.json. Per-script
    # idempotency: a script already mentioned anywhere in settings.json is
    # never added again.
    local settings="$1"
    local hooks_dir="$2"

    if ! command -v python3 >/dev/null 2>&1; then
        echo "python3 not found — register the hooks manually by merging hooks/hooks.json"
        echo "into $settings, replacing __HOOKS_DIR__ with $hooks_dir"
        return
    fi

    python3 - "$settings" "hooks/hooks.json" "$hooks_dir" <<'PY'
import json, os, re, shutil, sys

settings_path, frag_path, hooks_dir = sys.argv[1], sys.argv[2], sys.argv[3]

raw = "{}"
if os.path.exists(settings_path):
    with open(settings_path) as f:
        raw = f.read()
data = json.loads(raw) if raw.strip() else {}

with open(frag_path) as f:
    frag = json.loads(f.read().replace("__HOOKS_DIR__", hooks_dir))

added = []
hooks = data.setdefault("hooks", {})
for event, entries in frag["hooks"].items():
    for entry in entries:
        new_cmds = []
        for h in entry["hooks"]:
            m = re.search(r"flow-[a-z-]+\.sh", h["command"])
            name = m.group(0) if m else h["command"]
            if name not in raw:
                new_cmds.append(h)
                added.append(name)
        if new_cmds:
            e = dict(entry)
            e["hooks"] = new_cmds
            hooks.setdefault(event, []).append(e)

if added:
    if os.path.exists(settings_path):
        shutil.copy(settings_path, settings_path + ".bak")
    with open(settings_path, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    print("Registered hooks in %s: %s (backup: settings.json.bak)" % (settings_path, ", ".join(added)))
else:
    print("All toolkit hooks already registered in %s" % settings_path)
PY
}

for profile in "${PROFILES[@]}"; do
    profile_name=$(basename "$profile")
    if [ ! -d "$profile" ]; then
        echo "Skipping $profile_name (profile directory does not exist)"
        continue
    fi

    # --- Commands ---
    target="$profile/commands"
    mkdir -p "$target"
    for file in commands/*.md; do
        cp "$file" "$target/"
    done
    echo "Installed $count commands to $target"

    # --- Hooks ---
    if [ "$hook_count" -gt 0 ]; then
        hooks_dir="$profile/hooks"
        mkdir -p "$hooks_dir"
        for script in hooks/*.sh; do
            cp "$script" "$hooks_dir/"
            chmod +x "$hooks_dir/$(basename "$script")"
        done
        echo "Installed $hook_count hook script(s) to $hooks_dir"
        register_hooks "$profile/settings.json" "$hooks_dir"
    fi
done

echo ""
echo "Done. Restart Claude Code (or start a new session) for changes to take effect."

#!/usr/bin/env bash
# install.sh — Install flow-toolkit commands and hooks into Claude Code's global config
# Run from the repo root: ./install.sh

set -e

PROFILES=(
    "$HOME/.claude"
    "$HOME/.claude-company"
)

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

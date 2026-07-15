#!/usr/bin/env bash
# install.sh — LEGACY FALLBACK installer for flow-toolkit.
#
# The PRIMARY distribution is now the `flow` Claude Code plugin (namespaced /flow:*):
#   /plugin marketplace add liminalarc/flow-toolkit
#   /plugin install flow@flow-toolkit
#
# Use this installer only where the plugin isn't an option. It force-copies the
# commands/skills/agents as BARE names (e.g. /run, /hunt — not /flow:run) and
# registers the hooks in each profile's settings.json. It also prunes pre-plugin
# stale files so a reinstall doesn't leave old bare commands lying around.
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
    # Every skip path returns 0: this runs under `set -e`, and add_profile is
    # called both bare in a loop and after `&&`. A bare `return` would propagate
    # the last test's non-zero (e.g. an unmatched `~/.claude-*` glob, or a
    # $CLAUDE_CONFIG_DIR that fails the checks) and abort the whole installer
    # before it installs anything — which breaks single-profile installs.
    [ -d "$d" ] || return 0
    # Canonicalize so the same dir reached two ways (e.g. $CLAUDE_CONFIG_DIR as a
    # Windows path vs. the glob's Unix path under Git Bash) compares and serializes
    # as one form — this also keeps backslashes out of the JSON we later emit.
    d=$(cd "$d" 2>/dev/null && pwd) || return 0
    local p
    for p in "${PROFILES[@]}"; do [ "$p" = "$d" ] && return 0; done
    # keep the canonical ~/.claude, or any dir that looks like a Claude config dir
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
    echo "No Claude config directories found under $HOME (looked for .claude and .claude-*)."
    exit 1
fi
echo "Detected Claude profile(s): $(for p in "${PROFILES[@]}"; do basename "$p"; done | paste -sd, -)"
echo ""

count=$(ls commands/*.md 2>/dev/null | wc -l)
hook_count=$(ls hooks/*.sh 2>/dev/null | wc -l)
agent_count=$(ls agents/*.md 2>/dev/null | wc -l)
skill_count=$(ls -d skills/*/ 2>/dev/null | wc -l)

register_hooks() {
    # Additive merge of hooks/hooks.json into settings.json. Per-script
    # idempotency: a script already mentioned anywhere in settings.json is
    # never added again.
    local settings="$1"
    local hooks_dir="$2"

    if ! command -v python3 >/dev/null 2>&1; then
        echo "python3 not found — register the hooks manually by merging hooks/hooks.json"
        echo "into $settings, replacing \${CLAUDE_PLUGIN_ROOT}/hooks with $hooks_dir"
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
    frag = json.loads(f.read().replace("${CLAUDE_PLUGIN_ROOT}/hooks", hooks_dir))

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

    # --- Prune stale pre-plugin artifacts ---
    # The toolkit now ships as the `flow` plugin. Remove files it distributed under
    # OLD names (pre-1.10 bare commands + renamed-away skills) so a fallback reinstall
    # doesn't leave stale bare entry points beside the current set. Exact-name only —
    # never touches non-toolkit commands/skills in the profile. (Resolves spec 1.11's
    # deferred stale-command prune.)
    for stale in flow.md flow-hunt.md flow-review.md flow-pr.md flow-init.md flow-lint.md flow-ship.md; do
        rm -f "$profile/commands/$stale"
    done
    for stale in flow flow-hunt flow-review flow-pr; do
        rm -rf "$profile/skills/$stale"
    done

    # --- Commands ---
    target="$profile/commands"
    mkdir -p "$target"
    for file in commands/*.md; do
        cp "$file" "$target/"
    done
    echo "Installed $count commands to $target"

    # --- Agents ---
    # Sub-agent definitions (implementer/verifier and later reviewers etc.).
    # Passive until dispatched, so a global install costs nothing in projects
    # that never invoke them. 1.10 moves this to the plugin; the installer is
    # the distribution mechanism until then.
    if [ "$agent_count" -gt 0 ]; then
        agents_dir="$profile/agents"
        mkdir -p "$agents_dir"
        for file in agents/*.md; do
            cp "$file" "$agents_dir/"
        done
        echo "Installed $agent_count agent(s) to $agents_dir"
    fi

    # --- Skills ---
    # A skill is a directory (SKILL.md + reference/*), copied whole. Force-clean
    # the target skill dir first so a removed/renamed reference file doesn't linger.
    # Same rationale as agents: inert until invoked; 1.10 folds these into the plugin.
    if [ "$skill_count" -gt 0 ]; then
        skills_dir="$profile/skills"
        mkdir -p "$skills_dir"
        for dir in skills/*/; do
            name=$(basename "$dir")
            rm -rf "$skills_dir/$name"
            cp -R "${dir%/}" "$skills_dir/"
        done
        echo "Installed $skill_count skill(s) to $skills_dir"
    fi

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

# install.ps1 — Install flow-toolkit commands and hooks into Claude Code's global config
# Run from the repo root: .\install.ps1

# Discover Claude profile directories instead of hardcoding account names.
# A machine set up with multiple Claude accounts keeps each account's config in
# its own dir — the canonical ~/.claude plus siblings like ~/.claude-work, and/or
# whatever $CLAUDE_CONFIG_DIR points at. We install into every one that exists and
# looks like a real Claude config dir, so adding/removing an account needs no edit here.
function Test-ClaudeProfile($dir) {
    if (-not (Test-Path $dir)) { return $false }
    if ((Split-Path $dir -Leaf) -eq ".claude") { return $true }   # canonical, even if bare
    (Test-Path (Join-Path $dir "settings.json")) -or
    (Test-Path (Join-Path $dir "commands")) -or
    (Test-Path (Join-Path $dir "projects"))
}

$candidates = New-Object System.Collections.Generic.List[string]
if ($env:CLAUDE_CONFIG_DIR) { $candidates.Add($env:CLAUDE_CONFIG_DIR) }
Get-ChildItem -Path $env:USERPROFILE -Directory -Filter ".claude*" -Force -ErrorAction SilentlyContinue |
    ForEach-Object { $candidates.Add($_.FullName) }

$profiles = @($candidates | Sort-Object -Unique | Where-Object { Test-ClaudeProfile $_ })

if ($profiles.Count -eq 0) {
    Write-Host "No Claude config directories found under $env:USERPROFILE (looked for .claude and .claude-*)."
    exit 1
}
Write-Host "Detected Claude profile(s): $(( $profiles | ForEach-Object { Split-Path $_ -Leaf }) -join ', ')"
Write-Host ""

$commands = Get-ChildItem -Path ".\commands\*.md"
$hookScripts = Get-ChildItem -Path ".\hooks\*.sh" -ErrorAction SilentlyContinue
$agentFiles = Get-ChildItem -Path ".\agents\*.md" -ErrorAction SilentlyContinue

foreach ($profileDir in $profiles) {
    $profileName = Split-Path $profileDir -Leaf
    if (-not (Test-Path $profileDir)) {
        Write-Host "Skipping $profileName (profile directory does not exist)"
        continue
    }

    # --- Commands ---
    $target = Join-Path $profileDir "commands"
    if (-not (Test-Path $target)) {
        New-Item -ItemType Directory -Path $target -Force | Out-Null
    }
    foreach ($file in $commands) {
        Copy-Item -Path $file.FullName -Destination $target -Force
    }
    Write-Host "Installed $($commands.Count) commands to $target"

    # --- Agents ---
    # Sub-agent definitions (implementer/verifier and later reviewers etc.).
    # Passive until dispatched, so a global install costs nothing in projects
    # that never invoke them. 1.10 moves this to the plugin; the installer is
    # the distribution mechanism until then. (Placed before the hooks block's
    # early `continue` so agents install even when there are no hook scripts.)
    if ($agentFiles) {
        $agentsDir = Join-Path $profileDir "agents"
        if (-not (Test-Path $agentsDir)) {
            New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null
        }
        foreach ($file in $agentFiles) {
            Copy-Item -Path $file.FullName -Destination $agentsDir -Force
        }
        Write-Host "Installed $($agentFiles.Count) agent(s) to $agentsDir"
    }

    # --- Hook scripts ---
    if (-not $hookScripts) { continue }
    $hooksDir = Join-Path $profileDir "hooks"
    if (-not (Test-Path $hooksDir)) {
        New-Item -ItemType Directory -Path $hooksDir -Force | Out-Null
    }
    foreach ($script in $hookScripts) {
        Copy-Item -Path $script.FullName -Destination $hooksDir -Force
    }
    Write-Host "Installed $($hookScripts.Count) hook script(s) to $hooksDir"

    # --- Hook registration: additive merge of hooks/hooks.json into settings.json ---
    # Per-script idempotency: a script already mentioned anywhere in settings.json
    # (any path, any registration style) is never added again.
    $settingsPath = Join-Path $profileDir "settings.json"
    $hooksDirFwd = $hooksDir -replace '\\', '/'
    $fragRaw = (Get-Content ".\hooks\hooks.json" -Raw).Replace('__HOOKS_DIR__', $hooksDirFwd)
    $frag = $fragRaw | ConvertFrom-Json

    $raw = if (Test-Path $settingsPath) { Get-Content $settingsPath -Raw } else { "{}" }
    $settings = $raw | ConvertFrom-Json
    if ($null -eq $settings) { $settings = New-Object PSObject }
    if (-not $settings.PSObject.Properties['hooks']) {
        $settings | Add-Member -MemberType NoteProperty -Name hooks -Value (New-Object PSObject)
    }

    $added = @()
    foreach ($evt in $frag.hooks.PSObject.Properties) {
        foreach ($entry in $evt.Value) {
            $newHooks = @($entry.hooks | Where-Object {
                $name = [regex]::Match($_.command, 'flow-[a-z-]+\.sh').Value
                $name -and ($raw -notmatch [regex]::Escape($name))
            })
            if ($newHooks.Count -eq 0) { continue }
            if (-not $settings.hooks.PSObject.Properties[$evt.Name]) {
                $settings.hooks | Add-Member -MemberType NoteProperty -Name $evt.Name -Value @()
            }
            $newEntry = $entry | Select-Object *
            $newEntry.hooks = $newHooks
            $settings.hooks.($evt.Name) = @($settings.hooks.($evt.Name)) + $newEntry
            $added += ($newHooks | ForEach-Object { [regex]::Match($_.command, 'flow-[a-z-]+\.sh').Value })
        }
    }

    if ($added.Count -gt 0) {
        if (Test-Path $settingsPath) {
            Copy-Item $settingsPath "$settingsPath.bak" -Force
        }
        $settings | ConvertTo-Json -Depth 16 | Set-Content $settingsPath -Encoding UTF8
        Write-Host "Registered hooks in ${settingsPath}: $($added -join ', ') (backup: settings.json.bak)"
    }
    else {
        Write-Host "All toolkit hooks already registered in $settingsPath"
    }
}

Write-Host ""
Write-Host "Done. Restart Claude Code (or start a new session) for changes to take effect."

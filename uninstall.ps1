# uninstall.ps1 — Purge a *manual* flow-toolkit install so the `flow` plugin can
# stand alone. Removes the toolkit files the old installer force-copied into each
# Claude profile (commands/skills/agents/hooks) and deregisters its hooks from
# settings.json. It does NOT touch the plugin (use `claude plugin uninstall
# flow@flow-toolkit` for that) and never removes non-toolkit files.
#
# Migrating to the plugin? Install it, restart, then run this. See README.
# Run from the repo root: .\uninstall.ps1

# --- Profile detection (kept identical to install.ps1 — lockstep) ---
function Test-ClaudeProfile($dir) {
    if (-not (Test-Path $dir)) { return $false }
    if ((Split-Path $dir -Leaf) -eq ".claude") { return $true }
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
    Write-Host "No Claude config directories found under $env:USERPROFILE."
    exit 1
}
Write-Host "Detected Claude profile(s): $(( $profiles | ForEach-Object { Split-Path $_ -Leaf }) -join ', ')"
Write-Host ""

# Exact toolkit artifacts a manual install created — exact-name only.
$staleCommands = @('flow.md','flow-hunt.md','flow-init.md','flow-lint.md','flow-ship.md','flow-pr.md','flow-review.md','init.md','lint.md','ship.md')
$staleSkills   = @('flow','flow-hunt','flow-review','flow-pr','run','hunt','review','pr')
$staleAgents   = @('flow-implementer.md','flow-verifier.md','flow-researcher.md','flow-reviewer.md','flow-pr-reviewer.md')

foreach ($profileDir in $profiles) {
    $name = Split-Path $profileDir -Leaf
    Write-Host "-- $name --"
    foreach ($f in $staleCommands) { $p = Join-Path $profileDir "commands/$f"; if (Test-Path $p) { Remove-Item -Force $p } }
    foreach ($s in $staleSkills)   { $p = Join-Path $profileDir "skills/$s";   if (Test-Path $p) { Remove-Item -Recurse -Force $p } }
    foreach ($a in $staleAgents)   { $p = Join-Path $profileDir "agents/$a";   if (Test-Path $p) { Remove-Item -Force $p } }
    Get-ChildItem -Path (Join-Path $profileDir "hooks") -Filter "flow-*.sh" -ErrorAction SilentlyContinue | Remove-Item -Force
    Write-Host "  removed manual-install commands/skills/agents/hook scripts (toolkit-only)"

    # Deregister flow hooks from settings.json (backup first; preserve everything else)
    $settingsPath = Join-Path $profileDir "settings.json"
    if (Test-Path $settingsPath) {
        $raw = Get-Content $settingsPath -Raw
        $settings = $raw | ConvertFrom-Json
        $removed = @()
        if ($settings.PSObject.Properties['hooks']) {
            foreach ($evt in @($settings.hooks.PSObject.Properties)) {
                $newEntries = @()
                foreach ($entry in @($evt.Value)) {
                    $kept = @($entry.hooks | Where-Object { [regex]::Match($_.command, 'flow-[a-z-]+\.sh').Value -eq '' })
                    $dropped = @($entry.hooks | Where-Object { [regex]::Match($_.command, 'flow-[a-z-]+\.sh').Value -ne '' })
                    foreach ($d in $dropped) { $removed += [regex]::Match($d.command, 'flow-[a-z-]+\.sh').Value }
                    if ($kept.Count -gt 0) { $e = $entry | Select-Object *; $e.hooks = $kept; $newEntries += $e }
                }
                if ($newEntries.Count -gt 0) { $settings.hooks.($evt.Name) = $newEntries }
                else { $settings.hooks.PSObject.Properties.Remove($evt.Name) }
            }
        }
        if ($removed.Count -gt 0) {
            Copy-Item $settingsPath "$settingsPath.bak" -Force
            $settings | ConvertTo-Json -Depth 16 | Set-Content $settingsPath -Encoding UTF8
            Write-Host "  deregistered hooks: $(($removed | Sort-Object -Unique) -join ', ') (backup: settings.json.bak)"
        } else {
            Write-Host "  no flow hooks in settings.json"
        }
    }
}

Write-Host ""
Write-Host "Done. The manual install is purged. If the flow plugin is installed and enabled,"
Write-Host "it is now the sole source. Restart Claude Code. (A leftover commands/CLAUDE.md, if"
Write-Host "any, is left untouched — delete it by hand only if it was the toolkit's.)"

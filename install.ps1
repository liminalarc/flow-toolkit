# install.ps1 — Install flow-toolkit commands into Claude Code's global commands directory
# Run from the repo root: .\install.ps1

$targets = @(
    "$env:USERPROFILE\.claude\commands",
    "$env:USERPROFILE\.claude-company\commands"
)

$commands = Get-ChildItem -Path ".\commands\*.md"

foreach ($target in $targets) {
    $profileName = Split-Path (Split-Path $target -Parent) -Leaf
    if (-not (Test-Path (Split-Path $target -Parent))) {
        Write-Host "Skipping $profileName (profile directory does not exist)"
        continue
    }
    if (-not (Test-Path $target)) {
        New-Item -ItemType Directory -Path $target -Force | Out-Null
    }
    foreach ($file in $commands) {
        Copy-Item -Path $file.FullName -Destination $target -Force
    }
    Write-Host "Installed $($commands.Count) commands to $target"
}

Write-Host ""
Write-Host "Done. Restart Claude Code (or start a new session) for changes to take effect."

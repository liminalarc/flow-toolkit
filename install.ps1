# install.ps1 — Install flow-toolkit commands into Claude Code's global commands directory
# Run from the repo root: .\install.ps1

$target = "$env:USERPROFILE\.claude\commands"

if (-not (Test-Path $target)) {
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    Write-Host "Created $target"
}

$commands = Get-ChildItem -Path ".\commands\*.md"
foreach ($file in $commands) {
    Copy-Item -Path $file.FullName -Destination $target -Force
    Write-Host "Installed $($file.Name)"
}

Write-Host ""
Write-Host "Done. $($commands.Count) commands installed to $target"
Write-Host "Restart Claude Code (or start a new session) for changes to take effect."

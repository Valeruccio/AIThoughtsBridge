# Install / refresh DeepSeekThoughts into Zomboid mods folder
$ErrorActionPreference = "Stop"
$RepoMod = Join-Path (Split-Path $PSScriptRoot -Parent) "DeepSeekThoughts"
$Dest = Join-Path $env:USERPROFILE "Zomboid\mods\DeepSeekThoughts"

if (-not (Test-Path $RepoMod)) {
    Write-Error "Mod source not found: $RepoMod"
}

New-Item -ItemType Directory -Force -Path (Split-Path $Dest -Parent) | Out-Null
if (Test-Path $Dest) {
    Remove-Item -Recurse -Force $Dest
}
Copy-Item -Recurse -Force $RepoMod $Dest

# IO folders for the Python bridge
$Io = Join-Path $env:USERPROFILE "Zomboid\Lua\DeepSeekThoughts"
New-Item -ItemType Directory -Force -Path @(
    (Join-Path $Io "outbox"),
    (Join-Path $Io "inbox")
) | Out-Null

Write-Host "Installed mod to: $Dest"
Write-Host "Bridge IO path:   $Io"
Write-Host ""
Write-Host "Next:"
Write-Host "  1. Start Bridge Launcher:  .\scripts\Start_DST_Bridge.bat"
Write-Host "  2. Pick provider (DeepSeek / Ollama / …) → Save → Test → Start Bridge"
Write-Host "  3. Enable mod 'AI Thoughts' in the game (Build 42)"

# Mirror repo mod folder → Zomboid/mods (exact copy).
# Source of truth: git working tree DeepSeekThoughts/
# After git pull / clone, run this on EVERY machine (host + clients).
$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path $PSScriptRoot -Parent
$RepoMod = Join-Path $RepoRoot "DeepSeekThoughts"
$Dest = Join-Path $env:USERPROFILE "Zomboid\mods\DeepSeekThoughts"

if (-not (Test-Path $RepoMod)) {
    Write-Error "Mod source not found: $RepoMod"
}

New-Item -ItemType Directory -Force -Path (Split-Path $Dest -Parent) | Out-Null
if (Test-Path $Dest) {
    Remove-Item -Recurse -Force $Dest
}
Copy-Item -Recurse -Force $RepoMod $Dest

# IO folders for the Python bridge (host only; harmless on clients)
$Io = Join-Path $env:USERPROFILE "Zomboid\Lua\DeepSeekThoughts"
New-Item -ItemType Directory -Force -Path @(
    (Join-Path $Io "outbox"),
    (Join-Path $Io "inbox")
) | Out-Null

# Fingerprint one shared file so host/client can compare
$Probe = Join-Path $Dest "42\media\lua\shared\DST_06_PromptHooks.lua"
if (Test-Path $Probe) {
    $hash = (Get-FileHash $Probe -Algorithm SHA256).Hash.Substring(0, 12)
    Write-Host "Mirror OK. DST_06_PromptHooks.lua sha256[:12]=$hash"
}

Write-Host "Installed mod to: $Dest"
Write-Host "Bridge IO path:   $Io"
Write-Host ""
Write-Host "MP: host and clients must run this after the SAME git commit."
Write-Host "Next:"
Write-Host "  1. Start Bridge Launcher (host):  .\scripts\Start_DST_Bridge.bat"
Write-Host "  2. Enable mod 'AI Thoughts' in the game (Build 42)"

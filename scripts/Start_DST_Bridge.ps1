# Start AI Thoughts Bridge Launcher (GUI)
$ErrorActionPreference = "Stop"
$Repo = Split-Path $PSScriptRoot -Parent
$Py = Join-Path $Repo ".venv\Scripts\python.exe"
$Launcher = Join-Path $Repo "bridge\launcher.py"

if (-not (Test-Path $Py)) {
    Write-Error "Missing venv python: $Py — run: python -m venv .venv && .\.venv\Scripts\python.exe -m pip install -r .\bridge\requirements.txt"
}

Set-Location $Repo
& $Py $Launcher

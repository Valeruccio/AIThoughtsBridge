@echo off
setlocal
cd /d "%~dp0\.."
if not exist ".venv\Scripts\python.exe" (
  echo ERROR: .venv not found. Create it first:
  echo   python -m venv .venv
  echo   .venv\Scripts\python.exe -m pip install -r bridge\requirements.txt
  pause
  exit /b 1
)
start "DST Bridge Launcher" ".venv\Scripts\python.exe" "bridge\launcher.py"
endlocal

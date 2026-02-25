@echo off
cd /d "%~dp0"
start "Scoop Daily" powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scoop-daily.ps1"
start "pnpm Daily" powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\pnpm-daily.ps1"

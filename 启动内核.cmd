@echo off
chcp 65001 >nul
rem Fallback entry: start the core only (no GUI).
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start.ps1"
pause

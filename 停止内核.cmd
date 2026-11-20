@echo off
chcp 65001 >nul
rem Fallback entry: stop the core.
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0stop.ps1"
pause

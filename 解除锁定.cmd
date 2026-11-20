@echo off
chcp 65001 >nul
rem Run this ONCE before first use: unlock files blocked by Windows (Mark of the Web).
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -LiteralPath '%~dp0' -Recurse -File | Unblock-File; Write-Host 'Unblocked. You can start the console now.'"
echo.
pause

@echo off
chcp 65001 >nul
rem Launch the proxy control console (WPF GUI, no black window).
cd /d "%~dp0"
start "" wscript.exe "%~dp0console-hidden.vbs"

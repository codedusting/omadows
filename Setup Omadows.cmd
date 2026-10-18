@echo off
rem Double-click to run omadows-setup.ps1 (kept next to this file). It asks for admin once.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0omadows-setup.ps1" %*
echo.
pause

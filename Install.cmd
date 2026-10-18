@echo off
setlocal
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0scripts\Setup.ps1" -Action Install
set "setupExit=%errorlevel%"
if not "%setupExit%"=="0" pause
exit /b %setupExit%

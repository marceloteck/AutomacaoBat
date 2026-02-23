@echo off
setlocal

REM ==========================================
REM GERADOR DE EVENTOS - START
REM ==========================================

set "DIR=%~dp0"
set "PS1=%DIR%GERADOR_DE_EVENTOS.ps1"

echo ==========================================
echo  GERADOR DE EVENTOS (Excel + Recorder)
echo ==========================================
echo.

if not exist "%PS1%" (
  echo [ERRO] Nao achei: "%PS1%"
  pause
  exit /b 2
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
pause
exit /b 0
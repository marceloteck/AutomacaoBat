@echo off
setlocal

REM ==========================================
REM RUN_CONFIG.bat
REM Executa o motor por config.txt (sem instalar nada)
REM Coloque este BAT na mesma pasta do EXEC_CONFIG.ps1
REM ==========================================

set "SCRIPT_DIR=%~dp0"
set "PS1=%SCRIPT_DIR%EXEC_CONFIG.ps1"
set "CFG=%SCRIPT_DIR%config.txt"

echo ==========================================
echo  AUTOMACAO - CONFIG (linha a linha)
echo ==========================================
echo PS1:  "%PS1%"
echo CFG:  "%CFG%"
echo.

if not exist "%PS1%" (
  echo [ERRO] Nao achei: "%PS1%"
  pause
  exit /b 2
)

if not exist "%CFG%" (
  echo [ERRO] Nao achei: "%CFG%"
  echo Crie o arquivo config.txt (modelo esta junto).
  pause
  exit /b 2
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -ConfigFile "%CFG%"
set "EC=%ERRORLEVEL%"

echo.
echo ==========================================
echo FINALIZADO (ExitCode=%EC%)
echo ==========================================
pause
exit /b %EC%

@echo off
chcp 65001 >nul
title CENTRAL - SISTEMA UNIFICADO
setlocal

set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "ROOT=%%~fI"
set "PS_SCRIPT=%ROOT%\AUTOMACAO_SISTEMA.ps1"

if not exist "%PS_SCRIPT%" (
  echo.
  echo [ERRO] Script principal nao encontrado:
  echo %PS_SCRIPT%
  pause
  exit /b 1
)

echo ==========================================
echo  CENTRAL - SISTEMA UNIFICADO DE AUTOMACAO
echo ==========================================
echo.
echo Iniciando menu PowerShell...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%"
set "EC=%ERRORLEVEL%"

echo.
if not "%EC%"=="0" (
  echo [ERRO] O sistema finalizou com codigo %EC%.
) else (
  echo [OK] Sistema finalizado.
)

echo.
pause
exit /b %EC%

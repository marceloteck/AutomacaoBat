@echo off
setlocal EnableExtensions

REM ==========================================
REM GERADOR DE EVENTOS - START
REM ==========================================

set "DIR=%~dp0"
set "PS1=%DIR%GERADOR_DE_EVENTOS.ps1"
set "BK=%DIR%backup_ps1"


echo ==========================================
echo  GERADOR DE EVENTOS (Excel + Recorder)
echo ==========================================
echo.

if not exist "%BK%" mkdir "%BK%" >nul 2>nul

if exist "%PS1%" (
  copy /y "%PS1%" "%BK%\GERADOR_DE_EVENTOS_%DATE:~6,4%-%DATE:~3,2%-%DATE:~0,2%_%TIME:~0,2%-%TIME:~3,2%-%TIME:~6,2%.ps1" >nul
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
pause
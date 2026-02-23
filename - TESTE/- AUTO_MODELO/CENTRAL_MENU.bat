@echo off
chcp 65001 >nul
setlocal EnableExtensions EnableDelayedExpansion
title CENTRAL - MENU AUTOMACOES

rem Pasta onde este .bat está
set "BASE=%~dp0"
if "%BASE:~-1%"=="\" set "BASE=%BASE:~0,-1%"

:MENU
cls
echo ==========================================
echo        CENTRAL - MENU AUTOMACOES
echo ==========================================
echo.
echo  1) RECEBIMENTO DE ENTRADA
echo  2) SALVAR PEDIDOS
echo  3) IMPRIMIR ACERTOS
echo.
echo  D) Abrir pasta Downloads\DESKTOP
echo  O) Abrir pasta deste projeto
echo  0) Sair
echo.
set /p "OP=Escolha uma opcao: "

if /i "%OP%"=="0" exit /b 0
if /i "%OP%"=="D" goto OPEN_DESKTOP
if /i "%OP%"=="O" goto OPEN_PROJETO

if "%OP%"=="1" call :RUN_BAT "%BASE%\RUN_RECEBIMENTO.bat"
if "%OP%"=="2" call :RUN_BAT "%BASE%\RUN_SALVAR_PEDIDOS.bat"
if "%OP%"=="3" call :RUN_BAT "%BASE%\RUN_IMPRESSAO_ACERTOS.bat"

echo.
echo Opcao invalida.
timeout /t 2 >nul
goto MENU


:RUN_BAT
set "F=%~1"
if not exist "%F%" (
  echo.
  echo [ERRO] Nao encontrei:
  echo "%F%"
  pause
  goto MENU
)

echo.
echo Executando: "%F%"
echo.

rem Roda em CMD filho para evitar "Deseja finalizar..."
cmd /c ""%F%""
set "RC=%ERRORLEVEL%"

echo.
echo Concluido. (ExitCode=%RC%)
pause
goto MENU


:OPEN_DESKTOP
set "P=%USERPROFILE%\Downloads\DESKTOP"
if not exist "%P%" mkdir "%P%"
start "" "%P%"
goto MENU

:OPEN_PROJETO
start "" "%BASE%"
goto MENU


REM | CENTRAL_MENU.bat (menu)
REM | RUN_RECEBIMENTO.bat, RUN_SALVAR_PEDIDOS.bat, etc (launchers)
REM | scripts\AUTOMACAO_PADRAO.ps1 (motor único)
REM | input\*_config.txt e input\*_dados.txt (um par por automação)
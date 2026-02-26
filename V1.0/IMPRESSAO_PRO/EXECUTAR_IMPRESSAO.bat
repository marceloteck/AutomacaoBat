@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
title SISTEMA DE IMPRESSAO AUTOMATICA (AC/PEDIDO/ROMANEIO/NFE)

echo ==========================================================
echo  SISTEMA PROFISSIONAL DE IMPRESSAO
echo  Ordem: AC ^> PEDIDO ^> ROMANEIO ^> NFE
echo  Produtores: ordem alfabetica
echo ==========================================================
echo.

REM ==========================================================
REM DEFINE IMPRESSORA PADRAO PARA IMPRESSAO
REM ==========================================================

echo Definindo impressora HP COMPRA DE BOI como padrao...
wmic printer where "Name='IMPRESSORA HP COMPRA DE BOI'" call SetDefaultPrinter >nul 2>&1

if errorlevel 1 (
    echo [ERRO] Nao foi possivel definir a impressora HP.
    echo Verifique se o nome esta exatamente igual ao do Windows.
    pause
    exit /b 1
)

echo Impressora "IMPRESSORA HP COMPRA DE BOI" definida como padrao.
echo.

REM ==========================================================

set "ROOT="
set /p "ROOT=Digite o caminho da pasta para impressao: "

if "%ROOT%"=="" (
  echo [ERRO] Caminho nao informado.
  goto RESTORE_PRINTER
)

set "ROOT=%ROOT:"=%"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"

if not exist "%ROOT%\" (
  echo [ERRO] Pasta nao encontrada:
  echo   "%ROOT%"
  goto RESTORE_PRINTER
)

set "BASEDIR=%~dp0"
set "PS1=%BASEDIR%scripts\pipeline_print.ps1"

if not exist "%PS1%" (
  echo [ERRO] Script PowerShell nao encontrado:
  echo   "%PS1%"
  goto RESTORE_PRINTER
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -Root "%ROOT%" -BaseDir "%~dp0"
set "EC=%ERRORLEVEL%"

echo.
echo ==========================================================
if not "%EC%"=="0" (
  echo FINALIZADO COM ERRO ^(ExitCode=%EC%^)
) else (
  echo CONCLUIDO COM SUCESSO
)
echo ==========================================================

:RESTORE_PRINTER
echo.
echo Restaurando impressora padrao para PDFCreator...
wmic printer where "Name='PDFCreator'" call SetDefaultPrinter >nul 2>&1
echo Impressora "PDFCreator" definida como padrao.
echo.

pause
exit /b %EC%

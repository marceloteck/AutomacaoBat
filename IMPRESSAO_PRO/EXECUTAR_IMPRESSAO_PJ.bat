@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
title SISTEMA DE IMPRESSAO PJ (AC/PEDIDO/ROMANEIO/ESPELHO/AC.FINANCEIRO)

echo ==========================================================
echo  SISTEMA PROFISSIONAL DE IMPRESSAO - PESSOA JURIDICA
echo  Ordem: AC (1) ^> PEDIDO ^> ROMANEIO ^> ESPELHO ^> AC.FINANCEIRO (ultima)
echo  Regras PJ:
echo    - Pagina 1 = AC (SOMENTE UM LADO)
echo    - Ultima pagina = AC.FINANCEIRO (SOMENTE UM LADO)
echo    - Penultima + Antepenultima = ESPELHO (FRENTE E VERSO)
echo    - O que sobrar = ROMANEIO (FRENTE E VERSO)
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

REM Procura o PS1 primeiro em .\scripts e depois ao lado do BAT
set "PS1=%BASEDIR%scripts\pipeline_print_pj.ps1"
if not exist "%PS1%" set "PS1=%BASEDIR%pipeline_print_pj.ps1"

if not exist "%PS1%" (
  echo [ERRO] Script PowerShell PJ nao encontrado:
  echo   "%BASEDIR%scripts\pipeline_print_pj.ps1"
  echo   ou "%BASEDIR%pipeline_print_pj.ps1"
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

@echo off
setlocal EnableExtensions
chcp 65001 >nul
title SISTEMA DE IMPRESSAO AUTOMATICA (AUTO PF/PJ)

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
  set "EC=1"
  goto RESTORE_PRINTER
)

echo Impressora "IMPRESSORA HP COMPRA DE BOI" definida como padrao.
echo.

REM ==========================================================
REM LER PASTA (ROBUSTO PARA PONTOS/ESPACOS)
REM ==========================================================
set "ROOT="
set /p "ROOT=Digite o caminho da pasta para impressao: "

if not defined ROOT (
  echo [ERRO] Caminho nao informado.
  set "EC=1"
  goto RESTORE_PRINTER
)

REM remove aspas soltas
set "ROOT=%ROOT:"=%"

REM normaliza para caminho absoluto (sem quebrar com pontos)
for %%A in ("%ROOT%") do set "ROOT=%%~fA"

REM valida pasta
if not exist "%ROOT%\NUL" (
  echo [ERRO] Pasta nao encontrada:
  echo   "%ROOT%"
  set "EC=1"
  goto RESTORE_PRINTER
)

set "BASEDIR=%~dp0"
set "PS1=%BASEDIR%scripts\pipeline_print_auto_pf_pj.ps1"
if not exist "%PS1%" set "PS1=%BASEDIR%scripts\pipeline_print.ps1"
if not exist "%PS1%" set "PS1=%BASEDIR%pipeline_print_auto_pf_pj.ps1"
if not exist "%PS1%" set "PS1=%BASEDIR%pipeline_print.ps1"

if not exist "%PS1%" (
  echo [ERRO] Script PowerShell nao encontrado (procurado em scripts\ e na pasta do BAT).
  echo   "%BASEDIR%scripts\pipeline_print_auto_pf_pj.ps1"
  echo   "%BASEDIR%scripts\pipeline_print.ps1"
  echo   "%BASEDIR%pipeline_print_auto_pf_pj.ps1"
  echo   "%BASEDIR%pipeline_print.ps1"
  set "EC=1"
  goto RESTORE_PRINTER
)

REM chama o PowerShell
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
BAT

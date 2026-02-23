@echo off
chcp 65001 >nul
title CENTRAL - MENU RAPIDO
setlocal EnableExtensions EnableDelayedExpansion

rem =========================
rem BASE = pasta deste .bat
rem =========================
set "BASE=%~dp0"
if "%BASE:~-1%"=="\" set "BASE=%BASE:~0,-1%"

:MENU
cls
echo ==========================================
echo         CENTRAL - MENU RAPIDO
echo ==========================================
echo.
echo  F) PASTA DE FATURAMENTO (MES ATUAL)
echo.
echo  1) MESCLAR ACERTOS
echo  2) IMPRIMIR ACERTOS
echo  3) COPIAR ACERTOS (interativo)
echo  4) TRAZER DOCS - DESKTOP (abrir pasta no final)
echo  5) TRAZER DOCS - ZAP     (abrir pasta no final)
echo.
echo  6) CREATOR PADRAO (PDFCreator)
echo  7) IMPRESSORA FISICA (padrao)
echo  8) SALVAR PDF
echo.
echo  9) PDFCreator_SAVE_OFF
echo  10) PDFCreator_SAVE_ON
echo.
echo  11) ABRIR CORPORATE
echo.
echo  12) VER CELULAR (Tela Windows)
echo.
echo  13) FECHAR TODOS OS CORPORATE
echo.
echo  14) ABRIR AUTO FATURAMENTO
echo.
echo  D) Abrir pasta Downloads\DESKTOP
echo.
echo  0) Sair
echo.
set /p "OP=Escolha uma opcao: "

if /i "%OP%"=="0" exit /b 0
if /i "%OP%"=="D" goto OPEN_DESKTOP

rem Pasta de faturamento (mes atual)
if /i "%OP%"=="F"  call :RUN "O:\COMPRA DE GADO\ACERTOS\2026\2 - FEVEREIRO 2026"

if "%OP%"=="1"  call :RUN "%BASE%\AC. CONTABIL\processo_acertos_CONTABIL.cmd"
if "%OP%"=="2"  call :RUN "%BASE%\IMPRESSAO_PRO\EXECUTAR_IMPRESSAO_AUTO_PF_PJ.bat"

if "%OP%"=="3"  call :RUN "%BASE%\SCRCPY\copiar_para_jbs_interativo.bat"
if "%OP%"=="4"  call :RUN_OPEN "%BASE%\SCRCPY\copiar_pasta_mobile_pc DESKTOP MOBILE.bat"
if "%OP%"=="5"  call :RUN_OPEN "%BASE%\SCRCPY\copiar_pasta_mobile_pc.bat"

if "%OP%"=="6"  call :RUN "%BASE%\FERRAMENTAS_DIA_A_DIA\PDF CREATOR.cmd"
if "%OP%"=="7"  call :RUN "%BASE%\FERRAMENTAS_DIA_A_DIA\IMPRESSORA PADRÃO.cmd"
if "%OP%"=="8"  call :RUN "%BASE%\FERRAMENTAS_DIA_A_DIA\SALVAR PDF.cmd"

if "%OP%"=="9"  call :RUN "%BASE%\UTILITARIOS\PDFCreator_SAVE_OFF.bat"
if "%OP%"=="10" call :RUN "%BASE%\UTILITARIOS\PDFCreator_AUTOSAVE_ON.bat"

if "%OP%"=="11" call :RUN "%BASE%\FERRAMENTAS_DIA_A_DIA\abrir_corporate_quantidade.bat"

if "%OP%"=="12" call :RUN "%BASE%\SCRCPY\scrcpy_auto.bat"

if "%OP%"=="13" call :RUN "%BASE%\FERRAMENTAS_DIA_A_DIA\fechar_corporate_com_confirmacao.bat"

if "%OP%"=="14" call :RUN "%BASE%\MENU_AUTO_FATURAMENTO.bat"

echo.
echo Opcao invalida.
timeout /t 2 >nul
goto MENU


rem =========================================================
rem RUN = executa arquivo OU abre pasta, sem fechar o menu
rem - .bat/.cmd executa via cmd /c (evita "Deseja finalizar...")
rem - .txt abre no app padrao (notepad)
rem =========================================================
:RUN
set "F=%~1"

if not exist "%F%" (
  echo.
  echo [ERRO] Nao encontrado:
  echo "%F%"
  pause
  goto MENU
)

echo.
echo Executando: "%F%"
echo.

rem Se for pasta
if exist "%F%\*" (
  start "" "%F%"
  echo Pasta aberta.
  timeout /t 1 >nul
  goto MENU
)

rem Se for TXT abre no Bloco de Notas
if /i "%~x1"==".txt" (
  start "" notepad "%F%"
  timeout /t 1 >nul
  goto MENU
)

rem Se for BAT/CMD roda em cmd filho pra nao matar o menu
if /i "%~x1"==".bat" (
  cmd /c ""%F%""
  set "RC=%ERRORLEVEL%"
  goto RUN_DONE
)
if /i "%~x1"==".cmd" (
  cmd /c ""%F%""
  set "RC=%ERRORLEVEL%"
  goto RUN_DONE
)

rem Qualquer outro arquivo: abre com o associado
start "" "%F%"
set "RC=%ERRORLEVEL%"

:RUN_DONE
echo.
echo Concluido. (ExitCode=%RC%)
pause
goto MENU


rem =========================================================
rem RUN_OPEN = executa e depois abre Downloads\DESKTOP
rem =========================================================
:RUN_OPEN
set "F=%~1"

if not exist "%F%" (
  echo.
  echo [ERRO] Nao encontrado:
  echo "%F%"
  pause
  goto MENU
)

echo.
echo Executando: "%F%"
echo.

if /i "%~x1"==".bat" (
  cmd /c ""%F%""
) else if /i "%~x1"==".cmd" (
  cmd /c ""%F%""
) else (
  start "" /wait "%F%"
)

goto OPEN_DESKTOP


:OPEN_DESKTOP
set "P=%USERPROFILE%\Downloads\DESKTOP"
if not exist "%P%" mkdir "%P%"
start "" "%P%"
goto MENU
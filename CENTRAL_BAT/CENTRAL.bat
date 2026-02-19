@echo off
chcp 65001 >nul
title CENTRAL - MENU RAPIDO
setlocal

:MENU
cls
echo ==========================================
echo         CENTRAL - MENU RAPIDO
echo ==========================================
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
echo 10) PDFCreator_SAVE_ON
echo.
echo  D) Abrir pasta Downloads\DESKTOP
echo  0) Sair
echo.
set /p OP=Escolha uma opcao: 

if "%OP%"=="0" exit /b 0
if /i "%OP%"=="D" goto OPEN_DESKTOP

if "%OP%"=="1"  call :RUN "C:\Users\marcelohenrique-cdt\Documents\BAT\FATURAMENTO-PRO\processo_acertos.cmd"
if "%OP%"=="2"  call :RUN "C:\Users\marcelohenrique-cdt\Documents\BAT\IMPRESSAO_PRO\EXECUTAR_IMPRESSAO.bat"
if "%OP%"=="3"  call :RUN "C:\Users\marcelohenrique-cdt\Documents\- MARCELO HENRIQUE\MARCELO HENRIQUE\SISTEMAS\scrcpy-win64-v3.2\copiar_para_jbs_interativo.bat"
if "%OP%"=="4"  call :RUN_OPEN "C:\Users\marcelohenrique-cdt\Documents\- MARCELO HENRIQUE\MARCELO HENRIQUE\SISTEMAS\scrcpy-win64-v3.2\copiar_pasta_mobile_pc DESKTOP MOBILE.bat"
if "%OP%"=="5"  call :RUN_OPEN "C:\Users\marcelohenrique-cdt\Documents\- MARCELO HENRIQUE\MARCELO HENRIQUE\SISTEMAS\scrcpy-win64-v3.2\copiar_pasta_mobile_pc.bat"

if "%OP%"=="6"  call :RUN "C:\Users\marcelohenrique-cdt\Documents\BAT\PDF CREATOR.cmd"
if "%OP%"=="7"  call :RUN "C:\Users\marcelohenrique-cdt\Documents\BAT\IMPRESSORA PADRÃO.cmd"
if "%OP%"=="8"  call :RUN "C:\Users\marcelohenrique-cdt\Documents\BAT\SALVAR PDF.cmd"

if "%OP%"=="9"  call :RUN "C:\Users\marcelohenrique-cdt\Documents\BAT\PDFCreator_SAVE_OFF.bat"
if "%OP%"=="10" call :RUN "C:\Users\marcelohenrique-cdt\Documents\BAT\PDFCreator_AUTOSAVE_ON.bat"

echo.
echo Opcao invalida.
pause
goto MENU

:RUN
set "F=%~1"
if not exist "%F%" (
  echo.
  echo [ERRO] Arquivo nao encontrado:
  echo %F%
  pause
  goto MENU
)
echo.
echo Executando: %F%
start "" /wait "%F%"
echo.
echo Concluido.
pause
goto MENU

:RUN_OPEN
set "F=%~1"
if not exist "%F%" (
  echo.
  echo [ERRO] Arquivo nao encontrado:
  echo %F%
  pause
  goto MENU
)
echo.
echo Executando: %F%
start "" /wait "%F%"
goto OPEN_DESKTOP

:OPEN_DESKTOP
set "P=%USERPROFILE%\Downloads\DESKTOP"
if not exist "%P%" mkdir "%P%"
start "" "%P%"
goto MENU

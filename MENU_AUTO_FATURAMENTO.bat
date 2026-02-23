@echo off
chcp 65001 >nul
title AUTO FATURAMENTO - MENU
setlocal EnableExtensions EnableDelayedExpansion

rem =========================
rem BASE = pasta deste .bat
rem =========================
set "BASE=%~dp0"
if "%BASE:~-1%"=="\" set "BASE=%BASE:~0,-1%"

rem =========================
rem Pasta alvo
rem =========================
set "AUTO=%BASE%\AUTO_FATURAMENTO"

:MENU
cls
echo ==========================================
echo        AUTO FATURAMENTO - MENU
echo ==========================================
echo.
echo  Pasta: "%AUTO%"
echo.
echo  1) LANCAR RECEBIMENTO DE ENTRADA
echo  2) CADASTRAR PLACAS / FRETE
echo  3) NFE NA CONTRATACAO DE VEICULO
echo  4) FATURAMENTO F7
echo  5) SOLICITAR CTE
echo.
echo.
echo  6) SALVAR PEDIDO
echo  7) ABRIR PASTAS DOS ARQUIVOS TXT
echo.
echo.
echo  A) ABRIR PASTA DE AUTO FATURAMENTO
echo  0) VOLTAR / SAIR
echo.
set /p "OP=Escolha uma opcao: "

if /i "%OP%"=="0" exit /b 0
if /i "%OP%"=="A" goto OPEN_AUTO

if "%OP%"=="1" call :RUN "%AUTO%\RUN_SAA_RECEBIMENTO_DE_ENTRADA.bat"
if "%OP%"=="2" call :RUN "%AUTO%\RUN_CADASTRAR_VEICULO_FRETE.bat"
if "%OP%"=="3" call :RUN "%AUTO%\RUN_NFE_CONTRATACAO_DE_VEICULO.bat"
if "%OP%"=="4" call :RUN "%AUTO%\RUN_FATURAMENTO.bat"
if "%OP%"=="5" call :RUN "%AUTO%\RUN_SOLICITAR_CTE.bat"


if "%OP%"=="6" call :RUN "%AUTO%\RUN_SALVAR_PEDIDO.bat"
if "%OP%"=="7" call :RUN "%BASE%\AUTO_FATURAMENTO\input\pec"

echo.
echo Opcao invalida.
timeout /t 2 >nul
goto MENU


rem =========================================================
rem RUN = executa sem fechar o menu
rem - .bat/.cmd executa via cmd /c
rem - pasta abre no Explorer
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


:OPEN_AUTO
if not exist "%AUTO%" (
  echo.
  echo [ERRO] Pasta AUTO_FATURAMENTO nao existe:
  echo "%AUTO%"
  pause
  goto MENU
)
start "" "%AUTO%"
goto MENU
@echo off
chcp 65001 >nul
setlocal EnableExtensions
title SAA - Corporate (PowerShell)

set "ROOT=%~dp0"
set "INPUT=%ROOT%input\pec\RecebimentoDeEntrada.txt"
set "PS1=%ROOT%scripts\Recebimento_de_entrada.ps1"

:START
cls
echo ==========================================
echo  SAA - Cadastro de Notas (Corporate)
echo  (CMD + PowerShell - sem instalar nada)
echo ==========================================
echo.

if not exist "%PS1%" (
  echo [ERRO] Nao achei:
  echo   "%PS1%"
  echo.
  pause
  goto START
)

if not exist "%INPUT%" (
  echo [ERRO] Nao achei:
  echo   "%INPUT%"
  echo.
  pause
  goto START
)

echo Executando...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -InputFile "%INPUT%"
set "EC=%ERRORLEVEL%"

echo.
if not "%EC%"=="0" (
  echo FINALIZADO COM ERRO (ExitCode=%EC%^)
) else (
  echo CONCLUIDO COM SUCESSO
)

:MENU
echo.
echo ==========================================
echo  ENTER = Rodar novamente
echo  E     = Abrir notas.txt (editar)
echo  S     = Sair
echo ==========================================
set "OP="
set /p "OP=> "

if /I "%OP%"=="E" (
  start "" notepad "%INPUT%"
  echo.
  echo Salve o arquivo no Bloco de Notas e volte aqui.
  pause
  goto START
)

if /I "%OP%"=="S" (
  exit /b %EC%
)

goto START

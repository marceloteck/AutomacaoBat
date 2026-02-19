@echo off
setlocal EnableExtensions
cls
title PDFCreator - Restaurar configuracao (manual)

set "BKDIR=%~dp0PDFCreator_Backup"
set "BK_LAST=%BKDIR%\LAST_BACKUP.reg"

echo ============================================
echo  RESTAURAR CONFIGURACAO PDFCREATOR
echo ============================================
echo.

if not exist "%BK_LAST%" (
  echo ERRO: nao achei o backup:
  echo %BK_LAST%
  echo Rode primeiro o AUTOSAVE_ON para criar o backup.
  pause
  exit /b 1
)

echo Vai restaurar usando:
echo %BK_LAST%
echo.

REM Fecha PDFCreator (se estiver aberto)
taskkill /IM PDFCreator.exe /F >nul 2>nul
taskkill /IM PDFCreator-cli.exe /F >nul 2>nul

reg import "%BK_LAST%" >nul
if errorlevel 1 (
  echo.
  echo ERRO: Falha ao importar backup.
  pause
  exit /b 1
)

echo.
echo ============================================
echo  RESTAURADO!
echo ============================================
echo.
pause
exit /b 0

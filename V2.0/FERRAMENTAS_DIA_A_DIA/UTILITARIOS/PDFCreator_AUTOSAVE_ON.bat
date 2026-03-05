@echo off
setlocal EnableExtensions
cls
title PDFCreator - Ativar AutoSave (com backup)

REM === Onde ficam as configs do perfil default (geralmente 0) ===
set "KEY=HKCU\Software\pdfforge\PDFCreator\Settings\ConversionProfiles\0"

REM === Pasta pra guardar backup ===
set "BKDIR=%~dp0PDFCreator_Backup"
if not exist "%BKDIR%" mkdir "%BKDIR%"

REM === Backup com data/hora (sem caracteres invalidos) ===
for /f "tokens=1-3 delims=/" %%a in ("%date%") do set "D=%%c-%%b-%%a"
for /f "tokens=1-3 delims=:." %%a in ("%time%") do set "T=%%a%%b%%c"
set "BK=%BKDIR%\Profile0_%D%_%T%.reg"
set "BK_LAST=%BKDIR%\LAST_BACKUP.reg"

echo ============================================
echo  ATIVAR AUTOSAVE - PDFCreator
echo ============================================
echo.
echo Vai fazer backup do perfil 0 em:
echo %BK%
echo.

REM Fecha PDFCreator (se estiver aberto)
taskkill /IM PDFCreator.exe /F >nul 2>nul
taskkill /IM PDFCreator-cli.exe /F >nul 2>nul

REM Exporta backup
reg export "%KEY%" "%BK%" /y >nul
if errorlevel 1 (
  echo.
  echo ERRO: Falha ao exportar backup do registro.
  echo Talvez sem permissao ou chave nao existe.
  pause
  exit /b 1
)

copy /y "%BK%" "%BK_LAST%" >nul

echo.
echo Backup OK.

REM Ativa AutoSave (modo Automatico)
REM (enabled true/false fica em ...\AutoSave)  — setamos como string por compatibilidade
reg add "%KEY%\AutoSave" /v Enabled /t REG_SZ /d true /f >nul

REM Opcional: evitar sobrescrever arquivo com mesmo nome
reg add "%KEY%\AutoSave" /v EnsureUniqueFilenames /t REG_SZ /d true /f >nul

echo.
echo ============================================
echo  AUTOSAVE ATIVADO!
echo ============================================
echo.
echo Se ainda aparecer janela de "Salvar como", abra o PDFCreator 1 vez
echo e verifique se o perfil Default esta vinculado a impressora PDFCreator.
echo.
pause
exit /b 0

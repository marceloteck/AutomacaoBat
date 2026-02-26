@echo off
cd /d "%~dp0"
title Copiar do celular para Downloads

echo -----------------------------------------------
echo Copiador do celular para o PC (/sdcard/jbs/DESKTOP)
echo -----------------------------------------------
echo.

echo [INFO] Aguardando conexão do celular via USB com depuração habilitada...
:wait_for_device
adb get-state 1>nul 2>nul
if errorlevel 1 (
    timeout /t 2 >nul
    goto wait_for_device
)

echo [INFO] Celular detectado!

REM === Caminho de destino fixo no PC ===
set "DESTINO_PC=C:\Users\marcelohenrique-cdt\Downloads"

REM === Verifica se a pasta existe ===
if not exist "%DESTINO_PC%" (
    echo Criando a pasta de destino: "%DESTINO_PC%"
    mkdir "%DESTINO_PC%"
)

REM === Verifica conexao com o celular ===
echo.
echo Verificando conexao com o celular via ADB...
adb get-state 1>nul 2>nul
if errorlevel 1 (
    echo [ERRO] Celular nao detectado.
    echo Verifique o cabo e a depuracao USB.
    pause
    exit /b
)

REM === Caminho fixo do Android ===
set "ORIGEM_ANDROID=/sdcard/jbs/DESKTOP"

echo.
echo Copiando "%ORIGEM_ANDROID%" para "%DESTINO_PC%"...
adb pull "%ORIGEM_ANDROID%" "%DESTINO_PC%"

echo.
echo === APAGANDO SOMENTE ARQUIVOS DO CELULAR ===

REM ---- Lista apenas arquivos, ignorando pastas ----
for /f "delims=" %%A in ('adb shell "ls -p \"%ORIGEM_ANDROID%\" | grep -v /"') do (
    echo Apagando arquivo: %%A
    adb shell rm "'%ORIGEM_ANDROID%/%%A'"
)

echo.
echo [SUCESSO] Copiado e APENAS os arquivos foram apagados!
REM explorer "%DESTINO_PC%"
pause

@echo off
cd /d "%~dp0"
title Copiar do celular para Downloads

echo -----------------------------------------------
echo Copiador do celular para o PC (/sdcard/Android/...)
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
set "DESTINO_PC=C:\Users\marcelohenrique-cdt\Downloads\DESKTOP"

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
set "ORIGEM_ANDROID=/sdcard/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Documents"

echo.
echo Copiando SOMENTE arquivos (sem pastas) de:
echo   "%ORIGEM_ANDROID%"
echo Para:
echo   "%DESTINO_PC%"
echo.

mkdir "%DESTINO_PC%" >nul 2>&1

echo.
echo === COPIANDO ARQUIVOS ===
for /f "delims=" %%A in ('adb shell "ls -p \"%ORIGEM_ANDROID%\" | grep -v /"') do (
    echo Copiando arquivo: %%A
    adb pull "%ORIGEM_ANDROID%/%%A" "%DESTINO_PC%" >nul

    echo Apagando do celular: %%A
    adb shell rm "'%ORIGEM_ANDROID%/%%A'"
)

echo.
echo [SUCESSO] Arquivos copiados e apagados do celular com segurança!
pause

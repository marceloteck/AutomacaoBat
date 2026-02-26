@echo off
cd /d "%~dp0"
title Copiar pasta para o celular (/sdcard/jbs)

echo ----------------------------------------------
echo Copiador de pastas para o Android (/sdcard/jbs)
echo ----------------------------------------------
echo.

echo [INFO] Aguardando conexão do celular via USB com depuração habilitada...
:wait_for_device
adb get-state 1>nul 2>nul
if errorlevel 1 (
    timeout /t 2 >nul
    goto wait_for_device
)

echo [INFO] Celular detectado!

REM === Solicita o caminho da pasta local ===
set /p PASTA_ORIGEM=Digite ou cole o caminho da pasta que deseja copiar para o celular:

REM === Verifica se a pasta existe ===
if not exist "%PASTA_ORIGEM%" (
    echo.
    echo [ERRO] A pasta especificada nao existe: "%PASTA_ORIGEM%"
    echo Verifique o caminho e tente novamente.
    pause
    exit /b
)

REM === Caminho no Android ===
set "DESTINO_ANDROID=/sdcard/jbs/"

REM === Verifica conexão com o celular ===
echo.
echo Verificando conexão com o celular via ADB...
adb get-state 1>nul 2>nul
if errorlevel 1 (
    echo [ERRO] Celular nao detectado.
    echo Certifique-se de que a depuracao USB esta ativada e o cabo conectado.
    pause
    exit /b
)

REM === Copia a pasta ===
echo.
echo Copiando "%PASTA_ORIGEM%" para "%DESTINO_ANDROID%" no celular...
adb push "%PASTA_ORIGEM%" "%DESTINO_ANDROID%"

echo.
echo [SUCESSO] Pasta copiada com sucesso para o celular!
pause

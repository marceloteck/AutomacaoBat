@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
title Copiar pasta para o celular (/sdcard/jbs)

set "DESTINO_ANDROID=/sdcard/jbs"

:inicio
cls
echo ----------------------------------------------
echo Copiador de pastas para o Android (^%DESTINO_ANDROID^%)
echo ----------------------------------------------
echo.

echo [INFO] Aguardando conexao do celular via USB com depuracao habilitada...
:wait_for_device
adb get-state 1>nul 2>nul
if errorlevel 1 (
    timeout /t 2 >nul
    goto wait_for_device
)

echo [INFO] Celular detectado!
echo.

:loop
set "PASTA_ORIGEM="
set /p PASTA_ORIGEM=Digite ou cole o caminho da pasta que deseja copiar (SAIR para encerrar / CLEAR para limpar a tela): 

if /i "%PASTA_ORIGEM%"=="SAIR" (
    echo Encerrando o programa...
    exit /b
)

if /i "%PASTA_ORIGEM%"=="CLEAR" (
    goto inicio
)

if not exist "%PASTA_ORIGEM%" (
    echo.
    echo [ERRO] A pasta especificada nao existe: "%PASTA_ORIGEM%"
    echo Verifique o caminho e tente novamente.
    echo.
    goto loop
)

REM Pega apenas o nome da pasta (ex: ROMANEIO)
for %%A in ("%PASTA_ORIGEM%") do set "NOME_PASTA=%%~nxA"

echo.
echo Verificando conexao com o celular via ADB...
adb get-state 1>nul 2>nul
if errorlevel 1 (
    echo [ERRO] Celular nao detectado.
    echo Certifique-se de que a depuracao USB esta ativada e o cabo conectado.
    pause
    goto inicio
)

REM Garante que a pasta base existe no celular
echo.
echo [INFO] Garantindo pasta base no celular: %DESTINO_ANDROID%
adb shell "mkdir -p '%DESTINO_ANDROID%'"

REM APAGA a pasta com mesmo nome no destino (se existir)
echo.
echo [INFO] Removendo no celular (se existir): %DESTINO_ANDROID%/%NOME_PASTA%
adb shell "rm -rf '%DESTINO_ANDROID%/%NOME_PASTA%'"

REM Copia a pasta
echo.
echo [INFO] Copiando "%PASTA_ORIGEM%" para "%DESTINO_ANDROID%/" no celular...
adb push "%PASTA_ORIGEM%" "%DESTINO_ANDROID%/"

if errorlevel 1 (
    echo.
    echo [ERRO] Falha ao copiar. Verifique o cabo, permissao e o caminho.
    echo.
    pause
    goto inicio
)

echo.
echo [SUCESSO] Pasta "%NOME_PASTA%" copiada e substituida no celular!
echo.
pause
goto inicio
@echo off
cd /d "%~dp0"
title Scrcpy com tela desligada + opção de restauração

echo [INFO] Aguardando conexão do celular via USB com depuração habilitada...
:wait_for_device
adb get-state 1>nul 2>nul
if errorlevel 1 (
    timeout /t 2 >nul
    goto wait_for_device
)

echo [INFO] Celular detectado! Iniciando Scrcpy com tela desligada...
start "" scrcpy --turn-screen-off --prefer-text

timeout /t 3 >nul
adb shell input keyevent 223
echo.
echo [OK] Scrcpy iniciado com tela desligada.

:menu
echo.
echo ----------------------------
echo Deseja encerrar e restaurar?
echo ----------------------------
echo 1 - Sim, restaurar a tela
echo 2 - Nao, manter como está
echo ----------------------------
set /p opcao=Escolha uma opção (1 ou 2): 

if "%opcao%"=="1" (
  
echo.
echo [INFO] Restaurando tela do celular...

adb shell input keyevent 224
adb shell input keyevent 82
adb shell input keyevent 3

echo [OK] Tela ligada e restaurada.
pause
exit


) else if "%opcao%"=="2" (
    echo OK, saindo sem restaurar.
    exit
) else (
    echo Opção inválida.
    goto menu
)
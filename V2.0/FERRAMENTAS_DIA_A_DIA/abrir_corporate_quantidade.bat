@echo off
title Abrir Corporate - Quantidade Personalizada

set APP_PATH=K:\Div\CorporateUpdater\JBS.Updater.Corporate.exe

echo|set /p="MARCELOHENRIQUE-CDT"|clip

echo ==========================================
echo     ABRIR CORPORATE - MULTIPLAS INSTANCIAS
echo ==========================================
echo.

:: Verifica se o arquivo existe
if not exist "%APP_PATH%" (
    echo ERRO: Arquivo nao encontrado:
    echo %APP_PATH%
    echo.
    pause
    exit /b
)

set /p QTD="Quantas instancias deseja abrir? "

:: Verifica se digitou algo
if "%QTD%"=="" (
    echo Valor invalido.
    pause
    exit /b
)

:: Valida se é numero
for /f "delims=0123456789" %%A in ("%QTD%") do (
    echo Valor invalido. Digite apenas numeros.
    pause
    exit /b
)

echo.
echo Abrindo %QTD% instancia(s)...
echo.

set /a I=1

:LOOP
if %I% GTR %QTD% goto FIM

start "" "%APP_PATH%"

echo Instancia %I% aberta.
set /a I+=1
timeout /t 1 >nul
goto LOOP

echo teste-CDT | clip
echo @teste | clip

:FIM
echo.
echo Concluido com sucesso.

echo|set /p="@Nelore25"|clip



pause
exit /b
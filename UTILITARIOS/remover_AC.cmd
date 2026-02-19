@echo off
cls
title Renomeador - Remover "AC." dos PDFs

echo ============================================
echo  RENOMEADOR DE PDFs - REMOVER "AC."
echo ============================================
echo.
echo Cole abaixo o CAMINHO COMPLETO da pasta:
echo Exemplo:
echo C:\Users\Marcelo\Documents\PDFs
echo.

set /p PASTA=Digite o caminho da pasta: 

:: Verifica se a pasta existe
if not exist "%PASTA%" (
    echo.
    echo ERRO: A pasta informada nao existe.
    pause
    exit
)

cls
echo Pasta selecionada:
echo %PASTA%
echo.
echo Serao renomeados APENAS arquivos:
echo - Que comecem com "AC."
echo - Que sejam PDF
echo.

pause

echo --------------------------------------------
echo ATENCAO: Essa operacao NAO pode ser desfeita!
echo.

set /p CONFIRMA=Digite SIM para continuar: 

if /I NOT "%CONFIRMA%"=="SIM" (
    echo.
    echo Operacao cancelada.
    pause
    exit
)

cls
echo Iniciando processo...
echo.

set CONTADOR=0

pushd "%PASTA%"

for %%F in ("AC.*.pdf") do (

    set "OLDNAME=%%~nxF"

    setlocal EnableDelayedExpansion

    set "NEWNAME=!OLDNAME:AC.=!"

    ren "%%F" "!NEWNAME!"

    endlocal

    set /a CONTADOR+=1
)

popd

echo.
echo ============================================
echo FINALIZADO
echo ============================================
echo Total de PDFs renomeados: %CONTADOR%
echo.

pause
exit

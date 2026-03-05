@echo off
cls
title Renomeador - Adicionar "AC." nos PDFs

echo ============================================
echo  RENOMEADOR DE PDFs - ADICIONAR "AC."
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
echo - Que sejam PDF
echo - Que NAO comecem com "AC."
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

for %%F in ("*.pdf") do (

    set "OLDNAME=%%~nxF"

    setlocal EnableDelayedExpansion

    set "TEST=!OLDNAME:~0,3!"

    if /I NOT "!TEST!"=="AC." (

        set "NEWNAME=AC.!OLDNAME!"
        ren "%%F" "!NEWNAME!"
        endlocal

        set /a CONTADOR+=1
    ) else (
        endlocal
    )
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

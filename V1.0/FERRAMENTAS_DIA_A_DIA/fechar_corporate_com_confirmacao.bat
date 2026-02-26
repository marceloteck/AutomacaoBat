@echo off
title Encerrador Seguro - Corporate.exe


echo ==========================================
echo   ENCERRAMENTO SEGURO - CORPORATE.EXE
echo ==========================================
echo.

:: Verifica se o processo existe
tasklist | findstr /I "Corporate.exe" >nul

if errorlevel 1 (
    echo Nenhum processo Corporate.exe encontrado em execucao.
    echo.
    pause
    exit /b
)

echo Processos encontrados:
echo ------------------------------------------
tasklist | findstr /I "Corporate.exe"
echo ------------------------------------------
echo.

echo ATENCAO:
echo Isso ira ENCERRAR todos os processos Corporate.exe
echo e seus subprocessos.
echo.

set /p CONFIRMA="Deseja realmente continuar? (S/N): "

if /I NOT "%CONFIRMA%"=="S" (
    echo.
    echo Operacao cancelada pelo usuario.
    pause
    exit /b
)

echo.
echo Encerrando processos...
echo.

:: Mata a arvore de processos
taskkill /F /T /IM Corporate.exe

if errorlevel 1 (
    echo Erro ao tentar encerrar os processos.
) else (
    echo Processos encerrados com sucesso.
)

echo.
pause
exit /b
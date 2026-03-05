@echo off
chcp 65001 >nul
title CENTRAL - MENU RAPIDO
setlocal EnableExtensions EnableDelayedExpansion

rem =========================
rem BASE = pasta deste .bat
rem =========================
set "BASE=%~dp0"
if "%BASE:~-1%"=="\" set "BASE=%BASE:~0,-1%"

rem =====================================================
rem DEFINICAO DOS ITENS
rem KEY | TITLE | PATH | MODE
rem MODE = RUN | RUN_OPEN | SPECIAL
rem =====================================================

set COUNT=16

set "M[1].KEY=F"
set "M[1].TITLE=PASTA DE FATURAMENTO (MES ATUAL)"
set "M[1].PATH=O:\COMPRA DE GADO\ACERTOS\2026\2 - FEVEREIRO 2026"
set "M[1].MODE=RUN"

set "M[2].KEY=1"
set "M[2].TITLE=MESCLAR ACERTOS"
set "M[2].PATH=%BASE%\AC. CONTABIL\processo_acertos_CONTABIL.cmd"
set "M[2].MODE=RUN"

set "M[3].KEY=2.1"
set "M[3].TITLE=IMPRIMIR ACERTOS (PF)"
set "M[3].PATH=%BASE%\IMPRESSAO_PRO\EXECUTAR_IMPRESSAO.bat"
set "M[3].MODE=RUN"

set "M[4].KEY=2.2"
set "M[4].TITLE=IMPRIMIR ACERTOS (PJ)"
set "M[4].PATH=%BASE%\IMPRESSAO_PRO\EXECUTAR_IMPRESSAO_PJ.bat"
set "M[4].MODE=RUN"

set "M[5].KEY=3"
set "M[5].TITLE=COPIAR ACERTOS (interativo)"
set "M[5].PATH=%BASE%\SCRCPY\copiar_para_jbs_interativo.bat"
set "M[5].MODE=RUN"

set "M[6].KEY=4"
set "M[6].TITLE=TRAZER DOCS - DESKTOP"
set "M[6].PATH=%BASE%\SCRCPY\copiar_pasta_mobile_pc DESKTOP MOBILE.bat"
set "M[6].MODE=RUN_OPEN"

set "M[7].KEY=5"
set "M[7].TITLE=TRAZER DOCS - ZAP"
set "M[7].PATH=%BASE%\SCRCPY\copiar_pasta_mobile_pc.bat"
set "M[7].MODE=RUN_OPEN"

set "M[8].KEY=6"
set "M[8].TITLE=CREATOR PADRAO (PDFCreator)"
set "M[8].PATH=%BASE%\FERRAMENTAS_DIA_A_DIA\PDF CREATOR.cmd"
set "M[8].MODE=RUN"

set "M[9].KEY=7"
set "M[9].TITLE=IMPRESSORA FISICA (padrao)"
set "M[9].PATH=%BASE%\FERRAMENTAS_DIA_A_DIA\IMPRESSORA PADRÃO.cmd"
set "M[9].MODE=RUN"

set "M[10].KEY=8"
set "M[10].TITLE=SALVAR PDF"
set "M[10].PATH=%BASE%\FERRAMENTAS_DIA_A_DIA\SALVAR PDF.cmd"
set "M[10].MODE=RUN"

set "M[11].KEY=9"
set "M[11].TITLE=PDFCreator_SAVE_OFF"
set "M[11].PATH=%BASE%\UTILITARIOS\PDFCreator_SAVE_OFF.bat"
set "M[11].MODE=RUN"

set "M[12].KEY=10"
set "M[12].TITLE=PDFCreator_SAVE_ON"
set "M[12].PATH=%BASE%\UTILITARIOS\PDFCreator_AUTOSAVE_ON.bat"
set "M[12].MODE=RUN"

set "M[13].KEY=11"
set "M[13].TITLE=ABRIR CORPORATE"
set "M[13].PATH=%BASE%\FERRAMENTAS_DIA_A_DIA\abrir_corporate_quantidade.bat"
set "M[13].MODE=RUN"

set "M[14].KEY=12"
set "M[14].TITLE=VER CELULAR (Tela Windows)"
set "M[14].PATH=%BASE%\SCRCPY\scrcpy_auto.bat"
set "M[14].MODE=RUN"

set "M[15].KEY=13"
set "M[15].TITLE=FECHAR TODOS OS CORPORATE"
set "M[15].PATH=%BASE%\FERRAMENTAS_DIA_A_DIA\fechar_corporate_com_confirmacao.bat"
set "M[15].MODE=RUN"

set "M[16].KEY=14"
set "M[16].TITLE=ABRIR AUTO FATURAMENTO"
set "M[16].PATH=%BASE%\MENU_AUTO_FATURAMENTO.bat"
set "M[16].MODE=RUN"

rem =====================================================
:MENU
cls
echo ==========================================
echo         CENTRAL - MENU RAPIDO
echo ==========================================
echo.

for /L %%i in (1,1,%COUNT%) do (
    echo  !M[%%i].KEY!^) !M[%%i].TITLE!
)

echo.
echo  D^) Abrir pasta Downloads\DESKTOP
echo.
echo  0^) Sair
echo.
set /p OP=Escolha uma opcao: 

if /I "%OP%"=="0" exit /b
if /I "%OP%"=="D" goto OPEN_DESKTOP

for /L %%i in (1,1,%COUNT%) do (
    if /I "!OP!"=="!M[%%i].KEY!" (
        set "EXEC_PATH=!M[%%i].PATH!"
        set "EXEC_MODE=!M[%%i].MODE!"
        goto EXECUTE
    )
)

echo.
echo Opcao invalida.
timeout /t 2 >nul
goto MENU

rem =====================================================
:EXECUTE
cls
set "F=!EXEC_PATH!"

if not exist "!F!" (
    echo.
    echo [ERRO] Nao encontrado:
    echo "!F!"
    pause
    goto MENU
)

echo Executando: "!F!"
echo.

rem Pasta
if exist "!F!\*" (
    start "" "!F!"
    timeout /t 1 >nul
    goto MENU
)

rem TXT
if /I "!F:~-4!"==".txt" (
    start "" notepad "!F!"
    timeout /t 1 >nul
    goto MENU
)

rem RUN_OPEN
if /I "!EXEC_MODE!"=="RUN_OPEN" (
    cmd /c ""!F!""
    goto OPEN_DESKTOP
)

rem BAT/CMD
if /I "!F:~-4!"==".bat" (
    cmd /c ""!F!""
    set "RC=!ERRORLEVEL!"
    goto RUN_DONE
)
if /I "!F:~-4!"==".cmd" (
    cmd /c ""!F!""
    set "RC=!ERRORLEVEL!"
    goto RUN_DONE
)

rem Outros
start "" "!F!"
set "RC=!ERRORLEVEL!"

:RUN_DONE
echo.
echo Concluido. (ExitCode=!RC!)
pause
goto MENU

rem =====================================================
:OPEN_DESKTOP
set "P=%USERPROFILE%\Downloads\DESKTOP"
if not exist "!P!" mkdir "!P!"
start "" "!P!"
goto MENU
@echo off
chcp 65001 >nul
setlocal EnableExtensions

title SAA - Start Automacao (AutoHotkey)

REM ===============================
REM BLOQUEAR EXECUCAO COMO ADMIN
REM ===============================
net session >nul 2>&1 && (
    echo.
    echo ==========================================
    echo  [BLOQUEADO] NAO EXECUTE COMO ADMINISTRADOR
    echo ==========================================
    echo.
    echo Feche esta janela e execute normalmente (duplo clique).
    echo.
    pause
    exit /b 1
)

set "ROOT=%~dp0"
set "AHK=%ROOT%ahk\AutoHotkey.exe"
set "SCRIPT=%ROOT%ahk\start_automacao.ahk"

if not exist "%AHK%" (
    echo.
    echo [ERRO] Nao encontrei AutoHotkey.exe em:
    echo %AHK%
    echo.
    pause
    exit /b 1
)

if not exist "%SCRIPT%" (
    echo.
    echo [ERRO] Nao encontrei start_automacao.ahk em:
    echo %SCRIPT%
    echo.
    pause
    exit /b 1
)

echo ==========================================
echo  Iniciando Automacao SAA...
echo ==========================================
echo.

start "" "%AHK%" "%SCRIPT%"

echo [OK] Automacao ativada.
echo Um icone verde deve aparecer perto do relogio.
echo.
pause
exit /b 0
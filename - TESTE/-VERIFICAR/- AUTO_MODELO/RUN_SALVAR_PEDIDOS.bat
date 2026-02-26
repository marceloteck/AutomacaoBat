@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0"

set "MOTOR=%~dp0scripts\AUTOMACAO_PADRAO.ps1"
set "CFG=%~dp0input\salvar_pedidos_config.txt"
set "DADOS=%~dp0input\salvar_pedidos_dados.txt"

echo ==========================================
echo  AUTOMACAO: SALVAR PEDIDOS
echo ==========================================
echo Config: %CFG%
echo Dados : %DADOS%
echo.

powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%MOTOR%" -Config "%CFG%" -Dados "%DADOS%"
exit /b %ERRORLEVEL%
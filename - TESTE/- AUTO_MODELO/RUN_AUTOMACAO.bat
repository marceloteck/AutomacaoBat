@echo off
setlocal
chcp 65001 >nul

rem Ir para a pasta onde este .bat está
cd /d "%~dp0"

echo ==========================================
echo  AUTOMACAO PADRAO (CONFIG + DADOS)
echo ==========================================
echo.
echo Deixe o sistema (ERP) em FOCO antes de iniciar.
echo.

powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0scripts\AUTOMACAO_PADRAO.ps1"

echo.
pause
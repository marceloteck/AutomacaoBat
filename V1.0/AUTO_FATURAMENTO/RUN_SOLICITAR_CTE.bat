@echo off
setlocal
cd /d "%~dp0"

echo ==========================================
echo  AUTOMACAO SOLICITAR CTE
echo ==========================================
echo.
echo Abra o sistema e deixe a tela pronta.
echo.

powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0scripts\SOLICITAR_CTE_PEC.ps1"

echo.
pause
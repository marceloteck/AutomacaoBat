@echo off
setlocal
cd /d "%~dp0"

echo ==========================================
echo  AUTOMACAO ABRIR_TELAS_CTE_RECEBIMENTO_ENTRADA
echo ==========================================
echo.
echo Abra o sistema e deixe a tela pronta.
echo.

powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0scripts\ABRIR_TELAS_CTE_RECEBIMENTO_ENTRADA.ps1"

echo.
pause
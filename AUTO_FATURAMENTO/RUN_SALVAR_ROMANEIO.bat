@echo off
setlocal
cd /d "%~dp0"

echo ==========================================
echo  AUTOMACAO SALVAR ACERTOS PECUARISTA
echo ==========================================
echo.
echo Abra o sistema e deixe a tela pronta.
echo.

powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0scripts\SALVAR_ROMANEIO.ps1"

echo.
pause
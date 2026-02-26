@echo off
setlocal
cd /d "%~dp0"

echo ==========================================
echo  AUTOMACAO PECUARIA (PEDIDO)
echo ==========================================
echo.
echo Abra o sistema e deixe a tela pronta.
echo.

wmic printer where "Name='Microsoft Print to PDF'" call SetDefaultPrinter
echo Impressora "Microsoft Print to PDF" definida como padrão.
echo.
echo.

powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0scripts\SALVAR_PEDIDOS.ps1"

echo.
echo.
wmic printer where "Name='PDFCreator'" call SetDefaultPrinter
echo Impressora "PDFCreator" definida como padrão.

echo.
pause
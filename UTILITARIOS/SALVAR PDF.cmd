@echo off
wmic printer where "Name='Microsoft Print to PDF'" call SetDefaultPrinter
echo Impressora "Microsoft Print to PDF" definida como padrão.
rem pause

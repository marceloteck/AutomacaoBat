@echo off
wmic printer where "Name='PDFCreator'" call SetDefaultPrinter
echo Impressora "PDFCreator" definida como padrão.
rem pause

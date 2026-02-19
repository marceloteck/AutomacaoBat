@echo off
wmic printer where "Name='IMPRESSORA HP COMPRA DE BOI'" call SetDefaultPrinter
echo Impressora "IMPRESSORA HP COMPRA DE BOI" definida como padrão.
rem pause

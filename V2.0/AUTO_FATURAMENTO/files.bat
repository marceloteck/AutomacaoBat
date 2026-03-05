@echo off
setlocal

if not exist "modules\faturando" mkdir modules\faturando

call :CreateFile 01-Recebimento.ps1 Step-RecebimentoEntrada
call :CreateFile 02-CadastrarPlacas.ps1 Step-CadastrarPlacas
call :CreateFile 03-CadastrarNotas.ps1 Step-CadastrarNotas
call :CreateFile 04-FaturarFase7.ps1 Step-FaturarFase7
call :CreateFile 05-EmitirCTE.ps1 Step-EmitirCTE
call :CreateFile 06-LancarCTE.ps1 Step-LancarCTE
call :CreateFile 07-FecharStatus.ps1 Step-FecharStatus
call :CreateFile 08-FaturarFase3.ps1 Step-FaturarFase3
call :CreateFile 09-EmitirNFe.ps1 Step-EmitirNFe
call :CreateFile 10-SalvarAcertos.ps1 Step-SalvarAcertos
call :CreateFile 11-SalvarPedidos.ps1 Step-SalvarPedidos
call :CreateFile 12-SalvarRomaneios.ps1 Step-SalvarRomaneios

echo Estrutura criada com template.
pause
exit /b

:CreateFile
(
echo function %2 {
echo     param(^$produtor^)
echo.
echo     Write-Host "[EXEC] %2 - $($produtor.Nome)" -ForegroundColor Cyan
echo.
echo     # IMPLEMENTAR LOGICA AQUI
echo }
) > modules\faturando\%1

exit /b
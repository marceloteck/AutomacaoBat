@echo off
setlocal enabledelayedexpansion

REM Solicita o caminho da pasta
set /p "BASE_DIR=Digite o caminho completo da pasta com os arquivos: "

REM Verifica se a pasta existe
if not exist "%BASE_DIR%" (
echo.
echo ERRO: A pasta especificada nao existe.
pause
exit /b
)

REM Muda para a pasta fornecida
cd /d "%BASE_DIR%"

REM Processa arquivos
for %%F in (*.xml *.XML *.PDF *.pdf) do (
set "filename=%%~nF"
mkdir "!filename!" 2>nul
move "%%F" "!filename!" >nul
)

echo.
echo Todos os arquivos foram organizados em suas proprias pastas.
pause
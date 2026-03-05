@echo off
setlocal enabledelayedexpansion

REM === Solicita caminho da pasta ao usuário ===
set /p "PDF_FOLDER=Cole o caminho da pasta onde estão os PDFs: "

REM === Caminho do PDFtk portátil ===
set "PDFTK_PATH=Ferramentas\pdftk.exe"

REM === Pasta temporária para arquivos intermediários ===
set "TMP_FOLDER=%TEMP%\pdf_temp"

REM Cria pasta temporária
if not exist "%TMP_FOLDER%" mkdir "%TMP_FOLDER%"

REM Loop por todos os PDFs na pasta indicada
for %%F in ("%PDF_FOLDER%\*.pdf") do (
    set "filename=%%~nF"
    echo Processando: %%~nxF

    REM Descobre número total de páginas
    for /f %%P in ('"%PDFTK_PATH%" "%%F" dump_data ^| findstr NumberOfPages') do (
        set "pages=%%P"
        set "pages=!pages:~15!"
    )

    REM Extrai página 1
    "%PDFTK_PATH%" "%%F" cat 1 output "%TMP_FOLDER%\!filename!_pg1.pdf"

    REM Extrai última página
    "%PDFTK_PATH%" "%%F" cat !pages! output "%TMP_FOLDER%\!filename!_pgN.pdf"

    REM Junta as duas páginas
    "%PDFTK_PATH%" "%TMP_FOLDER%\!filename!_pg1.pdf" "%TMP_FOLDER%\!filename!_pgN.pdf" cat output "%TMP_FOLDER%\!filename!_print.pdf"

    REM Abre o PDF gerado para o usuário imprimir manualmente (impressão controlada)
    start "" "%TMP_FOLDER%\!filename!_print.pdf"
)

echo.
echo Arquivos preparados e abertos para impressão.
pause

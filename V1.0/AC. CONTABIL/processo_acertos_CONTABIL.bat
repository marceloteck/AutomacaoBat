@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul
cls
title PROCESSO - ACERTOS CONTABIL (PDFCreator) - COMPLETO

echo ============================================
echo  PROCESSO AUTOMATICO - ACERTOS CONTABIL
echo ============================================
echo Estrutura esperada:
echo   PASTA_PRINCIPAL\
echo     - PDFs dos ACERTOS na raiz (podem estar "AC." ou sem numero)
echo     - - PEDIDOS\  (PDFs dos pedidos)  (NAO sera apagado)
echo.
echo Cole o caminho completo da pasta principal:
echo Exemplo: O:\...\ACERTOS_CONTABIL
echo.

set "ROOT="
set /p "ROOT=PASTA PRINCIPAL: "

REM Normalizar entrada: remove aspas e barra final
if defined ROOT set "ROOT=%ROOT:"=%"
if defined ROOT if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"

if not exist "%ROOT%" (
  echo.
  echo [ERRO] Pasta principal nao existe:
  echo "%ROOT%"
  pause
  exit /b 1
)

REM /////////////////////////////////// AUTO SALVE //////////////////////////////////
cls

REM === Onde ficam as configs do perfil default (geralmente 0) ===
set "KEY=HKCU\Software\pdfforge\PDFCreator\Settings\ConversionProfiles\0"

REM === Pasta pra guardar backup ===
set "BKDIR=%~dp0PDFCreator_Backup"
if not exist "%BKDIR%" mkdir "%BKDIR%"

REM === UM UNICO BACKUP (sempre sobrescreve) ===
set "BK_LAST=%BKDIR%\LAST_BACKUP.reg"

echo ==========================================================
echo    PDFCreator - Configurar AutoSave (perfil Default/0)
echo ==========================================================
echo.
echo  Backup unico:
echo    "%BK_LAST%"
echo.
echo  O que vai acontecer agora:
echo    1) Fechar PDFCreator (se estiver aberto)
echo    2) Salvar backup do perfil 0 no .reg
echo    3) Ativar AutoSave + Nome unico
echo.


REM Fecha PDFCreator (se estiver aberto)
taskkill /IM PDFCreator.exe /F >nul 2>nul
taskkill /IM PDFCreator-cli.exe /F >nul 2>nul

REM Checa se a chave existe
reg query "%KEY%" >nul 2>nul
if errorlevel 1 goto AUTOSAVE_ERR_NO_KEY

REM Exporta backup SEMPRE no mesmo arquivo
reg export "%KEY%" "%BK_LAST%" /y >nul
if errorlevel 1 goto AUTOSAVE_ERR_EXPORT

REM Confirma que o arquivo foi criado
if not exist "%BK_LAST%" goto AUTOSAVE_ERR_NOT_CREATED

REM Confirma que nao esta vazio (0 bytes)
set "BKSIZE=0"
for %%A in ("%BK_LAST%") do set "BKSIZE=%%~zA"
if "%BKSIZE%"=="0" goto AUTOSAVE_ERR_EMPTY

REM Ativa AutoSave - Nota: PDFCreator usa "true" como string em algumas versões
reg add "%KEY%\AutoSave" /v Enabled /t REG_SZ /d "true" /f >nul
if errorlevel 1 goto AUTOSAVE_ERR_REGADD

REM Evitar sobrescrever arquivo com mesmo nome
reg add "%KEY%\AutoSave" /v EnsureUniqueFilenames /t REG_SZ /d "true" /f >nul
if errorlevel 1 goto AUTOSAVE_ERR_REGADD

echo.
echo ==========================================================
echo    OK - AUTOSAVE ATIVADO
echo ==========================================================
goto CONTINUAR_PROCESSO

:AUTOSAVE_ERR_NO_KEY
echo [ERRO] CHAVE DO PERFIL 0 NAO ENCONTRADA: %KEY%
pause & exit /b 1

:AUTOSAVE_ERR_EXPORT
echo [ERRO] FALHA AO EXPORTAR BACKUP.
pause & exit /b 1

:AUTOSAVE_ERR_NOT_CREATED
echo [ERRO] BACKUP NAO FOI CRIADO.
pause & exit /b 1

:AUTOSAVE_ERR_EMPTY
echo [ERRO] BACKUP VAZIO.
pause & exit /b 1

:AUTOSAVE_ERR_REGADD
echo [ERRO] FALHA AO ALTERAR REGISTRO. Verifique permissoes.
pause & exit /b 1

:CONTINUAR_PROCESSO
REM /////////////////////////////////// INICIO DA LOGICA DE PASTAS //////////////////////////////////

set "PEDIDOS_DIRNAME=- PEDIDOS"
set "PEDIDOS=%ROOT%\%PEDIDOS_DIRNAME%"

if not exist "%PEDIDOS%" (
  echo.
  echo [ERRO] Nao achei a pasta de pedidos: "%PEDIDOS%"
  pause
  exit /b 1
)

REM Achar PDFCreator-cli.exe
set "PDFCLI="
for /f "delims=" %%I in ('where pdfcreator-cli.exe 2^>nul') do set "PDFCLI=%%I"
if exist "C:\Program Files\PDFCreator\PDFCreator-cli.exe" set "PDFCLI=C:\Program Files\PDFCreator\PDFCreator-cli.exe"
if exist "C:\Program Files (x86)\PDFCreator\PDFCreator-cli.exe" set "PDFCLI=C:\Program Files (x86)\PDFCreator\PDFCreator-cli.exe"

if "%PDFCLI%"=="" (
  echo [ERRO] PDFCreator-cli.exe nao encontrado.
  pause & exit /b 1
)

set "SCRIPTDIR=%~dp0"
set "PS_NORM=%SCRIPTDIR%normalizar_acertos.ps1"
set "PS_COPY=%SCRIPTDIR%copiar_pedidos.ps1"
set "PS_MERGE=%SCRIPTDIR%merge_pastas.ps1"
set "PS_FIN=%SCRIPTDIR%finalizar_limpeza.ps1"

REM Validação de arquivos PS1
if not exist "%PS_NORM%" ( echo [ERRO] Falta: %PS_NORM% & pause & exit /b 1 )
if not exist "%PS_COPY%" ( echo [ERRO] Falta: %PS_COPY% & pause & exit /b 1 )
if not exist "%PS_MERGE%" ( echo [ERRO] Falta: %PS_MERGE% & pause & exit /b 1 )
if not exist "%PS_FIN%"  ( echo [ERRO] Falta: %PS_FIN%  & pause & exit /b 1 )

REM (1/6) Normalizar
cls
echo (1/6) NORMALIZAR ACERTOS...
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_NORM%" -Root "%ROOT%"
if errorlevel 1 ( echo [ERRO] Passo 1 falhou. & pause & exit /b 1 )

REM (2/6) Prefixar pedidos
echo (2/6) RENOMEAR PEDIDOS...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$p='%PEDIDOS%';" ^
  "$pdfs=Get-ChildItem -LiteralPath $p -Filter '*.pdf' -File -ErrorAction SilentlyContinue;" ^
  "if(-not $pdfs){ exit 0 };" ^
  "foreach($f in $pdfs){ if($f.Name -notmatch '^2\.'){ Rename-Item -LiteralPath $f.FullName -NewName ('2.'+$f.Name) -Force } }"
if errorlevel 1 ( echo [ERRO] Passo 2 falhou. & pause & exit /b 1 )

REM (3/6) Criar pastas
echo (3/6) CRIAR PASTAS POR ACERTO...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$root='%ROOT%';" ^
  "function SafeName([string]$n){ $inv=[Regex]::Escape([string]::Join('',[IO.Path]::GetInvalidFileNameChars())); return ($n -replace '['+$inv+']','').Trim() };" ^
  "$acertos=Get-ChildItem -LiteralPath $root -Filter '1.*.pdf' -File;" ^
  "foreach($a in $acertos){ $folder=SafeName($a.BaseName); $dir=Join-Path $root $folder; if(-not(Test-Path -LiteralPath $dir)){ New-Item -ItemType Directory -Path $dir }; Move-Item -LiteralPath $a.FullName -Destination $dir -Force }"
if errorlevel 1 ( echo [ERRO] Passo 3 falhou. & pause & exit /b 1 )

REM (4/6) Copiar Pedidos
echo (4/6) COPIANDO PEDIDOS (SIMILARIDADE)...
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_COPY%" -Root "%ROOT%" -PedidosDirName "%PEDIDOS_DIRNAME%" -Threshold 0.90
if errorlevel 1 ( echo [ERRO] Passo 4 falhou. & pause & exit /b 1 )

cls

REM (5/6) Merge
color 0E
echo.
echo  ###################################################################################
echo  #                                                                                 #
echo  #  ######  ####  #####  ###### #####    ##   #    # #####   ####                  #
echo  #  #      #    # #    # #      #    #  #  #  ##   # #    # #    #                 #
echo  #  #####   ####  #    # #####  #    # #    # # #  # #    # #    #                 #
echo  #  #           # #####  #      #####  ###### #  # # #    # #    #                 #
echo  #  #      #    # #      #      #   #  #    # #   ## #    # #    #                 #
echo  #  ######  ####  #      ###### #    # #    # #    # #####   ####                  #
echo  #                                                                                 #
echo  #              #    #  ####  #####   ##    ####                                   #
echo  #              ##   # #    #   #    #  #  #                                       #
echo  #              # #  # #    #   #   #    #  ####                                   #
echo  #              #  # # #    #   #   ######      #                                  #
echo  #              #   ## #    #   #   #    # #    #                                  #
echo  #              #    #  ####    #   #    #  ####                                   #
echo  #                                                                                 #
echo  #                    ###### #  ####   ####    ##   #  ####                        #
echo  #                    #      # #      #    #  #  #  # #                            #
echo  #                    #####  #  ####  #      #    # #  ####                        #
echo  #                    #      #      # #      ###### #      #                       #
echo  #                    #      # #    # #    # #    # # #    #                       #
echo  #                    #      #  ####   ####  #    # #  ####                        #
echo  #                                                                                 #
echo  ###################################################################################
echo.
echo   DICA: Insira as Notas Fiscais nas pastas e pressione qualquer tecla para continuar.
echo.

pause
color 0F

cls

echo (5/6) MESCLAR PDFs...
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_MERGE%" -Root "%ROOT%" -Cli "%PDFCLI%" -PedidosDirName "%PEDIDOS_DIRNAME%" -ProfileName "Default"
if errorlevel 1 (
  echo [ERRO] Falha no Merge. O passo 6 nao sera executado para seguranca.
  pause & exit /b 1
)

REM (6/6) Finalizar e Restaurar
echo (6/6) FINALIZAR E LIMPAR...
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_FIN%" -Root "%ROOT%" -PedidosDirName "%PEDIDOS_DIRNAME%"

REM Restaurar Registro PDFCreator
echo Restaurando configuracoes originais do PDFCreator...
taskkill /IM PDFCreator.exe /F >nul 2>nul
reg import "%BK_LAST%" >nul

echo.
echo ============================================
echo  PROCESSO CONCLUIDO COM SUCESSO!
echo ============================================
pause
exit /b 0
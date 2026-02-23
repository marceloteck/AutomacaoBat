@echo off
chcp 65001 >nul
title Criador de Estrutura do Projeto

echo ========================================
echo  CRIANDO ESTRUTURA DO PROJETO
echo ========================================
echo.

REM Pasta base (onde o .bat estiver)
set "BASE=%~dp0"

REM Remove barra final se existir
if "%BASE:~-1%"=="\" set "BASE=%BASE:~0,-1%"

REM ==============================
REM Criar pastas
REM ==============================
echo Criando pastas...

mkdir "%BASE%\app"        >nul 2>&1
mkdir "%BASE%\public"     >nul 2>&1
mkdir "%BASE%\storage"    >nul 2>&1
mkdir "%BASE%\backup"     >nul 2>&1

REM ==============================
REM Criar arquivos app
REM ==============================
echo Criando arquivos PHP...

type nul > "%BASE%\app\config.php"
type nul > "%BASE%\app\lib.php"
type nul > "%BASE%\app\gerar.php"
type nul > "%BASE%\app\editar.php"
type nul > "%BASE%\app\salvar.php"
type nul > "%BASE%\app\placas_api.php"

REM ==============================
REM Criar index.php
REM ==============================
type nul > "%BASE%\public\index.php"

REM ==============================
REM Criar placas.json
REM ==============================
type nul > "%BASE%\storage\placas.json"

REM ==============================
REM Criar iniciar.bat
REM ==============================
type nul > "%BASE%\iniciar.bat"

REM ==============================
REM Mensagem final
REM ==============================
echo.
echo ========================================
echo  ESTRUTURA CRIADA COM SUCESSO!
echo ========================================
echo.
echo Pastas e arquivos prontos.
echo.

pause
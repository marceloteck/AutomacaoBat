# === FIXAR CONSOLE NO TOPO (mais confiavel) ===
Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class WinTop {
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();

    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool SetWindowPos(
        IntPtr hWnd,
        IntPtr hWndInsertAfter,
        int X, int Y, int cx, int cy,
        uint uFlags
    );
}
"@

$HWND_TOPMOST   = [IntPtr](-1)
$SWP_NOMOVE     = 0x0002


$SWP_NOSIZE     = 0x0001
$SWP_SHOWWINDOW = 0x0040

# espera o console existir
$hWnd = [IntPtr]::Zero
for ($i=0; $i -lt 25 -and $hWnd -eq [IntPtr]::Zero; $i++) {
    Start-Sleep -Milliseconds 200
    $hWnd = [WinTop]::GetConsoleWindow()
}

if ($hWnd -ne [IntPtr]::Zero) {
    [void][WinTop]::SetWindowPos($hWnd, $HWND_TOPMOST, 0,0,0,0, $SWP_NOMOVE -bor $SWP_NOSIZE -bor $SWP_SHOWWINDOW)
} else {
    Write-Host "[AVISO] Nao consegui pegar a janela do console para fixar no topo."
}


###################### CHAMADA DA click_positions

$lib = Join-Path $PSScriptRoot "click_positions.ps1"
. $lib
###################### 

Add-Type -AssemblyName System.Windows.Forms

function Send-Key {
    param([string]$keys)
    [System.Windows.Forms.SendKeys]::SendWait($keys)
}

function Set-ClipText {
    param([string]$text)
    if ($null -eq $text) { $text = "" }
    Set-Clipboard -Value $text
}

function Ask-YesNo {
    param([string]$Prompt = "Iniciar este produtor? (S/N)")
    while ($true) {
        $ans = Read-Host $Prompt
        if ($null -eq $ans) { $ans = "" }
        $ans = $ans.Trim().ToUpperInvariant()
        if ($ans -eq "S") { return $true }
        if ($ans -eq "N") { return $false }
        Write-Host "Digite apenas S ou N." -ForegroundColor Yellow
    }
}

function Countdown-3s {
    Write-Host ""
    Write-Host "CLIQUE AGORA NA JANELA DO SISTEMA (ela precisa ficar em foco)..." -ForegroundColor Yellow
    Start-Sleep -Milliseconds 200
    for ($i = 3; $i -ge 1; $i--) {
        [console]::beep(900,150)
        Write-Host ("Executando em {0}..." -f $i) -ForegroundColor Cyan
        Start-Sleep -Seconds 1
    }
    [console]::beep(1200,200)
    Write-Host "ENVIANDO TECLAS..." -ForegroundColor Cyan
}

function Parse-NotasIni {
    param([string]$path)

    if (!(Test-Path -LiteralPath $path)) { throw "Nao achei o arquivo: $path" }

    $lines = Get-Content -LiteralPath $path

    $items = New-Object System.Collections.Generic.List[object]
    $cur = $null
    $inProducer = $false

    foreach ($raw in $lines) {
        if ($null -eq $raw) { $raw = "" }
        $line = $raw.Trim()
        if ($line -eq "") { continue }

        if ($line -match '^\[(.+)\]$') {
            $section = $matches[1].Trim().ToUpperInvariant()

            if ($cur -ne $null -and -not [string]::IsNullOrWhiteSpace($cur.PEDIDO)) {
                $items.Add([pscustomobject]$cur)
            }

            $cur = @{
                SECAO     = $section
                NOME      = ""
                STATUS    = ""
                TIPO      = ""
                INSTRUCAO = ""
                PEDIDO    = ""
                NOTAS     = ""
            }

            $inProducer = ($section -eq "PRODUTOR")
            continue
        }

        if (-not $inProducer -or $cur -eq $null) { continue }

        if ($line -match '^NOTAS\s*:\s*(.*)$') {
            $cur.NOTAS = $matches[1].Trim()
            continue
        }

        if ($line -match '^([A-Za-zÇçÃãÕõÉéÍíÓóÚú_]+)\s*=\s*(.*)$') {
            $k = $matches[1].Trim().ToUpperInvariant()
            $v = $matches[2].Trim()
            switch ($k) {
                "NOME"      { $cur.NOME = $v; break }
                "STATUS"    { $cur.STATUS = $v; break }
                "TIPO"      { $cur.TIPO = $v; break }
                "INSTRUCAO" { $cur.INSTRUCAO = $v; break }
                "INSTRUÇÃO" { $cur.INSTRUCAO = $v; break }
                "PEDIDO"    { $cur.PEDIDO = $v; break }
                default     { break }
            }
        }
    }

    if ($cur -ne $null -and -not [string]::IsNullOrWhiteSpace($cur.PEDIDO)) {
        $items.Add([pscustomobject]$cur)
    }

    return $items
}

# ---- MAIN ----
$ScriptDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ScriptDir)) { $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$BaseDir = Split-Path -Parent $ScriptDir
$NotasPath = Join-Path $BaseDir "input\pec\faturarF7F3.txt"

try { $lista = Parse-NotasIni $NotasPath }
catch { Write-Host ("ERRO: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }

if ($lista.Count -eq 0) {
    Write-Host "Nada para executar (nenhum [PRODUTOR] com PEDIDO encontrado)." -ForegroundColor Yellow
    exit 0
}

# ================================
# SendKeys
# ================================
Add-Type -AssemblyName System.Windows.Forms

function Press-Key([string]$k) { [System.Windows.Forms.SendKeys]::SendWait($k) }
function SleepMs([int]$ms) { Start-Sleep -Milliseconds $ms }

function Paste-Text([string]$text) {
  Set-Clipboard -Value $text
  Press-Key("^v")
}


Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " AUTOMACAO: COLAR INSTRUCAO" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Obs: O NOME fica no clipboard para voce Ctrl+V manualmente." -ForegroundColor Cyan
Write-Host ""

function Countdown {
    param(
        [int]$Seconds = 3,
        [ConsoleColor]$Color = "Yellow"
    )

    for ($i = $Seconds; $i -ge 1; $i--) {
        Write-Host $i -ForegroundColor $Color
        Start-Sleep -Seconds 1
    }
}

# ================================
# PERGUNTAR TIPO DE FATURAMENTO
# ================================
$TipoFaturamento = ""

while ($TipoFaturamento -notin @("3","7")) {
    $TipoFaturamento = (Read-Host "Qual o tipo de faturamento? (Digite 3 para FASE 3 ou 7 para FASE 7)").Trim()

    if ($TipoFaturamento -notin @("3","7")) {
        Write-Host "Digite apenas 3 ou 7." -ForegroundColor Yellow
    }
}


Write-Host ("FASE selecionada: {0}" -f $TipoFaturamento) -ForegroundColor Green


# ================================
# FLUXO ERP
# ================================
Invoke-ClickPos -Name "ABRIR_TELA_FATURAMENTO_ERP"
SleepMs 200

Invoke-ClickPos -Name "CLICAR_INPUT_FASE7OR3"
SleepMs 150

Press-Key("^a")     # limpa o campo
SleepMs 50

Paste-Text $TipoFaturamento
SleepMs 150

Invoke-ClickPos -Name "CLICAR_FILTRO_FATURADO_OUNAO"
SleepMs 100
Invoke-ClickPos -Name "SELECIONAR_NAO_FATURADO"
SleepMs 150


Invoke-DoubleClickPos -Name "CLICAR_FATURAMENTO_DATA2"
SleepMs 150
Invoke-DoubleClickPos -Name "CLICAR_FATURAMENTO_DATA1"


Press-Key("{F3}")


Countdown -Seconds 2

Invoke-ClickPos -Name "ABRIR_FILTRO_COLAR_INSTRUCAO"
SleepMs 200
Invoke-ClickPos -Name "FOCAR_IMPUT_FILTRO"

foreach ($p in $lista) {

    $nome = $p.NOME
    $instrucao = $p.INSTRUCAO

    Write-Host ""
    Write-Host ("PRODUTOR: {0}" -f $nome) -ForegroundColor Green
    Write-Host ("INSTRUCAO: {0}" -f $instrucao) -ForegroundColor Green

    # Copia
    #Set-ClipText $instrucao
    #Set-ClipText $instrucao

    Press-Key("^A")
    Paste-Text $instrucao
    Press-Key("{ENTER}")
    SleepMs 30
    Invoke-ClickPos -Name "CLICAR_INSTRUCAO"

    Start-Sleep 1
    Press-Key("+{TAB}")


    # Espera pra voce colar no sistema
    Countdown -Seconds 1
    
}
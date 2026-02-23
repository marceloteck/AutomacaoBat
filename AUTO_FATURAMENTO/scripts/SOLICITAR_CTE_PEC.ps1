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

function Paste-CurrentDateBR {
  param(
    [int]$DelayAfterMs = 60
  )

  $date = (Get-Date).ToString("dd/MM/yyyy")
  Set-Clipboard -Value $date
  [System.Windows.Forms.SendKeys]::SendWait("^v")
  Start-Sleep -Milliseconds $DelayAfterMs
}

function Type-CurrentDateBR {
    param(
        [int]$DelayAfterMs = 60
    )

    $date = (Get-Date).ToString("dd/MM/yyyy")

    foreach ($char in $date.ToCharArray()) {
        [System.Windows.Forms.SendKeys]::SendWait($char)
        Start-Sleep -Milliseconds 10
    }

    Start-Sleep -Milliseconds $DelayAfterMs
}


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

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " AUTOMACAO: SOLICITAR CTE" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Obs: O NOME fica no clipboard para voce Ctrl+V manualmente." -ForegroundColor Cyan
Write-Host ""


Countdown -Seconds 3

Invoke-ClickPos -Name "ABRIR_TELA_CTE_ERP"
SleepMs 1000

Invoke-ClickPos -Name "CLICAR_INPUT_DATA1"
SleepMs 50
Press-Key("^A")
SleepMs 50
Type-CurrentDateBR

Press-Key("{TAB}")
SleepMs 50
Press-Key("^A")
SleepMs 50

Type-CurrentDateBR
SleepMs 800

Invoke-ClickPos -Name "CLICAR_CTE_SELECIONARTODOS"

SleepMs 900
Press-Key("{F4}")

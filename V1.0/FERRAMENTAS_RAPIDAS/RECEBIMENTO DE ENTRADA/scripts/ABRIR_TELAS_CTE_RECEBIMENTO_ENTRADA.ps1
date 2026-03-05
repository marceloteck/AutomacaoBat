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



# ===============================
# CHAMADA click_positions.ps1
# ===============================
# $lib = Join-Path $PSScriptRoot "click_positions.ps1"
$lib = Join-Path $PSScriptRoot "..\..\..\AUTO_FATURAMENTO\scripts\click_positions.ps1"

if (Test-Path -LiteralPath $lib) {
    . $lib
} else {
    Write-Host "[ERRO] Nao achei click_positions.ps1 em: $lib" -ForegroundColor Red
    exit 2
}



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
$NotasPath = Join-Path $BaseDir "input\ABRIR_TELAS_CTE_RECEBIMENTO_ENTRADA.txt"

try { $lista = Parse-NotasIni $NotasPath }
catch { Write-Host ("ERRO: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }

if ($lista.Count -eq 0) {
    Write-Host "Nada para executar (nenhum [PRODUTOR] com PEDIDO encontrado)." -ForegroundColor Yellow
    exit 0
}

###########

Add-Type -AssemblyName UIAutomationClient

function Test-IsEditableFocusedElement {

    try {
        $focused = [System.Windows.Automation.AutomationElement]::FocusedElement
        if ($null -eq $focused) { return $false }

        $controlType = $focused.Current.ControlType.ProgrammaticName

        # Tipos comuns de campo editável
        if ($controlType -match "Edit" -or
            $controlType -match "Document") {
            return $true
        }

        # Verifica se suporta ValuePattern (campo que aceita texto)
        $pattern = $null
        if ($focused.TryGetCurrentPattern(
            [System.Windows.Automation.ValuePattern]::Pattern,
            [ref]$pattern)) {
            return $true
        }

        return $false
    }
    catch {
        return $false
    }
}



function Paste-Text([string]$text) {

    # Espera até o foco estar em campo editável (máx 5s)
    $timeout = 5000
    $elapsed = 0

    while (-not (Test-IsEditableFocusedElement)) {
        Start-Sleep -Milliseconds 100
        $elapsed += 100
        if ($elapsed -ge $timeout) {
            Write-Host "[ERRO] Campo de texto não detectado." -ForegroundColor Red
            return
        }
    }

    Set-Clipboard -Value $text
    Press-Key("^v")
}

##########

function Press-Key([string]$k) { [System.Windows.Forms.SendKeys]::SendWait($k) }
function SleepMs([int]$ms) { Start-Sleep -Milliseconds $ms }




######################################### EXECUÇÃO AQUI ABAIXO
# ================================
# LISTA DE REPETIÇÕES
# ================================
$repeticoes = @(
    "cCOSP214",
    "cCOLG270",
    "cCoft252",
    "cCOFT240",
    "cFBED210",
    "cCOFT222"
)




    Invoke-ClickPos -Name "clicar_nocentro_"
    SleepMs 50

    # ALT + F10
    Press-Key("%{F10}")
    SleepMs 1200


    Invoke-ClickPos -Name "clicar_EMSIM_"

    SleepMs 2000

# ================================
# LOOP PRINCIPAL
# ================================
foreach ($rep in $repeticoes) {

    Write-Host "Executando: $rep" -ForegroundColor Cyan

    Invoke-ClickPos -Name "clicar_buscar_"
    SleepMs 800

    # ===== PRIMEIRO COLAR =====
    Paste-Text "TEXTO"
    SleepMs 50

    Press-Key("{ENTER}")
    SleepMs 1200

    Invoke-ClickPos -Name "clicar_buscar_2"
    SleepMs 800

    Press-Key("^a")
    SleepMs 300


    # ===== SEGUNDO COLAR =====
    Paste-Text $rep
    SleepMs 50

    Press-Key("{ENTER}")
    SleepMs 1000


    Invoke-ClickPos -Name "clicar_abrir_aba_1"
    Write-Host "Finalizado: $rep" -ForegroundColor Green

}

Write-Host "TODAS AS REPETIÇÕES CONCLUÍDAS!" -ForegroundColor Yellow

    


######################################### EXECUÇÃO AQUI ACIMA
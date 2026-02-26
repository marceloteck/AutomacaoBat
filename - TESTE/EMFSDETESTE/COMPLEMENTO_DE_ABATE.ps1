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
$lib = Join-Path $PSScriptRoot "click_positions.ps1"
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
$NotasPath = Join-Path $BaseDir "input\pec\COMPLEMENTO_DE_ABATE.txt"

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


Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " AUTOMACAO: F3 -> PEDIDO -> ENTER -> F11" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Obs: O NOME fica no clipboard para voce Ctrl+V manualmente." -ForegroundColor Cyan
Write-Host ""

# ================================
# PEDIR DIRETORIO (ANTES DO LOOP)
# ================================
$saveDir = ""
while ([string]::IsNullOrWhiteSpace($saveDir)) {
    $saveDir = Read-Host "Informe o DIRETORIO para salvar/imprimir (ex: C:\Pedidos\2026\02)"
    if ([string]::IsNullOrWhiteSpace($saveDir)) {
        Write-Host "Diretorio vazio. Tente novamente." -ForegroundColor Yellow
        continue
    }
    $saveDir = $saveDir.Trim().Trim('"')
}

# Se quiser validar que existe (opcional). Se não existir, cria.
if (-not (Test-Path -LiteralPath $saveDir)) {
    try {
        New-Item -ItemType Directory -Path $saveDir -Force | Out-Null
        Write-Host "[OK] Diretorio criado: $saveDir" -ForegroundColor Green
    } catch {
        Write-Host "[ERRO] Nao consegui criar/usar o diretorio: $saveDir" -ForegroundColor Red
        exit 2
    }
}

$dirPastedOnce = $false

# ================================
# LOOP PRINCIPAL
# ================================
foreach ($p in $lista) {
    $nome   = $p.NOME
    $pedido = $p.PEDIDO
    $instrucao = $p.INSTRUCAO


    # Invoke-DoubleClickPos -Name "NOME_DO_CLICK"
    # Invoke-ClickPos -Name "CLICAR_IMPRIMIR_PEDIDO"
    # Set-ClipText $saveDir
    # Paste-Text $saveDir
    # Invoke-RightClickPos -Name "MENU_OPCOES"

    Write-Host ""
    Write-Host ("PRODUTOR: {0}" -f $nome) -ForegroundColor Green
    Write-Host ("PEDIDO:   {0}" -f $pedido) -ForegroundColor Green

    if (-not (Ask-YesNo "Iniciar este produtor? (S/N)")) {
        Write-Host "PULADO." -ForegroundColor Yellow
        continue
    }

    # ================================
    # ABRIR/EXECUTAR TELA NFE
    # ================================
    


    # ========================================================
    # ABRIR/EXECUTAR TELA DOCUMENTO SIMPLIFICADO ANTIGO
    # ========================================================
    


    
    # ============================================
    # ABRIR/EXECUTAR TELA ROMANEIO DE ABATE
    # ============================================


  


    # ========================================================
    # COPIAR NOME DO PECUARISTA NA AREA DE TRANSFERENCIA
    # ========================================================    







    [void](Read-Host "Quando terminar, pressione Enter para o proximo")
}
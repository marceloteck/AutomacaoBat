# ==========================================
# Cadastrar_freteGr_jbs.ps1  (PS 5.1 OK)
# Lê TXT com [PRODUTOR] + blocos { } e executa automação
# ==========================================

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



# ================================
# SendKeys / Clipboard (PS 5.1)
# ================================
Add-Type -AssemblyName System.Windows.Forms

function Press-Key([string]$k) { [System.Windows.Forms.SendKeys]::SendWait($k) }
function SleepMs([int]$ms) { Start-Sleep -Milliseconds $ms }

function Paste-Text([string]$text) {
    if ($null -eq $text) { $text = "" }
    Set-Clipboard -Value $text
    Press-Key("^v")
}

function Countdown {
    param([int]$Seconds = 3)
    Write-Host ""
    Write-Host "CLIQUE AGORA NA JANELA DO SISTEMA (ela precisa ficar em foco)..." -ForegroundColor Yellow
    Start-Sleep -Milliseconds 200
    for ($i = $Seconds; $i -ge 1; $i--) {
        [console]::beep(900,150)
        Write-Host ("Executando em {0}..." -f $i) -ForegroundColor Cyan
        Start-Sleep -Seconds 1
    }
    [console]::beep(1200,200)
    Write-Host "ENVIANDO TECLAS..." -ForegroundColor Cyan
}

function Nz([object]$v) {
    if ($null -eq $v) { return "" }
    return [string]$v
}

# ==========================================
# Repetição tipo 2799317X3 / 27X5
# ==========================================
function Parse-RepeatToken([string]$s) {
    $t = (Nz $s).Trim()
    if ($t -eq "") { return $null }

    if ($t -match '^\s*(.+?)\s*[xX]\s*(\d+)\s*$') {
        return @{
            value = $matches[1].Trim()
            count = [int]$matches[2]
        }
    }

    return @{
        value = $t
        count = 1
    }
}

function Paste-RepeatDown {
    param(
        [string[]]$tokens,
        [int]$afterPasteDelayMs = 40
    )

    if ($null -eq $tokens) { return }

    foreach ($tk in $tokens) {
        $rr = Parse-RepeatToken $tk
        if ($null -eq $rr) { continue }

        for ($i=1; $i -le $rr.count; $i++) {
            Paste-Text $rr.value
            SleepMs $afterPasteDelayMs
            Press-Key("{DOWN}")
            SleepMs $afterPasteDelayMs
        }
    }
}

# ==========================================
# Parser do TXT (formato do seu exemplo)
# ==========================================
function Parse-ProducersTxt {
    param([string]$path)

    if (!(Test-Path -LiteralPath $path)) { throw "Nao achei o arquivo: $path" }

    $lines = Get-Content -LiteralPath $path

    $items = New-Object System.Collections.Generic.List[object]
    $cur = $null
    $mode = ""   # "", "GRorJBS", "QUANT_MINUTAS", "PLACAS"
    $inProducer = $false
    $pendingBlock = ""  # "GRorJBS" ou "QUANT_MINUTAS" quando vier '=' e a chave '{' vem na linha seguinte

    function New-Producer {
        return @{
            SECAO         = "PRODUTOR"
            NOME          = ""
            STATUS        = ""
            TIPO          = ""
            INSTRUCAO     = ""
            PEDIDO        = ""
            GRorJBS       = New-Object System.Collections.Generic.List[string]
            QUANT_MINUTAS = New-Object System.Collections.Generic.List[string]
            PLACAS        = New-Object System.Collections.Generic.List[string]
        }
    }

    function Flush-Current {
        if ($cur -ne $null -and -not [string]::IsNullOrWhiteSpace((Nz $cur.PEDIDO))) {
            $items.Add([pscustomobject]@{
                SECAO         = $cur.SECAO
                NOME          = $cur.NOME
                STATUS        = $cur.STATUS
                TIPO          = $cur.TIPO
                INSTRUCAO     = $cur.INSTRUCAO
                PEDIDO        = $cur.PEDIDO
                GRorJBS       = @($cur.GRorJBS)
                QUANT_MINUTAS = @($cur.QUANT_MINUTAS)
                PLACAS        = @($cur.PLACAS)
            })
        }
    }

    foreach ($raw in $lines) {
        if ($null -eq $raw) { $raw = "" }
        $line = $raw.Trim()

        if ($line -eq "") { continue }
        if ($line.StartsWith("#") -or $line.StartsWith(";")) { continue }

        # nova seção
        if ($line -match '^\[(.+)\]$') {
            $section = $matches[1].Trim().ToUpperInvariant()

            Flush-Current

            $cur = $null
            $mode = ""
            $pendingBlock = ""
            $inProducer = $false

            if ($section -eq "PRODUTOR") {
                $cur = New-Producer
                $inProducer = $true
            }
            continue
        }

        if (-not $inProducer -or $cur -eq $null) { continue }

        # fechamento de bloco { }
        if ($line -eq "}") {
            $mode = ""
            $pendingBlock = ""
            continue
        }

        # abertura de bloco { } na linha seguinte ao "GRorJBS=" ou "QUANT_MINUTAS="
        if ($line -eq "{") {
            if ($pendingBlock -ne "") {
                $mode = $pendingBlock
                $pendingBlock = ""
            }
            continue
        }

        # dentro do bloco { ... }
        if ($mode -ne "") {
            if ($mode -eq "GRorJBS")       { $cur.GRorJBS.Add($line); continue }
            if ($mode -eq "QUANT_MINUTAS") { $cur.QUANT_MINUTAS.Add($line); continue }
            continue
        }

        # PLACAS:
        if ($line -match '^PLACAS\s*:\s*(.*)$') {
            $mode = "PLACAS"
            $rest = $matches[1].Trim()
            if ($rest -ne "") { $cur.PLACAS.Add($rest) }
            continue
        }

        # lendo placas até mudar seção
        if ($mode -eq "PLACAS") {
            $cur.PLACAS.Add($line)
            continue
        }

        # GRorJBS=
        if ($line -match '^GRorJBS\s*=\s*(.*)$') {
            $rest = $matches[1].Trim()
            if ($rest -eq "{") { $mode = "GRorJBS"; continue }
            if ($rest -eq "")  { $pendingBlock = "GRorJBS"; continue }
            $cur.GRorJBS.Add($rest)
            continue
        }

        # QUANT_MINUTAS=
        if ($line -match '^QUANT_MINUTAS\s*=\s*(.*)$') {
            $rest = $matches[1].Trim()
            if ($rest -eq "{") { $mode = "QUANT_MINUTAS"; continue }
            if ($rest -eq "")  { $pendingBlock = "QUANT_MINUTAS"; continue }
            $cur.QUANT_MINUTAS.Add($rest)
            continue
        }

        # chaves simples
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
            continue
        }
    }

    Flush-Current
    return $items
}

# ==========================================
# MAIN
# ==========================================
$ScriptDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ScriptDir)) {
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}
$BaseDir = Split-Path -Parent $ScriptDir

$TXTPath = Join-Path $BaseDir "input\pec\CadastrarPlacasVeiculo.txt"

try {
    $lista = Parse-ProducersTxt $TXTPath
} catch {
    Write-Host ("ERRO: " + $_.Exception.Message) -ForegroundColor Red
    exit 1
}

if ($lista.Count -eq 0) {
    Write-Host "Nada para executar (nenhum [PRODUTOR] com PEDIDO encontrado)." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " AUTOMACAO PECUARIA (PEDIDO)" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host ("Arquivo: {0}" -f $TXTPath) -ForegroundColor DarkGray
Write-Host "Abra o sistema e deixe a tela pronta." -ForegroundColor Yellow

Countdown -Seconds 3

# Ajuste: abre a tela alvo
Invoke-ClickPos -Name "ABRIR_TELA_CONTRATACAO_VEICULO_ERP"
SleepMs 2000

foreach ($p in $lista) {

    $nome = (Nz $p.NOME).Trim()
    $instrucao = (Nz $p.INSTRUCAO).Trim()

    Write-Host ""
    Write-Host ("PRODUTOR:   {0}" -f $nome) -ForegroundColor Green
    Write-Host ("INSTRUCAO:  {0}" -f $instrucao) -ForegroundColor Green

    # 1) Pesquisa/abre pela instrução
    Press-Key("{F7}")
    SleepMs 80
    Paste-Text $instrucao
    SleepMs 80
    Press-Key("{ENTER}")
    Press-Key("{ENTER}")

    SleepMs 250

    # 2) Seleciona primeira linha/campo alvo
    Invoke-ClickPos -Name "SELECIONAR_PRIMEIRA_PLACA"
    SleepMs 150

    # === GRorJBS (colar e descer)
    if ($p.GRorJBS -ne $null -and $p.GRorJBS.Count -gt 0) {
        Paste-RepeatDown -tokens $p.GRorJBS -afterPasteDelayMs 40
        SleepMs 120
    }

    # Navegação do seu fluxo (ajuste se precisar)
    Press-Key("{HOME}")
    SleepMs 60
    Press-Key("{TAB}")
    SleepMs 60
    Press-Key("{TAB}")
    SleepMs 150

    # === QUANT_MINUTAS (colar e descer)
    if ($p.QUANT_MINUTAS -ne $null -and $p.QUANT_MINUTAS.Count -gt 0) {
        Paste-RepeatDown -tokens $p.QUANT_MINUTAS -afterPasteDelayMs 40
        SleepMs 120
    }

    # Volta para campo de placas (ajuste conforme sua tela)
    Press-Key("+{TAB}")
    SleepMs 150

    # === PLACAS (uma por linha, descendo)
    if ($p.PLACAS -ne $null -and $p.PLACAS.Count -gt 0) {
        foreach ($pl in $p.PLACAS) {
            $vv = (Nz $pl).Trim()
            if ($vv -eq "") { continue }
            Paste-Text $vv
            SleepMs 40
            Press-Key("{DOWN}")
            SleepMs 40
        }
    }


    Press-Key("{F4}")
    SleepMs 2000
    Invoke-ClickPos -Name "FECHAR_TELA_FRETE"

    # ================================
    # CONFIRMACAO PROXIMO PRODUTOR
    # ================================
    if ($pIndex -lt ($lista.Count - 1)) {
        Write-Host ""
        if (-not (Ask-YesNo "PASSAR PARA O PROXIMO PRODUTOR? (S/N)")) {
            Write-Host "Parado pelo usuario."
            exit 3
        }
        Start-Sleep -Seconds 3
    }
}

Write-Host ""
Write-Host "[OK] Finalizado." -ForegroundColor Green
exit 0
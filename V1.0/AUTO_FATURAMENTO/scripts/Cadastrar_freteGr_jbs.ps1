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

function Paste-RepeatDownGrid {
    param(
        [string[]]$tokens,
        [int]$afterPasteDelayMs = 60,
        [int]$afterEnterDelayMs = 120
    )

    if ($null -eq $tokens) { return }

    foreach ($tk in $tokens) {
        $rr = Parse-RepeatToken $tk
        if ($null -eq $rr) { continue }

        for ($i = 1; $i -le $rr.count; $i++) {

            # cola valor
            Paste-Text $rr.value
            SleepMs $afterPasteDelayMs

            # desce só se NÃO for o último
            if ($i -lt $rr.count) {
                Press-Key("{DOWN}")
                SleepMs $afterPasteDelayMs
            }
        }
    }
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

            # Só desce se NÃO for o último
            if ($i -lt $rr.count) {
                Press-Key("{DOWN}")
                SleepMs $afterPasteDelayMs
            }
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
    $mode = ""          # "", "GRorJBS", "QUANT_MINUTAS", "PLACAS"
    $inProducer = $false
    $pendingBlock = ""  # "GRorJBS" ou "QUANT_MINUTAS"

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

        $reprocess = $true
        while ($reprocess) {
            $reprocess = $false

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

            # ===== dentro de PLACAS =====
            if ($mode -eq "PLACAS") {
                # se começou outra chave, sai do modo PLACAS e reprocessa a linha
                if ($line -match '^[A-Za-zÇçÃãÕõÉéÍíÓóÚú_]+\s*=' -or
                    $line -match '^(GRorJBS|QUANT_MINUTAS)\s*=' -or
                    $line -match '^\[.+\]$') {
                    $mode = ""
                    $reprocess = $true
                    continue
                }

                $cur.PLACAS.Add($line)
                continue
            }

            # ===== dentro de blocos { } =====
            if ($mode -ne "") {
                if ($mode -eq "GRorJBS")       { $cur.GRorJBS.Add($line); continue }
                if ($mode -eq "QUANT_MINUTAS") { $cur.QUANT_MINUTAS.Add($line); continue }
                continue
            }

            # PLACAS:
            if ($line -match '^PLACAS?\s*[:=]\s*(.*)$') {
                $mode = "PLACAS"
                $rest = $matches[1].Trim()
                if ($rest -ne "") { $cur.PLACAS.Add($rest) }
                continue
            }

            # GRorJBS=
            if ($line -match '^GRorJBS\s*=\s*(.*)$') {
                $rest = $matches[1].Trim()
                if ($rest -eq "{") { $mode = "GRorJBS"; continue }
                if ([string]::IsNullOrWhiteSpace($rest)) { $pendingBlock = "GRorJBS"; continue }
                $cur.GRorJBS.Add($rest)
                continue
            }

            # QUANT_MINUTAS=
            if ($line -match '^QUANT_MINUTAS\s*=\s*(.*)$') {
                $rest = $matches[1].Trim()
                if ($rest -eq "{") { $mode = "QUANT_MINUTAS"; continue }
                if ([string]::IsNullOrWhiteSpace($rest)) { $pendingBlock = "QUANT_MINUTAS"; continue }
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
    }

    Flush-Current
    return $items
}

function Ask-YesNo([string]$msg){
  $ans = Read-Host $msg
  return ($ans.Trim().ToUpper() -eq "S")
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



<# teste de erro
Write-Host "=== DEBUG PLACAS LIDAS DO TXT ===" -ForegroundColor Yellow
foreach ($p in $lista) {
  Write-Host ("NOME={0} | PLACAS_COUNT={1} | PLACAS={2}" -f $p.NOME, ($p.PLACAS.Count), ($p.PLACAS -join ", "))
}
pause
#>


Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " AUTOMACAO PECUARIA (PEDIDO)" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host ("Arquivo: {0}" -f $TXTPath) -ForegroundColor DarkGray
Write-Host "Abra o sistema e deixe a tela pronta." -ForegroundColor Yellow

Countdown -Seconds 3

# Ajuste: abre a tela alvo
 # Invoke-ClickPos -Name "ABRIR_TELA_CONTRATACAO_VEICULO_ERP"
 # SleepMs 1000

foreach ($p in $lista) {

    $nome = (Nz $p.NOME).Trim()
    $instrucao = (Nz $p.INSTRUCAO).Trim()

    Invoke-ClickPos -Name "FOCAR_NA_TELA_CADASTRAR_FRETE"


    if($p.status -eq "CONFIRMADO"){
        Write-Host ("[SKIP] PRODUTOR {0}/{1}: {2} ja esta CONFIRMADO - pulando." -f $pIndex, $producers.Count, $p.nome)
        continue
    }


    Write-Host ""
    Write-Host ("PRODUTOR:   {0}" -f $nome) -ForegroundColor Green
    Write-Host ("INSTRUCAO:  {0}" -f $instrucao) -ForegroundColor Green

    ######################################### execução aqui
    

    SleepMs 50
    Invoke-ClickPos -Name "CADASTRAR_PLACAS_LEFT_001_535_67"
    SleepMs 639
    Press-Key("{F7}")
    SleepMs 639
    Paste-Text $instrucao
    SleepMs 639
    Press-Key("{ENTER}")
    SleepMs 639
    Press-Key("{ENTER}")
    SleepMs 639
    Invoke-ClickPos -Name "CADASTRAR_PLACAS_LEFT_002_134_456"
    SleepMs 639
    
    # === GRorJBS (colar e descer)
    if ($p.GRorJBS -ne $null -and $p.GRorJBS.Count -gt 0) {
        Paste-RepeatDownGrid -tokens $p.GRorJBS -afterPasteDelayMs 60 -afterEnterDelayMs 120
        SleepMs 120
    }
    Press-Key("{PGUP}")
    Press-Key("{PGUP}")
    Press-Key("{PGUP}")
    Press-Key("{PGUP}")

    SleepMs 639
    Invoke-ClickPos -Name "CADASTRAR_PLACAS_LEFT_002_134_456"

    SleepMs 639
    Press-Key("{TAB}")
    SleepMs 639
    Press-Key("{TAB}")
    SleepMs 639
    
    
    # === QUANT_MINUTAS (colar e descer)
    if ($p.QUANT_MINUTAS -ne $null -and $p.QUANT_MINUTAS.Count -gt 0) {
        Paste-RepeatDownGrid -tokens $p.QUANT_MINUTAS -afterPasteDelayMs 120 -afterEnterDelayMs 120
        SleepMs 120
    }
    Press-Key("{PGUP}")
    Press-Key("{PGUP}")
    Press-Key("{PGUP}")
    Press-Key("{PGUP}")    


    
    SleepMs 639
    Press-Key("+{TAB}")
    SleepMs 639



# === PLACAS (força foco + modo edição)
if ($p.PLACAS -ne $null -and $p.PLACAS.Count -gt 0) {

    # clica UMA vez na primeira linha/célula do grid
    Invoke-ClickPos -Name "CLICAR_ADD_PLACAS_CONTRATACAO_VEICULO"
    SleepMs 250

    for ($i=0; $i -lt $p.PLACAS.Count; $i++) {
        $vv = (Nz $p.PLACAS[$i]).Trim()
        if ($vv -eq "") { continue }

        # entra em edição
        Press-Key("A")
        SleepMs 200

        # limpa
        Press-Key("^a")
        SleepMs 120
        Press-Key("{DEL}")
        SleepMs 120

        # cola e confirma
        Paste-Text $vv
        SleepMs 250
        Press-Key("{ENTER}")
        Press-Key("{ENTER}")
        SleepMs 400

        # próxima linha
        if ($i -lt ($p.PLACAS.Count - 1)) {
            Press-Key("{DOWN}")
            SleepMs 250
        }
    }
}

    Press-Key("{PGUP}")
    Press-Key("{PGUP}")
    Press-Key("{PGUP}")
    Press-Key("{PGUP}")







# ===============================
# VALIDAR QUANT_MINUTAS (>20)
# ===============================
$maiorQue20 = $false

if ($p.QUANT_MINUTAS -ne $null -and $p.QUANT_MINUTAS.Count -gt 0) {
    foreach ($tk in $p.QUANT_MINUTAS) {

        $rr = Parse-RepeatToken $tk
        if ($null -eq $rr) { continue }

        # tenta converter valor para número
        $num = 0
        if ([int]::TryParse($rr.value, [ref]$num)) {
            if ($num -gt 20) {
                $maiorQue20 = $true
                break
            }
        }
    }
}

if ($maiorQue20) {
    Write-Host ""
    Write-Host "QUANT_MINUTAS acima de 20 detectado." -ForegroundColor Yellow
    Write-Host "FACA A EDICAO MANUAL E PRESSIONE ENTER PARA CONTINUAR..."
    Read-Host
}


SleepMs 100
    Invoke-ClickPos -Name "CADASTRAR_PLACAS_LEFT_001_535_67"

SleepMs 300
Press-Key("{F4}")
SleepMs 3000

Invoke-ClickPos -Name "FECHAR_TELA_DO_FRETE_CARREGANDO"

SleepMs 2000

Press-Key("{ENTER}")




    # até aqui ######################################### 
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
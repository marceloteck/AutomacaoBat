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

function Paste-RepeatDown {
    param(
        [string[]]$tokens,
        [int]$afterPasteDelayMs = 40,
        [int]$afterEnterDelayMs = 50
    )

    if ($null -eq $tokens -or $tokens.Count -eq 0) { return }

    # acha o último token válido (não vazio)
    $lastValid = -1
    for ($k = $tokens.Count - 1; $k -ge 0; $k--) {
        if ((Nz $tokens[$k]).Trim() -ne "") { $lastValid = $k; break }
    }
    if ($lastValid -lt 0) { return }

    for ($t = 0; $t -le $lastValid; $t++) {

        $tk = (Nz $tokens[$t]).Trim()
        if ($tk -eq "") { continue }

        $rr = Parse-RepeatToken $tk
        if ($null -eq $rr) { continue }

        for ($i = 1; $i -le $rr.count; $i++) {

            # cola
            Paste-Text $rr.value
            SleepMs 10

            # ✅ SEMPRE confirma a célula
            Press-Key("{ENTER}")
            SleepMs $afterEnterDelayMs

            $isLastRepeatOfThisToken = ($i -eq $rr.count)
            $isLastToken = ($t -eq $lastValid)
            $isLastOverall = ($isLastToken -and $isLastRepeatOfThisToken)

            # ✅ desce se ainda tem coisa pra preencher (mesmo token ou próximo token)
            if (-not $isLastOverall) {
                Press-Key("{DOWN}")
                SleepMs $afterPasteDelayMs
            }
            else {
                # ✅ você pediu: no último (ex.: 16X1) desce 1 linha e segue o fluxo sem colar mais
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



# =============================
# Função auxiliar: trata nulos
# =============================
function Nz {
    param($val)
    if ($null -eq $val) { return "" }
    return $val
}

# =============================
# Função para parsear tokens tipo 2799317x2
# =============================
function Parse-RepeatToken {
    param([string]$token)

    if ($token -match '^(.+?)x(\d+)$') {
        return [PSCustomObject]@{
            value = $matches[1].Trim()
            count = [int]$matches[2]
        }
    }
    return $null
}

# =============================
# Função que cola repetido e desce corretamente
# =============================
function Paste-RepeatDown {
    param(
        [string[]]$tokens,
        [int]$afterPasteDelayMs = 40
    )

    if ($null -eq $tokens -or $tokens.Count -eq 0) { return }

    for ($t = 0; $t -lt $tokens.Count; $t++) {

        $tk = (Nz $tokens[$t]).Trim()
        if ($tk -eq "") { continue }

        $rr = Parse-RepeatToken $tk
        if ($null -eq $rr) { continue }

        # Cola N vezes (Xn)
        for ($i = 1; $i -le $rr.count; $i++) {

            Paste-Text $rr.value
            SleepMs 10

            # Desce entre repetições do MESMO token (X2, X3...)
            if ($i -lt $rr.count) {
                SleepMs 50
                Press-Key("{DOWN}")
                SleepMs $afterPasteDelayMs
            }
        }

        # ✅ desce 1 linha apenas se existir um PRÓXIMO token não vazio
        $nextIdx = $t + 1
        while ($nextIdx -lt $tokens.Count) {
            $nextTk = (Nz $tokens[$nextIdx]).Trim()
            if ($nextTk -ne "") {

                SleepMs 50
                Press-Key("{DOWN}")
                SleepMs $afterPasteDelayMs
                break
            }
            $nextIdx++
        }
    }
}

# =============================
# Função que parseia o TXT
# =============================
function Parse-ProducersTxt {
    param([string]$path)

    if (!(Test-Path -LiteralPath $path)) { 
        throw "Nao achei o arquivo: $path" 
    }

    $lines = Get-Content -LiteralPath $path

    $items = New-Object System.Collections.Generic.List[object]
    $cur = $null
    $mode = ""          
    $inProducer = $false
    $pendingBlock = ""  

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
        if ($cur -ne $null -and 
            -not [string]::IsNullOrWhiteSpace((Nz $cur.PEDIDO))) {

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

            if ($line -match '^\[(.+)\]$') {
                $section = $matches[1].Trim().ToUpperInvariant()
                Flush-Current
                $cur = $null; $mode = ""; $pendingBlock = ""; $inProducer = $false
                if ($section -eq "PRODUTOR") { $cur = New-Producer; $inProducer = $true }
                continue
            }

            if (-not $inProducer -or $cur -eq $null) { continue }

            if ($line -eq "}") { $mode = ""; $pendingBlock = ""; continue }
            if ($line -eq "{") { if ($pendingBlock -ne "") { $mode = $pendingBlock; $pendingBlock = "" }; continue }

            if ($mode -eq "PLACAS") {
                if ($line -match '^[A-Za-zÇçÃãÕõÉéÍíÓóÚú_]+\s*[:=]' -or $line -match '^\[.+\]$') {
                    $mode = ""; $reprocess = $true; continue
                }
                $cur.PLACAS.Add($line); continue
            }

            if ($mode -ne "") {
                if ($mode -eq "GRorJBS")       { $cur.GRorJBS.Add($line); continue }
                if ($mode -eq "QUANT_MINUTAS") { $cur.QUANT_MINUTAS.Add($line); continue }
                continue
            }

            if ($line -match '^PLACAS?\s*[:=]\s*(.*)$') {
                $mode = "PLACAS"; $rest = $matches[1].Trim()
                if ($rest -ne "") { $cur.PLACAS.Add($rest) }; continue
            }

            if ($line -match '^GRorJBS\s*=\s*(.*)$') {
                $rest = $matches[1].Trim()
                if ($rest -eq "{") { $mode = "GRorJBS"; continue }
                if ([string]::IsNullOrWhiteSpace($rest)) { $pendingBlock = "GRorJBS"; continue }
                $cur.GRorJBS.Add($rest); continue
            }

            if ($line -match '^QUANT_MINUTAS\s*=\s*(.*)$') {
                $rest = $matches[1].Trim()
                if ($rest -eq "{") { $mode = "QUANT_MINUTAS"; continue }
                if ([string]::IsNullOrWhiteSpace($rest)) { $pendingBlock = "QUANT_MINUTAS"; continue }
                $cur.QUANT_MINUTAS.Add($rest); continue
            }

            if ($line -match '^([A-Za-zÇçÃãÕõÉéÍíÓóÚú_]+)\s*=\s*(.*)$') {
                $k = $matches[1].Trim().ToUpperInvariant()
                $v = $matches[2].Trim()
                switch ($k) {
                    "NOME"       { $cur.NOME = $v; break }
                    "STATUS"     { $cur.STATUS = $v; break }
                    "TIPO"       { $cur.TIPO = $v; break }
                    "INSTRUCAO"  { $cur.INSTRUCAO = $v; break }
                    "INSTRUÇÃO"  { $cur.INSTRUCAO = $v; break }
                    "PEDIDO"     { $cur.PEDIDO = $v; break }
                }
                continue
            }
        }
    }

    Flush-Current
    return $items
}

# =============================
# Função que processa cada produtor e cola todos os blocos
# =============================
function Process-Producer {
    param([pscustomobject]$producer)

    Write-Host "Processando: $($producer.NOME)"

    # Cole GRorJBS
    if ($producer.GRorJBS.Count -gt 0) {
        Paste-RepeatDown -tokens $producer.GRorJBS -afterPasteDelayMs 40
    }

    # Cole QUANT_MINUTAS
    if ($producer.QUANT_MINUTAS.Count -gt 0) {
        Paste-RepeatDown -tokens $producer.QUANT_MINUTAS -afterPasteDelayMs 40
    }

    # Cole PLACAS
    foreach ($placa in $producer.PLACAS) {
        $p = (Nz $placa).Trim()
        if ($p -ne "") {
            Paste-Text $p
            SleepMs 50
            Press-Key("{DOWN}")
            SleepMs 40
        }
    }
}

# =============================
# Fluxo principal
# =============================
$ScriptDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ScriptDir)) {
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}
$BaseDir = Split-Path -Parent $ScriptDir

$path = Join-Path $BaseDir "input\pec\CadastrarPlacasVeiculo.txt"  # <<< altere para seu arquivo TXT
$producers = Parse-ProducersTxt -path $path

foreach ($p in $producers) {
    Process-Producer -producer $p
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

    if(-not $p.PLACAS -or $p.PLACAS.Count -eq 0 -or ($p.PLACAS | Where-Object { $_ -and $_.Trim() -ne "" }).Count -eq 0){
        Write-Host ""
        Write-Host ("[SKIP] PRODUTOR {0}/{1}: {2} sem placas - pulando." -f $pIndex, $producers.Count, $p.nome)
        continue
    }

    Write-Host ""
    Write-Host ("PRODUTOR:   {0}" -f $nome) -ForegroundColor Green
    Write-Host ("INSTRUCAO:  {0}" -f $instrucao) -ForegroundColor Green

    ######################################### execução aqui
    <############################################################################################## REMOVER

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
        Paste-RepeatDown -tokens $p.GRorJBS -afterPasteDelayMs 60 -afterEnterDelayMs 120
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
        Paste-RepeatDown -tokens $p.QUANT_MINUTAS -afterPasteDelayMs 120 -afterEnterDelayMs 120
        SleepMs 120
    }
    Press-Key("{PGUP}")
    Press-Key("{PGUP}")
    Press-Key("{PGUP}")
    Press-Key("{PGUP}")    


    
    SleepMs 639
    Press-Key("+{TAB}")
    SleepMs 639


###############################################################################################>
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
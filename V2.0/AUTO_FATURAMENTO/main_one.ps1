param(
    [Parameter(Mandatory=$true)]
    [string]$InputFile,

    [switch]$ModoDebug
)

# ============================================================
# CONFIGURAÇÃO GLOBAL
# ============================================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$Global:AutomationConfig = @{
    RetryMaximo = 2
    PausaPadraoSegundos = 1
    PausaEmergenciaAtiva = $false
}

$Global:AutomationState = @{
    CurrentLevel = 0
    CurrentProducer = $null
    InputFile = $InputFile
}

# ============================================================
# VALIDAÇÕES INICIAIS
# ============================================================

if (-not (Test-Path $InputFile)) {
    Write-Host "[ERRO] Arquivo não encontrado: $InputFile" -ForegroundColor Red
    exit 1
}

$modulesPath = Join-Path $PSScriptRoot "modules"

if (-not (Test-Path $modulesPath)) {
    Write-Host "[ERRO] Pasta de módulos não encontrada: $modulesPath" -ForegroundColor Red
    exit 1
}

# ============================================================
# CARREGAMENTO DE MÓDULOS
# ============================================================

Get-ChildItem $modulesPath -Filter "*.ps1" -Recurse |
Sort-Object FullName |
ForEach-Object {
    try {
        Write-Host "[OK] Carregando módulo: $($_.Name)" -ForegroundColor Green
        . $_.FullName
    }
    catch {
        Write-Host "[ERRO] Falha ao carregar $($_.Name)" -ForegroundColor Red
        exit 1
    }
}

# ============================================================
# FUNÇÕES AUXILIARES
# ============================================================

function Invoke-EmergencyPause {
    if ($Global:AutomationConfig.PausaEmergenciaAtiva) {
        Write-Host "`n[PAUSA DE EMERGÊNCIA ATIVA]" -ForegroundColor Red
        Read-Host "Pressione ENTER para continuar"
        $Global:AutomationConfig.PausaEmergenciaAtiva = $false
    }
}

function Test-EscPressed {
    if ([Console]::KeyAvailable) {
        $key = [Console]::ReadKey($true)
        if ($key.Key -eq "Escape") {
            return $true
        }
    }
    return $false
}

function Show-PauseMenu {

    Write-Host ""
    Write-Host "========== PAUSA ==========" -ForegroundColor Yellow
    Write-Host "1 - Continuar"
    Write-Host "2 - Repetir Step atual"
    Write-Host "3 - Reiniciar execução"
    Write-Host "4 - Encerrar automação"
    Write-Host "===========================" -ForegroundColor Yellow

    while ($true) {
        $op = Read-Host "Escolha uma opção"

        switch ($op) {
            "1" { return "CONTINUE" }
            "2" { return "RETRY_STEP" }
            "3" { return "RESTART_ALL" }
            "4" { return "STOP_ALL" }
        }
    }
}

function Invoke-StepWithRetry {
    param(
        [string]$StepName,
        $Produtor
    )

    $tentativa = 0
    $max = $Global:AutomationConfig.RetryMaximo

    while ($tentativa -le $max) {

        try {

            Invoke-EmergencyPause

            if ($ModoDebug) {
                Write-Host "[DEBUG] Executando $StepName - Tentativa $($tentativa+1)" -ForegroundColor DarkGray
            }

            & $StepName $Produtor

            Start-Sleep -Seconds $Global:AutomationConfig.PausaPadraoSegundos
            return $true
        }
        catch {

            Write-Host "[ERRO] Falha em $StepName - Tentativa $($tentativa+1)" -ForegroundColor Red
        }

        $tentativa++
    }

    return $false
}

# ============================================================
# DEFINIÇÃO DO PIPELINE (ORDEM OFICIAL)
# ============================================================

$Pipeline = @(
    "Step-RecebimentoEntrada",
    "Step-CadastrarPlacas",
    "Step-CadastrarNotas",
    "Step-FaturarFase7",
    "Step-EmitirCTE",
    "Step-LancarCTE",
    "Step-FecharStatus",
    "Step-FaturarFase3",
    "Step-EmitirNFe",
    "Step-SalvarAcertos",
    "Step-SalvarPedidos",
    "Step-SalvarRomaneios"
)

# ============================================================
# EXECUÇÃO PRINCIPAL
# ============================================================

$lista = Parse-AutomacaoMaster $InputFile

$Global:ListaProdutores = $lista
$Global:AUTOMACAO_PATH  = $InputFile
$Global:PRODUTORES      = $lista

Read-Host "Pressione ENTER para iniciar"

# ============================================================
# LOOP PRINCIPAL
# ============================================================

foreach ($produtor in $lista) {

    $Global:AutomationState.CurrentProducer = $produtor
    $Global:AutomationState.CurrentLevel    = [int]$produtor.NIVEL

    if (-not (Test-ProdutorTemNotas $produtor)) {
        Write-Host "[SKIP] $($produtor.NOME) sem notas fiscais." -ForegroundColor DarkYellow
        continue
    }

    Write-Host ""
    Write-Host "=================================================" -ForegroundColor Cyan
    Write-Host "Processando produtor: $($produtor.NOME)" -ForegroundColor Cyan
    Write-Host "NÍVEL ATUAL: $($produtor.NIVEL)" -ForegroundColor Yellow
    Write-Host "=================================================" -ForegroundColor Cyan
    Write-Host ""

    $regraExecucao = Get-RegraExecucao $produtor
    if ($regraExecucao.Tipo -eq "BLOQUEADO_TOTAL") {
        Write-Host "[REGRA] Produtor bloqueado totalmente." -ForegroundColor DarkYellow
        continue
    }

    $executouStep = $false
    $nivelInicial = [int]$produtor.NIVEL

    for ($i = 0; $i -lt $Pipeline.Count; $i++) {

        if ($i -ne [int]$produtor.NIVEL) {
            continue
        }

        $step = $Pipeline[$i]

        if (-not (Get-Command $step -ErrorAction SilentlyContinue)) {
            Write-Host "[ERRO] Step não encontrado: $step" -ForegroundColor Red
            break
        }

        if (-not (Test-StepPermitido -Produtor $produtor -IndiceStep $i -RegraExecucao $regraExecucao)) {
            Write-Host "[REGRA] Step $i não permitido." -ForegroundColor DarkYellow
            break
        }

        Write-Host ""
        Write-Host "Executando Step [$i] -> $step" -ForegroundColor Cyan
        Write-Host ""

        try {
            & $step $produtor
            $executouStep = $true
        }
        catch {
            Write-Host ""
            Write-Host "[ERRO CRÍTICO] Falha no $step" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor DarkRed
            Write-Host "Produtor interrompido." -ForegroundColor Red
            break
        }

        # Verifica se o step realmente avançou o nível
        if ([int]$produtor.NIVEL -eq $nivelInicial) {
            Write-Host "[ALERTA] Step não atualizou o nível. Execução interrompida." -ForegroundColor Yellow
            break
        }

        break
    }

    if ($executouStep) {
        Write-Host ""
        Write-Host "Produtor finalizado: $($produtor.NOME)" -ForegroundColor Green
    }
    else {
        Write-Host ""
        Write-Host "Produtor não executado ou interrompido: $($produtor.NOME)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "=== AUTOMAÇÃO FINALIZADA ===" -ForegroundColor Cyan
param(
    [Parameter(Mandatory=$true)]
    [string]$InputFile,

    [switch]$ModoDebug
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# =========================
# CONFIG GLOBAL
# =========================

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

# =========================
# VALIDACOES INICIAIS
# =========================

if (-not (Test-Path $InputFile)) {
    Write-Host "[ERRO] Arquivo não encontrado: $InputFile" -ForegroundColor Red
    exit 1
}

$modulesPath = Join-Path $PSScriptRoot "modules"

if (-not (Test-Path $modulesPath)) {
    Write-Host "[ERRO] Pasta de módulos não encontrada: $modulesPath" -ForegroundColor Red
    exit 1
}

# =========================
# CARREGADOR DE MODULOS
# =========================

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

# =========================
# FUNÇÕES AUXILIARES
# =========================

function Invoke-EmergencyPause {

    if ($Global:AutomationConfig.PausaEmergenciaAtiva) {
        Write-Host "`n[PAUSA DE EMERGÊNCIA ATIVA]" -ForegroundColor Red
        Read-Host "Pressione ENTER para continuar"
        $Global:AutomationConfig.PausaEmergenciaAtiva = $false
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
            pause
            return $true
        }
        catch {

            Write-Host "[ERRO] Falha em $StepName - Tentativa $($tentativa+1)" -ForegroundColor Red

            if ($tentativa -ge $max) {

                $opcao = Read-Host "Deseja (R)e tentar, (P)ular ou (A)bortar?"

                switch ($opcao.ToUpper()) {
                    "R" { $tentativa = 0; continue }
                    "P" { return $false }
                    "A" { throw "Execução abortada pelo usuário." }
                    default { return $false }
                }
            }
        }

        $tentativa++
    }

    return $false
}

# =========================
# PIPELINE DE EXECUÇÃO
# =========================

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

function Confirm-NextStep {
    param($stepName)

    Write-Host ""
    Write-Host "Step atual: $stepName" -ForegroundColor Yellow
    $op = Read-Host "Executar (S)im, (P)ular, (A)bortar?"

    switch ($op.ToUpper()) {
        "S" { return "EXECUTE" }
        "P" { return "SKIP" }
        "A" { throw "Execução abortada pelo usuário." }
        default { return "SKIP" }
    }
}

Write-Host ""
Write-Host "Modo de execução:"
Write-Host "1 - Automático (executa todos)"
Write-Host "2 - Manual (confirma cada Step)"
Write-Host "3 - Executar Step específico"

$modoExecucao = Read-Host "Escolha uma opção"

# =========================
# EXECUÇÃO PRINCIPAL
# =========================

$lista = Parse-AutomacaoMaster $InputFile

$Global:ListaProdutores = $lista
$Global:AUTOMACAO_PATH = $InputFile
$Global:PRODUTORES = $lista

$Global:SAVE_PEDIDOS_DIR
$Global:SAVE_PEDIDOS_DIR_PASTED

foreach ($produtor in $lista) {

    $Global:AutomationState.CurrentProducer = $produtor
    $Global:AutomationState.CurrentLevel = [int]$produtor.NIVEL



    if (-not (Test-ProdutorTemNotas $produtor)) {
        Write-Host "[SKIP] $($produtor.NOME) sem notas fiscais." -ForegroundColor DarkYellow
        continue
    }


    Write-Host "`n=============================" -ForegroundColor Cyan
    Write-Host "Processando produtor: $($produtor.NOME)" -ForegroundColor Cyan
    Write-Host "=============================`n" -ForegroundColor Cyan

    foreach ($step in $Pipeline) {

        if (-not (Get-Command $step -ErrorAction SilentlyContinue)) {
            Write-Host "[AVISO] Step não encontrado: $step" -ForegroundColor DarkYellow
            continue
        }

        if ($modoExecucao -eq "3") {

    Write-Host ""
    Write-Host "Selecione como deseja executar os Steps:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Exemplos:"
    Write-Host "  1,3        -> Executa os Steps 1 e 3"
    Write-Host "  2-5        -> Executa do Step 2 ao 5"
    Write-Host "  +          -> Executa do NIVEL atual em diante"
    Write-Host "  -3         -> Executa do início até o Step 3"
    Write-Host "  <2         -> Executa somente se NIVEL < 2"
    Write-Host ""

    for ($i = 0; $i -lt $Pipeline.Count; $i++) {
        Write-Host "[$($i+1)] $($Pipeline[$i])"
    }

    $entrada = Read-Host "Digite a opção"

    $stepsParaExecutar = @()

    # --------------------------
    # 1️⃣ Vários números (1,3)
    # --------------------------
    if ($entrada -match "^\d+(,\d+)+$") {

        $numeros = $entrada.Split(",")
        foreach ($n in $numeros) {
            $index = [int]$n - 1
            if ($index -ge 0 -and $index -lt $Pipeline.Count) {
                $stepsParaExecutar += $Pipeline[$index]
            }
        }
    }

    # --------------------------
    # 2️⃣ Intervalo (2-5)
    # --------------------------
    elseif ($entrada -match "^\d+-\d+$") {

        $partes = $entrada.Split("-")
        $inicio = [int]$partes[0] - 1
        $fim    = [int]$partes[1] - 1

        for ($i = $inicio; $i -le $fim; $i++) {
            if ($i -ge 0 -and $i -lt $Pipeline.Count) {
                $stepsParaExecutar += $Pipeline[$i]
            }
        }
    }

    # --------------------------
    # 3️⃣ Do NIVEL atual em diante (+)
    # --------------------------
    elseif ($entrada -eq "+") {

        $nivelAtual = [int]$produtor.NIVEL

        for ($i = $nivelAtual; $i -lt $Pipeline.Count; $i++) {
            $stepsParaExecutar += $Pipeline[$i]
        }
    }

    # --------------------------
    # 4️⃣ Até determinado Step (-3)
    # --------------------------
    elseif ($entrada -match "^-\d+$") {

        $limite = [int]($entrada.Substring(1)) - 1

        for ($i = 0; $i -le $limite; $i++) {
            if ($i -lt $Pipeline.Count) {
                $stepsParaExecutar += $Pipeline[$i]
            }
        }
    }

    # --------------------------
    # 5️⃣ Somente se NIVEL < X  (<2)
    # --------------------------
    elseif ($entrada -match "^<\d+$") {

        $limiteNivel = [int]($entrada.Substring(1))

        if ([int]$produtor.NIVEL -lt $limiteNivel) {
            $stepsParaExecutar = $Pipeline
        }
        else {
            Write-Host "Produtor já possui NIVEL >= $limiteNivel. Nada executado." -ForegroundColor Yellow
        }
    }

    else {
        Write-Host "Formato inválido." -ForegroundColor Red
        break
    }

    # --------------------------
    # EXECUÇÃO
    # --------------------------

    foreach ($step in $stepsParaExecutar) {
        Write-Host ""
        Write-Host "Executando: $step" -ForegroundColor Cyan
        & $step $produtor
    }

    break
}

        if ($modoExecucao -eq "2") {

            $decisao = Confirm-NextStep $step

            if ($decisao -eq "SKIP") {
                Write-Host "[PULADO] $step"
                continue
            }

            & $step $produtor
            continue
        }

        # Modo automático
        if ($modoExecucao -eq "1") {
            & $step $produtor
        }
    }




    

    Write-Host "`nProdutor finalizado: $($produtor.NOME)" -ForegroundColor Green
}

Write-Host "`n=== AUTOMAÇÃO FINALIZADA ===" -ForegroundColor Cyan
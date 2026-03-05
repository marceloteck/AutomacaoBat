# ============================================================
# STEP 6 - LANÇAR CTE
# ============================================================

function Step-LancarCTE {

    param($Produtor)

    Write-Host ""
    Write-Host "=======================================" -ForegroundColor Cyan
    Write-Host "STEP 6 - LANÇAR CTE"
    Write-Host "Produtor: $($Produtor.NOME)"
    Write-Host "Pedido: $($Produtor.PEDIDO)"
    Write-Host "=======================================" -ForegroundColor Cyan
    Write-Host ""

    Countdown-3s

    # ================================
    # PERGUNTAS
    # ================================

    $qtChaves   = [int](Read-Host "Quantas chaves CTE existem?")
    $diasFaltam = (Read-Host "Quantos dias faltam?").Trim()
    $tipoEmpresa = (Read-Host "É JBS ou GR?").Trim().ToUpper()

    # ================================
    # ABRIR RECEBIMENTO
    # ================================

    Invoke-ClickPos -Name "ABRIR_TELA_RECEBIMENTO_ENTRADA"
    SleepMs 1200

    Press-Key "{F7}"
    SleepMs 500

    Paste-Text $Produtor.INSTRUCAO
    SleepMs 300

    Press-Key "{ENTER}"
    Press-Key "{ENTER}"
    SleepMs 1200

    # ================================
    # ABRIR EMISSÃO CTE
    # ================================

    Invoke-ClickPos -Name "ABRIR_TELA_EMISSAO_CTE"
    SleepMs 1200

    Invoke-ClickPos -Name "CLICAR_INPUT_INSTRUCAO"
    SleepMs 500

    Press-Key "{F3}"
    SleepMs 1500

    # ================================
    # CAPTURAR CHAVES
    # ================================

    $listaChaves = @()

    for ($i = 1; $i -le $qtChaves; $i++) {

        Invoke-DoubleClickPos -Name "CLICAR_CHAVE_CTE"
        SleepMs 400

        Press-Key "^c"
        SleepMs 400

        $chaveCapturada = Get-Clipboard

        if ([string]::IsNullOrWhiteSpace($chaveCapturada)) {
            Write-Host "[ERRO] Falha ao capturar chave. Tentando novamente..." -ForegroundColor Yellow
            SleepMs 800
            Press-Key "^c"
            SleepMs 400
            $chaveCapturada = Get-Clipboard
        }

        if (-not [string]::IsNullOrWhiteSpace($chaveCapturada)) {
            $listaChaves += $chaveCapturada.Trim()
        }

        if ($i -lt $qtChaves) {
            Press-Key "{DOWN}"
            SleepMs 400
        }
    }

    # ================================
    # LANÇAR CHAVES
    # ================================

    foreach ($chave in $listaChaves) {

        Invoke-ClickPos -Name "ABRIR_TELA_RECEBIMENTO_ENTRADA"
        SleepMs 1200

        Invoke-ClickPos -Name "CLICAR_INPUT_CHAVE_CTE"
        SleepMs 500

        Press-Key "^a"
        SleepMs 100

        Paste-Text $chave
        SleepMs 300

        Press-Key "{TAB}"
        SleepMs 500

        Invoke-ClickPos -Name "CLICAR_INPUT_DIAS"
        SleepMs 400

        Press-Key "^a"
        SleepMs 100

        if ($tipoEmpresa -eq "GR") {
            Paste-Text $diasFaltam
        }
        else {
            Paste-Text "44"
        }

        SleepMs 400

        Press-Key "{F4}"
        SleepMs 1200
    }

    Press-Key "{F4}"
    SleepMs 1200

    $Produtor.STATUS = "LANCAR_CTE_OK"

    Update-ProdutorNivel -Produtor $Produtor -NovoNivel 6
    Save-AutomacaoMaster -Path $Global:AUTOMACAO_PATH -Producers $Global:PRODUTORES

    Write-Host "[OK] CTEs lançados e TXT atualizado." -ForegroundColor Green
}
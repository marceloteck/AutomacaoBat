# ============================================================
# STEP 9 - EMITIR NF-e
# ============================================================

function Step-EmitirNFe {

    param($Produtor)

    Write-Host ""
    Write-Host "=======================================" -ForegroundColor Cyan
    Write-Host "STEP 9 - EMITIR NF-e"
    Write-Host "Produtor: $($Produtor.NOME)"
    Write-Host "Pedido: $($Produtor.PEDIDO)"
    Write-Host "=======================================" -ForegroundColor Cyan
    Write-Host ""

    Countdown-3s

    # ================================
    # INSTRUÇÃO
    # ================================

    Invoke-ClickPos -Name "CLICAR_INPUT_INSTRUCAO"
    SleepMs 500

    Press-Key "^a"
    SleepMs 120

    Paste-Text $Produtor.INSTRUCAO
    SleepMs 400

    # ================================
    # CONFIGURAR DATA (APENAS UMA VEZ)
    # ================================

    if (-not $Global:DATA_NFE_CONFIGURADA) {

        Write-Host "[INFO] Configurando datas pela primeira vez..."

        $dataAtual = Get-Date -Format "ddMMyyyy"

        Invoke-ClickPos -Name "CLICAR_DATA_01"
        SleepMs 500
        Press-Key "^a"
        SleepMs 120
        Paste-Text $dataAtual
        SleepMs 400

        Invoke-ClickPos -Name "CLICAR_DATA_02"
        SleepMs 500
        Press-Key "^a"
        SleepMs 120
        Paste-Text $dataAtual
        SleepMs 600

        $Global:DATA_NFE_CONFIGURADA = $true
    }

    # ================================
    # FILTRO
    # ================================

    Invoke-ClickPos -Name "CLICAR_SELECIONAR_FILTRO"
    SleepMs 600

    Invoke-ClickPos -Name "CLICAR_ESCOLHER_FILTRO_TODOS"
    SleepMs 800

    # ================================
    # BUSCAR
    # ================================

    Press-Key "{F3}"
    SleepMs 2000

    Press-Key "^a"
    SleepMs 400

    Press-Key "{F4}"
    SleepMs 1500

    # ================================
    # EMISSÃO
    # ================================

    Invoke-ClickPos -Name "CLICAR_INPUT_SELECIONAR"
    SleepMs 600

    Invoke-ClickPos -Name "CLICAR_OPCAO_2"
    SleepMs 800

    Invoke-ClickPos -Name "CLICAR_OK"
    SleepMs 1500

    # ================================
    # FINALIZAÇÃO
    # ================================

    $Produtor.STATUS = "EMITIR_NFE_OK"

    Update-ProdutorNivel -Produtor $Produtor -NovoNivel 9
    Save-AutomacaoMaster -Path $Global:AUTOMACAO_PATH -Producers $Global:PRODUTORES

    Write-Host "[OK] NF-e emitida e TXT atualizado." -ForegroundColor Green
}
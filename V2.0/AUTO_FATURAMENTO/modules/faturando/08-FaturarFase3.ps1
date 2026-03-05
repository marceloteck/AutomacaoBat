# ============================================================
# STEP 8 - FATURAR FASE 3
# ============================================================

function Step-FaturarFase3 {

    param($Produtor)

    Write-Host ""
    Write-Host "=======================================" -ForegroundColor Cyan
    Write-Host "STEP 8 - FATURAR FASE 3"
    Write-Host "Produtor: $($Produtor.NOME)"
    Write-Host "Instrucao: $($Produtor.INSTRUCAO)"
    Write-Host "=======================================" -ForegroundColor Cyan
    Write-Host ""

    $TipoFaturamento = "3"

    Countdown-3s

    # ================================
    # ABRIR TELA
    # ================================

    Invoke-ClickPos -Name "ABRIR_TELA_FATURAMENTO_ERP"
    SleepMs 1200

    # ================================
    # DEFINIR FASE
    # ================================

    Invoke-ClickPos -Name "CLICAR_INPUT_FASE7OR3"
    SleepMs 600

    Press-Key "^a"
    SleepMs 150

    Paste-Text $TipoFaturamento
    SleepMs 500

    # ================================
    # FILTRO NÃO FATURADO
    # ================================

    Invoke-ClickPos -Name "CLICAR_FILTRO_FATURADO_OUNAO"
    SleepMs 800

    Invoke-ClickPos -Name "SELECIONAR_NAO_FATURADO"
    SleepMs 1000

    # ================================
    # AJUSTE DATAS
    # ================================

    Invoke-DoubleClickPos -Name "CLICAR_FATURAMENTO_DATA_principal"
    SleepMs 1200

    Invoke-DoubleClickPos -Name "CLICAR_FATURAMENTO_DATA2"
    SleepMs 1200

    Invoke-DoubleClickPos -Name "CLICAR_FATURAMENTO_DATA1"
    SleepMs 1200

    # ================================
    # BUSCAR
    # ================================

    Press-Key "{F3}"
    SleepMs 2500

    # ================================
    # FILTRAR POR INSTRUÇÃO
    # ================================

    Invoke-ClickPos -Name "ABRIR_FILTRO_COLAR_INSTRUCAO"
    SleepMs 600

    Invoke-ClickPos -Name "FOCAR_IMPUT_FILTRO"
    SleepMs 600

    Press-Key "^a"
    SleepMs 150

    Paste-Text $Produtor.INSTRUCAO
    SleepMs 600

    Press-Key "{ENTER}"
    SleepMs 1200

    # ================================
    # SELECIONAR E FATURAR
    # ================================

    Invoke-ClickPos -Name "CLICAR_INSTRUCAO"
    SleepMs 300

    Invoke-ClickPos -Name "CLICAR_FORA_NA_TELA"
    SleepMs 800

    Invoke-ClickPos -Name "CLICAR_INSTRUCAO_SELECIONAR"
    SleepMs 1000

    Press-Key "{F4}"
    SleepMs 1500

    # ================================
    # FINALIZAÇÃO
    # ================================

    $Produtor.STATUS = "FATURAR_FASE3_OK"

    Update-ProdutorNivel -Produtor $Produtor -NovoNivel 8
    Save-AutomacaoMaster -Path $Global:AUTOMACAO_PATH -Producers $Global:PRODUTORES

    Write-Host "[OK] Faturamento Fase 3 concluído e TXT atualizado." -ForegroundColor Green
}
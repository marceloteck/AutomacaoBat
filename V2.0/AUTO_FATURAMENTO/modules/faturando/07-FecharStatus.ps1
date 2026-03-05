# ============================================================
# STEP 7 - FECHAR STATUS
# ============================================================

function Step-FecharStatus {

    param($Produtor)

    Write-Host ""
    Write-Host "=======================================" -ForegroundColor Cyan
    Write-Host "STEP 7 - FECHAR STATUS"
    Write-Host "Produtor: $($Produtor.NOME)"
    Write-Host "Pedido: $($Produtor.PEDIDO)"
    Write-Host "=======================================" -ForegroundColor Cyan
    Write-Host ""

    Countdown-3s

    # ================================
    # FOCAR TELA
    # ================================

    Invoke-ClickPos -Name "FOCAR_EM_FECHARSTATUS"
    SleepMs 1200

    # ================================
    # BUSCAR INSTRUÇÃO
    # ================================

    Press-Key "{F3}"
    SleepMs 1200

    Press-Key "^a"
    SleepMs 150

    Paste-Text $Produtor.INSTRUCAO
    SleepMs 500

    Press-Key "{ENTER}"
    SleepMs 1500

    # ================================
    # SELECIONAR E SALVAR
    # ================================

    Invoke-ClickPos -Name "CLICAR_INSTRUCAO_SELECIONAR_SALVAR"
    SleepMs 500

    Press-Key "{F4}"
    SleepMs 1500

    # ================================
    # FINALIZAÇÃO
    # ================================

    $Produtor.STATUS = "STATUS_FECHADO_OK"

    Update-ProdutorNivel -Produtor $Produtor -NovoNivel 7
    Save-AutomacaoMaster -Path $Global:AUTOMACAO_PATH -Producers $Global:PRODUTORES

    Write-Host "[OK] Status fechado e TXT atualizado." -ForegroundColor Green
}
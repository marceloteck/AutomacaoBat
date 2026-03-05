# ============================================================
# STEP 12 - SALVAR ROMANEIOS
# ============================================================

function Step-SalvarRomaneios {

    param($Produtor)

    Write-Host ""
    Write-Host "=======================================" -ForegroundColor Cyan
    Write-Host "STEP 12 - SALVAR ROMANEIOS"
    Write-Host "Produtor: $($Produtor.NOME)"
    Write-Host "Pedido: $($Produtor.PEDIDO)"
    Write-Host "Tipo: $($Produtor.TIPO)"
    Write-Host "=======================================" -ForegroundColor Cyan
    Write-Host ""

    Countdown-3s

    $cargas = [int](Read-Host "Quantas cargas tem esse pedido? (1 ou 2)")

    # =========================
    # ROMANEIO DE ABATE
    # =========================

    SleepMs 1000

    Invoke-ClickPos -Name "SALVAR_ACER_LEFT_013_337_313"
    SleepMs 1000

    Invoke-ClickPos -Name "SALVAR_ACER_LEFT_014_1257_59"
    SleepMs 1000

    Invoke-ClickPos -Name "SALVAR_ACER_LEFT_015_192_205"
    SleepMs 1000

    Invoke-DoubleClickPos -Name "SALVAR_ACER_LEFT_015_192_205"
    SleepMs 1000

    Press-Key "^a"
    SleepMs 80

    Paste-Text $Produtor.PEDIDO
    SleepMs 80

    Press-Key "{TAB}"
    SleepMs 900

    # =========================
    # CARGA 1
    # =========================

    Invoke-ClickPos -Name "CLICAR_ABA_MUDAR_CARGA"
    SleepMs 900

    Invoke-ClickPos -Name "CLICAR_INPUT_MUDAR_CARGA"
    SleepMs 900

    Press-Key "^a"
    SleepMs 80

    Paste-Text "1"
    SleepMs 500

    Press-Key "{F3}"
    SleepMs 1000

    # =========================
    # CARGA 2
    # =========================

    if ($cargas -eq 2) {

        Invoke-ClickPos -Name "CLICAR_ABA_MUDAR_CARGA_2"
        SleepMs 900

        Invoke-ClickPos -Name "CLICAR_INPUT_MUDAR_CARGA"
        SleepMs 900

        Press-Key "^a"
        SleepMs 600

        Paste-Text "2"
        SleepMs 200

        Press-Key "{F3}"
        SleepMs 2000
    }

    $Produtor.STATUS = "SALVAR_ROMANEIOS_OK"

    Update-ProdutorNivel -Produtor $Produtor -NovoNivel 12
    Save-AutomacaoMaster -Path $Global:AUTOMACAO_PATH -Producers $Global:PRODUTORES

    Write-Host "[OK] Romaneios salvos e TXT atualizado." -ForegroundColor Green
}
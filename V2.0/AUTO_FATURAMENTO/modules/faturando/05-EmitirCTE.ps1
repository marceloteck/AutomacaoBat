function Step-EmitirCTE {

    param($Produtor)

    Write-Host ""
    Write-Host "=======================================" -ForegroundColor Cyan
    Write-Host "STEP 4 - EMITIR CTE"
    Write-Host "Produtor: $($Produtor.NOME)"
    Write-Host "=======================================" -ForegroundColor Cyan
    Write-Host ""

    Countdown-3s

    # ============================================================
    # ABRIR TELA
    # ============================================================

    Invoke-ClickPos -Name "ABRIR_ABA_JANELA_EMITIR_CTE_ERP"
    SleepMs 900

    # ============================================================
    # INSTRUÇÃO
    # ============================================================

    Invoke-ClickPos -Name "CLICAR_INPUT_INSTRUCAO"
    SleepMs 500

    Press-Key "^a"
    SleepMs 150
    Press-Key "{DEL}"
    SleepMs 300

    Paste-Text $Produtor.INSTRUCAO
    SleepMs 600

    $dataAtual = Get-Date -Format "ddMMyyyy"

    # ============================================================
    # DATA INICIAL
    # ============================================================

    Invoke-ClickPos -Name "CLICAR_DATA_01"
    SleepMs 500

    Press-Key "^a"
    SleepMs 150
    Press-Key "{DEL}"
    SleepMs 300

    Paste-Text $dataAtual
    SleepMs 600

    # ============================================================
    # DATA FINAL
    # ============================================================

    Invoke-ClickPos -Name "CLICAR_DATA_02"
    SleepMs 500

    Press-Key "^a"
    SleepMs 150
    Press-Key "{DEL}"
    SleepMs 300

    Paste-Text $dataAtual
    SleepMs 600

    # ============================================================
    # FILTRO TODOS
    # ============================================================

    Invoke-ClickPos -Name "CLICAR_SELECIONAR_FILTRO"
    SleepMs 600

    Invoke-ClickPos -Name "CLICAR_ESCOLHER_FILTRO_TODOS"
    SleepMs 900

    # ============================================================
    # BUSCAR
    # ============================================================

    Press-Key "{F3}"
    SleepMs 2500   # ERP processa aqui

    # ============================================================
    # SELECIONAR TODOS
    # ============================================================

    Press-Key "^a"
    SleepMs 600

    # ============================================================
    # GRAVAR
    # ============================================================

    Press-Key "{F4}"
    SleepMs 3000   # gravação pesada

    Press-Key "{ENTER}"
    SleepMs 3000   # confirmação ERP

    Write-Host "[OK] CTEs emitidos." -ForegroundColor Green

    SleepMs 1000
    Press-Key "%{TAB}"

    $Produtor.STATUS = "EMITIR_CTE_OK"

    Update-ProdutorNivel -Produtor $Produtor -NovoNivel 5
    Save-AutomacaoMaster -Path $Global:AUTOMACAO_PATH -Producers $Global:PRODUTORES

    Write-Host "[OK] STATUS e NIVEL atualizados." -ForegroundColor Green
    Write-Host ""
}
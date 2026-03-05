function Step-CadastrarNotas {

    param($Produtor)

    Write-Host ""
    Write-Host "=======================================" -ForegroundColor Cyan
    Write-Host "STEP 2 - CADASTRAR NOTAS"
    Write-Host "Produtor: $($Produtor.NOME)"
    Write-Host "=======================================" -ForegroundColor Cyan
    Write-Host ""

    if (-not $Produtor.NOTAS -or $Produtor.NOTAS.Count -eq 0) {
        throw "Produtor sem notas para cadastrar."
    }

    if (-not $Produtor.PLACAS -or $Produtor.PLACAS.Count -eq 0) {
        throw "Produtor sem placas cadastradas."
    }

    Invoke-ClickPos -Name "ABRIR_ABA_JANELA_CONTRATACAO_DE_VEICULO_ERP"
    SleepMs 639

    # F7
    Press-Key "{F7}"
    SleepMs $DELAY_AFTER_F7_MS
    Abort-IfNeeded

    # COLAR INSTRUCAO
    Paste-Text $Produtor.INSTRUCAO
    SleepMs $DELAY_AFTER_INSTRUCAO_MS
    Abort-IfNeeded

    # ENTER ENTER
    Press-Key "{ENTER}"
    Press-Key "{ENTER}"
    SleepMs 80
    Abort-IfNeeded

    $totalPlacas = $Produtor.PLACAS.Count

    for ($i = 0; $i -lt $totalPlacas; $i++) {

        Abort-IfNeeded

        # Reset posição
        Invoke-ClickPos -Name "CLICAR_PRIMEIRA_LINHA_DO_PROJETO_ADD_NEW_PLACAS"
        SleepMs 150
        Press-Key("^{HOME}")
        SleepMs 150

        # Seleciona placa
        Select-PlacaByIndex -Index $i -TotalPlacas $totalPlacas

        # CTRL+F12
        Press-Key "^{F12}"
        SleepMs $DELAY_AFTER_CTRL_F12_MS
        Abort-IfNeeded

        Press-Key "A"
        SleepMs $DELAY_AFTER_TYPE_A_MS
        Abort-IfNeeded

        Press-Key "^a"
        SleepMs 80
        Press-Key "{DEL}"
        SleepMs $DELAY_AFTER_CLEAR_MS
        Abort-IfNeeded

        if ($i -lt $Produtor.NOTAS.Count) {
            Paste-Text $Produtor.NOTAS[$i]
        }

        SleepMs 100
        Press-Key "{ENTER}"
        SleepMs 60
        Press-Key "{ENTER}"
        SleepMs 120
        Abort-IfNeeded

        # F4 dentro do loop (igual base)
        Press-Key "{F4}"
        SleepMs $DELAY_AFTER_F4_MS
        Abort-IfNeeded
    }

    # FINALIZAÇÃO PADRÃO (IGUAL BASE)

    Press-Key "{F4}"
    SleepMs $DELAY_AFTER_F4_MS
    Abort-IfNeeded

    Press-Key "{F4}"
    SleepMs $DELAY_AFTER_F4_2_MS
    Abort-IfNeeded

    SleepMs 2000
    Press-Key "{F8}"
    SleepMs 150
    Abort-IfNeeded

    SleepMs 3000
    Press-Key "{ENTER}"
    SleepMs 100
    Abort-IfNeeded

    Write-Host "[OK] Cadastro de notas concluído." -ForegroundColor Green

    SleepMs 1000
    Press-Key "%{TAB}"

    $Produtor.STATUS = "NFE_CONTRATACAO_VEICULO_OK"

    Update-ProdutorNivel -Produtor $Produtor -NovoNivel 3
    Save-AutomacaoMaster -Path $Global:AUTOMACAO_PATH -Producers $Global:PRODUTORES

    Write-Host "[OK] STATUS e NIVEL atualizados." -ForegroundColor Green
    Write-Host ""
}
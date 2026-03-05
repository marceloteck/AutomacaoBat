function Step-FaturarFase7 {

    param($Produtor)

    Write-Host ""
    Write-Host "=======================================" -ForegroundColor Cyan
    Write-Host "STEP 3 - FATURAR FASE 7"
    Write-Host "Produtor: $($Produtor.NOME)"
    Write-Host "=======================================" -ForegroundColor Cyan
    Write-Host ""

    if($Produtor.STATUS -eq "CONFIRMADO" -or $Produtor.STATUS -eq "PENDENTE"){
        Write-Host "[SKIP] Produtor já CONFIRMADO ou PENDENTE." -ForegroundColor DarkGray
        return
    }

    # ============================================================
    # AGUARDAR USUARIO PREPARAR TELA
    # ============================================================

    Write-Host ""
    Write-Host ">>> PREPARE A TELA DE FATURAMENTO NO ERP <<<" -ForegroundColor Yellow
    Write-Host "A automação iniciará em 6 segundos..."
    Countdown -Seconds 6

    # ============================================================
    # COLAR INSTRUÇÃO (IGUAL AO BASE)
    # ============================================================

    Set-Clipboard -Value $Produtor.INSTRUCAO
    SleepMs 150

    Write-Host ("COLANDO INSTRUÇÃO: {0}" -f $Produtor.INSTRUCAO)

    Press-Key "^v"
    Press-Key "{ENTER}"
    SleepMs 200

    Write-Host ("CLICANDO NA INSTRUÇÃO: {0}" -f $Produtor.INSTRUCAO)

    Invoke-ClickPos -Name "CLICAR_INSTRUCAO"

    SleepMs 300

    Write-Host "[OK] Faturamento Fase 7 concluído." -ForegroundColor Green

    SleepMs 1000
    Press-Key "%{TAB}"

    $Produtor.STATUS = "FATURAR_FASE7_OK"

    Update-ProdutorNivel -Produtor $Produtor -NovoNivel 4
    Save-AutomacaoMaster -Path $Global:AUTOMACAO_PATH -Producers $Global:PRODUTORES

    Write-Host "[OK] STATUS e NIVEL atualizados." -ForegroundColor Green
    Write-Host ""
}
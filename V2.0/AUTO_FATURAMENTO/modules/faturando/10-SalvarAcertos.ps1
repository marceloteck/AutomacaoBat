# ============================================================
# STEP 10 - SALVAR ACERTOS
# ============================================================

function Step-SalvarAcertos {

    param($Produtor)

    Write-Host ""
    Write-Host "=======================================" -ForegroundColor Cyan
    Write-Host "STEP 10 - SALVAR ACERTOS"
    Write-Host "Produtor: $($Produtor.NOME)"
    Write-Host "Pedido: $($Produtor.PEDIDO)"
    Write-Host "Tipo: $($Produtor.TIPO)"
    Write-Host "=======================================" -ForegroundColor Cyan
    Write-Host ""

    Countdown-3s

    # =========================
    # VALIDAR CARGAS (IGUAL BASE)
    # =========================

    $cargas = 0
    while ($true) {
        $in = (Read-Host "Quantas cargas tem esse pedido? (1 ou 2)").Trim()
        if ($in -match '^[12]$') { 
            $cargas = [int]$in
            break 
        }
        Write-Host "Digite somente 1 ou 2." -ForegroundColor Yellow
    }

    # ============================================================
    # PESSOA JURIDICA (IGUAL BASE)
    # ============================================================

    if ($Produtor.TIPO -eq "PJ") {

        Invoke-ClickPos -Name "ABRIR_TELA_VINCULO1"
        SleepMs 900  
        Press-Key("{F2}")
        SleepMs 900 
        Paste-Text "2"

        SleepMs 1000
        Invoke-ClickPos -Name "ABRIR_TELA_AC_DOCUMENTO_SIMPLIFICADO_ERP"
        SleepMs 900
        Invoke-ClickPos -Name "ABRIR_TELA_AC_PESQUISASEM_F7"
        SleepMs 900
        Press-Key("^a")
        SleepMs 80
        Paste-Text $Produtor.INSTRUCAO
        SleepMs 50
        Press-Key("{ENTER}")

        SleepMs 800
        Invoke-ClickPos -Name "SALVAR_ACER_LEFT_004_757_420"
        SleepMs 1000
        Invoke-DoubleClickPos -Name "CLICARdOC_PJ_892"
        SleepMs 1000

        Invoke-DoubleClickPos -Name "CLCIAR_COPIAR_TERCEIRO"
        SleepMs 90
        Press-Key("^a")
        SleepMs 100
        Press-Key("^c")

        SleepMs 1000
        Invoke-ClickPos -Name "ABRIR_TELA_VINCULO1"
        SleepMs 900
        Invoke-ClickPos -Name "clicar_pracolaro_terceiro"
        SleepMs 100
        Press-Key("^v")
        SleepMs 90  
        Press-Key("{TAB}")

        SleepMs 1000
        Invoke-ClickPos -Name "ABRIR_TELA_AC_DOCUMENTO_SIMPLIFICADO_ERP"
        SleepMs 1000
        Invoke-DoubleClickPos -Name "CLCIAR_COPIAR_Numero_documento_ac"
        SleepMs 90
        Press-Key("^a")
        SleepMs 100
        Press-Key("^c")

        SleepMs 1000
        Invoke-ClickPos -Name "ABRIR_TELA_VINCULO1"
        SleepMs 1000
        Invoke-ClickPos -Name "clicarinput_colarNumero-doc"
        SleepMs 90  
        Press-Key("{TAB}")
        SleepMs 90 
        Paste-Text "1"
        SleepMs 90  
        Press-Key("{TAB}")

        SleepMs 1000
        Invoke-ClickPos -Name "ABRIR_TELA_DOCUMENTO"
        SleepMs 1000
        Invoke-ClickPos -Name "ABRIR_TELA_DOCUMENTO_PESQUISAR"
        SleepMs 900
        Press-Key("^a")
        SleepMs 80
        Paste-Text $Produtor.INSTRUCAO
        SleepMs 80
        Press-Key("{TAB}")
        SleepMs 80
        Press-Key("{ENTER}")

        pause
    }

    # ============================================================
    # PESSOA FISICA (IGUAL BASE)
    # ============================================================

    if ($Produtor.TIPO -eq "PF") {

        Invoke-ClickPos -Name "ABRIR_TELA_AC_NFE_ERP"
        SleepMs 80

        Invoke-DoubleClickPos -Name "SALVAR_ACER_LEFT_001_136_233"
        SleepMs 1200
        Press-Key("^a")
        SleepMs 200
        Paste-Text $Produtor.INSTRUCAO
        SleepMs 900  
        Press-Key("{TAB}")
        SleepMs 80
        Press-Key("{F3}")

        SleepMs 1200
        Invoke-ClickPos -Name "ABRIR_TELA_AC_DOCUMENTO_SIMPLIFICADO_ERP"
        SleepMs 900
        Invoke-ClickPos -Name "ABRIR_TELA_AC_PESQUISASEM_F7"
        SleepMs 900
        Press-Key("^a")
        SleepMs 80
        Paste-Text $Produtor.INSTRUCAO
        SleepMs 50
        Press-Key("{ENTER}")

        SleepMs 800
        Invoke-ClickPos -Name "SALVAR_ACER_LEFT_004_757_420"
        SleepMs 1000
        Invoke-DoubleClickPos -Name "SALVAR_ACER_LEFT_005_770_452"
        SleepMs 1000

        pause
    }

    # ============================================================
    # FINAL IGUAL BASE
    # ============================================================

    Set-ClipText $Produtor.NOME
    SleepMs 300

    Invoke-ClickPos -Name "SALVAR_ACER_LEFT_011_976_76"
    SleepMs 1200
    Press-Key("{F9}")
    SleepMs 6000
    Invoke-ClickPos -Name "CLICAR_IMPRIMIR_OPT_ACER"
    SleepMs 1200
    Invoke-ClickPos -Name "CLICAR_IMPRIMIR_OPT_SOMENTEESTAPAGINA_PAGINAATUAL"
    SleepMs 1200
    Invoke-ClickPos -Name "CLICAR_IMPRIMIR_OPT_SOMENTEOPT_OOK"

    $Produtor.STATUS = "SALVAR_ACERTO_OK"

    Update-ProdutorNivel -Produtor $Produtor -NovoNivel 10
    Save-AutomacaoMaster -Path $Global:AUTOMACAO_PATH -Producers $Global:PRODUTORES

    Write-Host "[OK] Acerto salvo e TXT atualizado." -ForegroundColor Green
}
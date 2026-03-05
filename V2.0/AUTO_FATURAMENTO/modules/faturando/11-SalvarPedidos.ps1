# ============================================================
# STEP 11 - SALVAR PEDIDO
# ============================================================

function Step-SalvarPedidos {

    param($Produtor)

    if (-not $Global:SAVE_PEDIDOS_DIR) {

        $saveDir = (Read-Host "Informe o DIRETORIO para salvar/imprimir").Trim().Trim('"')

        if (-not (Test-Path -LiteralPath $saveDir)) {
            New-Item -ItemType Directory -Path $saveDir -Force | Out-Null
            Write-Host "[OK] Diretorio criado: $saveDir" -ForegroundColor Green
        }

        $Global:SAVE_PEDIDOS_DIR = $saveDir
        $Global:SAVE_PEDIDOS_DIR_PASTED = $false
    }

    Write-Host ""
    Write-Host "=======================================" -ForegroundColor Cyan
    Write-Host "STEP 11 - SALVAR PEDIDO"
    Write-Host "Produtor: $($Produtor.NOME)"
    Write-Host "Pedido: $($Produtor.PEDIDO)"
    Write-Host "=======================================" -ForegroundColor Cyan
    Write-Host ""

    Countdown-3s

    Invoke-ClickPos -Name "FOCAR_NA_TELA_PEDIDO_SLV"
    SleepMs 1500

    Invoke-ClickPos -Name "ABRIR_PESQUISA_SEMF3"
    SleepMs 300

    Paste-Text $Produtor.PEDIDO
    SleepMs 200

    Press-Key "{ENTER}"
    SleepMs 200

    Press-Key "{F11}"
    SleepMs 4000

    Invoke-ClickPos -Name "PEDIDO_SALVAR_LEFT_001_36_33"
    SleepMs 1000

    Invoke-ClickPos -Name "PEDIDO_SALVAR_LEFT_002_910_638"
    SleepMs 1000

    Invoke-ClickPos -Name "PEDIDO_SALVAR_LEFT_003_602_750"
    SleepMs 1000

    if (-not $Global:SAVE_PEDIDOS_DIR_PASTED) {

        Paste-Text $Global:SAVE_PEDIDOS_DIR
        SleepMs 200

        Press-Key "{ENTER}"
        SleepMs 1000

        $Global:SAVE_PEDIDOS_DIR_PASTED = $true
    }

    Paste-Text $Produtor.NOME
    SleepMs 200

    Press-Key "{ENTER}"
    SleepMs 3000

    Invoke-ClickPos -Name "FECHAR_PEDIDO_LEFT_001_412_39"
    SleepMs 400

    Invoke-ClickPos -Name "FECHARpEDIDO_SEM_F5"
    SleepMs 200

    $Produtor.STATUS = "SALVAR_PEDIDO_OK"

    Update-ProdutorNivel -Produtor $Produtor -NovoNivel 11
    Save-AutomacaoMaster -Path $Global:AUTOMACAO_PATH -Producers $Global:PRODUTORES

    Write-Host "[OK] Pedido salvo e TXT atualizado." -ForegroundColor Green
}
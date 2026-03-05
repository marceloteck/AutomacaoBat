# ============================================================
# STEP 0 - RECEBIMENTO DE ENTRADA
# Responsabilidade: Executar recebimento das notas no ERP
# ============================================================

function Step-RecebimentoEntrada {

    param($Produtor)

    Write-Host ""
    Write-Host "=======================================" -ForegroundColor Cyan
    Write-Host "STEP 0 - RECEBIMENTO DE ENTRADA"
    Write-Host "Produtor: $($Produtor.NOME)"
    Write-Host "=======================================" -ForegroundColor Cyan
    Write-Host ""

    # ============================================================
    # Validação mínima
    # ============================================================

    if (-not $Produtor.NOTAS -or $Produtor.NOTAS.Count -eq 0) {
        throw "Produtor sem notas para processar."
    }

    if (-not $Produtor.INSTRUCAO) {
        throw "Produtor sem INSTRUCAO definida."
    }

    # ============================================================
    # CONFIGURAÇÕES DE TEMPO (iguais ao script base funcional)
    # ============================================================

    $DELAY_AFTER_F2_MS        = 250
    $DELAY_AFTER_TAB_MS       = 120
    $DELAY_STEP_MS            = 1000
    $FINAL_DELAY_F4_MS        = 500
    $FINAL_DELAY_RIGHT_MS     = 150
    $FINAL_DELAY_ENTER_MS     = 150

    # Códigos por tipo
    $CODE_PF = "2630"
    $CODE_PJ = "2629"
    $code = if ($Produtor.TIPO -eq "PJ") { $CODE_PJ } else { $CODE_PF }

    # ============================================================
    # ABRE TELA ERP
    # ============================================================

    Invoke-ClickPos -Name "ABRIR_TELA_RECEBIMENTODEENTRADA_ERP"
    SleepMs 800   # garante que a tela abriu

    Press-Key "{F2}"
    SleepMs $DELAY_AFTER_F2_MS
    Abort-IfNeeded

    Press-Key "{TAB}"
    SleepMs $DELAY_AFTER_TAB_MS
    Abort-IfNeeded

    # Aguarda foco real no campo editável (igual script original)
    $timeout = 5000
    $elapsed = 0
    while (-not (Test-IsEditableFocusedElement)) {
        SleepMs 100
        $elapsed += 100
        if ($elapsed -ge $timeout) {
            throw "Campo INSTRUCAO não ficou editável."
        }
    }

    Press-Key $Produtor.INSTRUCAO
    SleepMs 150

    Press-Key "{TAB}"
    SleepMs $DELAY_AFTER_TAB_MS
    Abort-IfNeeded

    # ============================================================
    # PROCESSA NOTAS
    # ============================================================

    $total = $Produtor.NOTAS.Count
    $i = 0

    foreach ($nota in $Produtor.NOTAS) {

        if (-not $nota -or $nota.Trim() -eq "") { continue }

        Abort-IfNeeded
        $i++

        # Cola chave (já espera foco internamente)
        Paste-Text $nota
        SleepMs 50

        Press-Key "{TAB}"
        SleepMs $DELAY_STEP_MS
        Abort-IfNeeded

        # Aguarda foco no campo de código
        $timeout = 5000
        $elapsed = 0
        while (-not (Test-IsEditableFocusedElement)) {
            SleepMs 100
            $elapsed += 100
            if ($elapsed -ge $timeout) {
                throw "Campo CODIGO não ficou editável."
            }
        }

        Press-Key $code
        SleepMs $DELAY_STEP_MS

        Press-Key "{ENTER}"
        SleepMs 3000  # tempo crítico de processamento ERP

        Press-Key "{F4}"
        SleepMs $DELAY_STEP_MS

        Write-Host ("  [OK] Nota {0}/{1} processada." -f $i, $total)
    }

    Abort-IfNeeded

    # ============================================================
    # FINALIZA REGISTRO
    # ============================================================

    Press-Key "{F4}"
    SleepMs $FINAL_DELAY_F4_MS

    Press-Key "{RIGHT}"
    SleepMs $FINAL_DELAY_RIGHT_MS

    Press-Key "{ENTER}"
    SleepMs $FINAL_DELAY_ENTER_MS

    Write-Host "[OK] Recebimento finalizado no ERP." -ForegroundColor Green

    SleepMs 1000
    Press-Key "%{TAB}"

    # ============================================================
    # ATUALIZA ESTADO
    # ============================================================

    $Produtor.STATUS = "RECEBIMENTO_OK"

    Update-ProdutorNivel -Produtor $Produtor -NovoNivel 1

    Save-AutomacaoMaster -Path $Global:AUTOMACAO_PATH -Producers $Global:PRODUTORES

    Write-Host "[OK] STATUS e NIVEL atualizados." -ForegroundColor Green
    Write-Host ""
}
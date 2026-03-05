function Step-CadastrarPlacas {

    param($Produtor)

    Write-Host ""
    Write-Host "=======================================" -ForegroundColor Cyan
    Write-Host "STEP 1 - CADASTRAR PLACAS"
    Write-Host "Produtor: $($Produtor.NOME)"
    Write-Host "=======================================" -ForegroundColor Cyan
    Write-Host ""

    $registros = Get-RegistroCadastro $Produtor

    if (-not $registros -or $registros.Count -eq 0) {
        throw "Nenhum registro de placas encontrado para o produtor."
    }

    Invoke-ClickPos -Name "ABRIR_ABA_JANELA_CONTRATACAO_DE_VEICULO_ERP"
    SleepMs 900   # 🔧 maior estabilidade ao abrir aba

    Press-Key "{F7}"
    SleepMs 900   # 🔧 ERP demora mais aqui

    Paste-Text $Produtor.INSTRUCAO
    SleepMs 300   # 🔧 80ms era muito curto

    Press-Key "{ENTER}"
    Press-Key "{ENTER}"
    SleepMs 900

    $total = $registros.Count

    foreach ($r in $registros) {

        Invoke-ClickPos -Name "CLICAR_PRIMEIRA_LINHA_DO_PROJETO_ADD_NEW_PLACAS"
        SleepMs 400

        Press-Key "^{HOME}"
        SleepMs 400

        Invoke-ClickPos -Name "CLICAR_PRIMEIRA_LINHA_DO_PROJETO_ADD_NEW_PLACAS"
        SleepMs 400

        Abort-IfNeeded

        Write-Host ""
        Write-Host "Executando [$($r.INDEX)] - $($r.PLACA)" -ForegroundColor Cyan

        Select-RegistroByIndex -Index $r.INDEX -TotalRegistros $total
        SleepMs 400   # 🔧 estabiliza posição

        $placaPrincipal = $r.PLACA
        $placaAtrelada  = $null

        if ($r.PLACA -match "->") {
            $partes = $r.PLACA -split "->"
            $placaPrincipal = $partes[0].Trim()
            $placaAtrelada  = $partes[1].Trim()
        }

        # === GR ===
        Paste-Text $r.GRorJBS
        SleepMs 400

        Press-Key "{TAB}"
        SleepMs 900   # 🔧 ERP troca foco aqui

        # === ENTRA EM EDIÇÃO PLACA ===
        Press-Key "A"
        SleepMs 500

        Press-Key "^a"
        SleepMs 300

        Press-Key "{DEL}"
        SleepMs 400

        Paste-Text $placaPrincipal
        SleepMs 500

        Press-Key "{ENTER}"
        Press-Key "{ENTER}"
        SleepMs 900

        Press-Key "{TAB}"
        SleepMs 800

        # === MINUTAS ===
        Paste-Text $r.QUANT_MINUTAS
        SleepMs 900

        # === ATRELADO ===
        if ($placaAtrelada) {
            Add-VeiculoAtrelado -PlacaAtrelada $placaAtrelada
            SleepMs 600
        }

        Invoke-ClickPos -Name "CLICAR_PRIMEIRA_LINHA_DO_PROJETO_ADD_NEW_PLACAS"
        SleepMs 300

        Press-Key "{PGUP}"
        Press-Key "{PGUP}"
        Press-Key "{PGUP}"
        Press-Key "{PGUP}"
        SleepMs 400
    }

    SleepMs 900
    Press-Key "{F4}"
    SleepMs 3000

    Invoke-ClickPos -Name "FECHAR_TELA_DO_FRETE_CARREGANDO"
    SleepMs 1500

    Press-Key "{ENTER}"
    SleepMs 2000

    Write-Host "[OK] Cadastro de placas concluído." -ForegroundColor Green

    SleepMs 1000
    Press-Key "%{TAB}"

    $Produtor.STATUS = "PLACAS_CADASTRADAS_OK"

    Update-ProdutorNivel -Produtor $Produtor -NovoNivel 2

    Save-AutomacaoMaster -Path $Global:AUTOMACAO_PATH -Producers $Global:PRODUTORES

    Write-Host "[OK] STATUS e NIVEL atualizados." -ForegroundColor Green
    Write-Host ""
}
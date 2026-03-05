function Test-CadastroIntegridade {

    param(
        [array]$Placas,
        [array]$GR,
        [array]$Minutas
    )

    $p = $Placas.Count
    $g = $GR.Count
    $m = $Minutas.Count

    if ($p -eq $g -and $p -eq $m) {
        return $true
    }

    Write-Host ""
    Write-Host "⚠ INCONSISTÊNCIA DETECTADA" -ForegroundColor Red
    Write-Host "Placas: $p"
    Write-Host "GRorJBS: $g"
    Write-Host "QUANT_MINUTAS: $m"
    Write-Host ""

    $resp = Read-Host "Deseja repetir a análise? (S/N)"
    if ($resp.ToUpper() -eq "S") {
        return $false
    }

    throw "Execução cancelada por inconsistência."
}

# ==========================================
# HELPERS - CADASTRO POR REGISTRO
# ==========================================

function Get-RegistroCadastro {

    param($produtor)

    if (-not $produtor) { return $null }

    $placas = @($produtor.PLACAS)

    $expandGR = if (Get-Command Expand-GRorJBS -ErrorAction SilentlyContinue) {
        Expand-GRorJBS $produtor
    } else {
        @($produtor.GRorJBS)
    }

    $expandMinutas = if (Get-Command Expand-QuantMinutas -ErrorAction SilentlyContinue) {
        Expand-QuantMinutas $produtor
    } else {
        @($produtor.QUANT_MINUTAS)
    }

    if (-not (Test-CadastroIntegridade $placas $expandGR $expandMinutas)) {
        return Get-RegistroCadastro $produtor
    }

    $lista = for ($i = 0; $i -lt $placas.Count; $i++) {

        [pscustomobject]@{
            INDEX         = $i + 1
            PLACA         = $placas[$i]
            GRorJBS       = $expandGR[$i]
            QUANT_MINUTAS = $expandMinutas[$i]
            PEDIDO        = $produtor.PEDIDO
            INSTRUCAO     = $produtor.INSTRUCAO
            NIVEL         = $produtor.NIVEL
        }
    }

    return $lista
}



function Invoke-CadastroPorRegistro {

    param(
        $produtor,
        [scriptblock]$Execucao
    )

    $registros = Get-RegistroCadastro $produtor

    if (-not $registros) {
        Write-Host "Nenhum registro para executar." -ForegroundColor Yellow
        return
    }

    foreach ($r in $registros) {

        Write-Host ""
        Write-Host "Executando registro $($r.INDEX) - Placa $($r.PLACA)" -ForegroundColor Cyan

        if ($Execucao) {
            & $Execucao $r
        }
    }
}
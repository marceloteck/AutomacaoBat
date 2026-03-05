# ============================================================
# VALIDATION ENGINE
# ============================================================

function Test-ProdutorTemNotas {
    param($Produtor)

    if (-not $Produtor.NOTAS) { return $false }
    if ($Produtor.NOTAS.Count -eq 0) { return $false }

    return $true
}

function Test-ProdutorTemPlacas {
    param($Produtor)

    if (-not $Produtor.PLACAS) { return $false }
    if ($Produtor.PLACAS.Count -eq 0) { return $false }

    return $true
}

# ============================================================
# REGRA GLOBAL DE EXECUÇÃO DE STEPS
# ============================================================

function Get-RegraExecucao {
    param($Produtor)

    $temNotas  = Test-ProdutorTemNotas  $Produtor
    $temPlacas = Test-ProdutorTemPlacas $Produtor

    # Sem nota e sem placa → não executa nada
    if (-not $temNotas -and -not $temPlacas) {

        Write-Host "[BLOQUEIO TOTAL] Sem NOTAS e sem PLACAS." -ForegroundColor Red

        return @{
            Bloqueado = $true
        }
    }

    return @{
        Bloqueado = $false
    }
}
# ============================================================
# CONTROLE CENTRAL DE LIBERAÇÃO DE STEP
# ============================================================
function Test-StepPermitido {
    param(
        $Produtor,
        [int]$IndiceStep,
        $RegraExecucao
    )

    if ($RegraExecucao.Bloqueado) {
        return $false
    }

    return $true
}
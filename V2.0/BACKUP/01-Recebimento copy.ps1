function Test-ConsistenciaCadastro {

    param($produtor)

    Write-Host ""
    Write-Host "Validando consistência do cadastro..." -ForegroundColor Cyan

    # ==========================
    # Expansão GR
    # ==========================
    $totalGR = 0
    foreach ($item in $produtor.GRorJBS) {
        if ($item -match "X(\d+)$") {
            $totalGR += [int]$Matches[1]
        }
        else {
            $totalGR += 1
        }
    }

    # ==========================
    # Expansão MINUTAS
    # ==========================
    $totalMinutas = 0
    foreach ($item in $produtor.QUANT_MINUTAS) {
        if ($item -match "X(\d+)$") {
            $totalMinutas += [int]$Matches[1]
        }
        else {
            $totalMinutas += 1
        }
    }

    # ==========================
    # Contagem PLACAS
    # ==========================
    $totalPlacas = $produtor.PLACAS.Count

    Write-Host "GR total expandido: $totalGR"
    Write-Host "Minutas total expandido: $totalMinutas"
    Write-Host "Placas informadas: $totalPlacas"
    Write-Host ""

    # ==========================
    # Validação
    # ==========================
    if ($totalGR -ne $totalMinutas -or $totalGR -ne $totalPlacas) {

        Write-Host "ERRO DE CONSISTÊNCIA DETECTADO!" -ForegroundColor Red
        Write-Host "Os totais não estão alinhados." -ForegroundColor Red
        Write-Host ""
        return $false
    }

    Write-Host "✔ Dados alinhados e consistentes." -ForegroundColor Green
    Write-Host ""
    return $true
}


function Step-RecebimentoEntrada {

    param($produtor)

try {


# ==========================================
# VALIDAÇÃO DO TXT
# ==========================================
if (-not (Test-ConsistenciaCadastro -produtor $produtor)) {
    Write-Host "Processamento cancelado por inconsistência no TXT." -ForegroundColor Red
    return
}
# ==========================================
  
    if ($produtor.NIVEL -ge 1) {
        Write-Host "[SKIP] Recebimento já executado (Nivel $($produtor.NIVEL))."
        return
    }

    Write-Host "=======================================" -ForegroundColor Cyan
    Write-Host "TESTE DE PROCESSAMENTO DE DADOS"
    Write-Host "Produtor: $($produtor.NOME)"
    Write-Host "Instrucao: $($produtor.INSTRUCAO)"
    Write-Host "Tipo: $($produtor.TIPO)"
    Write-Host "Pedido: $($produtor.PEDIDO)"
    Write-Host "=======================================" -ForegroundColor Cyan
    Write-Host ""

    #Abort-IfNeeded

    # =============================
    # NOTAS
    # =============================

    $totalNotas = 0

    if (Get-Command Get-TotalNotas -ErrorAction SilentlyContinue) {
        $totalNotas = Get-TotalNotas $produtor
    }
    else {
        if ($produtor.NOTAS) {
            $totalNotas = $produtor.NOTAS.Count
        }
    }

    Write-Host "Notas fiscais ($totalNotas):" -ForegroundColor Yellow

    $i = 1
    $notas = @()
    if ($produtor.NOTAS) { $notas = $produtor.NOTAS }

    foreach ($nota in $notas) {
        Write-Host "  [$i/$totalNotas] $nota"
        $i++
    }

    Write-Host ""

    # =============================
    # PLACAS
    # =============================

    $totalPlacas = 0

    if (Get-Command Get-TotalPlacas -ErrorAction SilentlyContinue) {
        $totalPlacas = Get-TotalPlacas $produtor
    }
    else {
        if ($produtor.PLACAS) {
            $totalPlacas = $produtor.PLACAS.Count
        }
    }

    Write-Host "Placas ($totalPlacas):" -ForegroundColor Yellow

    $i = 1
    $placas = @()
    if ($produtor.PLACAS) { $placas = $produtor.PLACAS }

    foreach ($placa in $placas) {
        Write-Host "  [$i/$totalPlacas] $placa"
        $i++
    }

    Write-Host ""

    # =============================
    # GRorJBS
    # =============================

    $expandGR = @()

    if (Get-Command Expand-GRorJBS -ErrorAction SilentlyContinue) {
        $expandGR = Expand-GRorJBS $produtor
    }
    else {
        if ($produtor.GRorJBS) {
            $expandGR = $produtor.GRorJBS
        }
        Write-Host "[INFO] Expand-GRorJBS não implementado." -ForegroundColor DarkYellow
    }

    Write-Host "GRorJBS expandido (Total $($expandGR.Count)):" -ForegroundColor Yellow

    $i = 1
    foreach ($g in $expandGR) {
        Write-Host "  [$i/$($expandGR.Count)] $g"
        $i++
    }

    Write-Host ""

        # # =============================
    # QUANT_MINUTAS
    # =============================

    $expandMinutas = @()

    if (Get-Command Expand-QuantMinutas -ErrorAction SilentlyContinue) {
        $expandMinutas = Expand-QuantMinutas $produtor
    }
    else {
        if ($produtor.QUANT_MINUTAS) {
            $expandMinutas = $produtor.QUANT_MINUTAS
        }
        Write-Host "[INFO] Expand-QuantMinutas não implementado." -ForegroundColor DarkYellow
    }

    Write-Host "QUANT_MINUTAS expandido (Total $($expandMinutas.Count)):" -ForegroundColor Yellow

    $i = 1
    foreach ($m in $expandMinutas) {
        Write-Host "  [$i/$($expandMinutas.Count)] $m"
        $i++
    }

    Write-Host ""
    Write-Host "======================================="
    Write-Host "[OK] Teste de processamento concluído."
    Write-Host "=======================================" -ForegroundColor Green

    Update-ProducerLevel -NewLevel 1

    Read-Host "Pressione ENTER para continuar"
}
catch {
    Write-Host ""
    Write-Host "ERRO DETECTADO:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""

    $op = Read-Host "Erro. (R)etentar, (P)ular, (A)bortar?"

    switch ($op.ToUpper()) {
        "R" { return Step-RecebimentoEntrada $produtor }
        "P" { return }
        "A" { throw }
    }
}

# Atualiza NIVEL para 1 após sucesso
Update-ProdutorNivel -Produtor $produtor -NovoNivel 1

}


<#
function Step-RecebimentoEntrada {

    param($produtor)

    if ($produtor.NIVEL -ge 1) {
        Write-Host "[SKIP] Recebimento já executado (Nivel $($produtor.NIVEL))."
        return
    }

    Write-Host "Executando Recebimento: $($produtor.INSTRUCAO) - $($produtor.NOME)" -ForegroundColor Cyan

    if (-not $produtor.NOTAS -or $produtor.NOTAS.Count -eq 0) {
        Write-Host "[SKIP] Sem notas."
        return
    }

    $code = if ($produtor.TIPO -eq "PJ") { "2629" } else { "2630" }

    

    Abort-IfNeeded

    Write-Host "Notas fiscais"
    Write-Host " "    
    foreach ($ch in $produtor.NOTAS) {

        Abort-IfNeeded
        $i++

        Write-Host "  [OK] Nota $($i-1)/$($produtor.NOTAS.Count)"
    
        Write-Host $($ch)   
        Write-Host " "
        Write-Host $($code)   
        Write-Host " "
        
    }
    Write-Host " "

    Write-Host "[OK] Recebimento concluído."

    Update-ProducerLevel -NewLevel 1



pause
  




    Invoke-ClickPos -Name "ABRIR_TELA_RECEBIMENTODEENTRADA_ERP"
    SleepMs 800
    Abort-IfNeeded

    Press-Key "{F2}"
    Press-Key "{TAB}"

    Paste-Text $produtor.INSTRUCAO 2000
    Press-Key "{TAB}"

    $i = 0
    foreach ($ch in $produtor.NOTAS) {

        Abort-IfNeeded
        $i++

        Paste-Text $ch 5000
        Press-Key "{TAB}"
        Press-Key $code
        Press-Key "{ENTER}"
        SleepMs 3000
        Press-Key "{F4}"

        Write-Host "  [OK] Nota $i/$($produtor.NOTAS.Count)"
    }

    Press-Key "{F4}"
    Press-Key "{RIGHT}"
    Press-Key "{ENTER}"

    Write-Host "[OK] Recebimento concluído."

    Update-ProducerLevel -NewLevel 1
 
      
}
   #>
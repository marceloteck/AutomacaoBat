function Parse-AutomacaoMaster {

    param([string]$Path)

    if (!(Test-Path -LiteralPath $Path)) {
        throw "Arquivo nao encontrado: $Path"
    }

    $lines = Get-Content -LiteralPath $Path -Encoding UTF8
    $items = New-Object System.Collections.Generic.List[object]

    $cur = $null
    $currentListKey = $null

    function New-Producer {
        return @{
            NOME                = ""
            STATUS              = "PENDENTE"
            TIPO                = ""
            INSTRUCAO           = ""
            PEDIDO              = ""
            NIVEL               = 0

            NOTAS               = New-Object System.Collections.Generic.List[string]
            GRorJBS             = New-Object System.Collections.Generic.List[string]
            QUANT_MINUTAS       = New-Object System.Collections.Generic.List[string]
            PLACAS              = New-Object System.Collections.Generic.List[string]

            TOTAL_GRorJBS       = 0
            TOTAL_QUANT_MINUTAS = 0
        }
    }

    function Flush-Current {

        if ($cur -eq $null) { return }

        # Calcular totais automáticos

        foreach ($item in $cur.GRorJBS) {
            if ($item -match '^(.+)[Xx](\d+)$') {
                $cur.TOTAL_GRorJBS += [int]$matches[2]
            }
        }

        foreach ($item in $cur.QUANT_MINUTAS) {
            if ($item -match '^(.+)[Xx](\d+)$') {
                $cur.TOTAL_QUANT_MINUTAS += [int]$matches[2]
            }
        }

        $items.Add([pscustomobject]$cur)
    }

    foreach ($raw in $lines) {

        $line = ("" + $raw).Trim()

        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line.StartsWith("#") -or $line.StartsWith(";")) { continue }

        # Novo produtor
        if ($line -eq "[PRODUTOR]") {
            Flush-Current
            $cur = New-Producer
            $currentListKey = $null
            continue
        }

        if ($null -eq $cur) { continue }

        # Fim de bloco
        if ($line -eq "}") {
            $currentListKey = $null
            continue
        }
        # ================================
        # Listas com dois pontos (NOTAS:, PLACAS:)
        # ================================

        # ============================================
        # Detecta lista no formato:
        # CHAVE=
        # {
        # ============================================
        if ($line -match '^([A-Z_]+)\s*=\s*$') {

            $key = $matches[1]

            if ($cur.ContainsKey($key)) {
                $currentListKey = $key
            }

            continue
        }
        if ($line -eq "{") {
            continue
        }

       # ============================================
        # Se estamos dentro de lista
        # ============================================
        if ($currentListKey) {

            # Se encontrou nova chave (com "=" ou ":")
            if ($line -match '^[A-Z_]+\s*(=|:)\s*') {

                # Encerra a lista atual
                $currentListKey = $null
                # NÃO usa continue aqui — deixa o código tratar a linha como nova chave
            }
            else {
                $clean = $line.Trim()
                if ($clean -ne "") {
                    $cur.$currentListKey.Add($clean)
                }
                continue
            }
        }

        # Campos simples
        if ($line -match '^([A-ZÇÃÕÉÍÓÚ_]+)\s*=\s*(.*)$') {

            $k = $matches[1].ToUpper()
            $v = $matches[2].Trim()

            if ($cur.ContainsKey($k)) {

                switch ($k) {
                    "NIVEL" { $cur.NIVEL = [int]$v }
                    default { $cur.$k = $v }
                }
            }
        }
    }

    Flush-Current
    return $items
}

function Update-ProdutorNivel {

    param(
        [Parameter(Mandatory)]
        [object]$Produtor,

        [Parameter(Mandatory)]
        [int]$NovoNivel
    )

    try {

        if ($Produtor.NIVEL -lt $NovoNivel) {

            $Produtor.NIVEL = $NovoNivel

            Write-Host "[OK] NIVEL atualizado para $NovoNivel -> $($Produtor.NOME)" -ForegroundColor Green
        }
        else {
            Write-Host "[INFO] NIVEL já está em $($Produtor.NIVEL)" -ForegroundColor Yellow
        }

    }
    catch {
        Write-Host "[ERRO] Falha ao atualizar NIVEL: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

function Save-AutomacaoMaster {

    param(
        [string]$Path,
        [object[]]$Producers
    )

    $sb = New-Object System.Text.StringBuilder

    foreach ($p in $Producers) {

        $null = $sb.AppendLine("[PRODUTOR]")
        $null = $sb.AppendLine("NOME=$($p.NOME)")
        $null = $sb.AppendLine("STATUS=$($p.STATUS)")
        $null = $sb.AppendLine("TIPO=$($p.TIPO)")
        $null = $sb.AppendLine("INSTRUCAO=$($p.INSTRUCAO)")
        $null = $sb.AppendLine("PEDIDO=$($p.PEDIDO)")
        $null = $sb.AppendLine("NIVEL=$($p.NIVEL)")
        $null = $sb.AppendLine()

        function Write-List($key, $list) {
            if ($list -and $list.Count -gt 0) {
                $null = $sb.AppendLine("$key=")
                $null = $sb.AppendLine("{")
                foreach ($item in $list) {
                    $null = $sb.AppendLine($item)
                }
                $null = $sb.AppendLine("}")
                $null = $sb.AppendLine()
            }
        }

        Write-List "NOTAS" $p.NOTAS
        Write-List "GRorJBS" $p.GRorJBS
        Write-List "QUANT_MINUTAS" $p.QUANT_MINUTAS
        Write-List "PLACAS" $p.PLACAS

        $null = $sb.AppendLine()
    }

    Set-Content -LiteralPath $Path -Value $sb.ToString() -Encoding UTF8

    Write-Host "[OK] Arquivo atualizado com sucesso." -ForegroundColor Green
}


######## VALIDAÇÃO
function Test-ProdutorTemNotas {
    param($produtor)

    if ($null -eq $produtor) { return $false }

    if ($null -eq $produtor.NOTAS) { return $false }

    if ($produtor.NOTAS.Count -eq 0) { return $false }

    return $true
}

function Validate-ProdutorAntesPipeline {
    param($produtor)

    if ($null -eq $produtor) {
        Write-Host "Produtor nulo." -ForegroundColor Red
        return $false
    }

    if ([string]::IsNullOrWhiteSpace($produtor.NOME)) {
        Write-Host "Produtor sem nome válido." -ForegroundColor Red
        return $false
    }

    if ($null -eq $produtor.NIVEL) {
        Write-Host "Produtor sem NIVEL definido." -ForegroundColor Yellow
        return $false
    }

    return $true
}
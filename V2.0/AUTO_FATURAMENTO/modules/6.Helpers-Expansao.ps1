function Get-TotalNotas {
    param($produtor)
    if ($produtor.NOTAS) {
        return $produtor.NOTAS.Count
    }
    return 0
}

function Get-TotalPlacas {
    param($produtor)
    if ($produtor.PLACAS) {
        return $produtor.PLACAS.Count
    }
    return 0
}

function Expand-GRorJBS {

    param($produtor)

    $result = New-Object System.Collections.Generic.List[string]

    foreach ($item in $produtor.GRorJBS) {

        if ($item -match '^(.+)[Xx](\d+)$') {

            $codigo = $matches[1]
            $quant  = [int]$matches[2]

            for ($i = 0; $i -lt $quant; $i++) {
                $result.Add($codigo)
            }
        }
    }

    return $result
}

function Expand-QuantMinutas {

    param($produtor)

    $result = New-Object System.Collections.Generic.List[string]

    foreach ($item in $produtor.QUANT_MINUTAS) {

        if ($item -match '^(.+)[Xx](\d+)$') {

            $codigo = $matches[1]
            $quant  = [int]$matches[2]

            for ($i = 0; $i -lt $quant; $i++) {
                $result.Add($codigo)
            }
        }
    }

    return $result
}
param(
  [Parameter(Mandatory=$true)][string]$Root,
  [Parameter(Mandatory=$true)][string]$PedidosDirName,
  [double]$Threshold = 0.85,
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# Função para remover acentos
function Remove-Diacritics([string]$text) {
  if ([string]::IsNullOrWhiteSpace($text)) { return "" }
  $normalized = $text.Normalize([System.Text.NormalizationForm]::FormD)
  $sb = New-Object System.Text.StringBuilder
  foreach ($ch in $normalized.ToCharArray()) {
    if ([System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch) -ne [System.Globalization.UnicodeCategory]::NonSpacingMark) {
      [void]$sb.Append($ch)
    }
  }
  return $sb.ToString().Normalize([System.Text.NormalizationForm]::FormC)
}

# Normalização de nomes para comparação
function Normalize-Text([string]$s) {
  if([string]::IsNullOrWhiteSpace($s)) { return "" }

  $name = [IO.Path]::GetFileName($s)
  if($name -match '\.PDF$'){
    $name = [IO.Path]::GetFileNameWithoutExtension($name)
  }

  $name = $name -replace '^\d+\.', ''
  $name = $name -replace '\([^)]*\)', ' '
  $name = Remove-Diacritics $name
  $name = $name.ToUpperInvariant()
  $name = $name -replace '[^A-Z0-9 ]', ' '
  $name = $name -replace '\s+', ' '
  return $name.Trim()
}

function Tokens([string]$s) {
  $n = Normalize-Text $s
  if([string]::IsNullOrWhiteSpace($n)) { return @() }
  return $n.Split(' ') | Where-Object { $_.Length -ge 2 -and $_ -notmatch '^\d+$' }
}

function StrongNumbers([string]$s) {
  $raw = Normalize-Text $s
  $nums = [regex]::Matches($raw, '\b\d{2,}\b') | ForEach-Object { $_.Value }
  $ds   = [regex]::Matches($raw, '\b\d{2,3}D\b') | ForEach-Object { $_.Value }
  return ($nums + $ds) | Select-Object -Unique
}

function Score-Tokens($aTokens, $bTokens) {
  if($aTokens.Count -eq 0 -or $bTokens.Count -eq 0) { return 0.0 }

  $setA = [System.Collections.Generic.HashSet[string]]::new()
  foreach($t in $aTokens){ [void]$setA.Add($t) }

  $setB = [System.Collections.Generic.HashSet[string]]::new()
  foreach($t in $bTokens){ [void]$setB.Add($t) }

  $inter = 0
  foreach($t in $setA){
    if($setB.Contains($t)){ $inter++ }
  }

  $union = $setA.Count + $setB.Count - $inter
  if($union -le 0) { return 0.0 }

  $jacc  = $inter / $union
  $cover = $inter / [Math]::Max(1, $setA.Count)

  return (0.35 * $jacc) + (0.65 * $cover)
}

# ----------------- EXECUÇÃO -----------------

$PedidosPath = Join-Path $Root $PedidosDirName
if(-not (Test-Path -LiteralPath $PedidosPath)){
  Write-Host "[ERRO] Pasta de pedidos nao encontrada: $PedidosPath" -ForegroundColor Red
  exit 1
}

$pastas = Get-ChildItem -LiteralPath $Root -Directory | Where-Object { $_.Name -ne $PedidosDirName }

if(-not $pastas){
  Write-Host "[PULAR] Nao existem pastas de destino na raiz." -ForegroundColor Yellow
  exit 0
}

$pedidos = Get-ChildItem -LiteralPath $PedidosPath -Filter "*.pdf" -File
if(-not $pedidos){
  Write-Host "[PULAR] Nenhum PDF encontrado em $PedidosPath" -ForegroundColor Yellow
  exit 0
}

$copied=0; $skipped=0; $planned=0

foreach($pedido in $pedidos){
  $pTok = Tokens $pedido.Name
  if($pTok.Count -eq 0){ $skipped++; continue }

  $pNums = StrongNumbers $pedido.Name
  $best = $null
  $bestScore = -1.0
  $secondScore = -1.0
  $bestReason = ""

  foreach($pasta in $pastas){
    $fTok  = Tokens $pasta.Name
    $fNums = StrongNumbers $pasta.Name

    $nameScore = Score-Tokens $pTok $fTok

    $numHit = $false
    if($pNums.Count -gt 0 -and $fNums.Count -gt 0){
      foreach($n in $pNums){
        if($fNums -contains $n){ $numHit = $true; break }
      }
    }

    $score = $nameScore
    $reason = "nome"

    if($numHit){
      $score = [Math]::Max($score, 0.97)
      $reason = "nome+numero"
    }

    if($score -gt $bestScore){
      $secondScore = $bestScore
      $bestScore = $score
      $best = $pasta
      $bestReason = $reason
    } elseif($score -gt $secondScore){
      $secondScore = $score
    }
  }

  $marginNeed = if($bestReason -eq "nome+numero") { 0.05 } else { 0.10 }
  $marginOk = ($bestScore - $secondScore) -ge $marginNeed

  if($best -and $bestScore -ge $Threshold -and $marginOk){
    $dest = Join-Path $best.FullName $pedido.Name

    if(Test-Path -LiteralPath $dest){
      $skipped++
      continue
    }

    if($DryRun){
      $planned++
      Write-Host "[SIMULAR][$bestReason] $($pedido.Name) -> $($best.Name)" -ForegroundColor Cyan
    } else {
      Copy-Item -LiteralPath $pedido.FullName -Destination $dest -Force
      $copied++
      Write-Host "[OK][$bestReason] $($pedido.Name) -> $($best.Name)" -ForegroundColor Green
    }
  } else {
    $skipped++
  }
}

Write-Host "`n================================"
if($DryRun){
  Write-Host "[SIMULADO] Planejados: $planned | Ignorados: $skipped"
} else {
  Write-Host "[CONCLUIDO] Copiados: $copied | Ignorados: $skipped"
}
Write-Host "================================"

exit 0
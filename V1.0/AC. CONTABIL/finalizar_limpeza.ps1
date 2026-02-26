param(
  [Parameter(Mandatory=$true)][string]$Root,
  [Parameter(Mandatory=$true)][string]$PedidosDirName
)

$ErrorActionPreference = "Stop"

$dirs = Get-ChildItem -LiteralPath $Root -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne $PedidosDirName }

if(-not $dirs){
  Write-Host "[PULAR] Nao achei pastas de acertos para finalizar."
  exit 0
}

$moved=0
foreach($d in $dirs){
  $pdfs = Get-ChildItem -LiteralPath $d.FullName -Filter "*.pdf" -File -ErrorAction SilentlyContinue
  foreach($p in $pdfs){
    Move-Item -LiteralPath $p.FullName -Destination $Root -Force
    $moved++
  }
  Remove-Item -LiteralPath $d.FullName -Recurse -Force
}

# remove prefixo "1." dos finais na raiz
$finals = Get-ChildItem -LiteralPath $Root -Filter "1.*.pdf" -File -ErrorAction SilentlyContinue
$ren=0
foreach($f in $finals){
  $new = $f.Name -replace '^1\.',''
  if($new -ne $f.Name){
    Rename-Item -LiteralPath $f.FullName -NewName $new -Force
    $ren++
  }
}

Write-Host "[OK] PDFs movidos para raiz: $moved"
Write-Host "[OK] Removido prefixo 1.: $ren"
exit 0

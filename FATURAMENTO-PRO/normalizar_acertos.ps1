param([Parameter(Mandatory=$true)][string]$Root)

$ErrorActionPreference = "Stop"

$pdfs = Get-ChildItem -LiteralPath $Root -Filter "*.pdf" -File -ErrorAction SilentlyContinue
if(-not $pdfs){
  Write-Host "[PULAR] Nenhum PDF na raiz."
  exit 0
}

$cAC=0; $cADD=0; $cSKIP=0; $cREN=0

foreach($f in $pdfs){
  $name = $f.Name
  $new  = $null

  if($name -match '^AC\.'){
    $new = ($name -replace '^AC\.','1.')
    $cAC++
  }
  elseif($name -match '^\d+\.'){
    $cSKIP++
    continue
  }
  else{
    $new = '1.' + $name
    $cADD++
  }

  if($new -and $new -ne $name){
    $target = Join-Path $Root $new
    if(Test-Path -LiteralPath $target){
      $base = [IO.Path]::GetFileNameWithoutExtension($new)
      $ext  = [IO.Path]::GetExtension($new)
      $i=1
      do{
        $candidate = Join-Path $Root ($base + " ("+$i+")" + $ext)
        $i++
      } while(Test-Path -LiteralPath $candidate)
      $new = [IO.Path]::GetFileName($candidate)
    }
    Rename-Item -LiteralPath $f.FullName -NewName $new -Force
    $cREN++
  }
}

Write-Host "[OK] AC->1.: $cAC"
Write-Host "[OK] Adicionado 1.: $cADD"
Write-Host "[OK] Ja tinha numero.: $cSKIP"
Write-Host "[OK] Renomeados: $cREN"
exit 0

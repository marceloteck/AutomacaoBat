param(
  [Parameter(Mandatory=$true)][string]$Root,
  [Parameter(Mandatory=$true)][string]$Cli,
  [Parameter(Mandatory=$true)][string]$PedidosDirName,
  [string]$ProfileName = "Default"
)

$ErrorActionPreference = 'Stop'

function Get-SortKey([string]$baseName){
  $m = [regex]::Match($baseName, '^\d+')
  if($m.Success){ return [int]$m.Value }
  return [int]::MaxValue
}

function Wait-File([string]$path, [int]$seconds=120){
  for($i=0; $i -lt $seconds; $i++){
    if(Test-Path -LiteralPath $path){ return $true }
    Start-Sleep -Seconds 1
  }
  return $false
}

$dirs = Get-ChildItem -LiteralPath $Root -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne $PedidosDirName }

if(-not $dirs){
  Write-Host "[PULAR] Nao achei pastas de acertos."
  exit 2
}

$hadWork = $false
$hadFail = $false

foreach($d in $dirs){
  try{
    $pdfs = Get-ChildItem -LiteralPath $d.FullName -Filter '*.pdf' -File -ErrorAction SilentlyContinue
    if(-not $pdfs){ Write-Host "[PULAR] $($d.Name) (sem pdf)"; continue }
    if($pdfs.Count -lt 2){ Write-Host "[PULAR] $($d.Name) (apenas 1 pdf)"; continue }

    $hadWork = $true

    $sorted = $pdfs | Sort-Object @{Expression={ Get-SortKey $_.BaseName }}, @{Expression={$_.Name}}
    $first  = $sorted[0]
    $finalName = $first.Name
    $finalPath = Join-Path $d.FullName $finalName

    Write-Host ""
    Write-Host "[MESCLAR] $($d.Name)"
    Write-Host "[FINAL]  $finalName"
    $sorted | ForEach-Object { Write-Host (" - " + $_.Name) }

    $tempOut = Join-Path $d.FullName ("TEMP_MERGE_" + [Guid]::NewGuid().ToString("N") + ".pdf")
    if(Test-Path -LiteralPath $tempOut){ Remove-Item -LiteralPath $tempOut -Force -ErrorAction SilentlyContinue }

    # >>> SINTAXE que funcionou no seu PC: /Profile=... e /OutputFile=...
    $args = @(
      'mergefiles',
      ("/Profile=$ProfileName"),
      ("/OutputFile=$tempOut")
    ) + ($sorted | ForEach-Object { $_.FullName })

    & $Cli @args
    $exit = $LASTEXITCODE

    if($exit -ne 0){
      Write-Host "[ERRO] ExitCode=$exit (falhou nessa pasta)"
      $hadFail = $true
      continue
    }

    if(-not (Wait-File -path $tempOut -seconds 120)){
      Write-Host "[ERRO] TEMP nao apareceu (Auto-Save/saida do PDFCreator)."
      $hadFail = $true
      continue
    }

    # Só agora remove os antigos e renomeia o TEMP
    foreach($f in $sorted){
      Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue
    }

    if(Test-Path -LiteralPath $finalPath){
      Remove-Item -LiteralPath $finalPath -Force -ErrorAction SilentlyContinue
    }

    Rename-Item -LiteralPath $tempOut -NewName $finalName -Force

    if(Test-Path -LiteralPath $finalPath){
      Write-Host "[OK] Final gerado: $finalName"
    } else {
      Write-Host "[ERRO] Nao consegui aplicar o nome final."
      $hadFail = $true
    }
  }
  catch{
    Write-Host "[ERRO] $($d.Name) -> $($_.Exception.Message)"
    $hadFail = $true
    continue
  }
}

if(-not $hadWork){
  Write-Host "[PULAR] Nao havia pastas com 2+ PDFs para mesclar."
  exit 2
}

if($hadFail){
  Write-Host ""
  Write-Host "[FALHA] Uma ou mais pastas falharam no merge."
  exit 1
}

Write-Host ""
Write-Host "[SUCESSO] Todas as pastas foram mescladas com sucesso."
exit 0

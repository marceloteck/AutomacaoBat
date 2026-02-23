# ==========================================================
# CLICK POSITIONS (persistente) - Auto aprender / editar / excluir
# Salva em: click_positions.json (mesma pasta do script)
# ==========================================================

# ---------- Win32 (mouse + teclas) ----------
if (-not ("ClickPosU32" -as [type])) {
  Add-Type @"
using System;
using System.Runtime.InteropServices;

public class ClickPosU32 {
  [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int vKey);
  [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT lpPoint);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
  [DllImport("user32.dll")] public static extern void mouse_event(int dwFlags, int dx, int dy, int cButtons, int dwExtraInfo);

  public struct POINT { public int X; public int Y; }

  public const int VK_LBUTTON = 0x01;
  public const int LEFTDOWN = 0x02;
  public const int LEFTUP   = 0x04;
  public const int RIGHTDOWN= 0x08;
  public const int RIGHTUP  = 0x10;
}
"@ | Out-Null
}

# ---------- Utils ----------
function Normalize-PosName {
  param([Parameter(Mandatory=$true)][string]$Name)
  $n = $Name.Trim()
  if ($n.Length -lt 1) { throw "Nome da posição vazio." }
  return $n
}

function Get-ClickPosStorePath {
  param([string]$FileName = "click_positions.json")
  $base = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
  Join-Path $base $FileName
}

function Read-ClickPosStore {
  param([string]$StorePath)

  if (!(Test-Path $StorePath)) { return @{} }

  $raw = Get-Content -Raw -Encoding UTF8 $StorePath
  if ([string]::IsNullOrWhiteSpace($raw)) { return @{} }

  try {
    $obj = $raw | ConvertFrom-Json
    if ($null -eq $obj) { return @{} }

    $ht = @{}
    foreach ($p in $obj.PSObject.Properties) { $ht[$p.Name] = $p.Value }
    return $ht
  } catch {
    throw "JSON inválido em '$StorePath'. Apague/renomeie o arquivo e rode de novo. Erro: $($_.Exception.Message)"
  }
}

function Write-ClickPosStore {
  param([string]$StorePath, [hashtable]$Data)
  ($Data | ConvertTo-Json -Depth 6) | Set-Content -Encoding UTF8 $StorePath
}

function Get-ClickPos {
  param(
    [Parameter(Mandatory=$true)][string]$Name,
    [string]$StorePath = (Get-ClickPosStorePath)
  )
  $Name = Normalize-PosName $Name
  $store = Read-ClickPosStore -StorePath $StorePath
  if (-not $store.ContainsKey($Name)) { return $null }
  return $store[$Name]
}

function List-ClickPos {
  param([string]$StorePath = (Get-ClickPosStorePath))
  $store = Read-ClickPosStore -StorePath $StorePath
  $store.Keys | Sort-Object
}

function Remove-ClickPos {
  param(
    [Parameter(Mandatory=$true)][string]$Name,
    [string]$StorePath = (Get-ClickPosStorePath)
  )
  $Name = Normalize-PosName $Name
  $store = Read-ClickPosStore -StorePath $StorePath
  if ($store.ContainsKey($Name)) {
    $store.Remove($Name) | Out-Null
    Write-ClickPosStore -StorePath $StorePath -Data $store
    return $true
  }
  return $false
}

# ---------- Menu ----------
function Confirm-Choice {
  param([string]$Prompt)

  while ($true) {
    Write-Host ""
    Write-Host $Prompt
    Write-Host "  1) Aprender (clicar e salvar)"
    Write-Host "  2) Editar manualmente (digitar X/Y)"
    Write-Host "  3) Excluir (se existir)"
    Write-Host "  4) Cancelar (não salva / não clica)"
    $opt = (Read-Host "Escolha").Trim()

    switch ($opt) {
      "1" { return "learn" }
      "2" { return "edit" }
      "3" { return "delete" }
      "4" { return "cancel" }
      default { Write-Host "Opção inválida." -ForegroundColor Red }
    }
  }
}

function Ensure-ClickPos {
  param(
    [Parameter(Mandatory=$true)][string]$Name,
    [string]$StorePath = (Get-ClickPosStorePath),
    [switch]$AlsoTxt
  )

  $Name = Normalize-PosName $Name
  $pos = Get-ClickPos -Name $Name -StorePath $StorePath
  if ($null -ne $pos) { return $pos }

  $choice = Confirm-Choice "[POSIÇÃO NÃO EXISTE] '$Name'"

  if ($choice -eq "cancel") { throw "Cancelado. Posição '$Name' não foi criada." }

  if ($choice -eq "delete") {
    Remove-ClickPos -Name $Name -StorePath $StorePath | Out-Null
    throw "Removido (se existia). Rode de novo para aprender/editar."
  }

  if ($choice -eq "edit") {
    $x = [int](Read-Host "Digite X")
    $y = [int](Read-Host "Digite Y")

    $store = Read-ClickPosStore -StorePath $StorePath
    $store[$Name] = [pscustomobject]@{ x=$x; y=$y; savedAt=(Get-Date).ToString("s") }
    Write-ClickPosStore -StorePath $StorePath -Data $store

    if ($AlsoTxt) {
      $base = Split-Path -Parent $StorePath
      $txtPath = Join-Path $base ("pos_{0}.txt" -f ($Name -replace '[\\/:*?"<>|]', '_'))
      "$x;$y" | Set-Content -Encoding UTF8 $txtPath
    }

    Write-Host "[OK] Salvo manual: $Name => X=$x Y=$y" -ForegroundColor Green
    return $store[$Name]
  }

  # learn
  Write-Host ""
  Write-Host "[APRENDER] Posicione o mouse e clique 1x para salvar '$Name' (ESC cancela)" -ForegroundColor Yellow

  while ($true) {
    if ( (([ClickPosU32]::GetAsyncKeyState(0x1B)) -band 0x8000) -ne 0 ) { throw "Aprendizado cancelado (ESC)." }
    if ( (([ClickPosU32]::GetAsyncKeyState([ClickPosU32]::VK_LBUTTON)) -band 0x8000) -ne 0 ) { break }
    Start-Sleep -Milliseconds 10
  }

  $p = New-Object ClickPosU32+POINT
  [ClickPosU32]::GetCursorPos([ref]$p) | Out-Null

  while ( (([ClickPosU32]::GetAsyncKeyState([ClickPosU32]::VK_LBUTTON)) -band 0x8000) -ne 0 ) {
    Start-Sleep -Milliseconds 10
  }

  $store = Read-ClickPosStore -StorePath $StorePath
  $store[$Name] = [pscustomobject]@{ x=[int]$p.X; y=[int]$p.Y; savedAt=(Get-Date).ToString("s") }
  Write-ClickPosStore -StorePath $StorePath -Data $store

  if ($AlsoTxt) {
    $base = Split-Path -Parent $StorePath
    $txtPath = Join-Path $base ("pos_{0}.txt" -f ($Name -replace '[\\/:*?"<>|]', '_'))
    "$($p.X);$($p.Y)" | Set-Content -Encoding UTF8 $txtPath
  }

  Write-Host "[OK] Salvo: $Name => X=$($p.X) Y=$($p.Y)" -ForegroundColor Green
  return $store[$Name]
}

# ---------- O QUE VOCÊ CHAMA NO LOOP ----------
function Invoke-ClickPos {
  param(
    [Parameter(Mandatory=$true)][string]$Name,
    [int]$Repeat = 1,
    [int]$DelayBeforeMs = 0,
    [int]$DelayBetweenMs = 50,
    [ValidateSet("Left","Right")][string]$Button = "Left",
    [string]$StorePath = (Get-ClickPosStorePath),
    [switch]$AlsoTxt
  )

  $Name = Normalize-PosName $Name

  # Se não existir, abre menu e aprende/edita/exclui
  $pos = Get-ClickPos -Name $Name -StorePath $StorePath
  if ($null -eq $pos) {
    Ensure-ClickPos -Name $Name -StorePath $StorePath -AlsoTxt:$AlsoTxt | Out-Null
    return  # IMPORTANTE: não clica agora, pois o clique foi manual no aprendizado
  }

  if ($DelayBeforeMs -gt 0) { Start-Sleep -Milliseconds $DelayBeforeMs }

  $x = [int]$pos.x
  $y = [int]$pos.y

  for($i=1; $i -le $Repeat; $i++){
    [ClickPosU32]::SetCursorPos($x, $y) | Out-Null

    if ($Button -eq "Left") {
      [ClickPosU32]::mouse_event([ClickPosU32]::LEFTDOWN, 0, 0, 0, 0)
      Start-Sleep -Milliseconds 15
      [ClickPosU32]::mouse_event([ClickPosU32]::LEFTUP,   0, 0, 0, 0)
    } else {
      [ClickPosU32]::mouse_event([ClickPosU32]::RIGHTDOWN, 0, 0, 0, 0)
      Start-Sleep -Milliseconds 15
      [ClickPosU32]::mouse_event([ClickPosU32]::RIGHTUP,   0, 0, 0, 0)
    }

    if ($i -lt $Repeat -and $DelayBetweenMs -gt 0) {
      Start-Sleep -Milliseconds $DelayBetweenMs
    }
  }
}

# ---------- CLIQUE DUPLO (usa Invoke-ClickPos) ----------
function Invoke-DoubleClickPos {
  param(
    [Parameter(Mandatory=$true)]
    [string]$Name,

    [int]$DelayBetweenClicksMs = 80,

    [int]$DelayBeforeMs = 0,

    [ValidateSet("Left","Right")]
    [string]$Button = "Left",

    [string]$StorePath = (Get-ClickPosStorePath),

    [switch]$AlsoTxt
  )

  if ($DelayBeforeMs -gt 0) { Start-Sleep -Milliseconds $DelayBeforeMs }

  # 1º clique
  Invoke-ClickPos -Name $Name -Repeat 1 -DelayBeforeMs 0 -DelayBetweenMs 0 -Button $Button -StorePath $StorePath -AlsoTxt:$AlsoTxt

  # intervalo entre cliques
  if ($DelayBetweenClicksMs -gt 0) { Start-Sleep -Milliseconds $DelayBetweenClicksMs }

  # 2º clique
  Invoke-ClickPos -Name $Name -Repeat 1 -DelayBeforeMs 0 -DelayBetweenMs 0 -Button $Button -StorePath $StorePath -AlsoTxt:$AlsoTxt
}

# ---------- CLIQUE DIREITO ----------
function Invoke-RightClickPos {
  param(
    [Parameter(Mandatory=$true)]
    [string]$Name,

    [int]$DelayBeforeMs = 0,

    [string]$StorePath = (Get-ClickPosStorePath),

    [switch]$AlsoTxt
  )

  Invoke-ClickPos `
    -Name $Name `
    -Button Right `
    -DelayBeforeMs $DelayBeforeMs `
    -StorePath $StorePath `
    -AlsoTxt:$AlsoTxt
}
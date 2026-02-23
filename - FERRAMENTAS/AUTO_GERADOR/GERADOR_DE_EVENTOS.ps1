# ==========================================================
# GERADOR_DE_EVENTOS.ps1
# Grava mouse (left/right/double) + atalhos do teclado
# Gera:
#   <Projeto>_script.ps1
#   <Projeto>_click_positions.json
#
# PARAR: pressione ESC
# ==========================================================

# ---------------- Win32 (GetAsyncKeyState + cursor) ----------------
if (-not ("RecorderU32" -as [type])) {
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class RecorderU32 {
  [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int vKey);
  [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT lpPoint);

  public struct POINT { public int X; public int Y; }

  public const int VK_ESCAPE  = 0x1B;
  public const int VK_LBUTTON = 0x01;
  public const int VK_RBUTTON = 0x02;

  public const int VK_CONTROL = 0x11;
  public const int VK_SHIFT   = 0x10;
  public const int VK_MENU    = 0x12; // ALT

  public const int VK_TAB     = 0x09;
  public const int VK_RETURN  = 0x0D;
  public const int VK_DELETE  = 0x2E;
  public const int VK_BACK    = 0x08;

  public const int VK_LEFT    = 0x25;
  public const int VK_UP      = 0x26;
  public const int VK_RIGHT   = 0x27;
  public const int VK_DOWN    = 0x28;

  public const int VK_A = 0x41;
  public const int VK_C = 0x43;
  public const int VK_V = 0x56;

  public const int VK_F1  = 0x70;
  public const int VK_F2  = 0x71;
  public const int VK_F3  = 0x72;
  public const int VK_F4  = 0x73;
  public const int VK_F5  = 0x74;
  public const int VK_F6  = 0x75;
  public const int VK_F7  = 0x76;
  public const int VK_F8  = 0x77;
  public const int VK_F9  = 0x78;
  public const int VK_F10 = 0x79;
  public const int VK_F11 = 0x7A;
  public const int VK_F12 = 0x7B;
}
"@ | Out-Null
}

# ---------------- Config ----------------
$doubleClickMs       = 350     # janela para considerar double-click
$doubleClickMaxDist  = 4       # tolerância de distância (pixels)
$pollMs              = 10      # loop

function Read-NonEmpty([string]$prompt, [string]$default = "") {
  while ($true) {
    $v = Read-Host $prompt
    if ([string]::IsNullOrWhiteSpace($v)) { $v = $default }
    $v = ("" + $v).Trim()
    if ($v) { return $v }
    Write-Host "Valor vazio. Tente novamente." -ForegroundColor Yellow
  }
}

function Sanitize-FileName([string]$name) {
  $bad = [System.IO.Path]::GetInvalidFileNameChars()
  foreach ($ch in $bad) { $name = $name.Replace($ch, "_") }
  return $name.Trim()
}

function IsDown([int]$vk) {
  return (([RecorderU32]::GetAsyncKeyState($vk) -band 0x8000) -ne 0)
}

# Edge detect para teclado
$prevState = @{}  # vKey -> bool down
function EdgeDown([int]$vk) {
  $d = IsDown $vk
  $p = $false
  if ($prevState.ContainsKey($vk)) { $p = [bool]$prevState[$vk] }
  $prevState[$vk] = $d
  return ($d -and -not $p)
}

function Dist([int]$x1,[int]$y1,[int]$x2,[int]$y2) {
  $dx = $x1 - $x2; if ($dx -lt 0) { $dx = -$dx }
  $dy = $y1 - $y2; if ($dy -lt 0) { $dy = -$dy }
  return ($dx + $dy)
}

# ---------------- Saídas ----------------
$projectName = Read-NonEmpty "Nome do projeto de automacao (ex: AC_NFE)" ""
$projectName = Sanitize-FileName $projectName

$outDir = Read-NonEmpty "Diretorio para salvar (ENTER = pasta atual)" (Get-Location).Path
if (-not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

$scriptPath = Join-Path $outDir ("{0}_script.ps1" -f $projectName)
$jsonPath   = Join-Path $outDir ("{0}_click_positions.json" -f $projectName)

# ---------------- Store de posições (JSON separado) ----------------
$posStore   = @{}   # Name -> {x,y,savedAt}
$posCounter = 0

function New-PosName([int]$x, [int]$y, [string]$kind) {
  $script:posCounter++
  return ("{0}_{1}_{2:000}_{3}_{4}" -f $projectName, $kind.ToUpper(), $script:posCounter, $x, $y)
}

function Ensure-Pos([int]$x, [int]$y, [string]$kind) {
  $name = New-PosName $x $y $kind
  $posStore[$name] = [pscustomobject]@{
    x = $x
    y = $y
    savedAt = (Get-Date).ToString("s")
  }
  return $name
}

# Deduplicar por coordenadas: "x;y;kind" -> name
$posByKey = @{}
function Get-OrCreatePosName([int]$x, [int]$y, [string]$kind) {
  $key = "$x;$y;$kind"
  if ($posByKey.ContainsKey($key)) { return $posByKey[$key] }
  $name = Ensure-Pos $x $y $kind
  $posByKey[$key] = $name
  return $name
}

# ---------------- Writer do script ----------------
$sw = New-Object System.Diagnostics.Stopwatch
$sw.Start()
$lastEmitMs = 0

@"
# ==========================================
# SCRIPT GERADO: $projectName
# ==========================================
# Requer no seu projeto:
# - click_positions.ps1 (Invoke-ClickPos / Invoke-DoubleClickPos / Invoke-RightClickPos)
# - funcoes Press-Key / Paste-Text / SleepMs
"@ | Set-Content -Encoding UTF8 $scriptPath

function Emit-SleepIfNeeded() {
  $now = $sw.ElapsedMilliseconds
  $delta = [int]($now - $script:lastEmitMs)
  if ($delta -ge 30) {
    ("SleepMs {0}" -f $delta) | Add-Content -Encoding UTF8 $scriptPath
    $script:lastEmitMs = $now
  }
}

function Emit-Line([string]$line) {
  Emit-SleepIfNeeded
  $line | Add-Content -Encoding UTF8 $scriptPath
  $script:lastEmitMs = $sw.ElapsedMilliseconds
}

# ---------------- UI ----------------
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " GERADOR DE EVENTOS" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ("Projeto: {0}" -f $projectName) -ForegroundColor Green
Write-Host ("Saida script: {0}" -f $scriptPath) -ForegroundColor DarkGray
Write-Host ("Saida coords: {0}" -f $jsonPath) -ForegroundColor DarkGray
Write-Host ""
Write-Host "Regras:" -ForegroundColor Yellow
Write-Host "- Mouse: clique ESQ / clique DIR / duplo clique ESQ" -ForegroundColor Yellow
Write-Host "- Teclas gravadas: Ctrl+A/C/V, F1..F12, Enter, Tab, Shift+Tab, Setas, Del, Backspace" -ForegroundColor Yellow
Write-Host "- NAO grava letras soltas (pra nao capturar texto)" -ForegroundColor Yellow
Write-Host "- PARAR: pressione ESC" -ForegroundColor Yellow
Write-Host ""

# abre Excel (opcional)
# try { Start-Process "excel.exe" | Out-Null } catch {}

Write-Host "Comecando em 3..." -ForegroundColor Cyan
Start-Sleep -Seconds 3
Write-Host "GRAVANDO..." -ForegroundColor Green

# ---------------- Mouse state (clique completo: DOWN -> UP) ----------------
$leftWasDown  = $false
$rightWasDown = $false

# Double-click baseado no ultimo LEFT-UP
$lastLeftUpMs = -99999
$lastLeftX    = 0
$lastLeftY    = 0

# ---------------- Loop principal ----------------
while ($true) {

  # PARAR
  if (IsDown([RecorderU32]::VK_ESCAPE)) { break }

  # Estado atual
  $lDown = IsDown([RecorderU32]::VK_LBUTTON)
  $rDown = IsDown([RecorderU32]::VK_RBUTTON)

  # ===========================
  # LEFT: grava no SOLTAR (UP)
  # ===========================
  if ($leftWasDown -and -not $lDown) {
    $pt = New-Object RecorderU32+POINT
    [RecorderU32]::GetCursorPos([ref]$pt) | Out-Null
    $x = [int]$pt.X
    $y = [int]$pt.Y

    $nowMs = [int]$sw.ElapsedMilliseconds
    $age   = $nowMs - $lastLeftUpMs
    $d     = Dist $x $y $lastLeftX $lastLeftY

    $name = Get-OrCreatePosName $x $y "LEFT"

    if ($age -le $doubleClickMs -and $d -le $doubleClickMaxDist) {
      Emit-Line ("Invoke-DoubleClickPos -Name ""{0}""" -f $name)
      $lastLeftUpMs = -99999   # evita triple-click
    } else {
      Emit-Line ("Invoke-ClickPos -Name ""{0}""" -f $name)
      $lastLeftUpMs = $nowMs
      $lastLeftX = $x
      $lastLeftY = $y
    }
  }

  # ============================
  # RIGHT: grava no SOLTAR (UP)
  # ============================
  if ($rightWasDown -and -not $rDown) {
    $pt = New-Object RecorderU32+POINT
    [RecorderU32]::GetCursorPos([ref]$pt) | Out-Null
    $x = [int]$pt.X
    $y = [int]$pt.Y

    $name = Get-OrCreatePosName $x $y "RIGHT"
    Emit-Line ("Invoke-RightClickPos -Name ""{0}""" -f $name)
  }

  $leftWasDown  = $lDown
  $rightWasDown = $rDown

  # ===========================
  # TECLADO (somente atalhos)
  # ===========================
  $ctrl  = IsDown([RecorderU32]::VK_CONTROL)
  $shift = IsDown([RecorderU32]::VK_SHIFT)
  $alt   = IsDown([RecorderU32]::VK_MENU) | Out-Null  # (não gravamos ALT sozinho)

  # CTRL + A/C/V
  if ($ctrl -and (EdgeDown([RecorderU32]::VK_A))) { Emit-Line 'Press-Key("^a")' }
  if ($ctrl -and (EdgeDown([RecorderU32]::VK_C))) { Emit-Line 'Press-Key("^c")' }
  if ($ctrl -and (EdgeDown([RecorderU32]::VK_V))) { Emit-Line 'Press-Key("^v")' }

  # TAB / SHIFT+TAB
  if (EdgeDown([RecorderU32]::VK_TAB)) {
    if ($shift) { Emit-Line 'Press-Key("+{TAB}")' } else { Emit-Line 'Press-Key("{TAB}")' }
  }

  # ENTER
  if (EdgeDown([RecorderU32]::VK_RETURN)) { Emit-Line 'Press-Key("{ENTER}")' }

  # DEL / BACKSPACE
  if (EdgeDown([RecorderU32]::VK_DELETE)) { Emit-Line 'Press-Key("{DEL}")' }
  if (EdgeDown([RecorderU32]::VK_BACK))   { Emit-Line 'Press-Key("{BACKSPACE}")' }

  # Setas
  if (EdgeDown([RecorderU32]::VK_UP))    { Emit-Line 'Press-Key("{UP}")' }
  if (EdgeDown([RecorderU32]::VK_DOWN))  { Emit-Line 'Press-Key("{DOWN}")' }
  if (EdgeDown([RecorderU32]::VK_LEFT))  { Emit-Line 'Press-Key("{LEFT}")' }
  if (EdgeDown([RecorderU32]::VK_RIGHT)) { Emit-Line 'Press-Key("{RIGHT}")' }

  # F1..F12
  for ($vk = [RecorderU32]::VK_F1; $vk -le [RecorderU32]::VK_F12; $vk++) {
    if (EdgeDown($vk)) {
      $n = ($vk - [RecorderU32]::VK_F1) + 1
      Emit-Line ("Press-Key(""{{F{0}}}"")" -f $n)
    }
  }

  Start-Sleep -Milliseconds $pollMs
}

# ---------------- Finalização ----------------
($posStore | ConvertTo-Json -Depth 6) | Set-Content -Encoding UTF8 $jsonPath

Write-Host ""
Write-Host "[OK] Gravacao finalizada." -ForegroundColor Green
Write-Host ("Script: {0}" -f $scriptPath) -ForegroundColor Cyan
Write-Host ("Coords: {0}" -f $jsonPath) -ForegroundColor Cyan
Write-Host "Agora copie o conteudo do script gerado para seu projeto e una o JSON no seu click_positions.json." -ForegroundColor Yellow
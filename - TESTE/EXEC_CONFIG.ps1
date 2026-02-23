# ==========================================
# EXEC_CONFIG.ps1
# Motor de automação por "config.txt" (linha a linha)
# Baseado no estilo do seu FATURAMENTO.ps1 (sem mexer nele).
# ==========================================

param(
  [Parameter(Mandatory=$true)]
  [string]$ConfigFile
)

# === FIXAR CONSOLE NO TOPO (mais confiavel) ===
Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class WinTop {
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();

    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool SetWindowPos(
        IntPtr hWnd,
        IntPtr hWndInsertAfter,
        int X, int Y, int cx, int cy,
        uint uFlags
    );
}
"@

$HWND_TOPMOST   = [IntPtr](-1)
$SWP_NOMOVE     = 0x0002
$SWP_NOSIZE     = 0x0001
$SWP_SHOWWINDOW = 0x0040

$hWnd = [IntPtr]::Zero
for ($i=0; $i -lt 25 -and $hWnd -eq [IntPtr]::Zero; $i++) {
    Start-Sleep -Milliseconds 200
    $hWnd = [WinTop]::GetConsoleWindow()
}

if ($hWnd -ne [IntPtr]::Zero) {
    [void][WinTop]::SetWindowPos($hWnd, $HWND_TOPMOST, 0,0,0,0, $SWP_NOMOVE -bor $SWP_NOSIZE -bor $SWP_SHOWWINDOW)
} else {
    Write-Host "[AVISO] Nao consegui pegar a janela do console para fixar no topo."
}

# ================================
# click_positions (mesmo esquema do seu projeto)
# ================================
$lib = Join-Path $PSScriptRoot "click_positions.ps1"
if (Test-Path -LiteralPath $lib) {
  . $lib
} else {
  Write-Host "[AVISO] click_positions.ps1 nao encontrado em: $lib" -ForegroundColor Yellow
  Write-Host "        Comandos CLICAR <NOME> vao falhar se voce nao tiver esse arquivo." -ForegroundColor Yellow
}

# ================================
# SendKeys / Clipboard
# ================================
Add-Type -AssemblyName System.Windows.Forms

function Press-Key([string]$k) { [System.Windows.Forms.SendKeys]::SendWait($k) }
function SleepMs([int]$ms) { Start-Sleep -Milliseconds $ms }

function Paste-Text([string]$text) {
  if ($null -eq $text) { $text = "" }
  Set-Clipboard -Value $text
  Press-Key("^v")
}

function Ask-YesNo([string]$Prompt = "Iniciar agora? (S/N)") {
    while ($true) {
        $ans = Read-Host $Prompt
        if ($null -eq $ans) { $ans = "" }
        $ans = $ans.Trim().ToUpperInvariant()
        if ($ans -eq "S") { return $true }
        if ($ans -eq "N") { return $false }
        Write-Host "Digite apenas S ou N." -ForegroundColor Yellow
    }
}

function Countdown([int]$Seconds = 3) {
    Write-Host ""
    Write-Host "CLIQUE AGORA NA JANELA DO SISTEMA (ela precisa ficar em foco)..." -ForegroundColor Yellow
    Start-Sleep -Milliseconds 200
    for ($i = $Seconds; $i -ge 1; $i--) {
        [console]::beep(900,150)
        Write-Host ("Executando em {0}..." -f $i) -ForegroundColor Cyan
        Start-Sleep -Seconds 1
    }
    [console]::beep(1200,200)
    Write-Host "ENVIANDO TECLAS..." -ForegroundColor Cyan
}

function Expand-Placeholders([string]$s) {
  if ($null -eq $s) { return "" }

  $now = Get-Date
  $dateBR = $now.ToString("dd/MM/yyyy")
  $timeBR = $now.ToString("HH:mm")

  # Placeholders simples:
  # {{DATA}}  -> 22/02/2026
  # {{HORA}}  -> 08:12
  # {{DATAISO}} -> 2026-02-22
  $s = $s.Replace("{{DATA}}", $dateBR)
  $s = $s.Replace("{{HORA}}", $timeBR)
  $s = $s.Replace("{{DATAISO}}", $now.ToString("yyyy-MM-dd"))
  return $s
}

function Invoke-ClickLine([string]$arg) {
  # aceita:
  #   CLICAR ABRIR_FILTRO        (usa Invoke-ClickPos)
  #   CLICAR 123,456             (clica em coordenada)
  $a = $arg.Trim()

  if ($a -match '^\s*(-?\d+)\s*[,;]\s*(-?\d+)\s*$') {
    $x = [int]$matches[1]
    $y = [int]$matches[2]
    if (Get-Command Invoke-ClickXY -ErrorAction SilentlyContinue) {
      Invoke-ClickXY -X $x -Y $y
      return
    }
    throw "CLICAR por coordenada requer a funcao Invoke-ClickXY (na sua click_positions.ps1)."
  }

  if (-not (Get-Command Invoke-ClickPos -ErrorAction SilentlyContinue)) {
    throw "Nao encontrei Invoke-ClickPos. Verifique click_positions.ps1."
  }
  Invoke-ClickPos -Name $a
}

function Invoke-CommandLine([string]$line) {
  $raw = $line
  if ($null -eq $raw) { return }

  $l = $raw.Trim()
  if ($l -eq "") { return }
  if ($l.StartsWith("#")) { return }
  if ($l.StartsWith(";")) { return }

  # Normaliza espaços
  $l = ($l -replace '\s+', ' ').Trim()

  # ----------------
  # CLICAR ...
  # ----------------
  if ($l -match '^(CLICAR|CLICK)\s+(.+)$') {
    Invoke-ClickLine $matches[2]
    return
  }

  # ----------------
  # ESPERAR 500ms / ESPERAR 2s
  # ----------------
  if ($l -match '^(ESPERAR|SLEEP)\s+(\d+)\s*(MS|S)?$') {
    $n = [int]$matches[2]
    $u = $matches[3]
    if ($u -eq $null -or $u -eq "" -or $u.ToUpperInvariant() -eq "MS") { SleepMs $n; return }
    if ($u.ToUpperInvariant() -eq "S") { Start-Sleep -Seconds $n; return }
  }

  # ----------------
  # TAB / SHIFT+TAB
  # ----------------
  if ($l -eq "TAB") { Press-Key("{TAB}"); return }
  if ($l -in @("SHIFT+TAB","SHIFT+TABULACAO","SHIFT+TABULAÇÃO","SHIFT TAB")) { Press-Key("+{TAB}"); return }

  # ----------------
  # Control/Alt/Shift combos simples
  # ----------------
  if ($l -in @("CONTROL+A","CTRL+A","CTRL A","CONTROL A")) { Press-Key("^a"); return }
  if ($l -in @("CONTROL+C","CTRL+C","CTRL C","CONTROL C")) { Press-Key("^c"); return }
  if ($l -in @("CONTROL+V","CTRL+V","CTRL V","CONTROL V")) { Press-Key("^v"); return }

  # ----------------
  # TECLA F1..F24 / ENTER / ESC / SETAS
  # ----------------
  if ($l -match '^(TECLA|EXECUTAR TECLA|KEY)\s+(.+)$') {
    $k = $matches[2].Trim().ToUpperInvariant()
    switch ($k) {
      "ENTER" { Press-Key("{ENTER}"); return }
      "ESC"   { Press-Key("{ESC}"); return }
      "TAB"   { Press-Key("{TAB}"); return }
      "UP"    { Press-Key("{UP}"); return }
      "DOWN"  { Press-Key("{DOWN}"); return }
      "LEFT"  { Press-Key("{LEFT}"); return }
      "RIGHT" { Press-Key("{RIGHT}"); return }
      default {
        if ($k -match '^F(\d{1,2})$') { Press-Key("{F$($matches[1])}"); return }
      }
    }
    throw "TECLA nao reconhecida: $k"
  }

  # ----------------
  # COLAR DATA ATUAL
  # ----------------
  if ($l -in @("COLAR DATA ATUAL","PASTE DATE","COLAR DATA")) {
    Paste-Text (Get-Date -Format "dd/MM/yyyy")
    return
  }

  # ----------------
  # COLAR TEXTO = ...
  # DIGITAR/COLAR = ...
  # ----------------
  if ($l -match '^(COLAR TEXTO|COLAR|PASTE)\s*=\s*(.*)$') {
    $t = Expand-Placeholders $matches[2]
    Paste-Text $t
    return
  }
  if ($l -match '^(DIGITAR/COLAR|DIGITAR E COLAR)\s*=\s*(.*)$') {
    $t = Expand-Placeholders $matches[2]
    Paste-Text $t
    return
  }

  # ----------------
  # DIGITAR = ...
  # (envia como SendKeys; cuidado com caracteres especiais do SendKeys)
  # ----------------
  if ($l -match '^(DIGITAR|TYPE)\s*=\s*(.*)$') {
    $t = Expand-Placeholders $matches[2]
    Press-Key($t)
    return
  }

  # ----------------
  # CONTAGEM 3s (ou outro número)
  # ----------------
  if ($l -match '^(CONTAGEM|COUNTDOWN)\s*(\d+)?\s*S?$') {
    $sec = 3
    if ($matches[2]) { $sec = [int]$matches[2] }
    Countdown $sec
    return
  }

  throw "Linha nao reconhecida: $raw"
}

# ================================
# MAIN
# ================================
if (!(Test-Path -LiteralPath $ConfigFile)) {
  Write-Host "[ERRO] Nao achei o arquivo: $ConfigFile" -ForegroundColor Red
  exit 2
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " AUTOMACAO: EXECUCAO POR CONFIG (LINHA A LINHA)" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ("Config: {0}" -f $ConfigFile) -ForegroundColor DarkGray
Write-Host ""

if (-not (Ask-YesNo "Iniciar agora? (S/N)")) {
  Write-Host "[OK] Cancelado." -ForegroundColor Yellow
  exit 0
}

# Dê tempo pra focar o ERP, se quiser use no TXT: CONTAGEM 3
# Countdown 3

$lines = Get-Content -LiteralPath $ConfigFile

$idx = 0
foreach ($line in $lines) {
  $idx++
  try {
    Invoke-CommandLine $line
  } catch {
    Write-Host ""
    Write-Host ("[ERRO] Linha #{0}: {1}" -f $idx, $line) -ForegroundColor Red
    Write-Host ("       {0}" -f $_.Exception.Message) -ForegroundColor Red
    Write-Host ""
    Write-Host "DICA: comente a linha com # para pular." -ForegroundColor Yellow
    exit 1
  }
}

Write-Host ""
Write-Host "[OK] Finalizado." -ForegroundColor Green
exit 0

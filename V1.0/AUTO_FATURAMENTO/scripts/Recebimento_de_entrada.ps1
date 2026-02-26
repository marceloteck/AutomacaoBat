param(
  [Parameter(Mandatory=$true)]
  [string]$InputFile
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

# espera o console existir
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





$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ================================
# CONFIG (ajuste aqui)
# ================================
$START_DELAY_SECONDS = 2

# Fluxo inicial do produtor: F2 -> TAB -> INSTRUCAO -> TAB
$DELAY_AFTER_F2_MS        = 250
$DELAY_AFTER_TAB_MS       = 120
$DELAY_AFTER_INSTRUCAO_MS = 150

# Por nota: COLAR -> TAB -> CODIGO -> ENTER -> F4
$DELAY_AFTER_PASTE_MS = 3000   # 3s depois de colar a NF
$DELAY_STEP_MS        = 1000   # 1s em cada etapa

# Final do produtor: F4 -> RIGHT -> ENTER
$FINAL_DELAY_F4_MS    = 500
$FINAL_DELAY_RIGHT_MS = 150
$FINAL_DELAY_ENTER_MS = 150

# Códigos por tipo
$CODE_PF = "2630"
$CODE_PJ = "2629"

# Hotkey para abortar manualmente: CTRL+SHIFT+Q ou ESC
$ABORT_HOTKEY = "CTRL+SHIFT+Q"


###################### CHAMADA DA click_positions

$lib = Join-Path $PSScriptRoot "click_positions.ps1"
. $lib
###################### 

$focus_value = Join-Path $PSScriptRoot "Imports\_guard_focus.ps1"
. $focus_value


# ================================
# SendKeys
# ================================
Add-Type -AssemblyName System.Windows.Forms

function Press-Key([string]$k) { [System.Windows.Forms.SendKeys]::SendWait($k) }
function SleepMs([int]$ms) { Start-Sleep -Milliseconds $ms }

Add-Type -AssemblyName UIAutomationClient

function Test-IsEditableFocusedElement {

    try {
        $focused = [System.Windows.Automation.AutomationElement]::FocusedElement
        if ($null -eq $focused) { return $false }

        $controlType = $focused.Current.ControlType.ProgrammaticName

        # Tipos comuns de campo editável
        if ($controlType -match "Edit" -or
            $controlType -match "Document") {
            return $true
        }

        # Verifica se suporta ValuePattern (campo que aceita texto)
        $pattern = $null
        if ($focused.TryGetCurrentPattern(
            [System.Windows.Automation.ValuePattern]::Pattern,
            [ref]$pattern)) {
            return $true
        }

        return $false
    }
    catch {
        return $false
    }
}



function Paste-Text([string]$text) {

    # Espera até o foco estar em campo editável (máx 5s)
    $timeout = 5000
    $elapsed = 0

    while (-not (Test-IsEditableFocusedElement)) {
        Start-Sleep -Milliseconds 100
        $elapsed += 100
        if ($elapsed -ge $timeout) {
            Write-Host "[ERRO] Campo de texto não detectado." -ForegroundColor Red
            return
        }
    }

    Set-Clipboard -Value $text
    Press-Key("^v")
}

# ================================
# Abort (CTRL+SHIFT+Q ou ESC)
# ================================
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class KB {
  [DllImport("user32.dll")]
  public static extern short GetAsyncKeyState(int vKey);
}
"@ -ErrorAction SilentlyContinue

function Is-AbortRequested {
  $VK_CONTROL = 0x11
  $VK_SHIFT   = 0x10
  $VK_Q       = 0x51
  $VK_ESCAPE  = 0x1B

  $ctrl  = ([KB]::GetAsyncKeyState($VK_CONTROL) -band 0x8000) -ne 0
  $shift = ([KB]::GetAsyncKeyState($VK_SHIFT)   -band 0x8000) -ne 0
  $q     = ([KB]::GetAsyncKeyState($VK_Q)       -band 0x8000) -ne 0
  $esc   = ([KB]::GetAsyncKeyState($VK_ESCAPE)  -band 0x8000) -ne 0

  return ($esc -or ($ctrl -and $shift -and $q))
}

function Abort-IfNeeded {
  if (Is-AbortRequested) {
    throw "ABORTADO pelo usuario ($ABORT_HOTKEY ou ESC)."
  }
}

# ================================
# Parser do TXT
# Formato:
# [PRODUTOR]
# NOME=...
# STATUS=CONFIRMADO/PENDENTE
# TIPO=PF/PJ
# INSTRUCAO=123
# NOTAS:
# 44DIGITOS
# ...
# ================================
function Load-Producers([string]$path) {
  if(!(Test-Path -LiteralPath $path)) { throw "Arquivo nao encontrado: $path" }

  $lines = Get-Content -LiteralPath $path -Encoding UTF8
  $producers = New-Object System.Collections.Generic.List[object]

  $cur = $null
  $inNotas = $false

  foreach($raw in $lines){
    $line = ("" + $raw).Trim()

    if($line -eq ""){
      $inNotas = $false
      continue
    }
    if($line.StartsWith("#")) { continue }

    if($line -ieq "[PRODUTOR]"){
      if($cur){ $producers.Add($cur) }
      $cur = [ordered]@{
        nome      = ""
        status    = "PENDENTE"
        tipo      = ""
        instrucao = ""
        notas     = New-Object System.Collections.Generic.List[string]
      }
      $inNotas = $false
      continue
    }

    if(-not $cur){ continue }

    if($line -match '^(?i)NOTAS\s*:\s*$'){
      $inNotas = $true
      continue
    }

    if($inNotas){
      $ch = ($line -replace '\s+','')
      if($ch){ $cur.notas.Add($ch) }
      continue
    }

    if($line -match '^(?i)NOME\s*=\s*(.+)$'){ $cur.nome = $Matches[1].Trim(); continue }
    if($line -match '^(?i)STATUS\s*=\s*(CONFIRMADO|PENDENTE)\s*$'){ $cur.status = $Matches[1].ToUpper(); continue }
    if($line -match '^(?i)TIPO\s*=\s*(PF|PJ)\s*$'){ $cur.tipo = $Matches[1].ToUpper(); continue }
    if($line -match '^(?i)INSTRUCAO\s*=\s*(\d+)\s*$'){ $cur.instrucao = $Matches[1]; continue }
  }

  if($cur){ $producers.Add($cur) }
  return $producers
}

function Validate-Producers($producers){
  $errors = New-Object System.Collections.Generic.List[string]
  $idx = 0

  foreach($p in $producers){
    $idx++

    if([string]::IsNullOrWhiteSpace($p.nome)){
      $errors.Add("Produtor #${idx}: NOME vazio.")
    }
    if(($p.status -ne "CONFIRMADO") -and ($p.status -ne "PENDENTE")){
      $errors.Add("Produtor #$idx ($($p.nome)): STATUS deve ser CONFIRMADO ou PENDENTE.")
    }
    if(($p.tipo -ne "PF") -and ($p.tipo -ne "PJ")){
      $errors.Add("Produtor #$idx ($($p.nome)): TIPO deve ser PF ou PJ.")
    }
    if(-not ($p.instrucao -match '^\d+$')){
      $errors.Add("Produtor #$idx ($($p.nome)): INSTRUCAO invalida.")
    }
    if($p.notas.Count -lt 1){
      $errors.Add("Produtor #$idx ($($p.nome)): sem NOTAS.")
    }

    foreach($ch in $p.notas){
      if(-not ($ch -match '^\d{44}$')){
        $errors.Add("Produtor #$idx ($($p.nome)): chave invalida (44 digitos): $ch")
      }
    }
  }
  return $errors
}

function Save-Producers([string]$path, $producers) {
  # Backup antes de regravar
  $ts = Get-Date -Format "yyyyMMdd_HHmmss"
  $bak = "$path.bak_$ts"
  Copy-Item -LiteralPath $path -Destination $bak -ErrorAction SilentlyContinue | Out-Null

  $out = New-Object System.Collections.Generic.List[string]
  foreach($p in $producers){
    $out.Add("[PRODUTOR]")
    $out.Add("NOME=$($p.nome)")
    $out.Add("STATUS=$($p.status)")
    $out.Add("TIPO=$($p.tipo)")
    $out.Add("INSTRUCAO=$($p.instrucao)")
    $out.Add("NOTAS:")
    foreach($ch in $p.notas){ $out.Add($ch) }
    $out.Add("")
  }

  Set-Content -LiteralPath $path -Value $out -Encoding UTF8
}

function Ask-YesNo([string]$msg){
  $ans = Read-Host $msg
  return ($ans.Trim().ToUpper() -eq "S")
}

# ================================
# Execucao
# ================================
try {
  $producers = Load-Producers $InputFile
  if($producers.Count -eq 0){
    Write-Host "[ERRO] Nenhum produtor encontrado no arquivo."
    exit 2
  }

  $errors = Validate-Producers $producers
  # if($errors.Count -gt 0){
  #   Write-Host "=========================================="
  #   Write-Host "ERROS NO ARQUIVO. Corrija antes de rodar:"
  #   Write-Host "=========================================="
  #   $errors | ForEach-Object { Write-Host " - $_" }
  #   exit 2
  # }

  $totalNotas = ($producers | ForEach-Object { $_.notas.Count } | Measure-Object -Sum).Sum
  Write-Host "=========================================="
  Write-Host "SAA (PowerShell) - 1 PRODUTOR POR VEZ"
  Write-Host ("Produtores: {0}" -f $producers.Count)
  Write-Host ("Notas:      {0}" -f $totalNotas)
  Write-Host ("ABORTAR:    {0} (ou ESC)" -f $ABORT_HOTKEY)
  Write-Host "=========================================="
  Write-Host ""
  Write-Host "IMPORTANTE: deixe o ERP Corporate em FOCO."
  Write-Host ""

  if(-not (Ask-YesNo "CONFIRMAR INICIO? (S/N)")){
    Write-Host "Cancelado."
    exit 0
  }

  Write-Host ("Iniciando em {0} segundos..." -f $START_DELAY_SECONDS)
  Start-Sleep -Seconds $START_DELAY_SECONDS

  $pIndex = 0
  foreach($p in $producers){
    $pIndex++
    Abort-IfNeeded

    # ================================
    # IGNORAR PRODUTOR SEM NOTA FISCAL
    # ================================
    if(-not $p.notas -or $p.notas.Count -eq 0 -or ($p.notas | Where-Object { $_ -and $_.Trim() -ne "" }).Count -eq 0){
        Write-Host ""
        Write-Host ("[SKIP] PRODUTOR {0}/{1}: {2} sem nota fiscal - pulando." -f $pIndex, $producers.Count, $p.nome)
        continue
    }

    $code = if($p.tipo -eq "PJ") { $CODE_PJ } else { $CODE_PF }

    Invoke-ClickPos -Name "ABRIR_TELA_RECEBIMENTODEENTRADA_ERP"

    Write-Host ""
    Write-Host "--------------------------------------------------"
    Write-Host ("PRODUTOR {0}/{1}: {2}" -f $pIndex, $producers.Count, $p.nome)
    Write-Host ("STATUS={0}  TIPO={1}  INSTRUCAO={2}  NOTAS={3}" -f $p.status, $p.tipo, $p.instrucao, $p.notas.Count)
    Write-Host "--------------------------------------------------"
    Write-Host ""

    if($p.status -eq "CONFIRMADO"){
        Write-Host ("[SKIP] PRODUTOR {0}/{1}: {2} ja esta CONFIRMADO - pulando." -f $pIndex, $producers.Count, $p.nome)
        continue
    }

    # Vai para campo de instrucao
    Press-Key("{F2}")
    SleepMs $DELAY_AFTER_F2_MS
    Abort-IfNeeded

    Press-Key("{TAB}")
    SleepMs $DELAY_AFTER_TAB_MS
    Abort-IfNeeded

    Pause-IfNotTextInput -Message "Clique no campo correto antes de continuar."

    Press-Key($p.instrucao)
    SleepMs 100

    Press-Key("{TAB}")
    SleepMs $DELAY_AFTER_TAB_MS
    Abort-IfNeeded

    # Processa notas
    $i = 0
    foreach($ch in $p.notas){
        if(-not $ch -or $ch.Trim() -eq ""){ continue }

        $i++
        Abort-IfNeeded

        Paste-Text $ch
        SleepMs 100

        Press-Key("{TAB}")
        SleepMs $DELAY_STEP_MS

        Press-Key($code)
        SleepMs $DELAY_STEP_MS

        Press-Key("{ENTER}")
        SleepMs 3000

        Press-Key("{F4}")
        SleepMs $DELAY_STEP_MS

        Write-Host ("  [OK] {0}/{1} gravado." -f $i, $p.notas.Count)
    }

    Abort-IfNeeded

    # Confirma/finaliza produtor
    Press-Key("{F4}")
    SleepMs $FINAL_DELAY_F4_MS

    Press-Key("{RIGHT}")
    SleepMs $FINAL_DELAY_RIGHT_MS

    Press-Key("{ENTER}")
    SleepMs $FINAL_DELAY_ENTER_MS

    Write-Host "[OK] Produtor finalizado."

    $p.status = "CONFIRMADO"
    Save-Producers -path $InputFile -producers $producers
    Write-Host "[OK] STATUS atualizado para CONFIRMADO no notasNFE."

    if($pIndex -lt $producers.Count){
        Write-Host ""
        if(-not (Ask-YesNo "PASSAR PARA O PROXIMO PRODUTOR? (S/N)")){
            Write-Host "Parado pelo usuario."
            exit 3
        }
        Start-Sleep -Seconds 3
    }
}

Write-Host ""
Write-Host "[OK] Processo concluido."
exit 0

} catch {
    Write-Host ""
    Write-Host ("[ERRO] {0}" -f $_.Exception.Message)
    exit 3
}
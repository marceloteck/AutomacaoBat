param(
  [Parameter(Mandatory=$true)][string]$InputFile
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ========= CONFIG =========
$START_DELAY = 2

# Fluxo inicial do produtor: F2 -> TAB -> INSTRUCAO
$DELAY_AFTER_F2 = 250
$DELAY_AFTER_TAB = 90
$DELAY_AFTER_INSTRUCAO = 120

# Por nota: COLAR -> TAB -> CODIGO -> ENTER -> F4
$DELAY_AFTER_PASTE = 90
$DELAY_AFTER_TIPO = 40
$DELAY_AFTER_ENTER = 180
$DELAY_AFTER_F4 = 600

# Final do produtor: F4 -> RIGHT -> ENTER
$FINAL_DELAY_F4 = 500
$FINAL_DELAY_RIGHT = 150
$FINAL_DELAY_ENTER = 150

$CODE_PF = "2630"
$CODE_PJ = "2629"

# Hotkey abortar (manual): CTRL+SHIFT+Q
$ABORT_HOTKEY = "CTRL+SHIFT+Q"

# ========= SendKeys =========
Add-Type -AssemblyName System.Windows.Forms

function Press-Key([string]$k) {
  [System.Windows.Forms.SendKeys]::SendWait($k)
}

function SleepMs([int]$ms) { Start-Sleep -Milliseconds $ms }

function Paste-Text([string]$text) {
  Set-Clipboard -Value $text
  Press-Key("^v")
}

# ========= ABORT (CTRL+SHIFT+Q e ESC) =========
function Is-AbortRequested {
  Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class KB {
  [DllImport("user32.dll")]
  public static extern short GetAsyncKeyState(int vKey);
}
"@ -ErrorAction SilentlyContinue

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

# ========= Parser =========
function Load-Producers([string]$path) {
  if(!(Test-Path -LiteralPath $path)) { throw "Arquivo nao encontrado: $path" }

  $lines = Get-Content -LiteralPath $path -Encoding UTF8
  $producers = @()
  $cur = $null
  $inNotas = $false

  foreach($raw in $lines){
    $line = $raw.Trim()
    if($line -eq "" ){
      $inNotas = $false
      continue
    }
    if($line.StartsWith("#")){ continue }

    if($line -ieq "[PRODUTOR]"){
      if($cur){ $producers += $cur }
      $cur = [ordered]@{
        nome = ""
        status = "PENDENTE"
        tipo = ""
        instrucao = ""
        pedido = $null
        notas = New-Object System.Collections.Generic.List[string]
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
    if($line -match '^(?i)PEDIDO\s*=\s*(.+)$'){ $cur.pedido = $Matches[1].Trim(); continue }
  }

  if($cur){ $producers += $cur }
  return ,$producers
}

function Validate-Producers($producers){
  $errors = New-Object System.Collections.Generic.List[string]
  $idx = 0

  foreach($p in $producers){
    $idx++

    if([string]::IsNullOrWhiteSpace($p.nome)){
      $errors.Add("Produtor #${idx}: NOME vazio.")
    }
    if($p.status -ne "CONFIRMADO" -and $p.status -ne "PENDENTE"){
      $errors.Add("Produtor #${idx} ($($p.nome)): STATUS deve ser CONFIRMADO ou PENDENTE.")
    }
    if($p.tipo -ne "PF" -and $p.tipo -ne "PJ"){
      $errors.Add("Produtor #${idx} ($($p.nome)): TIPO deve ser PF ou PJ.")
    }
    if(-not ($p.instrucao -match '^\d+$')){
      $errors.Add("Produtor #${idx} ($($p.nome)): INSTRUCAO invalida.")
    }
    if($p.notas.Count -lt 1){
      $errors.Add("Produtor #${idx} ($($p.nome)): sem NOTAS.")
    }

    foreach($ch in $p.notas){
      if(-not ($ch -match '^\d{44}$')){
        $errors.Add("Produtor #${idx} ($($p.nome)): chave invalida (44 digitos): $ch")
      }
    }
  }
  return $errors
}

function Save-Producers([string]$path, $producers) {
  # Backup simples
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
    foreach($ch in $p.notas){
      $out.Add($ch)
    }
    $out.Add("") # linha em branco entre produtores
  }
  Set-Content -LiteralPath $path -Value $out -Encoding UTF8
}

function Ask-YesNo([string]$msg){
  $ans = Read-Host $msg
  return ($ans.Trim().ToUpper() -eq "S")
}

# ========= Execução =========
try {
  $producers = Load-Producers $InputFile
  if($producers.Count -eq 0){
    Write-Host "[ERRO] Nenhum produtor encontrado no arquivo."
    exit 2
  }

  $errors = Validate-Producers $producers
  if($errors.Count -gt 0){
    Write-Host "=========================================="
    Write-Host "ERROS NO ARQUIVO. Corrija antes de rodar:"
    Write-Host "=========================================="
    $errors | ForEach-Object { Write-Host " - $_" }
    exit 2
  }

  $totalNotas = ($producers | ForEach-Object { $_.notas.Count } | Measure-Object -Sum).Sum
  Write-Host "=========================================="
  Write-Host "SAA (PowerShell) - 1 PRODUTOR POR VEZ"
  Write-Host "Produtores: $($producers.Count)"
  Write-Host "Notas:      $totalNotas"
  Write-Host "ABORTAR:    $ABORT_HOTKEY (ou ESC)"
  Write-Host "=========================================="
  Write-Host ""
  Write-Host "IMPORTANTE: deixe o ERP Corporate em FOCO."
  Write-Host "O script vai apertar F2 e TAB automaticamente."
  Write-Host ""

  if(-not (Ask-YesNo "CONFIRMAR INICIO? (S/N)")){
    Write-Host "Cancelado."
    exit 0
  }

  Write-Host "Iniciando em $START_DELAY segundos..."
  Start-Sleep -Seconds $START_DELAY

  $pIndex = 0
  foreach($p in $producers){
    $pIndex++
    Abort-IfNeeded

    $code = if($p.tipo -eq "PJ") { $CODE_PJ } else { $CODE_PF }

    Write-Host ""
    Write-Host "--------------------------------------------------"
    Write-Host "PRODUTOR $pIndex/$($producers.Count): $($p.nome)"
    Write-Host "STATUS=$($p.status)  TIPO=$($p.tipo)  INSTRUCAO=$($p.instrucao)  NOTAS=$($p.notas.Count)"
    Write-Host "--------------------------------------------------"
    Write-Host ""

    if($p.status -eq "CONFIRMADO"){
      Write-Host ("[SKIP] PRODUTOR {0}/{1}: {2} ja esta CONFIRMADO — pulando." -f $pIndex, $producers.Count, $p.nome)
      continue
    }

    Press-Key("{F2}")
    SleepMs $DELAY_AFTER_F2
    Abort-IfNeeded

    Press-Key("{TAB}")
    SleepMs $DELAY_AFTER_TAB
    Abort-IfNeeded

    Press-Key($p.instrucao)
    SleepMs $DELAY_AFTER_INSTRUCAO
    Press-Key("{TAB}")
    SleepMs $DELAY_AFTER_TAB
    Abort-IfNeeded

    # ================================
    # DELAYS (em milissegundos)
    # ================================
    $DELAY_AFTER_PASTE = 3000   # 3s após colar NF
    $DELAY_STEP        = 1000   # 1s entre etapas

    $i = 0
    foreach($ch in $p.notas){
      $i++
      Abort-IfNeeded

      Paste-Text $ch
      SleepMs $DELAY_AFTER_PASTE

      Press-Key("{TAB}")
      SleepMs $DELAY_STEP

      Press-Key($code)
      SleepMs $DELAY_STEP

      Press-Key("{ENTER}")
      SleepMs $DELAY_STEP

      Press-Key("{F4}")
      SleepMs $DELAY_STEP

      Write-Host ("  [OK] {0}/{1} gravado." -f $i, $p.notas.Count)
    }

    Abort-IfNeeded

    Press-Key("{F4}")
    SleepMs $FINAL_DELAY_F4
    Press-Key("{RIGHT}")
    SleepMs $FINAL_DELAY_RIGHT
    Press-Key("{ENTER}")
    SleepMs $FINAL_DELAY_ENTER

    Write-Host "[OK] Produtor finalizado."

    # Marca como CONFIRMADO e salva no arquivo (para nao repetir na proxima execucao)
    $p.status = "CONFIRMADO"
    Save-Producers -path $InputFile -producers $producers
    Write-Host "[OK] STATUS atualizado para CONFIRMADO no notas.txt."

    if($pIndex -lt $producers.Count){
      Write-Host ""
      if(-not (Ask-YesNo "PASSAR PARA O PROXIMO PRODUTOR? (S/N)")){
        Write-Host "Parado pelo usuario."
        exit 3
      }
      Start-Sleep -Seconds 1
    }
  }

  Write-Host ""
  Write-Host "[OK] Processo concluido."
  exit 0

} catch {
  Write-Host ""
  Write-Host "[ERRO] $($_.Exception.Message)"
  exit 3
}

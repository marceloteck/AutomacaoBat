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


# ===============================
# CHAMADA click_positions.ps1
# ===============================
$lib = Join-Path $PSScriptRoot "click_positions.ps1"
if (Test-Path -LiteralPath $lib) {
    . $lib
} else {
    Write-Host "[ERRO] Nao achei click_positions.ps1 em: $lib" -ForegroundColor Red
    exit 2
}



$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ================================
# CONFIG
# ================================
$START_DELAY_SECONDS = 3          # tempo após iniciar (pra você focar o ERP)
$AFTER_CONFIRM_SECONDS = 2        # <<< IMPORTANTE: tempo após cada confirmação (pra focar o ERP)

$DELAY_AFTER_F7_MS        = 1
$DELAY_AFTER_INSTRUCAO_MS = 1000

$DELAY_AFTER_CTRL_F12_MS  = 2000
$DELAY_AFTER_TYPE_A_MS    = 1000
$DELAY_AFTER_CLEAR_MS     = 500

$DELAY_AFTER_F4_MS        = 2000
$DELAY_AFTER_F4_2_MS      = 1000

$ABORT_HOTKEY = "CTRL+SHIFT+Q"    # ou ESC
$FAIL_HOTKEY  = "F12"             # reiniciar bloco atual

# ================================
# SendKeys
# ================================
Add-Type -AssemblyName System.Windows.Forms

function Press-Key([string]$k) { [System.Windows.Forms.SendKeys]::SendWait($k) }
function SleepMs([int]$ms) { if($ms -gt 0){ Start-Sleep -Milliseconds $ms } }

function Paste-Text([string]$text) {
  if($null -eq $text){ $text = "" }
  Set-Clipboard -Value $text
  Press-Key("^v")
}

# ================================
# Abort / Fail (GetAsyncKeyState)
# ================================
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class KB {
  [DllImport("user32.dll")]
  public static extern short GetAsyncKeyState(int vKey);
}
"@ -ErrorAction SilentlyContinue | Out-Null

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

function Is-FailRequested {
  $VK_F12 = 0x7B
  return (([KB]::GetAsyncKeyState($VK_F12) -band 0x8000) -ne 0)
}

function Abort-IfNeeded {
  if (Is-AbortRequested) { throw "ABORTADO pelo usuario ($ABORT_HOTKEY ou ESC)." }
}

function Fail-IfNeeded {
  if (Is-FailRequested) { throw "FALHA sinalizada (F12)." }
}

function Ask-YesNo([string]$msg){
  $ans = Read-Host $msg
  return ($ans.Trim().ToUpper() -eq "S")
}

function Wait-And-FocusTime([int]$sec){
  # Tempo pra você clicar no ERP e deixar em foco
  Start-Sleep -Seconds $sec
  Abort-IfNeeded
}

# ================================
# Parser TXT (mesmo modelo)
# ================================
function Load-Producers([string]$path) {
  if(!(Test-Path -LiteralPath $path)) { throw "Arquivo nao encontrado: $path" }

  try { $lines = Get-Content -LiteralPath $path -Encoding UTF8 -ErrorAction Stop }
  catch { $lines = Get-Content -LiteralPath $path -Encoding Default }

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
        nome        = ""
        status      = "PENDENTE"
        tipo        = ""
        instrucao   = ""
        pedido      = ""
        total_placas = 0          # novo
        notas       = New-Object System.Collections.Generic.List[string]
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
      $nf = ($line -replace '\s+','').Trim()
      if($nf){ $cur.notas.Add($nf) }
      continue
    }

    if($line -match '^(?i)NOME\s*=\s*(.+)$'){ $cur.nome = $Matches[1].Trim(); continue }
    if($line -match '^(?i)STATUS\s*=\s*(CONFIRMADO|PENDENTE)\s*$'){ $cur.status = $Matches[1].ToUpper(); continue }
    if($line -match '^(?i)TIPO\s*=\s*(PF|PJ)\s*$'){ $cur.tipo = $Matches[1].ToUpper(); continue }
    if($line -match '^(?i)INSTRUCAO\s*=\s*(\d+)\s*$'){ $cur.instrucao = $Matches[1]; continue }
    if($line -match '^(?i)PEDIDO\s*=\s*(\d+)\s*$'){ $cur.pedido = $Matches[1]; continue }
    if($line -match '^(?i)TOTAL_PLACAS\s*=\s*(\d+)\s*$'){ $cur.total_placas = [int]$Matches[1]; continue }
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
      $errors.Add("Produtor #$($idx): NOME vazio.")
    }
    if(($p.tipo -ne "PF") -and ($p.tipo -ne "PJ")){
      $errors.Add("Produtor #$($idx) ($($p.nome)): TIPO deve ser PF ou PJ.")
    }
    if(-not ($p.instrucao -match '^\d+$')){
      $errors.Add("Produtor #$($idx) ($($p.nome)): INSTRUCAO invalida.")
    }
  }

  
    # TOTAL_PLACAS: se nao informado, assume = quantidade de notas
    if(($p.total_placas -eq $null) -or ($p.total_placas -le 0)){
      $p.total_placas = [int]$p.notas.Count
    }

    if($p.notas.Count -gt 1){
      if($p.total_placas -lt 1){
        $errors.Add("Produtor #$($idx) ($($p.nome)): TOTAL_PLACAS deve ser >= 1.")
      }

      # regra segura: precisa ter pelo menos uma nota por placa (normalmente igual)
      if($p.notas.Count -lt $p.total_placas){
        $errors.Add("Produtor #$($idx) ($($p.nome)): NOTAS (" + $p.notas.Count + ") menor que TOTAL_PLACAS (" + $p.total_placas + ").")
      }
    }

  return $errors
}


# ================================
# Selecionar placa (linha) pelo indice
# - Clica na primeira placa
# - Desce N vezes
# ================================
function Select-PlacaByIndex([int]$index){
  Invoke-ClickPos -Name "SELECIONAR_PRIMEIRA_PLACA"
  SleepMs 150
  Abort-IfNeeded; Fail-IfNeeded

  for($k=0; $k -lt $index; $k++){
    Press-Key("{DOWN}")
    SleepMs 60
    Abort-IfNeeded; Fail-IfNeeded
  }
}

# ================================
# Bloco NFE
# ================================
function Run-NFE-Bloco($p){

  # F7
  Press-Key("{F7}")
  SleepMs $DELAY_AFTER_F7_MS
  Abort-IfNeeded; Fail-IfNeeded

  # COLAR INSTRUCAO
  Paste-Text $p.instrucao
  SleepMs $DELAY_AFTER_INSTRUCAO_MS
  Abort-IfNeeded; Fail-IfNeeded

  # ENTER ENTER
  Press-Key("{ENTER}")
  Press-Key("{ENTER}")
  SleepMs 80
  Abort-IfNeeded; Fail-IfNeeded

  # Se tiver 1 nota
  if($p.notas.Count -eq 1){
    Press-Key("^{F12}")     # CTRL+F12
    SleepMs $DELAY_AFTER_CTRL_F12_MS
    Abort-IfNeeded; Fail-IfNeeded

    Press-Key("A")
    SleepMs $DELAY_AFTER_TYPE_A_MS
    Abort-IfNeeded; Fail-IfNeeded

    Press-Key("^a")
    SleepMs 80
    Press-Key("{DEL}")
    SleepMs $DELAY_AFTER_CLEAR_MS
    Abort-IfNeeded; Fail-IfNeeded

    Paste-Text $p.notas[0]
    SleepMs 100
    Press-Key("{ENTER}")
    SleepMs 60
    Press-Key("{ENTER}")
    SleepMs 80
    Abort-IfNeeded; Fail-IfNeeded

    # F4 / F4 / F8
    Press-Key("{F4}")
    SleepMs $DELAY_AFTER_F4_MS
    Abort-IfNeeded; Fail-IfNeeded

    Press-Key("{F4}")
    SleepMs $DELAY_AFTER_F4_2_MS
    Abort-IfNeeded; Fail-IfNeeded

    SleepMs 2000
    Press-Key("{F8}")
    SleepMs 150
    Abort-IfNeeded; Fail-IfNeeded

    SleepMs 3000
    Press-Key("{ENTER}")
    SleepMs 100
    Abort-IfNeeded; Fail-IfNeeded
  }

  # Se tiver MAIS DE 1 nota
  if($p.notas.Count -gt 1){

    # TOTAL_PLACAS: se nao veio, assume = quantidade de notas
    $totalPlacas = 0
    if(($p.total_placas -ne $null) -and ([int]$p.total_placas -gt 0)){
      $totalPlacas = [int]$p.total_placas
    } else {
      $totalPlacas = [int]$p.notas.Count
    }

    # A cada placa:
    # - Seleciona a linha (clica primeira e desce)
    # - CTRL+F12, A, limpa, cola NF correspondente, ENTER ENTER
    # No final, faz a finalizacao padrao (F4/F4/F8/ENTER) UMA vez.
    for($placaIndex = 0; $placaIndex -lt $totalPlacas; $placaIndex++){
      Abort-IfNeeded; Fail-IfNeeded

      # Seleciona a placa alvo (1a = 0 descidas, 2a = 1, 3a = 2, ...)
      Select-PlacaByIndex $placaIndex

      # Entra na tela de notas
      Press-Key("^{F12}")     # CTRL+F12
      SleepMs $DELAY_AFTER_CTRL_F12_MS
      Abort-IfNeeded; Fail-IfNeeded

      Press-Key("A")
      SleepMs $DELAY_AFTER_TYPE_A_MS
      Abort-IfNeeded; Fail-IfNeeded

      # Limpa campo
      Press-Key("^a")
      SleepMs 80
      Press-Key("{DEL}")
      SleepMs $DELAY_AFTER_CLEAR_MS
      Abort-IfNeeded; Fail-IfNeeded

      # Nota desta placa
      $nf = ""
      if($placaIndex -lt $p.notas.Count){
        $nf = $p.notas[$placaIndex]
      }

      Paste-Text $nf
      SleepMs 100
      Press-Key("{ENTER}")
      SleepMs 60
      Press-Key("{ENTER}")
      SleepMs 120
      Abort-IfNeeded; Fail-IfNeeded
    }

    # Finalizacao padrao (igual ao fluxo de 1 nota) - uma vez ao final
    Press-Key("{F4}")
    SleepMs $DELAY_AFTER_F4_MS
    Abort-IfNeeded; Fail-IfNeeded

    Press-Key("{F4}")
    SleepMs $DELAY_AFTER_F4_2_MS
    Abort-IfNeeded; Fail-IfNeeded

    SleepMs 2000
    Press-Key("{F8}")
    SleepMs 150
    Abort-IfNeeded; Fail-IfNeeded

    SleepMs 3000
    Press-Key("{ENTER}")
    SleepMs 100
    Abort-IfNeeded; Fail-IfNeeded
  }
}

# ================================
# Execução
# ================================
try {
  $producers = Load-Producers $InputFile
  if($producers.Count -eq 0){
    Write-Host "[ERRO] Nenhum [PRODUTOR] encontrado no arquivo." -ForegroundColor Red
    exit 2
  }

  $errors = Validate-Producers $producers
  if($errors.Count -gt 0){
    Write-Host "==========================================" -ForegroundColor Yellow
    Write-Host "ERROS NO ARQUIVO. Corrija antes de rodar:" -ForegroundColor Yellow
    Write-Host "==========================================" -ForegroundColor Yellow
    $errors | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
    exit 2
  }

  Write-Host "=========================================="
  Write-Host " NFE - Contratacao de veiculo"
  Write-Host ("Produtores: {0}" -f $producers.Count)
  Write-Host ("Reiniciar bloco: {0}" -f $FAIL_HOTKEY)
  Write-Host ("Abortar: {0} (ou ESC)" -f $ABORT_HOTKEY)
  Write-Host "=========================================="
  Write-Host ""
  Write-Host "IMPORTANTE: quando confirmar, CLIQUE no ERP antes de iniciar o bloco." -ForegroundColor DarkGray
  Write-Host ""

  

  if(-not (Ask-YesNo "CONFIRMAR INICIO? (S/N)")){
    Write-Host "Cancelado."
    exit 0
  }

  # Ajuste: abre a tela alvo
  Invoke-ClickPos -Name "ABRIR_TELA_CONTRATACAO_VEICULO_ERP"

  Write-Host ("Iniciando em {0}s..." -f $START_DELAY_SECONDS)
  Wait-And-FocusTime $START_DELAY_SECONDS

  # ==================================================
  # ORDEM DE EXECUCAO
  # 1) Primeiro: produtores com 1 nota fiscal
  # 2) Depois: produtores com mais de 1 nota fiscal
  # (Mantem o restante do fluxo igual)
  # ==================================================
  $producersSingle = @($producers | Where-Object { $_.notas.Count -eq 1 })
  $producersMulti  = @($producers | Where-Object { $_.notas.Count -gt 1 })
  $ordered = @($producersSingle + $producersMulti)

  Write-Host "" 
  Write-Host "ORDEM DE PROCESSAMENTO:" -ForegroundColor DarkGray
  Write-Host ("- 1 nota:  {0}" -f $producersSingle.Count) -ForegroundColor DarkGray
  Write-Host ("- multi:   {0}" -f $producersMulti.Count) -ForegroundColor DarkGray
  Write-Host "" 

  $pIndex = 0
  foreach($p in $ordered){
    $pIndex++
    Abort-IfNeeded

    if($p.status -eq "CONFIRMADO"){
      Write-Host ("[SKIP] {0}/{1}: {2} ja CONFIRMADO" -f $pIndex, $ordered.Count, $p.nome) -ForegroundColor DarkGray
      continue
    }
    

    Write-Host ""
    Write-Host "--------------------------------------------------"
    Write-Host ("PRODUTOR {0}/{1}: {2}" -f $pIndex, $ordered.Count, $p.nome)
    Write-Host ("INSTRUCAO={0}  PEDIDO={1}  NOTAS={2}" -f $p.instrucao, $p.pedido, $p.notas.Count)
    Write-Host "--------------------------------------------------"

    $tent = 0
    while($true){
      $tent++
      try {
        Write-Host ""
        Write-Host ("Ajuste a tela do ERP e confirme. (Tentativa {0})" -f $tent) -ForegroundColor Cyan
        if(-not (Ask-YesNo "PRONTO PARA RODAR ESTE BLOCO? (S/N)")){
          Write-Host "Parado pelo usuario."
          exit 3
        }

        # <<< ESSENCIAL: tempo pra focar o ERP após responder no console
        Wait-And-FocusTime $AFTER_CONFIRM_SECONDS

        Run-NFE-Bloco $p
        Write-Host "[OK] Bloco concluido." -ForegroundColor Green
        break
      }
      catch {
        $msg = $_.Exception.Message
        if($msg -like "ABORTADO*"){ throw }
        Write-Host ("[ERRO] {0}" -f $msg) -ForegroundColor Red
        Write-Host "[ACAO] Reiniciando BLOCO ATUAL..." -ForegroundColor Yellow
        Start-Sleep -Milliseconds 250
        continue
      }
    }

    if($pIndex -lt $ordered.Count){
      Start-Sleep -Seconds 1
    }
  }

  Write-Host ""
  Write-Host "[OK] Processo concluido."
  exit 0
}
catch {
  Write-Host ""
  Write-Host ("[ERRO] {0}" -f $_.Exception.Message) -ForegroundColor Red
  exit 3
}
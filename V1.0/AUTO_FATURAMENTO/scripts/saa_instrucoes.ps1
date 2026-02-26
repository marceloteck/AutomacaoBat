param(
  [Parameter(Mandatory=$true)]
  [string]$InputFile
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Backup-File($path){
  $ts = Get-Date -Format "yyyyMMdd_HHmmss"
  Copy-Item -LiteralPath $path -Destination "$path.bak_$ts" -ErrorAction SilentlyContinue | Out-Null
}

function Load-Instrucoes($path){
  if(!(Test-Path -LiteralPath $path)) { throw "Arquivo nao encontrado: $path" }
  $lines = Get-Content -LiteralPath $path -Encoding UTF8

  $mode = ""
  $pend = New-Object System.Collections.Generic.List[string]
  $conc = New-Object System.Collections.Generic.List[string]

  foreach($raw in $lines){
    $line = ($raw ?? "").Trim()
    if($line -eq "" -or $line.StartsWith("#")){ continue }

    if($line -ieq "[PENDENTE]"){ $mode="P"; continue }
    if($line -ieq "[CONCLUIDO]"){ $mode="C"; continue }

    if($line -match '^\d+$'){
      if($mode -eq "P"){ $pend.Add($line) }
      elseif($mode -eq "C"){ $conc.Add($line) }
    }
  }

  return [pscustomobject]@{ pendente=$pend; concluido=$conc }
}

function Save-Instrucoes($path, $pend, $conc){
  $out = New-Object System.Collections.Generic.List[string]
  $out.Add("[PENDENTE]")
  foreach($n in $pend){ $out.Add($n) }
  $out.Add("")
  $out.Add("[CONCLUIDO]")
  foreach($n in $conc){ $out.Add($n) }
  $out.Add("")
  Set-Content -LiteralPath $path -Value $out -Encoding UTF8
}

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

Add-Type -AssemblyName System.Windows.Forms

# Caminhos
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)  # ...\SAA_BAT
$ahkExe = Join-Path $root "ahk\AutoHotkey.exe"
$ahkScript = Join-Path $root "ahk\select_and_refocus.ahk"

if(!(Test-Path -LiteralPath $ahkExe)) { throw "Nao achei AutoHotkey.exe em: $ahkExe" }
if(!(Test-Path -LiteralPath $ahkScript)) { throw "Nao achei o AHK script em: $ahkScript" }

# Lê arquivo
$data = Load-Instrucoes $InputFile
$pend = $data.pendente
$conc = $data.concluido

if($pend.Count -eq 0){
  Write-Host "[OK] Nao ha instrucoes em [PENDENTE]."
  exit 0
}

# Backup inicial
Backup-File $InputFile

Write-Host ("[OK] PENDENTE: {0} | CONCLUIDO: {1}" -f $pend.Count, $conc.Count)
Write-Host "[INFO] Iniciando loop... (deixe o ERP em foco com o cursor piscando no input)"

# Para cada instrução pendente
while($pend.Count -gt 0){
  $instr = $pend[0]

  # Ctrl+A, apaga, cola, Enter
  [System.Windows.Forms.SendKeys]::SendWait("^a")
  Start-Sleep -Milliseconds 50
  [System.Windows.Forms.SendKeys]::SendWait("{BACKSPACE}")
  Start-Sleep -Milliseconds 50

  Paste-Text $instr
  Start-Sleep -Milliseconds 60

  [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")

  # AHK: espera 0,4s, clica 1º item e refoca no input
  $p = Start-Process -FilePath $ahkExe -ArgumentList "`"$ahkScript`"" -Wait -PassThru -WindowStyle Hidden
  if($p.ExitCode -ne 0){
    throw "AHK terminou com erro (ExitCode=$($p.ExitCode))"
  }

  # Marca como CONCLUIDO e salva imediatamente
  $pend.RemoveAt(0)
  $conc.Add($instr)
  Save-Instrucoes -path $InputFile -pend $pend -conc $conc

  Write-Host ("[OK] {0} -> CONCLUIDO | Restantes: {1}" -f $instr, $pend.Count)

  Start-Sleep -Milliseconds 120
}

Write-Host "[OK] Tudo concluido."
exit 0
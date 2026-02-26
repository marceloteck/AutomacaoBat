param(
  [Parameter(Mandatory=$true)][string]$Config,
  [Parameter(Mandatory=$true)][string]$Dados
)

# ==========================================================
# MOTOR PROFISSIONAL - Automacao por TXT (config + dados)
# PS 5.1 friendly
# ==========================================================
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms

# ------------------------------
# Helpers: tipo seguro (corrige ContainsKey em string)
# ------------------------------
function As-Hashtable($obj) {
  if ($obj -is [hashtable]) { return $obj }
  return @{}
}

function Has-Key($obj, [string]$key) {
  return ($obj -is [hashtable] -and $obj.ContainsKey($key))
}

# ------------------------------
# Helpers de path
# ------------------------------
function Resolve-PathSafe([string]$p) {
  if ([string]::IsNullOrWhiteSpace($p)) { return $null }
  try { return (Resolve-Path -LiteralPath $p -ErrorAction Stop).Path } catch {
    $base = $PSScriptRoot
    if ([string]::IsNullOrWhiteSpace($base)) { $base = Split-Path -Parent $MyInvocation.MyCommand.Path }
    $try = Join-Path $base $p
    return (Resolve-Path -LiteralPath $try -ErrorAction Stop).Path
  }
}

$ConfigTxt = Resolve-PathSafe $Config
$DadosTxt  = Resolve-PathSafe $Dados
if (!(Test-Path -LiteralPath $ConfigTxt)) { Write-Host "ERRO: Config nao encontrado: $ConfigTxt" -ForegroundColor Red; exit 2 }
if (!(Test-Path -LiteralPath $DadosTxt))  { Write-Host "ERRO: Dados nao encontrado : $DadosTxt"  -ForegroundColor Red; exit 2 }

# ------------------------------
# click_positions (opcional)
# ------------------------------
$clickLib = Join-Path $PSScriptRoot "click_positions.ps1"
if (Test-Path -LiteralPath $clickLib) { . $clickLib }

# ------------------------------
# IO básico
# ------------------------------

function Press-Key([string]$k) {
  if ($null -eq $k) { return }
  $k = ($k + "")
  if ($k.Trim().Length -eq 0) { return }
  [System.Windows.Forms.SendKeys]::SendWait($k)
}

function Type-Text([string]$t) {
  if ($null -eq $t) { return }
  $t = ($t + "")
  if ($t.Trim().Length -eq 0) { return }
  [System.Windows.Forms.SendKeys]::SendWait($t)
}

function SleepMs([int]$ms) {
  if ($ms -lt 0) { $ms = 0 }
  Start-Sleep -Milliseconds $ms
}

function Set-ClipText([string]$text) {
  if ($null -eq $text) { $text = "" }
  Set-Clipboard -Value ([string]$text)
}

function Paste-Text([string]$text) {
  if ($null -eq $text) { $text = "" }
  Set-ClipText $text
  Press-Key("^v")
}

function Ask-YesNo([string]$Prompt = "Continuar? (S/N)") {
  while ($true) {
    $ans = Read-Host $Prompt
    if ($null -eq $ans) { $ans = "" }
    $ans = ($ans + "").Trim().ToUpperInvariant()
    if ($ans -eq "S") { return $true }
    if ($ans -eq "N") { return $false }
    Write-Host "Digite apenas S ou N." -ForegroundColor Yellow
  }
}

function Open-DesktopFolder {
  $p = Join-Path $env:USERPROFILE "Downloads\DESKTOP"
  if (!(Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Path $p | Out-Null }
  Start-Process -FilePath $p | Out-Null
}

# ==========================================================
# LOG
# ==========================================================
function Now-StampDate { return (Get-Date).ToString("yyyyMMdd") }
function Now-StampTime { return (Get-Date).ToString("HHmmss") }

function Ensure-Dir([string]$path) {
  $dir = Split-Path -Parent $path
  if (![string]::IsNullOrWhiteSpace($dir) -and !(Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Path $dir | Out-Null
  }
}

function Write-LogLine([string]$logPath, [string]$line) {
  if ([string]::IsNullOrWhiteSpace($logPath)) { return }
  Ensure-Dir $logPath
  $ts = (Get-Date).ToString("s")
  ($ts + " | " + $line) | Add-Content -Encoding UTF8 -LiteralPath $logPath
}

# ==========================================================
# Template {{...}}
# - {{CAMPO}}: ctx (produtor)
# - {{VAR.X}}: globals
# - {{ITEM}}, {{ITEM_INDEX}}: foreach
# - params do CALL entram em locals
# ==========================================================
function Render-Template {
  param(
    [string]$text,
    $ctx,
    $globals,
    $locals
  )

  if ($null -eq $text) { return "" }

  $ctxH     = As-Hashtable $ctx
  $globalsH = As-Hashtable $globals
  $localsH  = As-Hashtable $locals

  return ([regex]::Replace($text, '\{\{([^}]+)\}\}', {
    param($m)
    $key = $m.Groups[1].Value.Trim()
    $kU  = $key.ToUpperInvariant()

    # locals
    if (Has-Key $localsH $kU) { return [string]$localsH[$kU] }

    # globals VAR.
    if ($kU.StartsWith("VAR.")) {
      $k2 = $kU.Substring(4).Trim()
      if (Has-Key $globalsH $k2) { return [string]$globalsH[$k2] }
      return ""
    }

    # ctx
    if (Has-Key $ctxH $kU) {
      $v = $ctxH[$kU]
      if ($v -is [System.Array]) {
        return (($v | ForEach-Object { ($_ + "").Trim() }) -join "`r`n")
      }
      return [string]$v
    }

    return ""
  }))
}

# ==========================================================
# Condições: == != && ||
# ==========================================================
function Eval-Cond {
  param([string]$expr, $ctx, $globals, $locals)

  if ([string]::IsNullOrWhiteSpace($expr)) { return $true }

  $ctxH     = As-Hashtable $ctx
  $globalsH = As-Hashtable $globals
  $localsH  = As-Hashtable $locals

  $expr2 = Render-Template $expr $ctxH $globalsH $localsH

  $orParts = $expr2 -split '\|\|'
  foreach ($orPart in $orParts) {
    $andOk = $true
    $andParts = $orPart -split '&&'
    foreach ($p in $andParts) {
      $c = ($p + "").Trim()
      if ($c -match '^([A-Za-z0-9_ÇçÃãÕõÉéÍíÓóÚú]+)\s*(==|!=)\s*(.+)$') {
        $k  = $matches[1].Trim().ToUpperInvariant()
        $op = $matches[2]
        $v  = $matches[3].Trim()

        $cur = ""
        if (Has-Key $localsH $k) { $cur = [string]$localsH[$k] }
        elseif (Has-Key $ctxH $k) {
          $cv = $ctxH[$k]
          $cur = if ($cv -is [System.Array]) { ($cv -join ";") } else { [string]$cv }
        }
        elseif (Has-Key $globalsH $k) { $cur = [string]$globalsH[$k] }

        $ok = $false
        if ($op -eq "==") { $ok = ($cur -eq $v) }
        if ($op -eq "!=") { $ok = ($cur -ne $v) }
        if (-not $ok) { $andOk = $false; break }
      } else {
        $andOk = $false; break
      }
    }
    if ($andOk) { return $true }
  }
  return $false
}

# ==========================================================
# PARSER config.txt
# ==========================================================
function Parse-Config {
  param([string]$path)

  $lines = Get-Content -LiteralPath $path -ErrorAction Stop

  $CONFIG = @{}
  $VARS   = @{}
  $Tarefas = New-Object System.Collections.Generic.List[hashtable]
  $Macros  = @{}  # NAME -> scriptLines (string[])

  $section = ""
  $curTask = $null
  $curMacro = $null
  $scriptMode = $false
  $scriptBuf = New-Object System.Collections.Generic.List[string]

  for ($i=0; $i -lt $lines.Count; $i++) {
    $raw = $lines[$i]
    if ($null -eq $raw) { $raw = "" }
    $line = $raw.Trim()

    if ($scriptMode) {
      if ($line -eq "]") {
        $scriptMode = $false

        if ($section -eq "TAREFA" -and $curTask -ne $null) {
          $curTask["SCRIPT_LINES"] = @($scriptBuf)
        }
        elseif ($section -eq "MACRO" -and $curMacro -ne $null) {
          $mName = ($curMacro["NOME"] + "").Trim()
          if ([string]::IsNullOrWhiteSpace($mName)) { throw "MACRO sem NOME." }
          $Macros[$mName.ToUpperInvariant()] = @($scriptBuf)
        }

        $scriptBuf = New-Object System.Collections.Generic.List[string]
        continue
      }

      if ($line -eq "" -or $line.StartsWith(";")) { continue }
      $scriptBuf.Add($line)
      continue
    }

    if ($line -eq "" -or $line.StartsWith(";")) { continue }

    if ($line -match '^\[(.+)\]$') {
      $section = $matches[1].Trim().ToUpperInvariant()
      if ($section -eq "TAREFA") { $curTask = @{}; $Tarefas.Add($curTask) }
      elseif ($section -eq "MACRO") { $curMacro = @{} }
      continue
    }

    if ($line.ToUpperInvariant() -eq "SCRIPT=[" ) {
      $scriptMode = $true
      $scriptBuf = New-Object System.Collections.Generic.List[string]
      continue
    }

    if ($line -match '^([^=]+)=(.*)$') {
      $k = $matches[1].Trim().ToUpperInvariant()
      $v = $matches[2]
      switch ($section) {
        "CONFIG" { $CONFIG[$k] = $v; break }
        "VAR"    { $VARS[$k]   = $v; break }
        "TAREFA" { if ($curTask -ne $null) { $curTask[$k] = $v }; break }
        "MACRO"  { if ($curMacro -ne $null) { $curMacro[$k] = $v }; break }
        default  { }
      }
    }
  }

  foreach ($t in $Tarefas) {
    if (-not (Has-Key $t "SCRIPT_LINES")) { throw "TAREFA sem SCRIPT=[ ... ]" }
  }

  return [pscustomobject]@{
    CONFIG = $CONFIG
    VARS   = $VARS
    TAREFAS = $Tarefas
    MACROS = $Macros
  }
}

# ==========================================================
# PARSER dados.txt (listas CHAVE:)
# ==========================================================
function Parse-Dados {
  param([string]$path)

  $lines = Get-Content -LiteralPath $path -Encoding UTF8 -ErrorAction Stop
  $items = New-Object System.Collections.Generic.List[hashtable]

  $cur = $null
  $section = ""

  $inList = $false
  $listKey = ""
  $listBuf = New-Object System.Collections.Generic.List[string]

  function Flush-List {
    if ($inList -and $cur -ne $null) {
      $k = $listKey.Trim().ToUpperInvariant()
      $arr = @()
      foreach ($x in $listBuf) {
        $v = ($x + "").Trim()
        if ($v -ne "") { $arr += $v }
      }
      $cur[$k] = $arr
    }
    $inList = $false
    $listKey = ""
    $listBuf = New-Object System.Collections.Generic.List[string]
  }

  for ($i=0; $i -lt $lines.Count; $i++) {
    $raw = $lines[$i]
    if ($null -eq $raw) { $raw = "" }
    $line = $raw.Trim()

    if ($line -eq "" -or $line.StartsWith(";") -or $line.StartsWith("#")) {
      if ($inList) { continue }
      continue
    }

    if ($line -match '^\[(.+)\]$') {
      Flush-List

      $section = $matches[1].Trim().ToUpperInvariant()
      if ($section -eq "PRODUTOR") {
        if ($cur -ne $null) { $items.Add($cur) }
        $cur = @{ SECAO = "PRODUTOR" }
      } else {
        if ($cur -ne $null) { $items.Add($cur); $cur=$null }
      }
      continue
    }

    if ($cur -eq $null) { continue }

    if ($line -match '^([A-Za-z0-9_ÇçÃãÕõÉéÍíÓóÚú]+)\s*:\s*$') {
      Flush-List
      $inList = $true
      $listKey = $matches[1].Trim()
      continue
    }

    if ($inList -and $line -match '^([^=]+)=(.*)$') { Flush-List }

    if ($inList) {
      $listBuf.Add($line)
      continue
    }

    if ($line -match '^([^=]+)=(.*)$') {
      $k = $matches[1].Trim().ToUpperInvariant()
      $v = $matches[2]
      $cur[$k] = $v
      continue
    }

    throw "Linha inválida em dados.txt: '$line'"
  }

  Flush-List
  if ($cur -ne $null) { $items.Add($cur) }

  $prods = New-Object System.Collections.Generic.List[hashtable]
  foreach ($it in $items) {
    if ($it["SECAO"] -eq "PRODUTOR") { $prods.Add($it) }
  }
  return $prods
}

# ==========================================================
# SAVE_DADOS (backup + regravar)
# ==========================================================
function Save-Dados {
  param(
    [Parameter(Mandatory=$true)][string]$path,
    [Parameter(Mandatory=$true)]$producers
  )

  $ts = Get-Date -Format "yyyyMMdd_HHmmss"
  $bak = "$path.bak_$ts"
  Copy-Item -LiteralPath $path -Destination $bak -ErrorAction SilentlyContinue | Out-Null

  $out = New-Object System.Collections.Generic.List[string]

  foreach ($p in $producers) {
    $out.Add("[PRODUTOR]")

    $priority = @("NOME","STATUS","TIPO","INSTRUCAO","PEDIDO")
    foreach ($k in $priority) {
      if (Has-Key $p $k -and -not ($p[$k] -is [System.Array])) {
        $out.Add("$k=$($p[$k])")
      }
    }

    $simpleKeys = @()
    foreach ($k in $p.Keys) {
      if ($k -eq "SECAO") { continue }
      if ($priority -contains $k) { continue }
      if ($p[$k] -is [System.Array]) { continue }
      $simpleKeys += $k
    }
    $simpleKeys = $simpleKeys | Sort-Object
    foreach ($k in $simpleKeys) {
      $out.Add("$k=$($p[$k])")
    }

    $listKeys = @()
    foreach ($k in $p.Keys) {
      if ($k -eq "SECAO") { continue }
      if ($p[$k] -is [System.Array]) { $listKeys += $k }
    }
    $listKeys = $listKeys | Sort-Object

    foreach ($lk in $listKeys) {
      $out.Add("")
      $out.Add("$lk`:")
      foreach ($it in $p[$lk]) {
        $v = ($it + "").Trim()
        if ($v -ne "") { $out.Add($v) }
      }
    }

    $out.Add("")
    $out.Add("")
  }

  Set-Content -LiteralPath $path -Value $out -Encoding UTF8
}

# ==========================================================
# Precompilar saltos IF/ELSE/ENDIF e FOREACH/END
# ==========================================================
function Build-Jumps {
  param([string[]]$scriptLines)

  $ifStack = New-Object System.Collections.Generic.Stack[int]
  $foreachStack = New-Object System.Collections.Generic.Stack[int]

  $ifElse = @{}
  $ifEnd  = @{}
  $elseEnd= @{}
  $forEnd = @{}
  $endFor = @{}

  for ($i=0; $i -lt $scriptLines.Length; $i++) {
    $s = $scriptLines[$i].Trim()

    if ($s -match '^IF\s*:(.+)$') { $ifStack.Push($i); continue }

    if ($s -eq "ELSE") {
      if ($ifStack.Count -lt 1) { throw "ELSE sem IF (linha $($i+1))" }
      $ifIndex = $ifStack.Peek()
      $ifElse[$ifIndex] = $i
      continue
    }

    if ($s -eq "ENDIF") {
      if ($ifStack.Count -lt 1) { throw "ENDIF sem IF (linha $($i+1))" }
      $ifIndex = $ifStack.Pop()
      $ifEnd[$ifIndex] = $i
      if ($ifElse.ContainsKey($ifIndex)) {
        $elseIndex = $ifElse[$ifIndex]
        $elseEnd[$elseIndex] = $i
      } else {
        $ifElse[$ifIndex] = -1
      }
      continue
    }

    if ($s -match '^FOREACH\s*:(.+)$') { $foreachStack.Push($i); continue }

    if ($s -eq "END") {
      if ($foreachStack.Count -lt 1) { throw "END sem FOREACH (linha $($i+1))" }
      $f = $foreachStack.Pop()
      $forEnd[$f] = $i
      $endFor[$i] = $f
      continue
    }
  }

  if ($ifStack.Count -gt 0) { throw "Existe IF sem ENDIF." }
  if ($foreachStack.Count -gt 0) { throw "Existe FOREACH sem END." }

  return [pscustomobject]@{
    IfElse = $ifElse
    IfEnd  = $ifEnd
    ElseEnd= $elseEnd
    ForEnd = $forEnd
    EndFor = $endFor
  }
}

# ==========================================================
# CALL parsing
# ==========================================================
function Parse-Call {
  param([string]$line)

  $rest = $line.Substring(5).Trim()
  if ([string]::IsNullOrWhiteSpace($rest)) { throw "CALL sem nome" }

  $parts = @($rest.Split(" ") | Where-Object { $_ -ne "" })
  $name = $parts[0].Trim()
  $params = @{}

  for ($i=1; $i -lt $parts.Count; $i++) {
    $p = $parts[$i]
    if ($p -match '^([^=]+)=(.*)$') {
      $k = $matches[1].Trim().ToUpperInvariant()
      $v = $matches[2]
      $params[$k] = $v
    } else {
      $params[(($p + "").Trim().ToUpperInvariant())] = "true"
    }
  }

  return [pscustomobject]@{ Name=$name; Params=$params }
}

# ==========================================================
# Execução de ações (inclui SET e SAVE_DADOS)
# ==========================================================
function Do-Action {
  param(
    [string]$cmd,
    $ctx,
    $globals,
    $locals,
    [int]$delayPadrao,
    [string]$modo,
    [string]$logPath,
    $saveState
  )

  $ctxH     = As-Hashtable $ctx
  $globalsH = As-Hashtable $globals
  $localsH  = As-Hashtable $locals

  $upper = $cmd.ToUpperInvariant()

  if ($upper -eq "OPEN_DESKTOP") {
    Write-LogLine $logPath "OPEN_DESKTOP"
    if ($modo -eq "REAL") { Open-DesktopFolder }
    return
  }

# SLEEP:valor  (aceita número ou template, ex: SLEEP:{{VAR.X}})
if ($cmd -match '^SLEEP\s*:\s*(.+)$') {
  $raw = Render-Template $matches[1] $ctxH $globalsH $localsH
  $raw = ($raw + "").Trim()

  $ms = 0
  if (-not [int]::TryParse($raw, [ref]$ms) -or $ms -lt 0) {
    throw "SLEEP inválido: '$raw'"
  }

  Write-LogLine $logPath "SLEEP $ms"
  if ($modo -eq "REAL") { SleepMs $ms }
  return
}
  if ($cmd -match '^KEY\s*:\s*(.+)$') {
  $k = Render-Template (($matches[1] + "").Trim()) $ctxH $globalsH $localsH
  $k = ($k + "").Trim()
  Write-LogLine $logPath "KEY $k"
  if ($modo -eq "REAL" -and $k -ne "") {
    Press-Key $k
    if ($delayPadrao -gt 0) { SleepMs $delayPadrao }
  }
  return
}

  if ($cmd -match '^PASTE\s*=\s*(.*)$') {
  $v = Render-Template $matches[1] $ctxH $globalsH $localsH
  $v = ($v + "")   # <- mata $null
  Write-LogLine $logPath ("PASTE len=" + $v.Length)
  if ($modo -eq "REAL") {
    Paste-Text $v
    if ($delayPadrao -gt 0) { SleepMs $delayPadrao }
  }
  return
}

  if ($cmd -match '^TYPE\s*=\s*(.*)$') {
  $v = Render-Template $matches[1] $ctxH $globalsH $localsH
  $v = ($v + "")   # <- mata $null
  Write-LogLine $logPath ("TYPE len=" + $v.Length)
  if ($modo -eq "REAL" -and $v.Trim() -ne "") {
    Press-Key $v
    if ($delayPadrao -gt 0) { SleepMs $delayPadrao }
  }
  return
}

  if ($cmd -match '^ASK\s*:\s*(.+)$') {
    $q = Render-Template $matches[1] $ctxH $globalsH $localsH
    Write-LogLine $logPath ("ASK " + $q)
    $ok = Ask-YesNo $q
    if (-not $ok) { throw "Abortado pelo usuario." }
    return
  }

  if ($cmd -match '^OPENPATH\s*:\s*(.+)$') {
    $p = Render-Template $matches[1] $ctxH $globalsH $localsH
    Write-LogLine $logPath ("OPENPATH " + $p)
    if ($modo -eq "REAL") { Start-Process -FilePath $p | Out-Null }
    return
  }

  if ($cmd -match '^SETVAR\s*:\s*([^=]+)=(.*)$') {
    $k = $matches[1].Trim().ToUpperInvariant()
    $v = Render-Template $matches[2] $ctxH $globalsH $localsH
    $globalsH[$k] = $v
    Write-LogLine $logPath ("SETVAR " + $k + "=" + $v)
    return
  }

  # SET:CAMPO=VALOR (ctx/produtor)
  if ($cmd -match '^SET\s*:\s*([^=]+)=(.*)$') {
    $k = $matches[1].Trim().ToUpperInvariant()
    $v = Render-Template $matches[2] $ctxH $globalsH $localsH
    $ctxH[$k] = $v
    Write-LogLine $logPath ("SET " + $k + "=" + $v)
    return
  }

  # SAVE_DADOS
  if ($upper -eq "SAVE_DADOS") {
    $p = $saveState.DadosPath
    Write-LogLine $logPath ("SAVE_DADOS " + $p)
    if ($modo -eq "REAL") {
      Save-Dados -path $p -producers $saveState.Producers
    }
    return
  }

  if ($cmd -match '^REQUIRE\s*:\s*(.+)$') {
    $k = $matches[1].Trim().ToUpperInvariant()

    $val = ""
    if (Has-Key $localsH $k) { $val = [string]$localsH[$k] }
    elseif (Has-Key $ctxH $k) {
      $cv = $ctxH[$k]
      $val = if ($cv -is [System.Array]) { ($cv -join ";") } else { [string]$cv }
    }
    elseif (Has-Key $globalsH $k) { $val = [string]$globalsH[$k] }

    if ([string]::IsNullOrWhiteSpace($val)) { throw "REQUIRE falhou: '$k' está vazio." }
    Write-LogLine $logPath ("REQUIRE OK " + $k)
    return
  }

  if ($cmd -match '^SKIP_IF_EMPTY\s*:\s*(.+)$') {
    $k = $matches[1].Trim().ToUpperInvariant()

    if (Has-Key $ctxH $k -and ($ctxH[$k] -is [System.Array])) {
      $arr = $ctxH[$k]
      if ($null -eq $arr -or $arr.Count -eq 0) { throw "SKIP_TASK: '$k' vazio (lista)." }
      return
    }

    $val = ""
    if (Has-Key $localsH $k) { $val = [string]$localsH[$k] }
    elseif (Has-Key $ctxH $k) { $val = [string]$ctxH[$k] }
    elseif (Has-Key $globalsH $k) { $val = [string]$globalsH[$k] }

    if ([string]::IsNullOrWhiteSpace($val)) { throw "SKIP_TASK: '$k' vazio." }
    return
  }

  if ($cmd -match '^CLICK\s*:\s*(.+)$') {
    $name = Render-Template $matches[1].Trim() $ctxH $globalsH $localsH
    Write-LogLine $logPath ("CLICK " + $name)

    if ($modo -eq "REAL") {
      $c = Get-Command Invoke-ClickPos -ErrorAction SilentlyContinue
      if ($null -eq $c) { throw "CLICK usado, mas click_positions.ps1 nao tem Invoke-ClickPos." }
      Invoke-ClickPos -Name $name
      if ($delayPadrao -gt 0) { SleepMs $delayPadrao }
    }
    return
  }

  throw "Comando desconhecido: $cmd"
}

# ==========================================================
# Run-Script
# ==========================================================
function Run-Script {
  param(
    [string[]]$scriptLines,
    $ctx,
    $globals,
    $macros,
    [int]$delayPadrao,
    [string]$modo,
    [string]$logPath,
    $saveState
  )

  $ctxH     = As-Hashtable $ctx
  $globalsH = As-Hashtable $globals
  $macrosH  = As-Hashtable $macros

  $locals = @{}
  $jumps = Build-Jumps $scriptLines

  $ip = 0
  $loopStack = New-Object System.Collections.Generic.Stack[hashtable]

  while ($ip -lt $scriptLines.Length) {
    $line = $scriptLines[$ip].Trim()
    if ($line -eq "" -or $line.StartsWith(";")) { $ip++; continue }

    if ($line -match '^IF\s*:(.+)$') {
      $cond = $matches[1].Trim()
      $ok = Eval-Cond $cond $ctxH $globalsH $locals
      if ($ok) { $ip++; continue }

      $elseIndex = -1
      if ($jumps.IfElse.ContainsKey($ip)) { $elseIndex = [int]$jumps.IfElse[$ip] }
      $endIndex  = [int]$jumps.IfEnd[$ip]

      if ($elseIndex -ge 0) { $ip = $elseIndex + 1 } else { $ip = $endIndex + 1 }
      continue
    }

    if ($line -eq "ELSE") {
      $endIndex = [int]$jumps.ElseEnd[$ip]
      $ip = $endIndex + 1
      continue
    }

    if ($line -eq "ENDIF") { $ip++; continue }

    if ($line -match '^FOREACH\s*:\s*(.+)$') {
      $field = $matches[1].Trim().ToUpperInvariant()

      $arr = $null
      if (Has-Key $ctxH $field -and ($ctxH[$field] -is [System.Array])) {
        $arr = $ctxH[$field]
      } else {
        $raw = ""
        if (Has-Key $ctxH $field) { $raw = [string]$ctxH[$field] }
        $raw = ($raw + "").Trim()
        if ($raw -eq "") { $arr = @() }
        else {
          if ($raw.Contains("`n")) { $arr = ($raw -split "`r?`n") }
          elseif ($raw.Contains(";")) { $arr = ($raw -split ";") }
          elseif ($raw.Contains(",")) { $arr = ($raw -split ",") }
          else { $arr = @($raw) }
          $arr = @($arr | ForEach-Object { ($_ + "").Trim() } | Where-Object { $_ -ne "" })
        }
      }

      $endIndex = [int]$jumps.ForEnd[$ip]
      if ($null -eq $arr -or $arr.Count -eq 0) { $ip = $endIndex + 1; continue }

      $frame = @{
        FOREACH_INDEX = $ip
        ITEMS         = $arr
        POS           = 0
        FIELD         = $field
      }
      $loopStack.Push($frame)

      $locals["ITEM"] = $arr[0]
      $locals["ITEM_INDEX"] = "1"

      $ip++
      continue
    }

    if ($line -eq "END") {
      if ($loopStack.Count -lt 1) { throw "END sem FOREACH." }
      $frame = $loopStack.Peek()
      $frame.POS = [int]$frame.POS + 1

      if ($frame.POS -ge $frame.ITEMS.Count) {
        $null = $loopStack.Pop()
        $locals.Remove("ITEM") | Out-Null
        $locals.Remove("ITEM_INDEX") | Out-Null
        $ip++
        continue
      }

      $locals["ITEM"] = $frame.ITEMS[$frame.POS]
      $locals["ITEM_INDEX"] = ([int]$frame.POS + 1).ToString()

      $ip = [int]$frame.FOREACH_INDEX + 1
      continue
    }

    if ($line.ToUpperInvariant().StartsWith("CALL:")) {
      $call = Parse-Call $line
      $mName = $call.Name.Trim().ToUpperInvariant()
      if (-not $macrosH.ContainsKey($mName)) { throw "CALL macro inexistente: $($call.Name)" }

      $backup = @{}
      foreach ($k in $call.Params.Keys) {
        $uk = $k.ToUpperInvariant()
        if ($locals.ContainsKey($uk)) { $backup[$uk] = $locals[$uk] } else { $backup[$uk] = $null }
        $locals[$uk] = Render-Template $call.Params[$k] $ctxH $globalsH $locals
      }

      Write-LogLine $logPath ("CALL " + $mName)

      Run-Script -scriptLines $macrosH[$mName] -ctx $ctxH -globals $globalsH -macros $macrosH -delayPadrao $delayPadrao -modo $modo -logPath $logPath -saveState $saveState

      foreach ($k in $call.Params.Keys) {
        $uk = $k.ToUpperInvariant()
        if ($backup[$uk] -eq $null) { $locals.Remove($uk) | Out-Null } else { $locals[$uk] = $backup[$uk] }
      }

      $ip++
      continue
    }

    Do-Action -cmd $line -ctx $ctxH -globals $globalsH -locals $locals -delayPadrao $delayPadrao -modo $modo -logPath $logPath -saveState $saveState
    $ip++
  }
}

# ==========================================================
# MAIN
# ==========================================================
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " MOTOR PROFISSIONAL - AUTOMACAO" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ("CONFIG: {0}" -f $ConfigTxt) -ForegroundColor Cyan
Write-Host ("DADOS : {0}" -f $DadosTxt)  -ForegroundColor Cyan

$cfg = Parse-Config $ConfigTxt
$CONFIG = As-Hashtable $cfg.CONFIG
$VARS   = As-Hashtable $cfg.VARS
$TAREFAS= $cfg.TAREFAS
$MACROS = As-Hashtable $cfg.MACROS

$PRODUTORES = Parse-Dados $DadosTxt

$saveState = [pscustomobject]@{
  DadosPath = $DadosTxt
  Producers = $PRODUTORES
}

function GetCfg([string]$k, [string]$def="") {
  $uk = $k.ToUpperInvariant()
  if (Has-Key $CONFIG $uk) { return ($CONFIG[$uk] + "").Trim() }
  return $def
}

$delayPadrao = 0
$tmp = 0
if ([int]::TryParse((GetCfg "DELAY_PADRAO_MS" "0"), [ref]$tmp) -and $tmp -ge 0) { $delayPadrao = $tmp }

$confirmar = (GetCfg "CONFIRMAR_INICIO" "S").ToUpperInvariant()
$mostrar   = (GetCfg "MOSTRAR_CONTAGEM" "N").ToUpperInvariant()
$modo      = (GetCfg "MODO" "REAL").ToUpperInvariant()
$onError   = (GetCfg "ON_ERROR" "ASK").ToUpperInvariant()

$logAtivo  = (GetCfg "LOG_ATIVO" "N").ToUpperInvariant()
$logPath   = ""

if ($logAtivo -eq "S") {
  $lp = GetCfg "LOG_ARQUIVO" ("logs\exec_" + (Now-StampDate) + "_" + (Now-StampTime) + ".log")
  $baseCfg = Split-Path -Parent $ConfigTxt
  $logPath = Join-Path $baseCfg $lp
  Write-LogLine $logPath ("START modo=" + $modo + " on_error=" + $onError)
}

Write-Host ""
Write-Host ("MODO: {0} | ON_ERROR: {1} | LOG: {2}" -f $modo, $onError, ($(if($logAtivo -eq "S"){"S"}else{"N"}))) -ForegroundColor Yellow

if ($confirmar -eq "S") {
  $ok = Ask-YesNo "Iniciar agora? (S/N)"
  if (-not $ok) { Write-LogLine $logPath "ABORT user_cancel"; exit 0 }
}

if ($mostrar -eq "S") {
  Write-Host ""
  Write-Host "Deixe o ERP em FOCO AGORA..." -ForegroundColor Yellow
  Start-Sleep -Milliseconds 150
  for ($i=3; $i -ge 1; $i--) {
    [console]::beep(900,150)
    Write-Host ("Executando em {0}..." -f $i) -ForegroundColor Cyan
    Start-Sleep -Seconds 1
  }
  [console]::beep(1200,200)
}

foreach ($t in $TAREFAS) {
  $ativo = "S"
  if (Has-Key $t "ATIVO") { $ativo = ($t["ATIVO"] + "").Trim().ToUpperInvariant() }
  if ($ativo -ne "S") { continue }

  $nome = ($t["NOME"] + "")
  if ([string]::IsNullOrWhiteSpace($nome)) { $nome = "(sem nome)" }

  $escopo = "GLOBAL"
  if (Has-Key $t "ESCOPO") { $escopo = ($t["ESCOPO"] + "").Trim().ToUpperInvariant() }

  $quando = ""
  if (Has-Key $t "QUANDO") { $quando = ($t["QUANDO"] + "") }

  $rep = 1
  if (Has-Key $t "REPETIR") {
    $rt = 1
    if ([int]::TryParse(($t["REPETIR"] + "").Trim(), [ref]$rt) -and $rt -gt 0) { $rep = $rt }
  }

  $scriptLines = $t["SCRIPT_LINES"]
  Write-Host ""
  Write-Host ("TAREFA: {0} | ESCOPO={1} | REPETIR={2}" -f $nome, $escopo, $rep) -ForegroundColor Green
  Write-LogLine $logPath ("TASK " + $nome + " escopo=" + $escopo + " repetir=" + $rep)

  if ($escopo -eq "GLOBAL") {
    for ($i=1; $i -le $rep; $i++) {
      try {
        Run-Script -scriptLines $scriptLines -ctx @{} -globals $VARS -macros $MACROS -delayPadrao $delayPadrao -modo $modo -logPath $logPath -saveState $saveState
      } catch {
        Write-Host ("[ERRO] " + $_.Exception.Message) -ForegroundColor Red
        Write-LogLine $logPath ("ERROR " + $_.Exception.Message)
        if ($onError -eq "ABORT") { throw }
        if ($onError -eq "ASK") {
          $cont = Ask-YesNo "Erro. Continuar? (S/N)"
          if (-not $cont) { throw }
        }
        break
      }
    }
    continue
  }

  foreach ($p in $PRODUTORES) {
    $pName = if (Has-Key $p "NOME") { ($p["NOME"] + "") } else { "" }
    if (-not (Eval-Cond $quando $p $VARS @{})) { continue }

    Write-Host ("  PRODUTOR: " + $pName) -ForegroundColor Cyan
    Write-LogLine $logPath ("PRODUTOR " + $pName)

    for ($i=1; $i -le $rep; $i++) {
      try {
        Run-Script -scriptLines $scriptLines -ctx $p -globals $VARS -macros $MACROS -delayPadrao $delayPadrao -modo $modo -logPath $logPath -saveState $saveState
      } catch {
        $msg = $_.Exception.Message

        if ($msg.StartsWith("SKIP_TASK:")) {
          Write-Host ("  [PULOU TAREFA] " + $msg) -ForegroundColor Yellow
          Write-LogLine $logPath ("SKIP_TASK " + $msg)
          break
        }

        Write-Host ("  [ERRO] " + $msg) -ForegroundColor Red
        Write-LogLine $logPath ("ERROR " + $msg)

        if ($onError -eq "ABORT") { throw }
        if ($onError -eq "SKIP_PRODUTOR") { break }

        if ($onError -eq "ASK") {
          $opt = Ask-YesNo "Falhou. Repetir este PRODUTOR? (S/N)"
          if ($opt) { $i = 0; continue }
          $cont2 = Ask-YesNo "Pular este PRODUTOR e continuar? (S/N)"
          if ($cont2) { break } else { throw }
        }

        break
      }
    }
  }
}

Write-Host ""
Write-Host "FINALIZADO." -ForegroundColor Cyan
Write-LogLine $logPath "END ok"
exit 0
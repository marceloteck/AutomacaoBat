param(
  [switch]$NoMenu,
  [string]$Action,
  [string]$Path
)

$ErrorActionPreference = 'Stop'
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigPath = Join-Path $ScriptRoot 'config\system_config.psd1'

if (-not (Test-Path -LiteralPath $ConfigPath)) {
  throw "Arquivo de configuração não encontrado: $ConfigPath"
}

$Config = Import-PowerShellDataFile -LiteralPath $ConfigPath
$LogDir = Join-Path $ScriptRoot $Config.Paths.LogDir
if (-not (Test-Path -LiteralPath $LogDir)) {
  New-Item -ItemType Directory -Path $LogDir | Out-Null
}
$LogFile = Join-Path $LogDir ("automacao_{0}.log" -f (Get-Date -Format 'yyyy-MM-dd'))

function Write-Log {
  param(
    [string]$Message,
    [ValidateSet('INFO', 'WARN', 'ERROR')]
    [string]$Level = 'INFO'
  )

  $line = "[{0}] [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
  Write-Host $line
  Add-Content -LiteralPath $LogFile -Value $line
}

function Resolve-Executable {
  param([string[]]$Candidates)

  foreach ($candidate in $Candidates) {
    if ([string]::IsNullOrWhiteSpace($candidate)) { continue }

    if (Test-Path -LiteralPath $candidate) {
      return (Resolve-Path -LiteralPath $candidate).Path
    }

    $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
  }

  return $null
}

function Invoke-ExternalScript {
  param(
    [Parameter(Mandatory = $true)][string]$ScriptPath,
    [string[]]$Arguments = @(),
    [switch]$Wait
  )

  if (-not (Test-Path -LiteralPath $ScriptPath)) {
    throw "Arquivo não encontrado: $ScriptPath"
  }

  Write-Log "Executando: $ScriptPath $($Arguments -join ' ')"

  $safeArguments = @($Arguments | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

  if ($Wait) {
    if ($safeArguments.Count -gt 0) {
      $proc = Start-Process -FilePath $ScriptPath -ArgumentList $safeArguments -Wait -PassThru -NoNewWindow
    }
    else {
      $proc = Start-Process -FilePath $ScriptPath -Wait -PassThru -NoNewWindow
    }
    if ($proc.ExitCode -ne 0) {
      throw "Execução retornou código $($proc.ExitCode): $ScriptPath"
    }
  }
  else {
    if ($safeArguments.Count -gt 0) {
      Start-Process -FilePath $ScriptPath -ArgumentList $safeArguments | Out-Null
    }
    else {
      Start-Process -FilePath $ScriptPath | Out-Null
    }
  }

  Write-Log "Concluído: $ScriptPath"
}

function Set-DefaultPrinterSafe {
  param([Parameter(Mandatory = $true)][string]$PrinterName)

  Write-Log "Definindo impressora padrão: $PrinterName"

  try {
    $printerCmd = Get-Command Set-Printer -ErrorAction SilentlyContinue
    if ($printerCmd) {
      Set-Printer -Name $PrinterName -IsDefault $true -ErrorAction Stop
      Write-Log "Impressora definida via Set-Printer: $PrinterName"
      return
    }

    $wmiPrinter = Get-WmiObject -Class Win32_Printer -Filter "Name='$PrinterName'"
    if ($wmiPrinter) {
      $result = $wmiPrinter.SetDefaultPrinter()
      if ($result.ReturnValue -eq 0) {
        Write-Log "Impressora definida via WMI: $PrinterName"
        return
      }
    }

    $wmic = Resolve-Executable -Candidates @('wmic.exe', 'wmic')
    if ($wmic) {
      & $wmic printer where "Name='$PrinterName'" call SetDefaultPrinter | Out-Null
      if ($LASTEXITCODE -eq 0) {
        Write-Log "Impressora definida via WMIC: $PrinterName"
        return
      }
    }

    throw "Não foi possível definir a impressora '$PrinterName'."
  }
  catch {
    Write-Log "Falha ao definir impressora: $($_.Exception.Message)" 'ERROR'
    throw
  }
}

function Get-TargetPath {
  param([string]$Prompt = 'Digite o caminho da pasta')

  if ($Path) {
    $candidate = $Path.Trim().Trim('"')
  }
  else {
    $candidate = (Read-Host $Prompt).Trim().Trim('"')
  }

  if (-not (Test-Path -LiteralPath $candidate)) {
    throw "Pasta não encontrada: $candidate"
  }

  return (Resolve-Path -LiteralPath $candidate).Path
}

function Rename-PdfByPrefix {
  param(
    [Parameter(Mandatory = $true)][string]$Folder,
    [Parameter(Mandatory = $true)][string]$Mode
  )

  $files = Get-ChildItem -LiteralPath $Folder -Filter '*.pdf' -File -ErrorAction SilentlyContinue
  $count = 0

  foreach ($file in $files) {
    $newName = $null

    switch ($Mode) {
      'AddAC' {
        if ($file.Name -notmatch '^(?i)AC\.') { $newName = "AC.$($file.Name)" }
      }
      'RemoveAC' {
        if ($file.Name -match '^(?i)AC\.') { $newName = ($file.Name -replace '^(?i)AC\.', '') }
      }
      'Remove2' {
        if ($file.Name -match '^2\.') { $newName = ($file.Name -replace '^2\.', '') }
      }
      default {
        throw "Modo de renomeação inválido: $Mode"
      }
    }

    if ($newName -and $newName -ne $file.Name) {
      Rename-Item -LiteralPath $file.FullName -NewName $newName -Force
      $count++
    }
  }

  Write-Log "Renomeação concluída ($Mode). Total: $count"
}

function Organize-FilesIntoFolders {
  param([Parameter(Mandatory = $true)][string]$Folder)

  $items = Get-ChildItem -LiteralPath $Folder -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -match '^(?i)\.(pdf|xml)$' }

  foreach ($item in $items) {
    $targetDir = Join-Path $Folder $item.BaseName
    if (-not (Test-Path -LiteralPath $targetDir)) {
      New-Item -ItemType Directory -Path $targetDir | Out-Null
    }
    Move-Item -LiteralPath $item.FullName -Destination $targetDir -Force
  }

  Write-Log "Arquivos organizados em subpastas: $Folder"
}

function Invoke-AllAutomations {
  Write-Log 'Iniciando automação completa (rede -> processo acertos -> impressão).'

  Invoke-Action -Name 'MAPEAR_REDE'
  Invoke-Action -Name 'PROCESSO_ACERTOS'
  Invoke-Action -Name 'EXECUTAR_IMPRESSAO'

  Write-Log 'Automação completa finalizada.'
}

function Invoke-Action {
  param([Parameter(Mandatory = $true)][string]$Name)

  switch ($Name) {
    'PROCESSO_ACERTOS' {
      Invoke-ExternalScript -ScriptPath (Join-Path $ScriptRoot 'FATURAMENTO-PRO\processo_acertos.cmd') -Wait
    }
    'EXECUTAR_IMPRESSAO' {
      Invoke-ExternalScript -ScriptPath (Join-Path $ScriptRoot 'IMPRESSAO_PRO\EXECUTAR_IMPRESSAO.bat') -Wait
    }
    'MAPEAR_REDE' {
      Invoke-ExternalScript -ScriptPath (Join-Path $ScriptRoot 'UTILITARIOS\MAPEAR REDE.cmd') -Wait
    }
    'INICIAR_CORPORATE' {
      $exe = $Config.Executables.CorporateUpdater
      if (-not (Test-Path -LiteralPath $exe)) {
        throw "Corporate updater não encontrado: $exe"
      }
      for ($i = 1; $i -le [Math]::Max(1, [int]$Config.Executables.CorporateStartTimes); $i++) {
        Start-Process -FilePath $exe | Out-Null
      }
      Write-Log "Corporate updater iniciado $($Config.Executables.CorporateStartTimes)x."
    }
    'SET_PDFCREATOR' {
      Set-DefaultPrinterSafe -PrinterName $Config.Printers.PDFCreator
    }
    'SET_PHYSICAL_PRINTER' {
      Set-DefaultPrinterSafe -PrinterName $Config.Printers.Physical
    }
    'SET_SAVE_PDF' {
      Set-DefaultPrinterSafe -PrinterName $Config.Printers.MicrosoftPdf
    }
    'AUTOSAVE_ON' {
      Invoke-ExternalScript -ScriptPath (Join-Path $ScriptRoot 'UTILITARIOS\PDFCreator_AUTOSAVE_ON.bat') -Wait
    }
    'AUTOSAVE_OFF' {
      Invoke-ExternalScript -ScriptPath (Join-Path $ScriptRoot 'UTILITARIOS\PDFCreator_SAVE_OFF.bat') -Wait
    }
    'ADD_AC' {
      $folder = Get-TargetPath -Prompt 'Pasta para ADICIONAR AC. nos PDFs'
      Rename-PdfByPrefix -Folder $folder -Mode 'AddAC'
    }
    'REMOVE_AC' {
      $folder = Get-TargetPath -Prompt 'Pasta para REMOVER AC. dos PDFs'
      Rename-PdfByPrefix -Folder $folder -Mode 'RemoveAC'
    }
    'REMOVE_2' {
      $folder = Get-TargetPath -Prompt 'Pasta para REMOVER 2. dos PDFs'
      Rename-PdfByPrefix -Folder $folder -Mode 'Remove2'
    }
    'ORGANIZE_FILES' {
      $folder = Get-TargetPath -Prompt 'Pasta para organizar PDFs/XML em subpastas'
      Organize-FilesIntoFolders -Folder $folder
    }
    'OPEN_DOWNLOADS_DESKTOP' {
      $desktop = Join-Path $env:USERPROFILE 'Downloads\DESKTOP'
      if (-not (Test-Path -LiteralPath $desktop)) {
        New-Item -ItemType Directory -Path $desktop | Out-Null
      }
      Start-Process explorer.exe $desktop
      Write-Log "Pasta aberta: $desktop"
    }
    'RUN_FULL_AUTOMATION' {
      Invoke-AllAutomations
    }
    default {
      throw "Ação inválida: $Name"
    }
  }
}

function Show-Menu {
  while ($true) {
    Clear-Host
    Write-Host '====================================================='
    Write-Host '        SISTEMA UNIFICADO DE AUTOMAÇÃO (WINDOWS)'
    Write-Host '====================================================='
    Write-Host ''
    Write-Host ' 1) Processo Acertos (FATURAMENTO-PRO)'
    Write-Host ' 2) Executar Impressão (IMPRESSAO_PRO)'
    Write-Host ' 3) Mapear Rede'
    Write-Host ' 4) Iniciar Corporate'
    Write-Host ''
    Write-Host ' 5) Impressora PDFCreator'
    Write-Host ' 6) Impressora Física'
    Write-Host ' 7) Salvar PDF (Microsoft Print to PDF)'
    Write-Host ''
    Write-Host ' 8) PDFCreator AutoSave ON'
    Write-Host ' 9) PDFCreator AutoSave OFF'
    Write-Host ''
    Write-Host '10) Adicionar AC. nos PDFs'
    Write-Host '11) Remover AC. dos PDFs'
    Write-Host '12) Remover 2. dos PDFs'
    Write-Host '13) Organizar arquivos em pastas'
    Write-Host ''
    Write-Host '14) Abrir Downloads\DESKTOP'
    Write-Host '15) Rodar automação completa (rede + acertos + impressão)'
    Write-Host ' 0) Sair'
    Write-Host ''

    $op = Read-Host 'Escolha uma opção'
    $map = @{
      '1'  = 'PROCESSO_ACERTOS'
      '2'  = 'EXECUTAR_IMPRESSAO'
      '3'  = 'MAPEAR_REDE'
      '4'  = 'INICIAR_CORPORATE'
      '5'  = 'SET_PDFCREATOR'
      '6'  = 'SET_PHYSICAL_PRINTER'
      '7'  = 'SET_SAVE_PDF'
      '8'  = 'AUTOSAVE_ON'
      '9'  = 'AUTOSAVE_OFF'
      '10' = 'ADD_AC'
      '11' = 'REMOVE_AC'
      '12' = 'REMOVE_2'
      '13' = 'ORGANIZE_FILES'
      '14' = 'OPEN_DOWNLOADS_DESKTOP'
      '15' = 'RUN_FULL_AUTOMATION'
    }

    if ($op -eq '0') { break }

    if (-not $map.ContainsKey($op)) {
      Write-Host ''
      Write-Host 'Opção inválida.' -ForegroundColor Yellow
      Start-Sleep -Seconds 1
      continue
    }

    try {
      Invoke-Action -Name $map[$op]
      Write-Host ''
      Write-Host 'Concluído com sucesso.' -ForegroundColor Green
    }
    catch {
      Write-Log $_.Exception.Message 'ERROR'
      Write-Host ''
      Write-Host "Falha: $($_.Exception.Message)" -ForegroundColor Red
    }

    Write-Host ''
    Read-Host 'Pressione ENTER para continuar'
  }
}

Write-Log 'Sistema iniciado.'

if ($NoMenu) {
  if (-not $Action) {
    throw 'Use -Action quando utilizar -NoMenu.'
  }
  Invoke-Action -Name $Action
}
else {
  Show-Menu
}

Write-Log 'Sistema finalizado.'

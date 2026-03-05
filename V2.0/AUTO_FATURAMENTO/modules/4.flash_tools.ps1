if (-not ("System.Windows.Forms.SendKeys" -as [type])) {
    Add-Type -AssemblyName System.Windows.Forms
}

if (-not ("System.Windows.Automation.AutomationElement" -as [type])) {
    Add-Type -AssemblyName UIAutomationClient
}



function SleepMs([int]$ms) { Start-Sleep -Milliseconds $ms }

function Press-Key {
    param(
        [string]$Keys,
        [int]$DelayMs = 50
    )

    try {
        [System.Windows.Forms.SendKeys]::SendWait($Keys)
        Start-Sleep -Milliseconds $DelayMs
    }
    catch {
        Write-Host "[ERRO] Falha ao enviar tecla: $Keys" -ForegroundColor Red
        return $false
    }

    return $true
}

function Set-ClipText {
    param([string]$text)
    if ($null -eq $text) { $text = "" }
    Set-Clipboard -Value $text
}

function Ask-YesNo {
    param([string]$Prompt = "Iniciar este produtor? (S/N)")
    while ($true) {
        $ans = Read-Host $Prompt
        if ($null -eq $ans) { $ans = "" }
        $ans = $ans.Trim().ToUpperInvariant()
        if ($ans -eq "S") { return $true }
        if ($ans -eq "N") { return $false }
        Write-Host "Digite apenas S ou N." -ForegroundColor Yellow
    }
}

function Countdown-3s {
    Write-Host ""
    Write-Host "CLIQUE AGORA NA JANELA DO SISTEMA (ela precisa ficar em foco)..." -ForegroundColor Yellow
    Start-Sleep -Milliseconds 200
    for ($i = 3; $i -ge 1; $i--) {
       # [console]::beep(900,150)
        Write-Host ("Executando em {0}..." -f $i) -ForegroundColor Cyan
        Start-Sleep -Seconds 1
    }
    #[console]::beep(1200,200)
    Write-Host "ENVIANDO TECLAS..." -ForegroundColor Cyan
}

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



function Paste-Text {
    param(
        [string]$Text,
        [int]$TimeoutMs = 0  # 0 = esperar indefinidamente
    )

    if ($null -eq $Text) { $Text = "" }

    $elapsed = 0
    $interval = 100
    $waitingShown = $false

    while (-not (Test-IsEditableFocusedElement)) {

        if (-not $waitingShown) {
            Write-Host "[INFO] Aguardando foco em campo editavel..." -ForegroundColor Yellow
            $waitingShown = $true
        }

        Start-Sleep -Milliseconds $interval
        $elapsed += $interval

        if ($TimeoutMs -gt 0 -and $elapsed -ge $TimeoutMs) {
            Write-Host "[ERRO] Timeout aguardando campo editavel." -ForegroundColor Red
            return $false
        }
    }

    Write-Host "[OK] Campo detectado. Colando texto..." -ForegroundColor Green

    Set-ClipText $Text
    Start-Sleep -Milliseconds 150  
    Press-Key("^v")

    return $true
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
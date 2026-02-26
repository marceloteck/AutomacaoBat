# ==========================================
# _guard_focus.ps1
# Biblioteca reutilizável de verificação de foco
# ==========================================

# Evita recarregar se já foi importado
if (-not $Global:__GUARD_FOCUS_LOADED__) {

    try {
        Add-Type -AssemblyName UIAutomationClient -ErrorAction Stop
        Add-Type -AssemblyName UIAutomationTypes -ErrorAction Stop
    } catch {
        Write-Host "[AVISO] UIAutomation nao disponivel neste ambiente." -ForegroundColor Yellow
    }

    function Get-FocusedElementInfo {
        try {
            $el = [System.Windows.Automation.AutomationElement]::FocusedElement
            if ($null -eq $el) { return $null }

            $ct = $el.Current.ControlType
            $ctName = if ($ct) { $ct.ProgrammaticName } else { "" }

            return [pscustomobject]@{
                Name         = $el.Current.Name
                ControlType  = $ctName
                ClassName    = $el.Current.ClassName
                AutomationId = $el.Current.AutomationId
                ProcessId    = $el.Current.ProcessId
            }
        } catch {
            return $null
        }
    }

    function Pause-IfNotTextInput {
        param(
            [string]$Message = "FOCO NAO ESTA EM CAMPO DE TEXTO. Corrija o foco no ERP e pressione ENTER para continuar.",
            [int]$BeepCount = 2
        )

        $info = Get-FocusedElementInfo

        if ($null -eq $info) {
            for($i=0;$i -lt $BeepCount;$i++){ [console]::Beep(900,180) }
            Write-Host "[PAUSA] Nao consegui ler o foco do Windows." -ForegroundColor Yellow
            [void](Read-Host $Message)
            return
        }

        $ok = ($info.ControlType -match 'ControlType\.Edit') -or
              ($info.ControlType -match 'ControlType\.Document')

        if (-not $ok) {
            for($i=0;$i -lt $BeepCount;$i++){ [console]::Beep(900,180) }
            Write-Host "[PAUSA] Foco NAO esta em campo de texto." -ForegroundColor Red
            Write-Host ("        ControlType: {0} | Class: {1}" -f $info.ControlType, $info.ClassName) -ForegroundColor DarkGray
            [void](Read-Host $Message)
        }
    }

    $Global:__GUARD_FOCUS_LOADED__ = $true
}
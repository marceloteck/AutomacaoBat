# ================================
# GUARD: verifica foco em campo de texto
# ================================
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

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
        Write-Host "[PAUSA] Nao consegui ler o foco do Windows (UIAutomation)." -ForegroundColor Yellow
        [void](Read-Host $Message)
        return
    }

    # Considera "input de texto" se o foco for:
    # - ControlType.Edit (campo de texto)
    # - ControlType.Document (alguns ERPs usam isso)
    $ok = ($info.ControlType -match 'ControlType\.Edit') -or ($info.ControlType -match 'ControlType\.Document')

    if (-not $ok) {
        for($i=0;$i -lt $BeepCount;$i++){ [console]::Beep(900,180) }
        Write-Host "[PAUSA] Foco atual NAO parece ser campo de texto." -ForegroundColor Red
        Write-Host ("        ControlType: {0} | Class: {1} | Name: {2}" -f $info.ControlType, $info.ClassName, $info.Name) -ForegroundColor DarkGray
        [void](Read-Host $Message)
    }
}





Como usar no seu fluxo (exemplo prático)

Antes de colar pedido / nota / data:


#============================================================

Invoke-ClickPos -Name "CLICAR_INPUT_DATA1"
SleepMs 80

Pause-IfNotTextInput  # <--- GARANTE que tá em input
Press-Key("^a")
Type-CurrentDateBR

#============================================================



Ou antes de colar uma NF:



#============================================================
Pause-IfNotTextInput
Paste-Text $nf
Press-Key("{ENTER}")
#============================================================



“Observando o funcionamento do BAT” (jeito correto)

Em vez de “o BAT observar”, o melhor padrão é:

O BAT chama o PowerShell

E o PowerShell faz as validações (como acima) antes de cada ação crítica (colar/digitar).

Isso te dá pausa imediata no ponto certo, sem depender de “erro do Windows”.
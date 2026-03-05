function Update-ProducerLevel {
    param(
        [int]$NewLevel
    )

    $produtor = $Global:AutomationState.CurrentProducer

    if ($NewLevel -le $produtor.NIVEL) {
        return
    }

    $produtor.NIVEL = $NewLevel
    $Global:AutomationState.CurrentLevel = $NewLevel

    Write-Host "[LEVEL] Atualizado para nível $NewLevel" -ForegroundColor Cyan

    if (Get-Command Save-AutomacaoMaster -ErrorAction SilentlyContinue) {
        Save-AutomacaoMaster -Path $Global:AutomationState.InputFile
    }


} 

function Check-UserPause {
    if (Test-EscPressed) {

        $choice = Show-PauseMenu

        switch ($choice) {
            "CONTINUE"     { return "CONTINUE" }
            "RETRY_STEP"   { return "RETRY_STEP" }
            "RESTART_ALL"  { return "RESTART_ALL" }
            "STOP_ALL"     { throw "Execução interrompida pelo usuário." }
        }
    }

    return "NONE"
}

<# 
Se quiser que ESC funcione também DURANTE sleeps longos, troque:
Start-Sleep -Seconds X

Por:

for ($s=0; $s -lt X*10; $s++) {
    Start-Sleep -Milliseconds 100
    if (Test-EscPressed) {
        Show-PauseMenu
    }
}
#>
; =========================================
; start_automacao.ahk
; Ctrl+F6 = Start da automacao SAA
; =========================================

#NoEnv
#SingleInstance Force
SendMode Input
SetWorkingDir, %A_ScriptDir%
SetTitleMatchMode, 2

global isRunning := false

^F6::

    ; Evita dupla execucao
    if (isRunning) {
        SoundBeep, 600, 120
        return
    }
    isRunning := true

    ; Envia Ctrl+F6 pro ERP (abre o filtro)
    Send, ^{F6}
    Sleep, 200

    ; Caminhos
    root := A_ScriptDir . "\.."
    ps1  := root . "\scripts\saa_instrucoes.ps1"
    inp  := root . "\input\instrucoes.txt"

    if (!FileExist(ps1)) {
        MsgBox, 16, ERRO, Nao achei:`n%ps1%
        isRunning := false
        return
    }

    if (!FileExist(inp)) {
        MsgBox, 16, ERRO, Nao achei:`n%inp%
        isRunning := false
        return
    }

    ; Executa PowerShell e espera terminar
    cmd := "powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ . ps1 . """ -InputFile """ . inp . """"

    RunWait, % cmd, , Hide UseErrorLevel

    if (ErrorLevel) {
        SoundBeep, 400, 200
        MsgBox, 48, Aviso, Automacao terminou com erro.
    } else {
        SoundBeep, 900, 120
    }

    isRunning := false
return


; ESC destrava manualmente se travar
Esc::
    isRunning := false
    SoundBeep, 700, 120
return
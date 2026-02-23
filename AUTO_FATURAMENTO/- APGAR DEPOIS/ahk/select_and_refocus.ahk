#NoEnv
#SingleInstance Force
SendMode Input
SetTitleMatchMode, 2

; ===== AJUSTES FINOS (pixels) =====
; Clique no 1º item (abaixo do cursor piscando no input)
offsetSelectX := 20
offsetSelectY := 55

; Clique de volta no input (perto do cursor)
offsetInputX := 5
offsetInputY := 5

; Aguarda a lista aparecer (0,4s)
waitListMs := 400

; ================================
CoordMode, Caret, Screen
CoordMode, Mouse, Screen

; Pega posição do cursor piscando (caret) no input
x := A_CaretX
y := A_CaretY

if (x = "" or y = "" or (x = 0 and y = 0)) {
  SoundBeep, 700, 120
  ExitApp
}

; Guarda mouse atual (opcional)
MouseGetPos, ox, oy

; Espera a lista aparecer
Sleep, %waitListMs%

; 1) Clica no primeiro item (abaixo do input)
Click, % (x + offsetSelectX), % (y + offsetSelectY)
Sleep, 80

; 2) Clica de volta no input pra voltar o cursor piscando
Click, % (x + offsetInputX), % (y + offsetInputY)
Sleep, 50

; Volta mouse onde estava (opcional)
MouseMove, %ox%, %oy%, 0

ExitApp
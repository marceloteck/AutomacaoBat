#NoEnv
#SingleInstance Force
SendMode Input
SetTitleMatchMode, 2

; Ajuste fino aqui (distância do clique abaixo do cursor)
offsetX := 20
offsetY := 55

; Hotkey manual de teste (você pode apertar quando quiser)
^!c::
  MouseGetPos, ox, oy
  CoordMode, Caret, Screen
  CoordMode, Mouse, Screen

  x := A_CaretX
  y := A_CaretY

  ; Se não conseguir ler caret (alguns ERPs), aborta com beep
  if (x = "" or y = "" or x = 0 and y = 0) {
    SoundBeep, 800, 150
    return
  }

  Click, % (x + offsetX), % (y + offsetY)
  Sleep, 50
  MouseMove, %ox%, %oy%, 0
return
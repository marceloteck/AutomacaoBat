@echo off
setlocal

REM ==========================================
REM CONFIGURE AQUI
REM ==========================================

set "BAT_PATH=C:\Users\Nanosistecck\Documents\BAT\CENTRAL.bat"
set "ATALHO_NOME=AUTO_FATURAMENTO"

REM ==========================================
REM NAO ALTERAR ABAIXO
REM ==========================================

set "MENU_PATH=%APPDATA%\Microsoft\Windows\Start Menu\Programs"
set "SHORTCUT_PATH=%MENU_PATH%\%ATALHO_NOME%.lnk"

echo.
echo Criando atalho em:
echo %SHORTCUT_PATH%
echo.

powershell -NoProfile -Command ^
"$WshShell = New-Object -ComObject WScript.Shell; ^
$Shortcut = $WshShell.CreateShortcut('%SHORTCUT_PATH%'); ^
$Shortcut.TargetPath = 'cmd.exe'; ^
$Shortcut.Arguments = '/c ""%BAT_PATH%""'; ^
$Shortcut.WorkingDirectory = '%~dp0'; ^
$Shortcut.WindowStyle = 1; ^
$Shortcut.IconLocation = 'C:\Windows\System32\shell32.dll,1'; ^
$Shortcut.Save()"

echo.
echo ==========================================
echo ATALHO CRIADO COM SUCESSO
echo ==========================================
echo.
echo Agora:
echo 1 - Abra o MENU INICIAR
echo 2 - Procure por %ATALHO_NOME%
echo 3 - Clique com o botao direito
echo 4 - Fixar na barra de tarefas
echo.
pause
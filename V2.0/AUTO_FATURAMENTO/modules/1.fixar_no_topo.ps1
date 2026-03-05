
# === FIXAR CONSOLE NO TOPO (mais confiavel) ===
if (-not ("WinTop" -as [type])) {
Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class WinTop {
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();

    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool SetWindowPos(
        IntPtr hWnd,
        IntPtr hWndInsertAfter,
        int X, int Y, int cx, int cy,
        uint uFlags
    );
}
"@
}

$HWND_TOPMOST   = [IntPtr](-1)
$SWP_NOMOVE     = 0x0002


$SWP_NOSIZE     = 0x0001
$SWP_SHOWWINDOW = 0x0040

# espera o console existir
$hWnd = [IntPtr]::Zero
for ($i=0; $i -lt 25 -and $hWnd -eq [IntPtr]::Zero; $i++) {
    Start-Sleep -Milliseconds 200
    $hWnd = [WinTop]::GetConsoleWindow()
}

if ($hWnd -ne [IntPtr]::Zero) {
    [void][WinTop]::SetWindowPos($hWnd, $HWND_TOPMOST, 0,0,0,0, $SWP_NOMOVE -bor $SWP_NOSIZE -bor $SWP_SHOWWINDOW)
} else {
    Write-Host "[AVISO] Nao consegui pegar a janela do console para fixar no topo."
}


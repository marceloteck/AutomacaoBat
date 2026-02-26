# === FIXAR CONSOLE NO TOPO (mais confiavel) ===
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



# ===============================
# CHAMADA click_positions.ps1
# ===============================
$lib = Join-Path $PSScriptRoot "click_positions.ps1"
if (Test-Path -LiteralPath $lib) {
    . $lib
} else {
    Write-Host "[ERRO] Nao achei click_positions.ps1 em: $lib" -ForegroundColor Red
    exit 2
}



Add-Type -AssemblyName System.Windows.Forms

function Send-Key {
    param([string]$keys)
    [System.Windows.Forms.SendKeys]::SendWait($keys)
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
        [console]::beep(900,150)
        Write-Host ("Executando em {0}..." -f $i) -ForegroundColor Cyan
        Start-Sleep -Seconds 1
    }
    [console]::beep(1200,200)
    Write-Host "ENVIANDO TECLAS..." -ForegroundColor Cyan
}

function Parse-NotasIni {
    param([string]$path)

    if (!(Test-Path -LiteralPath $path)) { throw "Nao achei o arquivo: $path" }

    $lines = Get-Content -LiteralPath $path

    $items = New-Object System.Collections.Generic.List[object]
    $cur = $null
    $inProducer = $false

    foreach ($raw in $lines) {
        if ($null -eq $raw) { $raw = "" }
        $line = $raw.Trim()
        if ($line -eq "") { continue }

        if ($line -match '^\[(.+)\]$') {
            $section = $matches[1].Trim().ToUpperInvariant()

            if ($cur -ne $null -and -not [string]::IsNullOrWhiteSpace($cur.PEDIDO)) {
                $items.Add([pscustomobject]$cur)
            }

            $cur = @{
                SECAO     = $section
                NOME      = ""
                STATUS    = ""
                TIPO      = ""
                INSTRUCAO = ""
                PEDIDO    = ""
                NOTAS     = ""
            }

            $inProducer = ($section -eq "PRODUTOR")
            continue
        }

        if (-not $inProducer -or $cur -eq $null) { continue }

        if ($line -match '^NOTAS\s*:\s*(.*)$') {
            $cur.NOTAS = $matches[1].Trim()
            continue
        }

        if ($line -match '^([A-Za-zÇçÃãÕõÉéÍíÓóÚú_]+)\s*=\s*(.*)$') {
            $k = $matches[1].Trim().ToUpperInvariant()
            $v = $matches[2].Trim()
            switch ($k) {
                "NOME"      { $cur.NOME = $v; break }
                "STATUS"    { $cur.STATUS = $v; break }
                "TIPO"      { $cur.TIPO = $v; break }
                "INSTRUCAO" { $cur.INSTRUCAO = $v; break }
                "INSTRUÇÃO" { $cur.INSTRUCAO = $v; break }
                "PEDIDO"    { $cur.PEDIDO = $v; break }
                default     { break }
            }
        }
    }

    if ($cur -ne $null -and -not [string]::IsNullOrWhiteSpace($cur.PEDIDO)) {
        $items.Add([pscustomobject]$cur)
    }

    return $items
}

# ---- MAIN ----
$ScriptDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ScriptDir)) { $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$BaseDir = Split-Path -Parent $ScriptDir
$NotasPath = Join-Path $BaseDir "input\pec\notas_PEDIDOS.txt"

try { $lista = Parse-NotasIni $NotasPath }
catch { Write-Host ("ERRO: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }

if ($lista.Count -eq 0) {
    Write-Host "Nada para executar (nenhum [PRODUTOR] com PEDIDO encontrado)." -ForegroundColor Yellow
    exit 0
}

Add-Type -AssemblyName UIAutomationClient

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



function Paste-Text([string]$text) {

    # Espera até o foco estar em campo editável (máx 5s)
    $timeout = 5000
    $elapsed = 0

    while (-not (Test-IsEditableFocusedElement)) {
        Start-Sleep -Milliseconds 100
        $elapsed += 100
        if ($elapsed -ge $timeout) {
            Write-Host "[ERRO] Campo de texto não detectado." -ForegroundColor Red
            return
        }
    }

    Set-Clipboard -Value $text
    Press-Key("^v")
}

function Press-Key([string]$k) { [System.Windows.Forms.SendKeys]::SendWait($k) }
function SleepMs([int]$ms) { Start-Sleep -Milliseconds $ms }

# ==============================
# Verifica se o foco é editável
# ==============================



Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " AUTOMACAO: F3 -> PEDIDO -> ENTER -> F11" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Obs: O NOME fica no clipboard para voce Ctrl+V manualmente." -ForegroundColor Cyan
Write-Host ""

# ================================
# PEDIR DIRETORIO (ANTES DO LOOP)
# ================================

<#
$saveDir = ""
while ([string]::IsNullOrWhiteSpace($saveDir)) {
    $saveDir = Read-Host "Informe o DIRETORIO para salvar/imprimir (ex: C:\Pedidos\2026\02)"
    if ([string]::IsNullOrWhiteSpace($saveDir)) {
        Write-Host "Diretorio vazio. Tente novamente." -ForegroundColor Yellow
        continue
    }
    $saveDir = $saveDir.Trim().Trim('"')
}


# Se quiser validar que existe (opcional). Se não existir, cria.
if (-not (Test-Path -LiteralPath $saveDir)) {
    try {
        New-Item -ItemType Directory -Path $saveDir -Force | Out-Null
        Write-Host "[OK] Diretorio criado: $saveDir" -ForegroundColor Green
    } catch {
        Write-Host "[ERRO] Nao consegui criar/usar o diretorio: $saveDir" -ForegroundColor Red
        exit 2
    }
}

#>
$dirPastedOnce = $false



# ================================
# LOOP PRINCIPAL
# ================================
foreach ($p in $lista) {
    $nome   = $p.NOME
    $pedido = $p.PEDIDO
    $instrucao = $p.INSTRUCAO
    

    if($p.status -eq "CONFIRMADO"){
        Write-Host ("[SKIP] PRODUTOR {0}/{1}: {2} ja esta CONFIRMADO - pulando." -f $pIndex, $producers.Count, $p.nome)
        continue
    }



    # Invoke-DoubleClickPos -Name "NOME_DO_CLICK"
    # Invoke-ClickPos -Name "CLICAR_IMPRIMIR_PEDIDO"
    # Set-ClipText $saveDir
    # Paste-Text $pedido
    # Invoke-RightClickPos -Name "MENU_OPCOES"

    Write-Host ""
    Write-Host ("PRODUTOR: {0}" -f $nome) -ForegroundColor Green
    Write-Host ("PEDIDO:   {0}" -f $pedido) -ForegroundColor Green

    if (-not (Ask-YesNo "Iniciar este produtor? (S/N)")) {
        Write-Host "PULADO." -ForegroundColor Yellow
        continue
    }

$cargas = 0
while ($true) {
  $in = (Read-Host "Quantas cargas tem esse pedido? (1 ou 2)").Trim()
  if ($in -match '^[12]$') { $cargas = [int]$in; break }
  Write-Host "Digite somente 1 ou 2." -ForegroundColor Yellow
}



# ==========================================
# SCRIPT GERADO: SALVAR_ACER
# ==========================================
# Requer no seu projeto:
# - click_positions.ps1 (Invoke-ClickPos / Invoke-DoubleClickPos / Invoke-RightClickPos)
# - funcoes Press-Key / Paste-Text / SleepMs


# TELA EMITIR NFE
Invoke-ClickPos -Name "ABRIR_TELA_AC_NFE_ERP"
SleepMs 1200

Invoke-DoubleClickPos -Name "SALVAR_ACER_LEFT_001_136_233" # INPUT NFE INSTRUÇÃO
SleepMs 1200
 Press-Key("^a")
SleepMs 1200
   Paste-Text $instrucao
SleepMs 1200  
Press-Key("{TAB}")
SleepMs 1200
Press-Key("{F3}")


# TELA DOCUMENTO SIMPLIFICADO
SleepMs 1200
Invoke-ClickPos -Name "ABRIR_TELA_AC_DOCUMENTO_SIMPLIFICADO_ERP"
SleepMs 1200
Press-Key("{F7}")
SleepMs 1200
Press-Key("^a")
SleepMs 1200
Paste-Text $instrucao
SleepMs 1200
Press-Key("{ENTER}")
SleepMs 1200

SleepMs 1200
Invoke-ClickPos -Name "SALVAR_ACER_LEFT_004_757_420" # CLIQUE ORGANIZAR LISTA
SleepMs 1200
Invoke-DoubleClickPos -Name "SALVAR_ACER_LEFT_005_770_452" # CLICAR NO DOCUMENTO TIPO 16
SleepMs 1200
Invoke-DoubleClickPos -Name "clicar_imput_n2_doc_simplificado" # CLICAR NO IMPUT CODIGO 2
SleepMs 1200
Press-Key("^a")
SleepMs 1200
Paste-Text "2"
SleepMs 900  
Press-Key("{TAB}")
SleepMs 900
Press-Key("{F4}")

SleepMs 800
Press-Key("{F3}")
SleepMs 800
Press-Key("{ENTER}")


# VOLTOU PRA TELA NFE
SleepMs 1200
Invoke-ClickPos -Name "SALVAR_ACER_LEFT_007_701_74" # ABRIR TELA NFE
SleepMs 1200
Invoke-ClickPos -Name "clicar_selecionar_form_nfe" # 
SleepMs 1200
Invoke-RightClickPos -Name "SALVAR_ACER_RIGHT_009_228_396" # BOTÃO DIREITO
SleepMs 1200
Invoke-ClickPos -Name "SALVAR_ACER_LEFT_010_254_407" #COPIAR CÓDIGO

SleepMs 1200
Invoke-ClickPos -Name "SALVAR_ACER_LEFT_011_976_76" # ABRIR DOCUMENTO SIMPLIFICADO
SleepMs 1200
Invoke-ClickPos -Name "SALVAR_ACER_LEFT_012_519_229" # CLICAR NO IMPUT DO FORMULARIO
SleepMs 1200
Press-Key("^a")
SleepMs 1200
Press-Key("^v") # COLADO: 3486
SleepMs 1200
Press-Key("{TAB}")

SleepMs 1200
Press-Key("{F4}")
SleepMs 1200
Press-Key("{F3}")
SleepMs 1200
Press-Key("{ENTER}")

pause
<#
#>
# =========================
# PERGUNTAR QUANTAS CARGAS
# =========================


# ROMANEIO DE ABATE
SleepMs 1200
Invoke-ClickPos -Name "SALVAR_ACER_LEFT_013_337_313"
SleepMs 1200

Invoke-ClickPos -Name "SALVAR_ACER_LEFT_014_1257_59"
SleepMs 1200
Invoke-ClickPos -Name "SALVAR_ACER_LEFT_015_192_205"
SleepMs 1200
Invoke-DoubleClickPos -Name "SALVAR_ACER_LEFT_015_192_205"
SleepMs 1200
Press-Key("^a")
SleepMs 1200
Paste-Text $pedido
SleepMs 1200
Press-Key("{TAB}")
SleepMs 1200
Invoke-ClickPos -Name "CLICAR_ABA_MUDAR_CARGA"
SleepMs 1200
Invoke-ClickPos -Name "CLICAR_INPUT_MUDAR_CARGA"
SleepMs 1200
Press-Key("^a")
SleepMs 1200
Paste-Text "1"

SleepMs 1200
Press-Key("{F3}")


# =========================
# SE TIVER 2 CARGAS, ABRIR A CARGA 2 TAMBÉM
# =========================
if ($cargas -eq 2) {
  Invoke-ClickPos -Name "CLICAR_ABA_MUDAR_CARGA"
  SleepMs 1200
  Invoke-ClickPos -Name "CLICAR_INPUT_MUDAR_CARGA"
  SleepMs 1200
  Press-Key("^a")
  SleepMs 1200
  Paste-Text "2"
  SleepMs 1200
  Press-Key("{F3}")
  SleepMs 2000
}


Set-ClipText $nome

# =========================
# NO FINAL: IMPRIMIR
# - se 1 carga: imprime só a primeira
# - se 2 cargas: imprime primeira e segunda
# =========================

<#
Invoke-ClickPos -Name "CLICAR_ABA_MUDAR_CARGA_ABA_PRIMEIRA_CARGA"
SleepMs 200
Invoke-ClickPos -Name "CLICAR_ABA_IMPRIMIR_PRIMEIRA_CARGA"
SleepMs 200

if ($cargas -eq 2) {
  Invoke-ClickPos -Name "CLICAR_ABA_MUDAR_CARGA_ABA_SEGUNDA_CARGA"
  SleepMs 200
  Invoke-ClickPos -Name "CLICAR_ABA_IMPRIMIR_SEGUNDA_CARGA"
  SleepMs 200

  Invoke-ClickPos -Name "CLICAR_ABA_IFECHAR_ABAS"
}

SleepMs 600
Invoke-ClickPos -Name "CLICAR_ABA_IFECHAR_ABAS"





# DOC. SIMPLIFICADO
SleepMs 1000
Invoke-ClickPos -Name "SALVAR_ACER_LEFT_016_1009_68"
SleepMs 200
Press-Key("{F9}")
SleepMs 400
Invoke-ClickPos -Name "SALVAR_ACER_LEFT_017_43_34"
SleepMs 400
Invoke-ClickPos -Name "SALVAR_ACER_LEFT_018_900_637"
SleepMs 400
Invoke-ClickPos -Name "SALVAR_ACER_LEFT_019_404_32"
SleepMs 400
Invoke-ClickPos -Name "SALVAR_ACER_LEFT_020_1226_58"
SleepMs 400
Invoke-ClickPos -Name "SALVAR_ACER_LEFT_021_234_154"
SleepMs 400
Invoke-ClickPos -Name "SALVAR_ACER_LEFT_022_700_65"
SleepMs 400
Invoke-ClickPos -Name "SALVAR_ACER_LEFT_023_453_439"
SleepMs 400
Press-Key("{RIGHT}")
SleepMs 400
Press-Key("{ENTER}")
SleepMs 400
Invoke-ClickPos -Name "SALVAR_ACER_LEFT_024_993_875"
SleepMs 400
Invoke-ClickPos -Name "SALVAR_ACER_LEFT_025_787_736"
SleepMs 400
Invoke-ClickPos -Name "SALVAR_ACER_LEFT_026_799_765"
SleepMs 400
Invoke-ClickPos -Name "SALVAR_ACER_LEFT_027_711_242"
SleepMs 400
   Paste-Text $nome
SleepMs 400
Invoke-ClickPos -Name "SALVAR_ACER_LEFT_028_815_312"
SleepMs 400

pause

Invoke-ClickPos -Name "SALVAR_ACER_LEFT_029_948_719"
SleepMs 400
Invoke-ClickPos -Name "SALVAR_ACER_LEFT_029_948_719"


#>















































  <#
     Invoke-ClickPos -Name "ABRIR_TELA_AC_NFE_ERP"
    SleepMs 900
    Invoke-ClickPos -Name "CLICAR_INPUT_COLAR_INSTRUCAO_AC_NFE"


    Press-Key("^A")
    SleepMs 100
    Paste-Text $instrucao
    SleepMs 400
    Press-Key("{F3}")


    SleepMs 900
    Invoke-ClickPos -Name "ABRIR_TELA_AC_DOCUMENTO_SIMPLIFICADO_ERP"
    SleepMs 900
    Press-Key("{F7}")
    SleepMs 900

    Invoke-ClickPos -Name "CLICAR_AC_INPUT_DOC_SIMPL_COLAR_INSTRUCAO"
    SleepMs 900
    Press-Key("^A")
    SleepMs 400
    Paste-Text $instrucao
    SleepMs 400
    Press-Key("{ENTER}")

    Invoke-ClickPos -Name "CLICAR_AC_FILTRO_SIMPLIF_DOC_SEQ"
    SleepMs 400
    Invoke-DoubleClickPos -Name "CLICAR_DOC_N16_ABRIR"
    SleepMs 900

    Invoke-ClickPos -Name "CLICAR_AC_ABRIR_ROMANEIO"
    SleepMs 400

    Invoke-ClickPos -Name "CLICAR_AC_ABA_ROMANEIO_PEDIDO"
    SleepMs 400
    Invoke-ClickPos -Name "CLICAR_AC_IMPUT_ROMANEIO_PEDIDO"
    SleepMs 400
    Press-Key("^a")
    SleepMs 900
    Paste-Text $pedido
    SleepMs 400
    Press-Key("{TAB}")

    SleepMs 900

    Press-Key("{F3}")

    SleepMs 2000

    Invoke-ClickPos -Name "ABRIR_TELA_AC_NFE_ERP"

    SleepMs 2000

    Invoke-RightClickPos -Name "SELECIONAR_FORM_NFE"

    SleepMs 1000

    Invoke-ClickPos -Name "CLICAR_COPIARFORM_NFE"

    SleepMs 900
    Invoke-ClickPos -Name "ABRIR_TELA_AC_DOCUMENTO_SIMPLIFICADO_ERP"

    SleepMs 1000

    Invoke-ClickPos -Name "CLICAR_iMPUT_DOC_SIMPL_COD2"

    Paste-Text "2"
SleepMs 900
    Press-Key("{TAB}")
SleepMs 900
    Press-Key("^v")
SleepMs 2000
    Press-Key("{F4}")
SleepMs 2000

Press-Key("{F9}")

SleepMs 2000
Invoke-ClickPos -Name "CLICAR_IMPRESSORA_ACC"

SleepMs 900
Invoke-ClickPos -Name "CLICAR_IMPRESSORA_ACC_OOK"
SleepMs 2000
Invoke-ClickPos -Name "CLICAR_fechar_telaIMPRESSORA_ACC_OOK"
SleepMs 2000

    Invoke-ClickPos -Name "CLICAR_AC_ABRIR_ROMANEIO"

SleepMs 2000
    Invoke-ClickPos -Name "CLICAR_AC_ABRIR_ROMANEIO_IMPRIMIR_DOC"
SleepMs 2000
     Invoke-ClickPos -Name "ABRIR_TELA_AC_NFE_ERP"
        
SleepMs 2000

Press-Key("^9")
SleepMs 1000
Press-Key("{TAB}")
SleepMs 1000
Press-Key("{ENTER}")
SleepMs 1000

     Invoke-ClickPos -Name "CLICAR_NAVEGADOR_MOSTRAR_TELA"

Set-Clipboard -Value $nome

pause

SleepMs 1000
Invoke-ClickPos -Name "clicar em salvar acerto"
SleepMs 1000
Press-Key("{ENTER}")


  #####################################################

    

    # ================================
    # ABRIR/EXECUTAR TELA NFE
    # ================================
    Invoke-ClickPos -Name "ABRIR_TELA_AC_NFE_ERP"
    SleepMs 250

    Invoke-DoubleClickPos -Name "ATUALIZAR_DATA02_AC_NFE"
    SleepMs 350
    Invoke-DoubleClickPos -Name "ATUALIZAR_DATA01_AC_NFE"
    SleepMs 200


    Invoke-ClickPos -Name "CLICAR_FILTRO_STATUS_AC_NFE"
    SleepMs 350
    Invoke-ClickPos -Name "CLICAR_FILTRO_ESCOLHER_ARPOVADO_AC_NFE"

    SleepMs 350
    Invoke-ClickPos -Name "CLICAR_INPUT_COLAR_INSTRUCAO_AC_NFE"
    SleepMs 200

    Press-Key("^A")
    Paste-Text $instrucao

    Press-Key("{F3}")

    SleepMs 1000

    Invoke-ClickPos -Name "ABRIR_TELA_AC_DOCUMENTO_SIMPLIFICADO_ERP"
    SleepMs 200
    Press-Key("{F7}")
    SleepMs 200

    Invoke-ClickPos -Name "CLICAR_AC_INPUT_DOC_SIMPL_COLAR_INSTRUCAO"
    SleepMs 200
    Press-Key("^A")
    Paste-Text $instrucao

    Press-Key("{ENTER}")

    Invoke-ClickPos -Name "CLICAR_AC_FILTRO_SIMPLIF_DOC_SEQ"
    SleepMs 250
    Invoke-DoubleClickPos -Name "CLICAR_DOC_N16_ABRIR"
    SleepMs 250
    Invoke-ClickPos -Name "ABRIR_TELA_AC_NFE_ERP"

    SleepMs 250
    Invoke-DoubleClickPos -Name "COPIAR_N_FORMULARIO"
    SleepMs 250
    Invoke-DoubleClickPos -Name "CLICAR_DOC_N16_ABRIR"
    SleepMs 250
    Press-Key("^C")
    SleepMs 800
    Invoke-ClickPos -Name "ABRIR_TELA_AC_DOCUMENTO_SIMPLIFICADO_ERP"

    SleepMs 250
    Invoke-ClickPos -Name "ABRIR_TELA_AC_DOCUMENTO_SIMPLIFICADO_ERP"
    




    # ========================================================
    # ABRIR/EXECUTAR TELA DOCUMENTO SIMPLIFICADO ANTIGO
    # ========================================================
    Invoke-ClickPos -Name "ABRIR_TELA_AC_DOCUMENTO_SIMPLIFICADO_ERP"




    Invoke-ClickPos -Name "ABRIR_TELA_AC_NFE_ERP"

    Press-Key("^9")
    SleepMs 200
    Press-Key("{RIGHT}")
    SleepMs 200
    Press-Key("{ENTER}")


    
    # ============================================
    # ABRIR/EXECUTAR TELA ROMANEIO DE ABATE
    # ============================================
    Invoke-ClickPos -Name "ABRIR_TELA_AC_ROMANEIO_ERP"

  


    # ========================================================
    # COPIAR NOME DO PECUARISTA NA AREA DE TRANSFERENCIA
    # ========================================================    



#>



    [void](Read-Host "Quando terminar, pressione Enter para o proximo")
}
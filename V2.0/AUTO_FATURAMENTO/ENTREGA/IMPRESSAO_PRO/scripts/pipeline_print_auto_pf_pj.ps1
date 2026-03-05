param(
  [Parameter(Mandatory = $true)][string]$Root,
  [Parameter(Mandatory = $true)][string]$BaseDir
)

# Normaliza caminhos (remove aspas e barra final)
$Root    = $Root.Trim().Trim('"')
$BaseDir = $BaseDir.Trim().Trim('"')
if ($Root.EndsWith('\'))    { $Root    = $Root.TrimEnd('\') }
if ($BaseDir.EndsWith('\')) { $BaseDir = $BaseDir.TrimEnd('\') }




$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ============================================================
# CONFIG
# ============================================================
$BinDir  = [IO.Path]::Combine($BaseDir, "bin")
$qpdf    = [IO.Path]::Combine($BinDir, "qpdf.exe")
$sumatra = [IO.Path]::Combine($BinDir, "SumatraPDF.exe")

if (!(Test-Path -LiteralPath $Root))  { throw "Pasta raiz nao encontrada: $Root" }
if (!(Test-Path -LiteralPath $qpdf))  { throw "qpdf.exe nao encontrado em: $qpdf" }
if (!(Test-Path -LiteralPath $sumatra)) { throw "SumatraPDF.exe nao encontrado em: $sumatra" }

$PedidosDir   = Join-Path $Root "- PEDIDOS"
$RomaneiosDir = Join-Path $Root "- ROMANEIOS"
$PrintDir     = Join-Path $Root "- PRINT"

if (!(Test-Path -LiteralPath $PrintDir)) {
  New-Item -ItemType Directory -Path $PrintDir | Out-Null
}

# Duplex mode do Sumatra (se precisar mudar: duplexshort / duplexlong)
$DuplexSetting = "duplex"

# Tempo entre envios (ajuda spooler)
$SleepMsBetweenPrints = 1200


# ============================================================
# FUNÇÕES - NORMALIZAÇÃO / SANITIZAÇÃO / REGEX
# ============================================================
function Remove-Diacritics([string]$s) {
  if ([string]::IsNullOrWhiteSpace($s)) { return "" }
  $norm = $s.Normalize([Text.NormalizationForm]::FormD)
  $sb = New-Object System.Text.StringBuilder
  foreach ($ch in $norm.ToCharArray()) {
    $cat = [Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch)
    if ($cat -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
      [void]$sb.Append($ch)
    }
  }
  return $sb.ToString().Normalize([Text.NormalizationForm]::FormC)
}

function Normalize-Key([string]$s) {
  $s = Remove-Diacritics $s
  $s = $s.ToLowerInvariant()
  $s = $s -replace '[^a-z0-9 ]', ' '   # remove pontuação
  $s = $s -replace '\s+', ' '
  return $s.Trim()
}


function Is-PessoaJuridicaName([string]$rawName) {
  if ([string]::IsNullOrWhiteSpace($rawName)) { return $false }

  # normaliza (sem acento, minúsculo, sem pontuação)
  $k = Normalize-Key $rawName

  # Regras (PJ):
  # 1) contém "agropecuaria"
  if ($k -match '\bagropecuaria\b') { return $true }

  # 2) contém "ltda"
  if ($k -match '\bltda\b') { return $true }

  # 3) começa com "agro" (ex: "AGRO XXXXXX")
  if ($k -match '^agro\b') { return $true }

  # 4) tem "agro" e termina com "sa" ou "s a" (ex: "... AGRO SA", "... AGRO S/A")
  # (Normalize-Key remove "/" e pontuação, então "S/A" vira "s a")
  if (($k -match '\bagro\b') -and ($k -match '\bsa$|\bs a$')) { return $true }

  return $false
}

function Sanitize-PathPart([string]$name) {
  if ([string]::IsNullOrWhiteSpace($name)) { return "SEM_NOME" }
  $invalid = [IO.Path]::GetInvalidFileNameChars() + [IO.Path]::GetInvalidPathChars()
  $out = $name
  foreach ($c in ($invalid | Select-Object -Unique)) {
    $out = $out.Replace($c, ' ')
  }
  $out = $out -replace '\s+', ' '
  $out = $out.Trim()
  if ($out.Length -gt 120) { $out = $out.Substring(0,120).Trim() }
  if ([string]::IsNullOrWhiteSpace($out)) { return "SEM_NOME" }
  return $out
}

function Normalize-Number([string]$n) {
  if ([string]::IsNullOrWhiteSpace($n)) { return "" }
  $n = ($n.Trim() -replace '\D','')   # só dígitos
  # remove zeros à esquerda
  $n2 = $n.TrimStart('0')
  if ($n2 -eq "") { $n2 = "0" }
  return $n2
}

function Extract-NameNumber-AC([string]$fileName) {
  # Aceita:
  # AC.NOME 17(BTG).pdf
  # AC.NOME 17 - BTG.pdf
  # AC.NOME 00017 (BTG).pdf
  # AC.NOME DO PRODUTOR 46577 (30D).pdf
  #
  # Regras:
  # - "AC." no início
  # - Nome vem até o número
  # - Número: 2+ dígitos (aceita zeros)
  # - Depois do número pode ter:
  #    ( ... )  ou  - TEXTO  ou nada
  # - .pdf no final

  $re = '^(?i)AC\.(?<name>.+?)\s*(?<num>\d{1,})\s*(?:(?:\((?<tag>[^)]*)\))|(?:-\s*(?<tag2>[^.]+?)))?\s*\.pdf$'
  if ($fileName -match $re) {
    $rawName = $matches['name'].Trim()
    $numRaw  = $matches['num']
    $numNorm = Normalize-Number $numRaw

    return @{
      RawName = $rawName
      NameKey = (Normalize-Key $rawName)
      Number  = $numNorm      # usado pra casar com pedidos/romaneios
      NumberRaw = $numRaw     # opcional (só pra auditoria/visual)
    }
  }
  return $null
}

function Extract-NameNumber-Generic([string]$fileName) {
  # Para PEDIDOS/ROMANEIOS:
  # NOME DO PRODUTOR 46577.pdf
  # NOME DO PRODUTOR 00017.pdf
  # NOME 17(BTG).pdf
  # NOME 17 - BTG.pdf

  $re = '^(?i)(?<name>.+?)\s*(?<num>\d{1,})\s*(?:(?:\((?<tag>[^)]*)\))|(?:-\s*(?<tag2>[^.]+?)))?\s*\.pdf$'
  if ($fileName -match $re) {
    $rawName = $matches['name'].Trim()
    $numRaw  = $matches['num']
    $numNorm = Normalize-Number $numRaw

    return @{
      RawName = $rawName
      NameKey = (Normalize-Key $rawName)
      Number  = $numNorm
      NumberRaw = $numRaw
    }
  }
  return $null
}


function Make-Key([string]$nameKey, [string]$num) {
  return "$nameKey|$num"
}


# ============================================================
# FUNÇÕES - PDF (QPDF)
# ============================================================
function Get-PageCount([string]$pdfPath) {
  $np = & $qpdf "--show-npages" $pdfPath 2>$null
  $np = ($np | Out-String).Trim()
  if (-not $np -or -not ($np -match '^\d+$')) { return $null }
  return [int]$np
}

function Extract-Page([string]$source, [string]$page, [string]$dest) {
  & $qpdf "--empty" "--pages" $source $page "--" $dest | Out-Null
  return ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $dest))
}

function Extract-Range([string]$source, [string]$range, [string]$dest) {
  & $qpdf "--empty" "--pages" $source $range "--" $dest | Out-Null
  return ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $dest))
}


# ============================================================
# FUNÇÕES - IMPRESSÃO (SUMATRA)
# ============================================================
function Print-PdfSimplex([string]$pdfPath) {
  $pdfPath = $pdfPath.Trim()
  $argLine = "-print-to-default -exit-on-print `"$pdfPath`""
  $p = Start-Process -FilePath $sumatra -ArgumentList $argLine -PassThru -Wait -NoNewWindow
  return ($p.ExitCode -eq 0)
}

function Print-PdfDuplex([string]$pdfPath) {
  $pdfPath = $pdfPath.Trim()
  $argLine = "-print-to-default -print-settings $DuplexSetting -exit-on-print `"$pdfPath`""
  $p = Start-Process -FilePath $sumatra -ArgumentList $argLine -PassThru -Wait -NoNewWindow
  return ($p.ExitCode -eq 0)
}



# ============================================================
# INDEXAR PEDIDOS / ROMANEIOS (DETECTA DUPLICADOS)
# ============================================================
function Build-Index([string]$dirPath) {
  $idx = @{}  # key => list of files
  if (!(Test-Path -LiteralPath $dirPath)) { return $idx }

  $files = Get-ChildItem -LiteralPath $dirPath -File -Filter "*.pdf" -ErrorAction SilentlyContinue
  foreach ($f in $files) {
    $info = Extract-NameNumber-Generic $f.Name
    if ($null -eq $info) { continue }
    $k = Make-Key $info.NameKey $info.Number
    if (-not $idx.ContainsKey($k)) { $idx[$k] = New-Object System.Collections.Generic.List[string] }
    $idx[$k].Add($f.FullName)
  }
  return $idx
}

$PedidosIndex   = Build-Index $PedidosDir
$RomaneiosIndex = Build-Index $RomaneiosDir


# ============================================================
# ETAPA 1 - ORGANIZAR PRINT (AC + NFE sempre; Pedido/Romaneio por index)
# ============================================================
Write-Host "`n=========================================================="
Write-Host " ETAPA 1 - ORGANIZAR / GERAR PRINT"
Write-Host "==========================================================`n"
Write-Host "ROOT:  $Root"
Write-Host "PRINT: $PrintDir"
Write-Host "BIN:   $BinDir"
Write-Host ""

$acs = Get-ChildItem -LiteralPath $Root -File -Filter "AC*.pdf" -ErrorAction SilentlyContinue |
  Where-Object { $_.DirectoryName -eq $Root }

if (-not $acs) {
  Write-Host "[PULAR] Nenhum AC*.pdf encontrado na raiz."
  exit 0
}

# Detecta duplicados de AC (mesma chave)
$acKeyMap = @{} # key => list
foreach ($ac in $acs) {
  $info = Extract-NameNumber-AC $ac.Name
  if ($null -eq $info) { continue }
  $k = Make-Key $info.NameKey $info.Number
  if (-not $acKeyMap.ContainsKey($k)) { $acKeyMap[$k] = New-Object System.Collections.Generic.List[string] }
  $acKeyMap[$k].Add($ac.FullName)
}

$acDuplicates = $acKeyMap.GetEnumerator() | Where-Object { $_.Value.Count -gt 1 }

foreach ($dup in $acDuplicates) {
  Write-Host "[AVISO] AC duplicado para chave $($dup.Key):"
  $dup.Value | ForEach-Object { Write-Host "   - $_" }
}
if ($acDuplicates.Count -gt 0) {
  Write-Host ""
  Write-Host "[ATENCAO] Existem ACs duplicados. Corrija para evitar impressao errada."
  Write-Host "          (O sistema vai considerar ERRO na auditoria se afetar a montagem.)"
  Write-Host ""
}

# Monta PRINT por AC
foreach ($ac in $acs) {
  $info = Extract-NameNumber-AC $ac.Name
  if ($null -eq $info) {
    Write-Host "[PULAR] Nome fora do padrao: $($ac.Name)"
    continue
  }

  $producerRaw = $info.RawName
  $producerKey = $info.NameKey
  $number      = $info.Number
  $key         = Make-Key $producerKey $number

  # Se AC duplicado: não escolhe automaticamente (deixa auditoria acusar)
  if ($acKeyMap.ContainsKey($key) -and $acKeyMap[$key].Count -gt 1) {
    continue
  }

  $folderName = Sanitize-PathPart("$producerRaw $number")
  $producerFolder = Join-Path $PrintDir $folderName
  if (!(Test-Path -LiteralPath $producerFolder)) {
    New-Item -ItemType Directory -Path $producerFolder | Out-Null
  }

  Write-Host "----------------------------------------------------------"
  Write-Host "AC: $($ac.Name)"
  Write-Host "PRODUTOR: $producerRaw | NUM: $number"

  $pageCount = Get-PageCount $ac.FullName
  if ($null -eq $pageCount) {
    Write-Host "[ERRO] Nao consegui ler paginas do AC."
    continue
  }

  # 1.AC (pagina 1)
  $acOut = Join-Path $producerFolder "1.AC.pdf"
  if (-not (Extract-Page $ac.FullName "1" $acOut)) {
    Write-Host "[ERRO] Falha ao gerar 1.AC.pdf"
    continue
  }
  Write-Host "[OK] 1.AC.pdf"

  # Detecta tipo (PF/PJ) pelo nome do produtor (arquivo do AC)
  $isPJ = Is-PessoaJuridicaName $producerRaw

  if ($isPJ) {
    Write-Host "[INFO] Detectado PJ (Pessoa Juridica) pelo nome."

    # 5.AC.FINANCEIRO (ultima pagina) - SOMENTE 1 LADO
    $finOut = Join-Path $producerFolder "5.AC.FINANCEIRO.pdf"
    if (-not (Extract-Page $ac.FullName ($pageCount.ToString()) $finOut)) {
      Write-Host "[ERRO] Falha ao gerar 5.AC.FINANCEIRO.pdf"
      continue
    }
    Write-Host "[OK] 5.AC.FINANCEIRO.pdf"

    # 4.ESPELHO (antepenultima + penultima) - FRENTE E VERSO
    if ($pageCount -ge 3) {
      $a = [Math]::Max(1, $pageCount - 2)
      $b = [Math]::Max(1, $pageCount - 1)
      $espOut = Join-Path $producerFolder "4.ESPELHO.pdf"
      $rangeEsp = "$a-$b"
      if (-not (Extract-Range $ac.FullName $rangeEsp $espOut)) {
        Write-Host "[ERRO] Falha ao gerar 4.ESPELHO.pdf (range $rangeEsp)"
        continue
      }
      Write-Host "[OK] 4.ESPELHO.pdf (range $rangeEsp)"
    }
    else {
      Write-Host "[PENDENTE] 4.ESPELHO.pdf (AC com poucas paginas: $pageCount)"
    }
  }
  else {
    # PF: 4.NFE (ultima pagina) - SOMENTE 1 LADO
    $nfeOut = Join-Path $producerFolder "4.NFE.pdf"
    if (-not (Extract-Page $ac.FullName ($pageCount.ToString()) $nfeOut)) {
      Write-Host "[ERRO] Falha ao gerar 4.NFE.pdf"
      continue
    }
    Write-Host "[OK] 4.NFE.pdf"
  }


# 2.PEDIDO
$pedidoOut = Join-Path $producerFolder "2.PEDIDO.pdf"

$pedidoMatch = $null

# 1º - tenta casar por NOME + NUMERO
if ($PedidosIndex.ContainsKey($key)) {
    $list = $PedidosIndex[$key]
    if ($list.Count -eq 1) {
        $pedidoMatch = $list[0]
    }
    elseif ($list.Count -gt 1) {
        Write-Host ("[ERRO] PEDIDOS duplicados para {0} {1}:" -f $producerRaw, $number)
        $list | ForEach-Object { Write-Host "   - $_" }
    }
}

# 2º - fallback: tentar apenas pelo nome (sem numero)
if (-not $pedidoMatch) {

    $candidates = Get-ChildItem $PedidosDir -File -Filter "*.pdf" -ErrorAction SilentlyContinue |
        Where-Object {
            $pi = Extract-NameNumber-Generic $_.Name
            if ($null -ne $pi) {
                return ($pi.NameKey -eq $producerKey)
            }
            else {
                # caso não tenha numero no nome
                $nameOnly = Normalize-Key ($_.BaseName)
                return ($nameOnly -eq $producerKey)
            }
        }

    if ($candidates.Count -eq 1) {
        $pedidoMatch = $candidates[0].FullName
    }
    elseif ($candidates.Count -gt 1) {
        Write-Host ("[ERRO] Mais de um PEDIDO encontrado para {0} (sem numero)." -f $producerRaw)
        $candidates | ForEach-Object { Write-Host "   - $($_.Name)" }
    }
}

if ($pedidoMatch) {
    Copy-Item -LiteralPath $pedidoMatch -Destination $pedidoOut -Force
    Write-Host "[OK] 2.PEDIDO.pdf"
}
else {
    Write-Host "[PENDENTE] 2.PEDIDO.pdf nao encontrado em PEDIDOS"
}


  # 3.ROMANEIO (prioriza pasta ROMANEIOS; fallback por NOME; se nao tiver, extrai do AC)
$romOut = Join-Path $producerFolder "3.ROMANEIO.pdf"

$romMatch = $null

# 1º - tenta casar por NOME + NUMERO (index)
if ($RomaneiosIndex.ContainsKey($key)) {
  $list = $RomaneiosIndex[$key]
  if ($list.Count -eq 1) {
    $romMatch = $list[0]
  } elseif ($list.Count -gt 1) {
    Write-Host ("[ERRO] ROMANEIOS duplicados para {0} {1}:" -f $producerRaw, $number)
    $list | ForEach-Object { Write-Host "   - $_" }
  }
}

# 2º - fallback: tentar apenas pelo nome (sem numero)
if (-not $romMatch) {

  $candidates = @()
  if (Test-Path -LiteralPath $RomaneiosDir) {
    $candidates = Get-ChildItem -LiteralPath $RomaneiosDir -File -Filter "*.pdf" -ErrorAction SilentlyContinue |
      Where-Object {
        $ri = Extract-NameNumber-Generic $_.Name
        if ($null -ne $ri) {
          return ($ri.NameKey -eq $producerKey)   # tem numero, mas casa pelo nome
        } else {
          # arquivo sem numero no nome
          $nameOnly = Normalize-Key ($_.BaseName)
          return ($nameOnly -eq $producerKey)
        }
      }
  }

  if ($candidates.Count -eq 1) {
    $romMatch = $candidates[0].FullName
  }
  elseif ($candidates.Count -gt 1) {
    Write-Host ("[ERRO] Mais de um ROMANEIO encontrado para {0} (sem numero)." -f $producerRaw)
    $candidates | ForEach-Object { Write-Host "   - $($_.Name)" }
  }
}

# aplica: se achou externo, usa e NAO extrai do AC
if ($romMatch) {
  Copy-Item -LiteralPath $romMatch -Destination $romOut -Force
  Write-Host "[OK] 3.ROMANEIO.pdf (de ROMANEIOS)"
}
else {
  # Só extrai do AC se não existir romaneio na pasta ROMANEIOS para esse nome
  if (($isPJ -and ($pageCount -gt 4)) -or ((-not $isPJ) -and ($pageCount -gt 2))) {
    $range = if ($isPJ) { "2-" + ($pageCount - 3) } else { "2-" + ($pageCount - 1) }
    if (Extract-Range $ac.FullName $range $romOut) {
      Write-Host "[OK] 3.ROMANEIO.pdf (extraido do AC: $range)"
    } else {
      Write-Host "[ERRO] Falha ao extrair ROMANEIO do AC."
    }
  } else {
    Write-Host "[PENDENTE] 3.ROMANEIO.pdf nao existe (AC com $pageCount pagina(s))"
  }
}



}

# ============================================================
# ETAPA 2 - AUDITORIA (LOOP ATÉ OK)
# ============================================================
function Audit-Once {
  Write-Host "`n=========================================================="
  Write-Host " ETAPA 2 - AUDITORIA (ANTES DE IMPRIMIR)"
  Write-Host "==========================================================`n"

  $errors = 0

  $folders = Get-ChildItem -LiteralPath $PrintDir -Directory -ErrorAction SilentlyContinue | Sort-Object Name
  if (-not $folders) {
    Write-Host "[ERRO] Nenhuma pasta de produtor encontrada em PRINT."
    return 1
  }

  foreach ($folder in $folders) {
    Write-Host "----------------------------------------------------------"
    Write-Host "PRODUTOR: $($folder.Name)"

    
    $isPJFolder = (Test-Path -LiteralPath (Join-Path $folder.FullName "5.AC.FINANCEIRO.pdf")) -or (Test-Path -LiteralPath (Join-Path $folder.FullName "4.ESPELHO.pdf"))
    $docs = if ($isPJFolder) {
      @("1.AC.pdf","2.PEDIDO.pdf","3.ROMANEIO.pdf","4.ESPELHO.pdf","5.AC.FINANCEIRO.pdf")
    } else {
      @("1.AC.pdf","2.PEDIDO.pdf","3.ROMANEIO.pdf","4.NFE.pdf")
    }

    foreach ($doc in $docs) {

      $file = Join-Path $folder.FullName $doc
      if (Test-Path -LiteralPath $file) {
        $pages = Get-PageCount $file
        if ($null -eq $pages) {
          Write-Host "  $doc - [ERRO] nao consegui ler paginas"
          $errors++
          continue
        }

        $mode = if ($doc -in @("1.AC.pdf","4.NFE.pdf","5.AC.FINANCEIRO.pdf")) { "SIMPLEX" } else { "DUPLEX" }
        Write-Host ("  {0,-12} - {1,2} pagina(s) - {2}" -f $doc, $pages, $mode)
      } else {
        Write-Host "  $doc - [FALTA]"
        $errors++
      }
    }
  }

  Write-Host ""
  if ($errors -gt 0) {
    Write-Host "[FALHA] Auditoria encontrou $errors problema(s)."
  } else {
    Write-Host "[OK] Auditoria sem erros."
  }

  return $errors
}

while ($true) {
  $errCount = Audit-Once
  if ($errCount -eq 0) { break }

  Write-Host ""
  Write-Host "Corrija os arquivos/pastas e depois:"
  Write-Host "  - Pressione ENTER para AUDITAR NOVAMENTE"
  Write-Host "  - Ou digite N e pressione ENTER para SAIR"
  $resp = Read-Host
  if ($resp.Trim().ToUpperInvariant() -eq "N") {
    Write-Host "Saindo sem imprimir."
    exit 2
  }
}

# ============================================================
# CONFIRMAÇÃO
# ============================================================
Write-Host ""
Write-Host "AUDITORIA OK."
Write-Host "CONFIRMAR IMPRESSAO? (S/N)"
$confirm = (Read-Host).Trim().ToUpperInvariant()
if ($confirm -ne "S") {
  Write-Host "Impressao cancelada."
  exit 0
}

# ============================================================
# ETAPA 3 - IMPRESSÃO (ORDEM ALFABÉTICA + ORDEM FIXA DE DOCS)
# ============================================================
Write-Host "`n=========================================================="
Write-Host " ETAPA 3 - IMPRESSAO AUTOMATICA"
Write-Host "==========================================================`n"

$printedProducers = New-Object System.Collections.Generic.List[string]
$printErrors = 0

$folders = Get-ChildItem -LiteralPath $PrintDir -Directory -ErrorAction SilentlyContinue | Sort-Object Name

foreach ($folder in $folders) {
  Write-Host "----------------------------------------------------------"
  Write-Host "IMPRIMINDO PRODUTOR: $($folder.Name)"

  
  $isPJFolder = (Test-Path -LiteralPath (Join-Path $folder.FullName "5.AC.FINANCEIRO.pdf")) -or (Test-Path -LiteralPath (Join-Path $folder.FullName "4.ESPELHO.pdf"))

  $order = if ($isPJFolder) {
    @(
      @{ File="1.AC.pdf";            Mode="SIMPLEX" },
      @{ File="2.PEDIDO.pdf";        Mode="DUPLEX"  },
      @{ File="3.ROMANEIO.pdf";      Mode="DUPLEX"  },
      @{ File="4.ESPELHO.pdf";       Mode="DUPLEX"  },
      @{ File="5.AC.FINANCEIRO.pdf"; Mode="SIMPLEX" }
    )
  } else {
    @(
      @{ File="1.AC.pdf";       Mode="SIMPLEX" },
      @{ File="2.PEDIDO.pdf";   Mode="DUPLEX"  },
      @{ File="3.ROMANEIO.pdf"; Mode="DUPLEX"  },
      @{ File="4.NFE.pdf";      Mode="SIMPLEX" }
    )
  }


  foreach ($item in $order) {
    $path = Join-Path $folder.FullName $item.File
    if (!(Test-Path -LiteralPath $path)) {
      Write-Host "[ERRO] Faltando para imprimir: $($item.File)"
      $printErrors++
      continue
    }

    Write-Host (" -> {0} ({1})" -f $item.File, $item.Mode)

    $ok = $false
    if ($item.Mode -eq "DUPLEX") {
      $ok = Print-PdfDuplex $path
    } else {
      $ok = Print-PdfSimplex $path
    }

    if (-not $ok) {
      Write-Host "[ERRO] Falha ao enviar para impressao: $($item.File)"
      $printErrors++
    }

    Start-Sleep -Milliseconds $SleepMsBetweenPrints
  }

  $printedProducers.Add($folder.Name) | Out-Null
}

# ============================================================
# ETAPA 4 - RESUMO FINAL (ORDEM QUE IMPRIMIU)
# ============================================================
Write-Host "`n=========================================================="
Write-Host " ETAPA 4 - RESUMO FINAL"
Write-Host "==========================================================`n"

Write-Host "Ordem de produtores impressos:"
for ($i=0; $i -lt $printedProducers.Count; $i++) {
  Write-Host ("{0}. {1}" -f ($i+1), $printedProducers[$i])
}

Write-Host ""
Write-Host ("Total produtores: {0}" -f $printedProducers.Count)

if ($printErrors -gt 0) {
  Write-Host ("[ATENCAO] Concluiu com {0} erro(s) na impressao." -f $printErrors)
  exit 3
}

Write-Host "[OK] Impressao finalizada sem erros."
exit 0

<?php
// app/lib.php

function cfg(): array {
  static $c = null;
  if ($c === null) $c = require __DIR__ . '/config.php';
  date_default_timezone_set($c['TZ'] ?? 'America/Belem');
  return $c;
}

function storage_path(string $file): string {
  return dirname(__DIR__) . DIRECTORY_SEPARATOR . 'storage' . DIRECTORY_SEPARATOR . $file;
}

function backup_dir_for_today(): string {
  $dir = dirname(__DIR__) . DIRECTORY_SEPARATOR . 'backup' . DIRECTORY_SEPARATOR . date('Y-m-d');
  if (!is_dir($dir)) @mkdir($dir, 0777, true);
  return $dir;
}

function read_json(string $path, $default) {
  if (!file_exists($path)) return $default;
  $raw = file_get_contents($path);
  $data = json_decode($raw, true);
  return is_array($data) ? $data : $default;
}

function write_json(string $path, $data): void {
  $dir = dirname($path);
  if (!is_dir($dir)) @mkdir($dir, 0777, true);
  file_put_contents($path, json_encode($data, JSON_PRETTY_PRINT|JSON_UNESCAPED_UNICODE));
}

function day_key(): string {
  return 'dia_' . date('Y-m-d') . '.json';
}

function is_pj_name(string $nome): bool {
  $nomeU = mb_strtoupper($nome);
  foreach (cfg()['PJ_KEYWORDS'] as $k) {
    if (mb_strpos($nomeU, mb_strtoupper($k)) !== false) return true;
  }
  return false;
}

function norm_spaces(string $s): string {
  $s = str_replace("\xC2\xA0", ' ', $s); // nbsp
  $s = preg_replace('/[ \t]+/', ' ', $s);
  return trim($s);
}

/**
 * Parseia a escala colada (TSV do Excel ou texto com espaços).
 * Espera colunas: LOTE, Pedido, Instrucao, Nome dos Produtores, ...
 */
function parse_escala(string $text): array {
  $lines = preg_split("/\r\n|\n|\r/", trim($text));
  $rows = [];

  foreach ($lines as $i => $line) {
    $line = trim($line);
    if ($line === '') continue;

    // pula linha de cabeçalho se tiver "LOTE" e "Pedido"
    if ($i === 0 && (stripos($line, 'LOTE') !== false) && (stripos($line, 'Pedido') !== false)) {
      continue;
    }

    // tenta TSV (tab)
    $parts = explode("\t", $line);
    if (count($parts) < 4) {
      // fallback: separa por 2+ espaços
      $parts = preg_split('/\s{2,}/', $line);
    }

    // Precisamos pelo menos: LOTE, Pedido, Instrucao, Nome
    if (count($parts) < 4) continue;

    $pedido = norm_spaces($parts[1] ?? '');
    $instr  = norm_spaces($parts[2] ?? '');
    $nome   = norm_spaces($parts[3] ?? '');

    if ($pedido === '' || $instr === '' || $nome === '') continue;

    $tipo = is_pj_name($nome) ? 'PJ' : 'PF';

    $rows[] = [
      'pedido' => $pedido,
      'instrucao' => $instr,
      'nome' => $nome,
      'tipo' => $tipo,
      'status' => 'PENDENTE',

      // Campos do dia (editáveis depois)
      'notas' => '',
      'placas' => [],
      'grorjbs' => '',
      'quant_minutas' => '',
      'total_placas' => 1,
    ];
  }

  // remove duplicados por (instrucao+pedido) mantendo o primeiro
  $uniq = [];
  foreach ($rows as $r) {
    $k = $r['instrucao'] . '|' . $r['pedido'];
    if (!isset($uniq[$k])) $uniq[$k] = $r;
  }

  return array_values($uniq);
}

function load_day_data(): array {
  $path = storage_path(day_key());
  return read_json($path, ['created_at' => date('c'), 'produtores' => []]);
}

function save_day_data(array $data): void {
  $path = storage_path(day_key());
  write_json($path, $data);
}

function load_placas_db(): array {
  $path = storage_path('placas.json');
  $arr = read_json($path, []);
  // garante array de strings únicas
  $out = [];
  foreach ($arr as $p) {
    $p = strtoupper(norm_spaces((string)$p));
    if ($p !== '') $out[$p] = true;
  }
  return array_keys($out);
}

function save_placas_db(array $placas): void {
  $clean = [];
  foreach ($placas as $p) {
    $p = strtoupper(norm_spaces((string)$p));
    if ($p !== '') $clean[$p] = true;
  }
  write_json(storage_path('placas.json'), array_values(array_keys($clean)));
}

function ensure_dir(string $dir): void {
  if (!is_dir($dir)) @mkdir($dir, 0777, true);
}

function backup_if_exists(string $filePath): void {
  if (!file_exists($filePath)) return;
  $dst = backup_dir_for_today() . DIRECTORY_SEPARATOR . basename($filePath);
  @copy($filePath, $dst);
}

/** Gera o conteúdo de cada arquivo */
function render_files(array $produtores): array {
  $out = [];

  // 1) RecebimentoDeEntrada.txt
  $s = '';
  foreach ($produtores as $p) {
    $s .= "[PRODUTOR]\n";
    $s .= "NOME={$p['nome']}\n";
    $s .= "STATUS={$p['status']}\n";
    $s .= "TIPO={$p['tipo']}\n";
    $s .= "INSTRUCAO={$p['instrucao']}\n";
    $s .= "NOTAS:\n";
    $s .= ($p['notas'] ?? '') . "\n\n"; // duas quebras antes do próximo bloco
  }
  $out['RecebimentoDeEntrada.txt'] = $s;

  // 2) CadastrarPlacasVeiculo.txt
  $s = '';
  foreach ($produtores as $p) {
    $s .= "[PRODUTOR]\n";
    $s .= "NOME={$p['nome']}\n";
    $s .= "STATUS={$p['status']}\n";
    $s .= "TIPO={$p['tipo']}\n";
    $s .= "INSTRUCAO={$p['instrucao']}\n";
    $s .= "PEDIDO={$p['pedido']}\n";
    $s .= "GRorJBS=" . ($p['grorjbs'] ?? '') . "\n";
    $s .= "{\n    # Aguardando\n}\n";
    $s .= "QUANT_MINUTAS=" . ($p['quant_minutas'] ?? '') . "\n";
    $s .= "{\n    # Aguardando\n}\n";
    $s .= "PLACAS:\n";
    $placas = $p['placas'] ?? [];
    foreach ($placas as $pl) $s .= strtoupper(norm_spaces($pl)) . "\n";
    $s .= "\n\n"; // duas quebras
  }
  $out['CadastrarPlacasVeiculo.txt'] = $s;

  // 3) nfe_contratacao_veiculo.txt
  $s = '';
  foreach ($produtores as $p) {
    $s .= "[PRODUTOR]\n";
    $s .= "NOME={$p['nome']}\n";
    $s .= "STATUS={$p['status']}\n";
    $s .= "TIPO={$p['tipo']}\n";
    $s .= "INSTRUCAO={$p['instrucao']}\n";
    $s .= "PEDIDO={$p['pedido']}\n";
    $s .= "TOTAL_PLACAS=" . (int)($p['total_placas'] ?? 1) . "\n";
    $s .= "NOTAS:\n";
    $s .= ($p['notas'] ?? '') . "\n\n";
  }
  $out['nfe_contratacao_veiculo.txt'] = $s;

  // 4) faturarF7F3.txt
  $s = '';
  foreach ($produtores as $p) {
    $s .= "[PRODUTOR]\n";
    $s .= "NOME={$p['nome']}\n";
    $s .= "STATUS={$p['status']}\n";
    $s .= "TIPO={$p['tipo']}\n";
    $s .= "INSTRUCAO={$p['instrucao']}\n";
    $s .= "PEDIDO={$p['pedido']}\n";
    $s .= "NOTAS:\n";
    $s .= ($p['notas'] ?? '') . "\n\n";
  }
  $out['faturarF7F3.txt'] = $s;

  // 5) notas_PEDIDOS.txt
  $out['notas_PEDIDOS.txt'] = $out['faturarF7F3.txt'];

  return $out;
}

function write_files_to_automacao(array $contents): array {
  $dir = cfg()['AUTOMACAO_DIR'];
  ensure_dir($dir);

  $written = [];
  foreach ($contents as $fname => $data) {
    $path = rtrim($dir, "\\/") . DIRECTORY_SEPARATOR . $fname;

    // backup do que existir antes de sobrescrever
    backup_if_exists($path);

    file_put_contents($path, $data);
    $written[] = $path;
  }
  return $written;
}

function h($s): string { return htmlspecialchars((string)$s, ENT_QUOTES, 'UTF-8'); }
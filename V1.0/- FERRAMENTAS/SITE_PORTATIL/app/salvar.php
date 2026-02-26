<?php
require __DIR__ . '/lib.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
  header('Location: editar.php'); exit;
}

$id = (string)($_POST['id'] ?? '');
if ($id === '' || strpos($id, '|') === false) {
  echo "ID inválido"; exit;
}

$day = load_day_data();
$produtores = $day['produtores'] ?? [];

$nome = norm_spaces((string)($_POST['nome'] ?? ''));
$instrucao = norm_spaces((string)($_POST['instrucao'] ?? ''));
$pedido = norm_spaces((string)($_POST['pedido'] ?? ''));
$tipo = (string)($_POST['tipo'] ?? 'PF');
$status = (string)($_POST['status'] ?? 'PENDENTE');
$notas = (string)($_POST['notas'] ?? '');

$grorjbs = norm_spaces((string)($_POST['grorjbs'] ?? ''));
$quant_minutas = norm_spaces((string)($_POST['quant_minutas'] ?? ''));
$total_placas = (int)($_POST['total_placas'] ?? 1);
if ($total_placas < 1) $total_placas = 1;

$placasText = (string)($_POST['placas'] ?? '');
$placasLines = preg_split("/\r\n|\n|\r/", trim($placasText));
$placas = [];
foreach ($placasLines as $pl) {
  $pl = strtoupper(norm_spaces($pl));
  if ($pl !== '') $placas[] = $pl;
}
$placas = array_values(array_unique($placas));

// atualiza produtor no JSON do dia (procura pelo id antigo)
$updated = false;
for ($i=0; $i<count($produtores); $i++) {
  $k = ($produtores[$i]['instrucao'] ?? '') . '|' . ($produtores[$i]['pedido'] ?? '');
  if ($k === $id) {
    $produtores[$i]['nome'] = $nome;
    $produtores[$i]['instrucao'] = $instrucao;
    $produtores[$i]['pedido'] = $pedido;
    $produtores[$i]['tipo'] = ($tipo === 'PJ') ? 'PJ' : 'PF';
    $produtores[$i]['status'] = ($status === 'OK') ? 'OK' : 'PENDENTE';
    $produtores[$i]['notas'] = $notas;

    $produtores[$i]['grorjbs'] = $grorjbs;
    $produtores[$i]['quant_minutas'] = $quant_minutas;
    $produtores[$i]['total_placas'] = $total_placas;
    $produtores[$i]['placas'] = $placas;

    $updated = true;
    break;
  }
}

if (!$updated) {
  echo "Produtor não encontrado no dia. Gere novamente a escala."; exit;
}

// salva dia
$day['produtores'] = $produtores;
save_day_data($day);

// atualiza placas permanentes
$placasDb = load_placas_db();
$merged = array_values(array_unique(array_merge($placasDb, $placas)));
save_placas_db($merged);

// reescreve os 5 TXT do dia na pasta da automação
$contents = render_files($produtores);
write_files_to_automacao($contents);

// volta pro editar já selecionando o novo id (instrucao|pedido atual)
$newId = $instrucao . '|' . $pedido;
header('Location: editar.php?id=' . urlencode($newId));
exit;
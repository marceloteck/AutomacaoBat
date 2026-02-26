<?php
require __DIR__ . '/lib.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
  header('Location: ../public/index.php'); exit;
}

$escala = (string)($_POST['escala'] ?? '');
$escala = trim($escala);

if ($escala === '') {
  echo "Escala vazia. Volte e cole o texto."; exit;
}

$produtores = parse_escala($escala);

// salva como dados do dia (temporário)
$day = [
  'created_at' => date('c'),
  'produtores' => $produtores,
];
save_day_data($day);

// gera os 5 arquivos e escreve na pasta da automação (sobrescreve)
$contents = render_files($produtores);
$written = write_files_to_automacao($contents);

?>
<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8">
  <title>Gerado</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    body{font-family:Arial, sans-serif; max-width:980px; margin:24px auto; padding:0 12px;}
    code{display:block; padding:8px; background:#f6f6f6; border-radius:10px; margin:6px 0;}
    .btn{display:inline-block; padding:10px 12px; border:1px solid #333; border-radius:10px; background:#fff; text-decoration:none; color:#000;}
  </style>
</head>
<body>
  <h2>Arquivos gerados ✅</h2>
  <p>Produtores: <b><?=count($produtores)?></b></p>

  <h3>Arquivos escritos:</h3>
  <?php foreach ($written as $p): ?>
    <code><?=h($p)?></code>
  <?php endforeach; ?>

  <p>
    <a class="btn" href="../public/index.php">Voltar</a>
    <a class="btn" href="editar.php">Editar produtores</a>
  </p>
</body>
</html>
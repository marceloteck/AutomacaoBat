<?php
require __DIR__ . '/../app/lib.php';
$day = load_day_data();
$produtores = $day['produtores'] ?? [];
?>
<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8">
  <title>Escala Abate - Gerador</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    body{font-family:Arial, sans-serif; max-width:980px; margin:24px auto; padding:0 12px;}
    textarea{width:100%; min-height:220px; font-family:Consolas, monospace;}
    .row{display:flex; gap:12px; flex-wrap:wrap;}
    .card{border:1px solid #ddd; border-radius:10px; padding:12px;}
    .btn{padding:10px 12px; border:1px solid #333; border-radius:10px; background:#fff; cursor:pointer;}
    .muted{color:#666}
  </style>
</head>
<body>
  <h2>Gerar arquivos do dia</h2>
  <p class="muted">
    Cola a escala (do Excel) e clica em <b>Gerar</b>. Isso vai <b>zerar e reescrever</b> os TXT na pasta da automação.
    Placas ficam permanentes em <code>storage/placas.json</code>.
  </p>

  <div class="row">
    <div class="card" style="flex:1 1 520px;">
      <form method="post" action="../app/gerar.php">
        <label><b>Escala de abate (colar aqui)</b></label><br>
        <textarea name="escala" placeholder="Cole aqui..."></textarea><br><br>
        <button class="btn" type="submit">Gerar (zera e reescreve)</button>
      </form>
    </div>

    <div class="card" style="flex:1 1 320px;">
      <h3>Dia: <?=h(date('Y-m-d'))?></h3>
      <p>Total produtores: <b><?=count($produtores)?></b></p>
      <p>Pasta automação:</p>
      <code><?=h(cfg()['AUTOMACAO_DIR'])?></code>
      <hr>
      <a class="btn" href="../app/editar.php">Editar produtores do dia</a>
    </div>
  </div>
</body>
</html>
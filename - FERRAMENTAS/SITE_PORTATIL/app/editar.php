<?php
require __DIR__ . '/lib.php';

$day = load_day_data();
$produtores = $day['produtores'] ?? [];

$id = $_GET['id'] ?? null;

function find_produtor(array $produtores, string $id): ?array {
  // id = instrucao|pedido
  foreach ($produtores as $p) {
    $k = $p['instrucao'] . '|' . $p['pedido'];
    if ($k === $id) return $p;
  }
  return null;
}

$selected = null;
if ($id) $selected = find_produtor($produtores, $id);
$placasDb = load_placas_db();
?>
<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8">
  <title>Editar</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    body{font-family:Arial, sans-serif; max-width:1100px; margin:24px auto; padding:0 12px;}
    table{width:100%; border-collapse:collapse;}
    th,td{border-bottom:1px solid #eee; padding:8px; text-align:left; font-size:14px;}
    .row{display:flex; gap:14px; flex-wrap:wrap;}
    .card{border:1px solid #ddd; border-radius:10px; padding:12px;}
    .btn{padding:10px 12px; border:1px solid #333; border-radius:10px; background:#fff; cursor:pointer; text-decoration:none; color:#000; display:inline-block;}
    input,select,textarea{width:100%; padding:8px; box-sizing:border-box;}
    textarea{min-height:120px;}
    .muted{color:#666}
  </style>
</head>
<body>
  <h2>Editar produtores do dia (<?=h(date('Y-m-d'))?>)</h2>
  <p class="muted">Ao salvar, ele atualiza JSON do dia, atualiza placas permanentes e reescreve os TXT na pasta da automação.</p>
  <p>
    <a class="btn" href="../public/index.php">← Voltar</a>
  </p>

  <div class="row">
    <div class="card" style="flex:1 1 560px;">
      <h3>Lista</h3>
      <?php if (count($produtores) === 0): ?>
        <p>Nenhum produtor no dia. Gere primeiro na página inicial.</p>
      <?php else: ?>
        <table>
          <thead>
            <tr>
              <th>Nome</th><th>Instrução</th><th>Pedido</th><th>Tipo</th><th>Status</th><th></th>
            </tr>
          </thead>
          <tbody>
          <?php foreach ($produtores as $p):
            $k = $p['instrucao'].'|'.$p['pedido'];
          ?>
            <tr>
              <td><?=h($p['nome'])?></td>
              <td><?=h($p['instrucao'])?></td>
              <td><?=h($p['pedido'])?></td>
              <td><?=h($p['tipo'])?></td>
              <td><?=h($p['status'])?></td>
              <td><a class="btn" href="editar.php?id=<?=urlencode($k)?>">Editar</a></td>
            </tr>
          <?php endforeach; ?>
          </tbody>
        </table>
      <?php endif; ?>
    </div>

    <div class="card" style="flex:1 1 420px;">
      <h3>Edição</h3>
      <?php if (!$selected): ?>
        <p>Selecione um produtor na lista.</p>
      <?php else: ?>
        <form method="post" action="salvar.php">
          <input type="hidden" name="id" value="<?=h($selected['instrucao'].'|'.$selected['pedido'])?>">

          <label><b>Nome</b></label>
          <input name="nome" value="<?=h($selected['nome'])?>">

          <div class="row">
            <div style="flex:1;">
              <label><b>Instrução</b></label>
              <input name="instrucao" value="<?=h($selected['instrucao'])?>">
            </div>
            <div style="flex:1;">
              <label><b>Pedido</b></label>
              <input name="pedido" value="<?=h($selected['pedido'])?>">
            </div>
          </div>

          <div class="row">
            <div style="flex:1;">
              <label><b>Tipo</b></label>
              <select name="tipo">
                <option value="PF" <?=$selected['tipo']==='PF'?'selected':''?>>PF</option>
                <option value="PJ" <?=$selected['tipo']==='PJ'?'selected':''?>>PJ</option>
              </select>
            </div>
            <div style="flex:1;">
              <label><b>Status</b></label>
              <select name="status">
                <option value="PENDENTE" <?=$selected['status']==='PENDENTE'?'selected':''?>>PENDENTE</option>
                <option value="OK" <?=$selected['status']==='OK'?'selected':''?>>OK</option>
              </select>
            </div>
          </div>

          <label><b>Notas (vai para todos os arquivos que usam NOTAS:)</b></label>
          <textarea name="notas"><?=h($selected['notas'] ?? '')?></textarea>

          <div class="row">
            <div style="flex:1;">
              <label><b>GRorJBS</b></label>
              <input name="grorjbs" value="<?=h($selected['grorjbs'] ?? '')?>">
            </div>
            <div style="flex:1;">
              <label><b>QUANT_MINUTAS</b></label>
              <input name="quant_minutas" value="<?=h($selected['quant_minutas'] ?? '')?>">
            </div>
          </div>

          <label><b>TOTAL_PLACAS (NFE contratação)</b></label>
          <input name="total_placas" type="number" min="1" value="<?=h((int)($selected['total_placas'] ?? 1))?>">

          <label><b>PLACAS (1 por linha) — com autocomplete</b></label>
          <textarea id="placas" name="placas"><?php
            $pls = $selected['placas'] ?? [];
            echo h(implode("\n", $pls));
          ?></textarea>

          <button class="btn" type="submit">Salvar e reescrever TXT</button>
        </form>

        <hr>
        <p class="muted">Dica: ao digitar placas, use formato comum tipo ABC1D23 ou ABC-1234. O sistema salva no banco permanente.</p>

        <script>
          // Autocomplete simples: quando você digita, ele busca sugestões e mostra no console (leve).
          // Se quiser, depois eu deixo com dropdown bonitinho.
          const ta = document.getElementById('placas');
          let last = '';
          ta.addEventListener('input', async () => {
            const lines = ta.value.split('\n');
            const cur = (lines[lines.length - 1] || '').trim();
            if (cur.length < 2 || cur === last) return;
            last = cur;
            const res = await fetch('placas_api.php?q=' + encodeURIComponent(cur));
            const j = await res.json();
            // (Modo simples) Só loga. Depois fazemos dropdown.
            console.log('Sugestoes placas:', j);
          });
        </script>
      <?php endif; ?>
    </div>
  </div>
</body>
</html>
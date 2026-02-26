<?php
require __DIR__ . '/lib.php';

$q = strtoupper(norm_spaces((string)($_GET['q'] ?? '')));
$db = load_placas_db();

$out = [];
if ($q !== '') {
  foreach ($db as $p) {
    if (strpos($p, $q) !== false) $out[] = $p;
    if (count($out) >= 20) break;
  }
}

header('Content-Type: application/json; charset=utf-8');
echo json_encode($out, JSON_UNESCAPED_UNICODE);
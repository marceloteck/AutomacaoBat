<?php
// app/config.php

return [
  // Pasta onde seus TXT da automação ficam (ajuste para a sua)
  // Ex: C:\Users\...\BAT\- AUTO_MODELO\input
  'AUTOMACAO_DIR' => 'C:\\Users\\Nanosistecck\\Documents\\BAT\\- AUTO_MODELO\\input',

  // Timezone
  'TZ' => 'America/Belem',

  // Palavras que indicam PJ
  'PJ_KEYWORDS' => [
    'LTDA','Ltda','S.A','SA','EIRELI','ME','EPP','CIA','COMPANHIA','INDUSTRIA',
    'INDÚSTRIA','COMERCIO','COMÉRCIO','AGROPECUARIA','AGROPECUÁRIA','FAZENDA'
  ],
];
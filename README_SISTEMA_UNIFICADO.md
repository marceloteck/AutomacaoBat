# Sistema Unificado de Automação (Windows)

Este projeto agora possui um **orquestrador central** em PowerShell:

- `AUTOMACAO_SISTEMA.ps1`
- Configuração em `config/system_config.psd1`
- Launcher pelo menu legado: `CENTRAL_BAT/CENTRAL.bat`

## O que foi melhorado

- Centralização das ações em um único menu.
- Redução de repetição entre scripts utilitários.
- Configuração externa para impressoras e executáveis.
- Log diário de execução em `CENTRAL_BAT/logs`.
- Modo automatizado sem menu (`-NoMenu -Action ...`).

## Ações disponíveis (`-Action`)

- `PROCESSO_ACERTOS`
- `EXECUTAR_IMPRESSAO`
- `MAPEAR_REDE`
- `INICIAR_CORPORATE`
- `SET_PDFCREATOR`
- `SET_PHYSICAL_PRINTER`
- `SET_SAVE_PDF`
- `AUTOSAVE_ON`
- `AUTOSAVE_OFF`
- `ADD_AC`
- `REMOVE_AC`
- `REMOVE_2`
- `ORGANIZE_FILES`
- `OPEN_DOWNLOADS_DESKTOP`
- `RUN_FULL_AUTOMATION`

## Exemplos

```bat
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\BAT\AUTOMACAO_SISTEMA.ps1"
```

```bat
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\BAT\AUTOMACAO_SISTEMA.ps1" -NoMenu -Action SET_PHYSICAL_PRINTER
```

## Configuração

Edite `config/system_config.psd1` para ajustar:

- Nome das impressoras
- Caminho do Corporate Updater
- Quantidade de inicializações do Corporate
- Diretório de logs

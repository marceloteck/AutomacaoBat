# Análise do projeto AutomacaoBat e evolução para Windows

## 1) Visão geral do projeto

O repositório concentra automações operacionais de faturamento e impressão no Windows, combinando:

- **Batch (`.bat`/`.cmd`)** para orquestração e menus.
- **PowerShell (`.ps1`)** para regras de negócio (normalização, matching, merge, auditoria e impressão).
- **Ferramentas embarcadas** (qpdf e SumatraPDF) para manipulação e impressão de PDFs.
- **Integração com PDFCreator** via CLI e alterações de Registro para auto-save.

O fluxo principal está dividido em dois blocos:

1. **FATURAMENTO-PRO**: prepara lotes, normaliza nomes, copia pedidos por similaridade, mescla PDFs e finaliza limpeza.
2. **IMPRESSAO_PRO**: organiza os documentos por produtor, audita e imprime em ordem fixa.

Além disso, existe um **menu central** (`CENTRAL_BAT/CENTRAL.bat`) para disparar os processos.

---

## 2) Pontos fortes identificados

- Fluxo de trabalho bem segmentado em etapas, com mensagens claras para operador.
- Validações de existência de arquivos/pastas antes de executar etapas críticas.
- Estratégia de backup/restauração do perfil do PDFCreator antes de alterar auto-save.
- Auditoria antes da impressão final, reduzindo risco operacional.
- Empacotamento local de executáveis (qpdf/Sumatra) reduz dependência de instalação manual.

---

## 3) Riscos e limitações atuais

### 3.1 Acoplamento forte ao ambiente de um único usuário

Há caminhos absolutos com nome de usuário e pastas específicas no `CENTRAL.bat`.

**Impacto:** dificulta portar para outro PC/usuário e aumenta manutenção.

### 3.2 Dependência de comandos legados do Windows

Uso de `wmic` para trocar impressora padrão. Em versões mais novas do Windows, `wmic` está descontinuado.

**Impacto:** risco de quebra futura em máquinas atualizadas.

### 3.3 Configuração sensível via Registro

A alteração/restauração do PDFCreator depende de chave fixa de perfil (`...ConversionProfiles\0`).

**Impacto:** se a estrutura de perfil mudar por versão/instalação, o fluxo pode falhar.

### 3.4 Ausência de arquivo de configuração central

Parâmetros importantes (nomes de impressora, limiares, diretórios, executáveis) estão espalhados em scripts.

**Impacto:** ajustes exigem edição de código e aumentam chance de erro operacional.

### 3.5 Observabilidade limitada

Há logs parciais, mas não existe padrão único de log estruturado por execução.

**Impacto:** dificuldade para auditoria, suporte e diagnóstico histórico de falhas.

---

## 4) Lista de melhorias recomendadas

## Prioridade alta (ganho rápido)

1. **Criar arquivo único de configuração** (ex.: `config.json` ou `config.psd1`) com:
   - Caminhos base dos processos.
   - Nome da impressora física e impressora de retorno (PDFCreator).
   - Caminho do PDFCreator CLI.
   - Threshold de similaridade.

2. **Remover caminhos absolutos do menu central**, usando:
   - `%~dp0` (caminho relativo ao script).
   - Variáveis de ambiente.
   - Descoberta automática com fallback.

3. **Substituir `wmic` por PowerShell moderno**, ex.:
   - `Get-Printer` / `Set-Printer` quando disponível.
   - Fallback controlado com mensagem amigável.

4. **Padronizar logs por execução**, criando pasta `logs\YYYY-MM-DD` com:
   - Início/fim da execução.
   - Parâmetros usados.
   - Etapa e erro detalhado.

5. **Criar checklist de pré-requisitos** automatizado (`preflight.ps1`) para validar:
   - Execução em Windows suportado.
   - Presença das impressoras esperadas.
   - Existência de executáveis (`qpdf`, `Sumatra`, `PDFCreator-cli`).
   - Permissão para Registro e pastas.

## Prioridade média (robustez)

6. **Padronizar códigos de saída e catálogo de erros** para cada etapa.
7. **Adicionar modo simulação (`-DryRun`) ponta-a-ponta** também para impressão.
8. **Versionar backup de configuração do PDFCreator com metadados** (data, host, usuário).
9. **Adicionar validação de nomes de arquivos mais resiliente** (regex configurável).
10. **Criar “reprocessar somente falhas”** (retentar apenas produtores com erro).

## Prioridade estratégica (evolução)

11. **Empacotar como toolkit Windows** com instalador simples (`.ps1` + atalho + estrutura de pastas).
12. **Migrar orquestração principal para PowerShell** (manter BAT apenas como launcher).
13. **Criar interface leve** (WinUI/WPF ou web local) para operador não técnico.
14. **Publicar artefato versionado** (release zip) com changelog e rollback.
15. **Adicionar telemetria local opcional** para indicadores de produtividade (tempo por lote, erros por etapa).

---

## 5) Possível evolução para uso no Windows (roadmap)

### Fase 1 — Padronização (1 a 2 semanas)

- Introduzir `config.psd1` e adaptar scripts para ler configuração central.
- Remover hardcodes de caminho no menu principal.
- Implementar preflight obrigatório antes de qualquer processamento.
- Unificar logs em formato consistente.

**Resultado esperado:** instalação repetível em vários PCs com mínima edição manual.

### Fase 2 — Confiabilidade operacional (2 a 4 semanas)

- Substituir pontos legados (`wmic`) por APIs PowerShell modernas.
- Expandir tratamento de erro com mensagens orientadas à ação.
- Criar rotina de reprocessamento de falhas.
- Definir suite mínima de testes com pastas de exemplo.

**Resultado esperado:** menor taxa de interrupção e manutenção simplificada.

### Fase 3 — Produto interno Windows (4 a 8 semanas)

- Empacotar release instalável com atualização controlada.
- Disponibilizar interface simplificada para operação diária.
- Criar documentação de operação, suporte e contingência.
- Implementar controle de versão do fluxo e das configurações.

**Resultado esperado:** solução sustentável para escalar uso entre setores e máquinas.

---

## 6) Recomendações práticas imediatas

- Começar pelo **arquivo de configuração central + preflight** (maior retorno, menor esforço).
- Em seguida, **desacoplar caminhos do usuário** no `CENTRAL.bat`.
- Depois, **padronizar logs e erros** para acelerar suporte no dia a dia.

Se essas três frentes forem concluídas, o projeto já avança de um conjunto de scripts pessoais para um **processo operacional Windows mais corporativo, portátil e confiável**.

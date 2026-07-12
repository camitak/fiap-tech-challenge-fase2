# Etapa 09 — Dashboard no Looker Studio

## Objetivo

Criar um painel executivo e analítico utilizando exclusivamente objetos
curados da camada Gold.

## Fontes do relatório

- `alfabetizacao_gold.vw_dashboard_resumo_nacional`
- `alfabetizacao_gold.vw_dashboard_uf`
- `alfabetizacao_gold.vw_dashboard_municipio`
- `alfabetizacao_gold.vw_dashboard_streaming`
- `alfabetizacao_gold.vw_dashboard_operacao`
- `alfabetizacao_gold.vw_dashboard_bigquery_uso_diario`

## Estrutura recomendada

### Página 1 — Visão Executiva

Fonte: `vw_dashboard_resumo_nacional`

Controles:

- lista de seleção para `ano`;
- valor inicial recomendado: 2024.

Cartões:

- taxa de alfabetização do Brasil;
- meta nacional;
- gap da meta;
- participação nacional;
- percentual de UFs que atingiram a meta;
- percentual de municípios que atingiram a meta.

Gráficos:

- série temporal de resultado versus meta;
- barras com percentual de UFs e municípios que atingiram a meta.

Nota textual:

> O detalhamento estadual e municipal da fonte utilizada está disponível até
> 2024. O resultado nacional já possui registro de 2025.

### Página 2 — Desempenho por UF

Fonte: `vw_dashboard_uf`

Controles:

- ano;
- status da meta;
- UF.

Gráficos:

- barras horizontais: taxa de alfabetização por UF;
- tabela: UF, resultado, meta, gap, participação, ranking e status;
- dispersão: participação no eixo X e taxa no eixo Y;
- gráfico de rosca: quantidade de UFs por status da meta.

Filtro recomendado:

- excluir linhas em que resultado e meta estejam simultaneamente nulos.

### Página 3 — Desempenho Municipal

Fonte: `vw_dashboard_municipio`

Controles:

- ano;
- status da meta;
- faixa de gap;
- faixa de participação;
- busca pelo `id_municipio`.

Gráficos:

- tabela ordenada pelo menor gap;
- barras: quantidade de municípios por status da meta;
- distribuição por quartil de desempenho;
- dispersão: participação versus taxa de alfabetização;
- cartões: municípios comparáveis e municípios que atingiram a meta.

Observação:

O projeto atual preserva o código oficial do município. Nome, UF e região
podem ser adicionados futuramente por uma dimensão territorial, sem alterar o
núcleo obrigatório da pipeline.

### Página 4 — Streaming e Operação

Fontes:

- `vw_dashboard_streaming`
- `vw_dashboard_operacao`

Cartões streaming:

- máximo de `eventos_bronze_total_run`;
- máximo de `eventos_validos_total_run`;
- máximo de `eventos_invalidos_total_run`;
- média de `avg_end_to_end_latency_seconds`.

Gráficos:

- quantidade de eventos por tipo;
- latência média e P95 por tipo;
- tabela da saúde das pipelines;
- cartão com quantidade de pipelines em `SUCCEEDED`.

### Página 5 — FinOps

Fonte: `vw_dashboard_bigquery_uso_diario`

Cartões:

- soma de consultas;
- soma de consultas com falha;
- soma de TiB faturados;
- soma de cache hits.

Gráficos:

- consultas por dia;
- GiB faturados por dia;
- cache hits por dia.

## Formatação de campos

Use o tipo percentual, sem multiplicar novamente, para campos já expressos
entre 0 e 100:

- taxas de alfabetização;
- metas;
- participação;
- percentuais de cobertura;
- percentuais que atingiram meta.

Use número decimal com sufixo `pp` para gaps em pontos percentuais.

Use número decimal com sufixo `s` para latências.

## Compartilhamento

O relatório pode usar credenciais do proprietário para uma demonstração
acadêmica controlada. Não habilite acesso público irrestrito a microdados.

Compartilhe preferencialmente:

- o relatório;
- somente as views Gold;
- sem acesso direto às tabelas de alunos da Silver.

## URL do relatório

Preencher após a criação:

`URL_LOOKER_STUDIO:`

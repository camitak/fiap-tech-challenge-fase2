# Etapa 05 — Silver, qualidade e integração

## Objetivo

Transformar o snapshot Bronze em tabelas nativas do BigQuery, aplicar regras de qualidade e integrar as bases heterogêneas.

## Transformações

- tipagem e padronização de chaves;
- decodificação pelo dicionário oficial;
- normalização das redes de ensino;
- deduplicação por chaves candidatas;
- metas convertidas do formato largo para o formato longo;
- separação entre regras críticas e alertas;
- quarentena com payload e regras violadas;
- agregação dos microdados por município;
- integração entre alunos, resultados e metas.

## Tabelas Silver

- `dim_dicionario`
- `alunos`
- `resultado_municipio`
- `resultado_uf`
- `meta_brasil`
- `meta_uf`
- `meta_municipio`
- `agg_alunos_municipio`
- `int_alunos_resultado_municipio`
- `int_municipio_meta`
- `int_uf_meta`
- `int_brasil_meta`

## Estratégia de armazenamento

As tabelas nativas são particionadas por `ano_referencia` e clusterizadas pelas chaves mais consultadas. A Bronze continua sendo a camada responsável pelo histórico integral dos snapshots.

## Execução

```bash
export PROJECT_ID="fiap-tc-f2-camila-takemoto"
export LOCATION="US"
export SA_BATCH="sa-batch-ingestion@${PROJECT_ID}.iam.gserviceaccount.com"
export INGESTION_DATE="2026-07-12"
export BATCH_ID="batch_20260712T011134Z"

./src/silver/run_silver.sh
./src/silver/validate_silver.sh
```

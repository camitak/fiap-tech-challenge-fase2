# Etapa 04 — Ingestão batch da camada Bronze

## Objetivo

Exportar as fontes públicas do Indicador Criança Alfabetizada do BigQuery
para o Cloud Storage em formato Parquet.

## Origem

- Projeto: basedosdados
- Dataset: br_inep_avaliacao_alfabetizacao

## Fontes obrigatórias

- alunos
- meta_alfabetizacao_brasil
- meta_alfabetizacao_municipio
- meta_alfabetizacao_uf
- municipio
- uf

## Fonte auxiliar

- dicionario

## Destino

- Bucket: fiap-tc-f2-camila-takemoto-alfabetizacao-bronze
- Localização: US
- Formato: Parquet
- Compressão: Snappy

## Particionamento

Os arquivos utilizam particionamento Hive:

`ingestion_date=AAAA-MM-DD/batch_id=IDENTIFICADOR`

Esse modelo preserva snapshots históricos e permite filtrar somente a carga
necessária.

## Metadados técnicos

Cada registro recebe:

- `_ingestion_timestamp`
- `_batch_id`
- `_source_table`

## Segurança

A exportação é executada pela conta:

`sa-batch-ingestion@fiap-tc-f2-camila-takemoto.iam.gserviceaccount.com`

A autenticação utiliza impersonação e credenciais temporárias. Nenhuma chave
JSON foi criada.

## FinOps

- formato colunar Parquet;
- compressão Snappy;
- particionamento por data e lote;
- limite de 1 GiB processado por consulta;
- execução sob demanda durante o desenvolvimento;
- armazenamento e computação desacoplados.

## Validação

A quantidade de registros de cada snapshot foi comparada com a fonte
correspondente.

Consulte os arquivos de validação em:

`docs/evidencias/etapa-04/`
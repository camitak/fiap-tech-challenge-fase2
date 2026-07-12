#!/usr/bin/env bash

set -Eeuo pipefail

PROJECT_ID="${PROJECT_ID:-fiap-tc-f2-camila-takemoto}"
LOCATION="${LOCATION:-US}"
BUCKET="${BUCKET:-fiap-tc-f2-camila-takemoto-alfabetizacao-bronze}"

TABLES=(
  "alunos"
  "meta_alfabetizacao_brasil"
  "meta_alfabetizacao_municipio"
  "meta_alfabetizacao_uf"
  "municipio"
  "uf"
  "dicionario"
)

# A criação das tabelas é feita com o usuário autenticado.
# Garante que a impersonação não ficou ativa após a exportação.
gcloud config unset auth/impersonate_service_account --quiet || true

for TABLE_NAME in "${TABLES[@]}"; do
  echo "Criando tabela externa ext_${TABLE_NAME}..."

  bq query \
    --quiet \
    --project_id="${PROJECT_ID}" \
    --location="${LOCATION}" \
    --use_legacy_sql=false \
    "
    CREATE OR REPLACE EXTERNAL TABLE
      \`${PROJECT_ID}.alfabetizacao_bronze.ext_${TABLE_NAME}\`
    WITH PARTITION COLUMNS (
      ingestion_date DATE,
      batch_id STRING
    )
    OPTIONS (
      format='PARQUET',
      uris=['gs://${BUCKET}/batch/${TABLE_NAME}/*'],
      hive_partition_uri_prefix='gs://${BUCKET}/batch/${TABLE_NAME}',
      require_hive_partition_filter=true
    );
    "

  echo "Tabela criada: ext_${TABLE_NAME}"
done

echo "Todas as tabelas externas foram criadas."
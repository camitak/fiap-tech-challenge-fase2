#!/usr/bin/env bash

set -Eeuo pipefail

PROJECT_ID="${PROJECT_ID:-fiap-tc-f2-camila-takemoto}"
LOCATION="${LOCATION:-US}"

SOURCE_PROJECT="${SOURCE_PROJECT:-basedosdados}"
SOURCE_DATASET="${SOURCE_DATASET:-br_inep_avaliacao_alfabetizacao}"

: "${INGESTION_DATE:?Execute: source /tmp/fiap_last_batch.env}"
: "${BATCH_ID:?Execute: source /tmp/fiap_last_batch.env}"

TABLES=(
  "alunos"
  "meta_alfabetizacao_brasil"
  "meta_alfabetizacao_municipio"
  "meta_alfabetizacao_uf"
  "municipio"
  "uf"
  "dicionario"
)

printf "%-38s %15s %15s %10s\n" \
  "TABELA" "ORIGEM" "BRONZE" "STATUS"

printf "%-38s %15s %15s %10s\n" \
  "--------------------------------------" \
  "---------------" \
  "---------------" \
  "----------"

HAS_ERROR=0

for TABLE_NAME in "${TABLES[@]}"; do
  SOURCE_ROWS=$(
    bq query \
      --quiet \
      --project_id="${PROJECT_ID}" \
      --location="${LOCATION}" \
      --use_legacy_sql=false \
      --maximum_bytes_billed=1073741824 \
      --format=csv \
      "SELECT COUNT(*) AS quantidade
       FROM \`${SOURCE_PROJECT}.${SOURCE_DATASET}.${TABLE_NAME}\`;" \
      | tail -n 1 \
      | tr -d '\r'
  )

  BRONZE_ROWS=$(
    bq query \
      --quiet \
      --project_id="${PROJECT_ID}" \
      --location="${LOCATION}" \
      --use_legacy_sql=false \
      --maximum_bytes_billed=1073741824 \
      --format=csv \
      "SELECT COUNT(*) AS quantidade
       FROM \`${PROJECT_ID}.alfabetizacao_bronze.ext_${TABLE_NAME}\`
       WHERE ingestion_date = DATE '${INGESTION_DATE}'
         AND batch_id = '${BATCH_ID}';" \
      | tail -n 1 \
      | tr -d '\r'
  )

  if [[ "${SOURCE_ROWS}" == "${BRONZE_ROWS}" ]]; then
    STATUS="OK"
  else
    STATUS="ERRO"
    HAS_ERROR=1
  fi

  printf "%-38s %15s %15s %10s\n" \
    "${TABLE_NAME}" \
    "${SOURCE_ROWS}" \
    "${BRONZE_ROWS}" \
    "${STATUS}"
done

exit "${HAS_ERROR}"
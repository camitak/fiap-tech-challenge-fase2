#!/usr/bin/env bash

set -Eeuo pipefail

# -------------------------------------------------------------------
# Configuração
# -------------------------------------------------------------------

PROJECT_ID="${PROJECT_ID:-fiap-tc-f2-camila-takemoto}"
LOCATION="${LOCATION:-US}"
BUCKET="${BUCKET:-fiap-tc-f2-camila-takemoto-alfabetizacao-bronze}"

SOURCE_PROJECT="${SOURCE_PROJECT:-basedosdados}"
SOURCE_DATASET="${SOURCE_DATASET:-br_inep_avaliacao_alfabetizacao}"

SA_BATCH="${SA_BATCH:-sa-batch-ingestion@${PROJECT_ID}.iam.gserviceaccount.com}"

TABLES=(
  "alunos"
  "meta_alfabetizacao_brasil"
  "meta_alfabetizacao_municipio"
  "meta_alfabetizacao_uf"
  "municipio"
  "uf"
  "dicionario"
)

# -------------------------------------------------------------------
# Identificação da execução
# -------------------------------------------------------------------

INGESTION_TIMESTAMP="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
INGESTION_DATE="${INGESTION_TIMESTAMP:0:10}"
BATCH_ID="batch_$(date -u +'%Y%m%dT%H%M%SZ')"

echo "============================================================"
echo "Iniciando ingestão batch"
echo "Projeto:          ${PROJECT_ID}"
echo "Origem:           ${SOURCE_PROJECT}.${SOURCE_DATASET}"
echo "Bucket:           gs://${BUCKET}"
echo "Data de ingestão: ${INGESTION_DATE}"
echo "Batch ID:         ${BATCH_ID}"
echo "============================================================"

# -------------------------------------------------------------------
# Executar os comandos bq como a conta de serviço batch
# -------------------------------------------------------------------

cleanup() {
  echo "Removendo impersonação da configuração local..."
  gcloud config unset auth/impersonate_service_account --quiet || true
}

trap cleanup EXIT

gcloud config set \
  auth/impersonate_service_account \
  "${SA_BATCH}" \
  --quiet

# -------------------------------------------------------------------
# Exportação das fontes
# -------------------------------------------------------------------

for TABLE_NAME in "${TABLES[@]}"; do
  TARGET_URI="gs://${BUCKET}/batch/${TABLE_NAME}/ingestion_date=${INGESTION_DATE}/batch_id=${BATCH_ID}/part-*.parquet"

  echo
  echo "Exportando: ${TABLE_NAME}"
  echo "Destino:    ${TARGET_URI}"

  SQL=$(cat <<EOF
EXPORT DATA OPTIONS(
  uri='${TARGET_URI}',
  format='PARQUET',
  compression='SNAPPY',
  overwrite=false
) AS
SELECT
  source.*,
  TIMESTAMP('${INGESTION_TIMESTAMP}') AS _ingestion_timestamp,
  '${BATCH_ID}' AS _batch_id,
  '${SOURCE_PROJECT}.${SOURCE_DATASET}.${TABLE_NAME}' AS _source_table
FROM
  \`${SOURCE_PROJECT}.${SOURCE_DATASET}.${TABLE_NAME}\` AS source;
EOF
)

  bq query \
    --quiet \
    --project_id="${PROJECT_ID}" \
    --location="${LOCATION}" \
    --use_legacy_sql=false \
    --maximum_bytes_billed=1073741824 \
    "${SQL}"

  echo "Exportação concluída: ${TABLE_NAME}"
done

# -------------------------------------------------------------------
# Guardar as variáveis da última execução
# -------------------------------------------------------------------

cat > /tmp/fiap_last_batch.env <<EOF
export INGESTION_DATE="${INGESTION_DATE}"
export INGESTION_TIMESTAMP="${INGESTION_TIMESTAMP}"
export BATCH_ID="${BATCH_ID}"
EOF

echo
echo "============================================================"
echo "Ingestão concluída"
echo "INGESTION_DATE=${INGESTION_DATE}"
echo "BATCH_ID=${BATCH_ID}"
echo
echo "Para carregar as variáveis desta execução:"
echo "source /tmp/fiap_last_batch.env"
echo "============================================================"
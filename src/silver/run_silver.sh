#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ID="${PROJECT_ID:-fiap-tc-f2-camila-takemoto}"
LOCATION="${LOCATION:-US}"
SA_BATCH="${SA_BATCH:-sa-batch-ingestion@${PROJECT_ID}.iam.gserviceaccount.com}"
INGESTION_DATE="${INGESTION_DATE:?Defina INGESTION_DATE}"
BATCH_ID="${BATCH_ID:?Defina BATCH_ID}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE_SQL="${ROOT_DIR}/sql/silver/build_silver.sql"
RENDERED_SQL="/tmp/build_silver_${BATCH_ID}.sql"

sed \
  -e "s/__PROJECT_ID__/${PROJECT_ID}/g" \
  -e "s/__INGESTION_DATE__/${INGESTION_DATE}/g" \
  -e "s/__BATCH_ID__/${BATCH_ID}/g" \
  "${SOURCE_SQL}" > "${RENDERED_SQL}"

cleanup() {
  gcloud config unset auth/impersonate_service_account --quiet || true
  rm -f "${RENDERED_SQL}"
}
trap cleanup EXIT

gcloud config set auth/impersonate_service_account "${SA_BATCH}" --quiet

bq query \
  --project_id="${PROJECT_ID}" \
  --location="${LOCATION}" \
  --use_legacy_sql=false \
  --maximum_bytes_billed=5368709120 \
  < "${RENDERED_SQL}"

echo "Camada Silver construída para ${INGESTION_DATE} / ${BATCH_ID}."

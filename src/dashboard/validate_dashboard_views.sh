#!/usr/bin/env bash

set -Eeuo pipefail

PROJECT_ID="${PROJECT_ID:-fiap-tc-f2-camila-takemoto}"
LOCATION="${LOCATION:-US}"
SA_BATCH="${SA_BATCH:-sa-batch-ingestion@${PROJECT_ID}.iam.gserviceaccount.com}"
MAXIMUM_BYTES_BILLED="${MAXIMUM_BYTES_BILLED:-2147483648}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SQL_SOURCE="${REPO_ROOT}/sql/dashboard/validate_dashboard_views.sql"
EVIDENCE_DIR="${REPO_ROOT}/docs/evidencias/etapa-09"
EVIDENCE_FILE="${EVIDENCE_DIR}/validacao_dashboard.txt"

if [[ ! -f "${SQL_SOURCE}" ]]; then
  echo "Arquivo SQL não encontrado: ${SQL_SOURCE}" >&2
  exit 1
fi

REQUIRED_VIEWS=(
  "vw_dashboard_resumo_nacional"
  "vw_dashboard_uf"
  "vw_dashboard_municipio"
  "vw_dashboard_streaming"
  "vw_dashboard_operacao"
  "vw_dashboard_bigquery_uso_diario"
)

MISSING=0

for VIEW_NAME in "${REQUIRED_VIEWS[@]}"; do
  if ! bq show \
    --quiet \
    "${PROJECT_ID}:alfabetizacao_gold.${VIEW_NAME}" \
    >/dev/null 2>&1; then
    echo "View ausente: ${VIEW_NAME}" >&2
    MISSING=1
  fi
done

if [[ "${MISSING}" -ne 0 ]]; then
  echo "Execute src/dashboard/run_dashboard_views.sh antes da validação." >&2
  exit 1
fi

mkdir -p "${EVIDENCE_DIR}"

RENDERED_SQL="$(mktemp "/tmp/validate_dashboard_${PROJECT_ID}_XXXXXX.sql")"
sed "s/__PROJECT_ID__/${PROJECT_ID}/g" "${SQL_SOURCE}" > "${RENDERED_SQL}"

cleanup() {
  gcloud config unset auth/impersonate_service_account --quiet || true
  rm -f "${RENDERED_SQL}"
}

trap cleanup EXIT

gcloud config set \
  auth/impersonate_service_account \
  "${SA_BATCH}" \
  --quiet

bq query \
  --quiet \
  --project_id="${PROJECT_ID}" \
  --location="${LOCATION}" \
  --use_legacy_sql=false \
  --maximum_bytes_billed="${MAXIMUM_BYTES_BILLED}" \
  < "${RENDERED_SQL}"

gcloud config unset auth/impersonate_service_account --quiet || true

bq query \
  --project_id="${PROJECT_ID}" \
  --location="${LOCATION}" \
  --use_legacy_sql=false \
  "
  SELECT *
  FROM \`${PROJECT_ID}.alfabetizacao_ops.latest_dashboard_validation\`
  ORDER BY check_type, object_name;
  " | tee "${EVIDENCE_FILE}"

ERROR_COUNT="$(
  bq query \
    --quiet \
    --project_id="${PROJECT_ID}" \
    --location="${LOCATION}" \
    --use_legacy_sql=false \
    --format=csv \
    "
    SELECT COUNT(*) AS quantidade
    FROM \`${PROJECT_ID}.alfabetizacao_ops.latest_dashboard_validation\`
    WHERE status != 'OK';
    " \
    | tail -n 1 \
    | tr -d '\r'
)"

if [[ "${ERROR_COUNT}" != "0" ]]; then
  echo "Validação do dashboard encontrou ${ERROR_COUNT} falha(s)." >&2
  exit 1
fi

echo "Validação das views do dashboard concluída sem falhas."

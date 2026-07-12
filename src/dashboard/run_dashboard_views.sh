#!/usr/bin/env bash

set -Eeuo pipefail

PROJECT_ID="${PROJECT_ID:-fiap-tc-f2-camila-takemoto}"
LOCATION="${LOCATION:-US}"
SA_BATCH="${SA_BATCH:-sa-batch-ingestion@${PROJECT_ID}.iam.gserviceaccount.com}"
MAXIMUM_BYTES_BILLED="${MAXIMUM_BYTES_BILLED:-2147483648}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SQL_SOURCE="${REPO_ROOT}/sql/dashboard/create_dashboard_views.sql"

if [[ ! -f "${SQL_SOURCE}" ]]; then
  echo "Arquivo SQL não encontrado: ${SQL_SOURCE}" >&2
  exit 1
fi

REQUIRED_OBJECTS=(
  "${PROJECT_ID}:alfabetizacao_gold.resumo_executivo"
  "${PROJECT_ID}:alfabetizacao_gold.kpi_uf"
  "${PROJECT_ID}:alfabetizacao_gold.kpi_municipio"
  "${PROJECT_ID}:alfabetizacao_gold.vw_streaming_eventos_resumo"
  "${PROJECT_ID}:alfabetizacao_ops.streaming_latency_summary"
  "${PROJECT_ID}:alfabetizacao_ops.vw_pipeline_health_latest"
  "${PROJECT_ID}:alfabetizacao_ops.bigquery_usage_daily"
)

echo "Validando dependências do dashboard..."
for OBJECT in "${REQUIRED_OBJECTS[@]}"; do
  if ! bq show --quiet "${OBJECT}" >/dev/null 2>&1; then
    echo "Dependência ausente: ${OBJECT}" >&2
    exit 1
  fi
done

RENDERED_SQL="$(mktemp "/tmp/create_dashboard_${PROJECT_ID}_XXXXXX.sql")"
sed "s/__PROJECT_ID__/${PROJECT_ID}/g" "${SQL_SOURCE}" > "${RENDERED_SQL}"

SUCCESS=0

cleanup() {
  gcloud config unset auth/impersonate_service_account --quiet || true

  if [[ "${SUCCESS}" -eq 1 ]]; then
    rm -f "${RENDERED_SQL}"
  else
    echo "SQL preservado em: ${RENDERED_SQL}" >&2
  fi
}

trap cleanup EXIT

gcloud config set \
  auth/impersonate_service_account \
  "${SA_BATCH}" \
  --quiet

echo "Criando views de consumo do dashboard..."
echo "SQL renderizado: ${RENDERED_SQL}"

if ! bq query \
  --quiet \
  --project_id="${PROJECT_ID}" \
  --location="${LOCATION}" \
  --use_legacy_sql=false \
  --maximum_bytes_billed="${MAXIMUM_BYTES_BILLED}" \
  < "${RENDERED_SQL}"; then
  echo "Falha na criação das views do dashboard." >&2
  exit 1
fi

SUCCESS=1
echo "Views do dashboard criadas com sucesso."

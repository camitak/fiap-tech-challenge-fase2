#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ID="${PROJECT_ID:-fiap-tc-f2-camila-takemoto}"
LOCATION="${LOCATION:-US}"
SA_BATCH="${SA_BATCH:-sa-batch-ingestion@${PROJECT_ID}.iam.gserviceaccount.com}"
MAXIMUM_BYTES_BILLED="${MAXIMUM_BYTES_BILLED:-1073741824}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SQL_FILE="${REPO_ROOT}/sql/ops/validate_observability.sql"
EVIDENCE_DIR="${REPO_ROOT}/docs/evidencias/etapa-08"
OUTPUT_FILE="${EVIDENCE_DIR}/validacao_observabilidade.txt"

mkdir -p "${EVIDENCE_DIR}"
[[ -f "${SQL_FILE}" ]] || {
  echo "Arquivo SQL ausente: ${SQL_FILE}" >&2
  exit 1
}

REQUIRED_OBJECTS=(
  silver_validation_history
  gold_validation_history
  streaming_validation_history
  pipeline_health_history
  streaming_latency_summary
  bigquery_usage_daily
  vw_pipeline_health_latest
  vw_quality_failures
  vw_bigquery_usage_summary
)

MISSING_OBJECTS=()
for OBJECT_NAME in "${REQUIRED_OBJECTS[@]}"; do
  if ! bq show \
    --project_id="${PROJECT_ID}" \
    "${PROJECT_ID}:alfabetizacao_ops.${OBJECT_NAME}" \
    >/dev/null 2>&1; then
    MISSING_OBJECTS+=("${OBJECT_NAME}")
  fi
done

if (( ${#MISSING_OBJECTS[@]} > 0 )); then
  echo "Objetos de observabilidade ausentes:" >&2
  printf '  - %s\n' "${MISSING_OBJECTS[@]}" >&2
  echo "Execute novamente ./src/ops/run_observability.sh antes da validação." >&2
  exit 1
fi

RENDERED_SQL="$(mktemp "/tmp/validate_observability_${PROJECT_ID}_XXXXXX.sql")"

cleanup() {
  gcloud config unset auth/impersonate_service_account --quiet || true
  rm -f "${RENDERED_SQL}"
}
trap cleanup EXIT

sed "s/__PROJECT_ID__/${PROJECT_ID}/g" "${SQL_FILE}" > "${RENDERED_SQL}"

gcloud config set auth/impersonate_service_account "${SA_BATCH}" --quiet

bq query \
  --quiet \
  --project_id="${PROJECT_ID}" \
  --location="${LOCATION}" \
  --use_legacy_sql=false \
  --maximum_bytes_billed="${MAXIMUM_BYTES_BILLED}" \
  < "${RENDERED_SQL}"

gcloud config unset auth/impersonate_service_account --quiet || true

bq show \
  --project_id="${PROJECT_ID}" \
  "${PROJECT_ID}:alfabetizacao_ops.latest_ops_validation" \
  >/dev/null 2>&1 || {
    echo "A tabela latest_ops_validation não foi criada." >&2
    exit 1
  }

bq query \
  --project_id="${PROJECT_ID}" \
  --location="${LOCATION}" \
  --use_legacy_sql=false \
  --format=pretty \
  "
  SELECT *
  FROM \`${PROJECT_ID}.alfabetizacao_ops.latest_ops_validation\`
  ORDER BY check_type, object_name;
  " | tee "${OUTPUT_FILE}"

ERROR_COUNT="$(
  bq query \
    --quiet \
    --project_id="${PROJECT_ID}" \
    --location="${LOCATION}" \
    --use_legacy_sql=false \
    --format=csv \
    "
    SELECT COUNT(*) AS error_count
    FROM \`${PROJECT_ID}.alfabetizacao_ops.latest_ops_validation\`
    WHERE status != 'OK';
    " | tail -n 1 | tr -d '\r'
)"

[[ "${ERROR_COUNT}" == "0" ]] || {
  echo "Foram encontradas ${ERROR_COUNT} falha(s)." >&2
  exit 1
}

echo "Validação da observabilidade concluída sem falhas."
echo "Evidência: ${OUTPUT_FILE}"

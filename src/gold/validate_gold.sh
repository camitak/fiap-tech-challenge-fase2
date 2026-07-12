#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ID="${PROJECT_ID:-fiap-tc-f2-camila-takemoto}"
LOCATION="${LOCATION:-US}"
SA_BATCH="${SA_BATCH:-sa-batch-ingestion@${PROJECT_ID}.iam.gserviceaccount.com}"
MAXIMUM_BYTES_BILLED="${MAXIMUM_BYTES_BILLED:-5368709120}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE_SQL="${ROOT_DIR}/sql/gold/validate_gold.sql"
RENDERED_SQL="$(mktemp "/tmp/validate_gold_${PROJECT_ID}_XXXXXX.sql")"
OUTPUT_FILE="${ROOT_DIR}/docs/evidencias/etapa-06/validacao_gold.txt"

REQUIRED_TABLES=(
  "kpi_brasil"
  "kpi_uf"
  "kpi_municipio"
  "cobertura_integracao"
  "distribuicao_niveis_uf"
  "resumo_executivo"
  "features_modelo_municipio"
)

cleanup() {
  local exit_code=$?

  gcloud config unset auth/impersonate_service_account --quiet || true

  if [[ ${exit_code} -eq 0 ]]; then
    rm -f "${RENDERED_SQL}"
  else
    echo "SQL de validação preservado para diagnóstico em: ${RENDERED_SQL}" >&2
  fi

  trap - EXIT
  exit "${exit_code}"
}
trap cleanup EXIT

mkdir -p "$(dirname "${OUTPUT_FILE}")"

if [[ ! -f "${SOURCE_SQL}" ]]; then
  echo "Arquivo SQL não encontrado: ${SOURCE_SQL}" >&2
  exit 1
fi

sed -e "s/__PROJECT_ID__/${PROJECT_ID}/g" \
  "${SOURCE_SQL}" > "${RENDERED_SQL}"

if grep -q '__PROJECT_ID__' "${RENDERED_SQL}"; then
  echo "O SQL renderizado ainda contém o placeholder __PROJECT_ID__." >&2
  exit 1
fi

gcloud config set auth/impersonate_service_account "${SA_BATCH}" --quiet

for table_name in "${REQUIRED_TABLES[@]}"; do
  if ! bq show \
    --project_id="${PROJECT_ID}" \
    --format=prettyjson \
    "${PROJECT_ID}:alfabetizacao_gold.${table_name}" >/dev/null 2>&1; then
    echo "Tabela Gold ausente: ${PROJECT_ID}.alfabetizacao_gold.${table_name}" >&2
    echo "Execute ./src/gold/run_gold.sh antes da validação." >&2
    exit 1
  fi
done

bq query \
  --project_id="${PROJECT_ID}" \
  --location="${LOCATION}" \
  --use_legacy_sql=false \
  --maximum_bytes_billed="${MAXIMUM_BYTES_BILLED}" \
  --format=pretty \
  < "${RENDERED_SQL}" | tee "${OUTPUT_FILE}"

FAIL_COUNT="$(bq query \
  --quiet \
  --project_id="${PROJECT_ID}" \
  --location="${LOCATION}" \
  --use_legacy_sql=false \
  --format=csv \
  "SELECT COUNTIF(status='FAIL') FROM \`${PROJECT_ID}.alfabetizacao_ops.latest_gold_validation\`" \
  | tail -n 1 | tr -d '\r')"

if [[ "${FAIL_COUNT}" != "0" ]]; then
  echo "Validação Gold falhou em ${FAIL_COUNT} teste(s)." >&2
  exit 1
fi

echo "Validação Gold concluída sem falhas."

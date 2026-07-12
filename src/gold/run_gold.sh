#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ID="${PROJECT_ID:-fiap-tc-f2-camila-takemoto}"
LOCATION="${LOCATION:-US}"
SA_BATCH="${SA_BATCH:-sa-batch-ingestion@${PROJECT_ID}.iam.gserviceaccount.com}"
MAXIMUM_BYTES_BILLED="${MAXIMUM_BYTES_BILLED:-5368709120}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE_SQL="${ROOT_DIR}/sql/gold/build_gold.sql"
RENDERED_SQL="$(mktemp "/tmp/build_gold_${PROJECT_ID}_XXXXXX.sql")"

cleanup() {
  local exit_code=$?

  gcloud config unset auth/impersonate_service_account --quiet || true

  if [[ ${exit_code} -eq 0 ]]; then
    rm -f "${RENDERED_SQL}"
  else
    echo >&2
    echo "A construção da Gold falhou." >&2
    echo "SQL renderizado preservado para diagnóstico em: ${RENDERED_SQL}" >&2
    echo "As tabelas anteriores ao ponto da falha podem ter sido criadas." >&2
    echo "É seguro corrigir e executar novamente, pois o script usa CREATE OR REPLACE TABLE." >&2
  fi

  trap - EXIT
  exit "${exit_code}"
}
trap cleanup EXIT

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

echo "============================================================"
echo "Construção da camada Gold"
echo "Projeto: ${PROJECT_ID}"
echo "Localização: ${LOCATION}"
echo "Conta de serviço: ${SA_BATCH}"
echo "Limite de bytes: ${MAXIMUM_BYTES_BILLED}"
echo "============================================================"

gcloud config set auth/impersonate_service_account "${SA_BATCH}" --quiet

bq query \
  --project_id="${PROJECT_ID}" \
  --location="${LOCATION}" \
  --use_legacy_sql=false \
  --maximum_bytes_billed="${MAXIMUM_BYTES_BILLED}" \
  < "${RENDERED_SQL}"

echo "Camada Gold construída com sucesso."

#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ID="${PROJECT_ID:-fiap-tc-f2-camila-takemoto}"
LOCATION="${LOCATION:-US}"
SA_BATCH="${SA_BATCH:-sa-batch-ingestion@${PROJECT_ID}.iam.gserviceaccount.com}"
MAXIMUM_BYTES_BILLED="${MAXIMUM_BYTES_BILLED:-5368709120}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SQL_FILE="${REPO_ROOT}/sql/ops/build_observability.sql"

[[ -f "${SQL_FILE}" ]] || { echo "Arquivo SQL ausente: ${SQL_FILE}" >&2; exit 1; }

LOCATION_LOWER="$(printf '%s' "${LOCATION}" | tr '[:upper:]' '[:lower:]')"
REGION_QUALIFIER="region-${LOCATION_LOWER}"
RENDERED_SQL="$(mktemp "/tmp/build_observability_${PROJECT_ID}_XXXXXX.sql")"

cleanup() {
  gcloud config unset auth/impersonate_service_account --quiet || true
}
trap cleanup EXIT

sed \
  -e "s/__PROJECT_ID__/${PROJECT_ID}/g" \
  -e "s/__REGION_QUALIFIER__/${REGION_QUALIFIER}/g" \
  "${SQL_FILE}" > "${RENDERED_SQL}"

if grep -qE "__PROJECT_ID__|__REGION_QUALIFIER__" "${RENDERED_SQL}"; then
  echo "Falha ao substituir placeholders em ${RENDERED_SQL}" >&2
  exit 1
fi

gcloud config set auth/impersonate_service_account "${SA_BATCH}" --quiet

echo "Construindo observabilidade..."
echo "SQL renderizado: ${RENDERED_SQL}"

if ! bq query \
  --quiet \
  --project_id="${PROJECT_ID}" \
  --location="${LOCATION}" \
  --use_legacy_sql=false \
  --maximum_bytes_billed="${MAXIMUM_BYTES_BILLED}" \
  < "${RENDERED_SQL}"; then
  echo "Falha na construção da observabilidade." >&2
  echo "SQL preservado em: ${RENDERED_SQL}" >&2
  exit 1
fi

rm -f "${RENDERED_SQL}"
echo "Observabilidade construída com sucesso."

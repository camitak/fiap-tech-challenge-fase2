#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ID="${PROJECT_ID:-fiap-tc-f2-camila-takemoto}"
LOCATION="${LOCATION:-US}"
SA_BATCH="${SA_BATCH:-sa-batch-ingestion@${PROJECT_ID}.iam.gserviceaccount.com}"
MAXIMUM_BYTES_BILLED="${MAXIMUM_BYTES_BILLED:-5368709120}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SQL_FILE="${REPO_ROOT}/sql/ops/build_observability.sql"

[[ -f "${SQL_FILE}" ]] || {
  echo "Arquivo SQL ausente: ${SQL_FILE}" >&2
  exit 1
}

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

if grep -qE '__PROJECT_ID__|__REGION_QUALIFIER__' "${RENDERED_SQL}"; then
  echo "Falha ao substituir placeholders em ${RENDERED_SQL}" >&2
  exit 1
fi

gcloud config set auth/impersonate_service_account "${SA_BATCH}" --quiet

# Falha antes de alterar objetos caso a conta não consiga consultar
# os metadados de jobs do projeto na localização escolhida.
echo "Validando acesso ao INFORMATION_SCHEMA.JOBS_BY_PROJECT..."
if ! bq query \
  --quiet \
  --project_id="${PROJECT_ID}" \
  --location="${LOCATION}" \
  --use_legacy_sql=false \
  --maximum_bytes_billed="${MAXIMUM_BYTES_BILLED}" \
  "
  SELECT COUNT(*) AS quantidade_jobs
  FROM \`${PROJECT_ID}\`.\`${REGION_QUALIFIER}\`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
  WHERE creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)
    AND job_type = 'QUERY';
  " >/dev/null; then
  echo "Falha no acesso ao histórico de jobs do BigQuery." >&2
  echo "Confirme os papéis roles/bigquery.jobUser e roles/bigquery.resourceViewer para ${SA_BATCH}." >&2
  echo "Localização usada: ${LOCATION}; qualificador: ${REGION_QUALIFIER}." >&2
  echo "Nenhuma nova construção de observabilidade foi iniciada." >&2
  exit 1
fi

# A Silver não armazena pubsub_publish_time. Esse metadado fica na Bronze
# e é associado pelo par simulation_run_id + event_id.
echo "Validando dependências das métricas de latência streaming..."
MISSING_PUBLISH_TIME="$(
  bq query \
    --quiet \
    --project_id="${PROJECT_ID}" \
    --location="${LOCATION}" \
    --use_legacy_sql=false \
    --maximum_bytes_billed="${MAXIMUM_BYTES_BILLED}" \
    --format=csv \
    "
    WITH bronze_publish_time AS (
      SELECT
        simulation_run_id,
        event_id,
        MIN(pubsub_publish_time) AS pubsub_publish_time
      FROM \`${PROJECT_ID}.alfabetizacao_bronze.streaming_eventos_raw\`
      WHERE simulation_run_id IS NOT NULL
        AND event_id IS NOT NULL
      GROUP BY simulation_run_id, event_id
    )
    SELECT COUNTIF(bronze.pubsub_publish_time IS NULL) AS missing_publish_time
    FROM \`${PROJECT_ID}.alfabetizacao_silver.streaming_eventos\` AS silver
    LEFT JOIN bronze_publish_time AS bronze
      USING (simulation_run_id, event_id);
    " | tail -n 1 | tr -d '\r'
)"

if [[ ! "${MISSING_PUBLISH_TIME}" =~ ^[0-9]+$ ]]; then
  echo "Não foi possível interpretar a validação de pubsub_publish_time: ${MISSING_PUBLISH_TIME}" >&2
  exit 1
fi

if (( MISSING_PUBLISH_TIME > 0 )); then
  echo "Foram encontrados ${MISSING_PUBLISH_TIME} evento(s) Silver sem pubsub_publish_time correspondente na Bronze." >&2
  echo "A construção foi interrompida antes de alterar novos objetos." >&2
  exit 1
fi

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
  echo "Objetos anteriores à instrução que falhou podem ter sido criados ou atualizados." >&2
  exit 1
fi

rm -f "${RENDERED_SQL}"
echo "Observabilidade construída com sucesso."

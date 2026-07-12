#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ID="${PROJECT_ID:-fiap-tc-f2-camila-takemoto}"
LOCATION="${LOCATION:-US}"
DLQ_SUBSCRIPTION_ID="${DLQ_SUBSCRIPTION_ID:-alfabetizacao-eventos-dlq-sub}"
MAXIMUM_BYTES_BILLED="${MAXIMUM_BYTES_BILLED:-1073741824}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE_SQL="${ROOT_DIR}/sql/streaming/validate_streaming.sql"
EVIDENCE_DIR="${ROOT_DIR}/docs/evidencias/etapa-07"

if [[ ! -f /tmp/fiap_simulation.env ]]; then
  echo "Arquivo /tmp/fiap_simulation.env ausente. Execute run_simulator.sh." >&2
  exit 1
fi
# shellcheck disable=SC1091
source /tmp/fiap_simulation.env

: "${SIMULATION_RUN_ID:?SIMULATION_RUN_ID ausente}"
: "${EXPECTED_VALID:?EXPECTED_VALID ausente}"
: "${EXPECTED_INVALID:?EXPECTED_INVALID ausente}"
: "${EXPECTED_TOTAL:?EXPECTED_TOTAL ausente}"

mkdir -p "${EVIDENCE_DIR}"
RENDERED_SQL="$(mktemp "/tmp/validate_streaming_${SIMULATION_RUN_ID}_XXXXXX.sql")"
OUTPUT_FILE="${EVIDENCE_DIR}/validacao_streaming_${SIMULATION_RUN_ID}.txt"
DLQ_OUTPUT_FILE="${EVIDENCE_DIR}/dlq_${SIMULATION_RUN_ID}.json"

cleanup() {
  local exit_code=$?
  if [[ ${exit_code} -eq 0 ]]; then
    rm -f "${RENDERED_SQL}"
  else
    echo "SQL renderizado preservado em: ${RENDERED_SQL}" >&2
  fi
  trap - EXIT
  exit "${exit_code}"
}
trap cleanup EXIT

# Aguarda a visibilidade dos eventos no BigQuery por até 8 minutos.
for _ in $(seq 1 48); do
  ACTUAL_TOTAL="$(bq query \
    --quiet \
    --project_id="${PROJECT_ID}" \
    --location="${LOCATION}" \
    --use_legacy_sql=false \
    --format=csv \
    "SELECT COUNT(*) FROM \`${PROJECT_ID}.alfabetizacao_bronze.streaming_eventos_raw\` WHERE simulation_run_id='${SIMULATION_RUN_ID}'" \
    | tail -n 1 | tr -d '\r')"
  echo "Eventos Bronze visíveis: ${ACTUAL_TOTAL}/${EXPECTED_TOTAL}"
  if [[ "${ACTUAL_TOTAL}" -ge "${EXPECTED_TOTAL}" ]]; then
    break
  fi
  sleep 10
done

sed \
  -e "s/__PROJECT_ID__/${PROJECT_ID}/g" \
  -e "s/__SIMULATION_RUN_ID__/${SIMULATION_RUN_ID}/g" \
  -e "s/__EXPECTED_VALID__/${EXPECTED_VALID}/g" \
  -e "s/__EXPECTED_INVALID__/${EXPECTED_INVALID}/g" \
  -e "s/__EXPECTED_TOTAL__/${EXPECTED_TOTAL}/g" \
  "${SOURCE_SQL}" > "${RENDERED_SQL}"

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
  "SELECT COUNTIF(status='FAIL') FROM \`${PROJECT_ID}.alfabetizacao_ops.latest_streaming_validation\`" \
  | tail -n 1 | tr -d '\r')"

# Lê e confirma as mensagens de erro da assinatura DLQ para evidência textual.
gcloud pubsub subscriptions pull "${DLQ_SUBSCRIPTION_ID}" \
  --project="${PROJECT_ID}" \
  --limit=100 \
  --auto-ack \
  --format=json > "${DLQ_OUTPUT_FILE}" || true

if [[ "${FAIL_COUNT}" != "0" ]]; then
  echo "Validação streaming falhou em ${FAIL_COUNT} teste(s)." >&2
  exit 1
fi

echo "Validação streaming concluída sem falhas."
echo "Evidência: ${OUTPUT_FILE}"
echo "Mensagens DLQ: ${DLQ_OUTPUT_FILE}"
echo "Agora drene o Dataflow: ./src/streaming/stop_streaming.sh"

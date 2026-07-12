#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ID="${PROJECT_ID:-fiap-tc-f2-camila-takemoto}"
BUCKET="${BUCKET:-fiap-tc-f2-camila-takemoto-alfabetizacao-bronze}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EVIDENCE_DIR="${ROOT_DIR}/docs/evidencias/etapa-07"

if [[ ! -f /tmp/fiap_streaming.env ]]; then
  echo "Arquivo /tmp/fiap_streaming.env ausente." >&2
  echo "Localize o job com: gcloud dataflow jobs list --region=us-central1" >&2
  exit 1
fi
# shellcheck disable=SC1091
source /tmp/fiap_streaming.env

: "${DATAFLOW_JOB_ID:?DATAFLOW_JOB_ID ausente}"
: "${DATAFLOW_JOB_NAME:?DATAFLOW_JOB_NAME ausente}"
: "${DATAFLOW_REGION:?DATAFLOW_REGION ausente}"

STATE="$(gcloud dataflow jobs describe "${DATAFLOW_JOB_ID}" \
  --project="${PROJECT_ID}" \
  --region="${DATAFLOW_REGION}" \
  --format='value(currentState)')"

echo "Estado atual: ${STATE}"

if [[ "${STATE}" == "JOB_STATE_RUNNING" ]]; then
  gcloud dataflow jobs drain "${DATAFLOW_JOB_ID}" \
    --project="${PROJECT_ID}" \
    --region="${DATAFLOW_REGION}" \
    --quiet
fi

for _ in $(seq 1 90); do
  STATE="$(gcloud dataflow jobs describe "${DATAFLOW_JOB_ID}" \
    --project="${PROJECT_ID}" \
    --region="${DATAFLOW_REGION}" \
    --format='value(currentState)')"
  echo "Estado do Dataflow: ${STATE}"
  if [[ "${STATE}" == "JOB_STATE_DRAINED" || "${STATE}" == "JOB_STATE_CANCELLED" || "${STATE}" == "JOB_STATE_DONE" ]]; then
    break
  fi
  if [[ "${STATE}" == "JOB_STATE_FAILED" ]]; then
    echo "O job terminou como FAILED. Consulte os logs." >&2
    break
  fi
  sleep 10
done

STOPPED_AT="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
mkdir -p "${EVIDENCE_DIR}"
cat > "${EVIDENCE_DIR}/dataflow_stop_${DATAFLOW_JOB_NAME}.txt" <<EOF
job_id=${DATAFLOW_JOB_ID}
job_name=${DATAFLOW_JOB_NAME}
region=${DATAFLOW_REGION}
final_state=${STATE}
stopped_at=${STOPPED_AT}
EOF

if [[ "${STATE}" == "JOB_STATE_DRAINED" || "${STATE}" == "JOB_STATE_CANCELLED" || "${STATE}" == "JOB_STATE_DONE" ]]; then
  gcloud storage rm --recursive "${DATAFLOW_STAGING_LOCATION}/**" || true
  gcloud storage rm --recursive "${DATAFLOW_TEMP_LOCATION}/**" || true
fi

cat <<EOF
============================================================
Dataflow encerrado.
JOB_ID=${DATAFLOW_JOB_ID}
FINAL_STATE=${STATE}
STOPPED_AT=${STOPPED_AT}

Confirme que não há job ativo:
gcloud dataflow jobs list --region=${DATAFLOW_REGION} --status=active
============================================================
EOF

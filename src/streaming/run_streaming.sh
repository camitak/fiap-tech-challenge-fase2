#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ID="${PROJECT_ID:-fiap-tc-f2-camila-takemoto}"
DATAFLOW_REGION="${DATAFLOW_REGION:-us-central1}"
BUCKET="${BUCKET:-fiap-tc-f2-camila-takemoto-alfabetizacao-bronze}"
SA_STREAMING="${SA_STREAMING:-sa-streaming-dataflow@${PROJECT_ID}.iam.gserviceaccount.com}"
SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-alfabetizacao-eventos-dataflow}"
DLQ_TOPIC_ID="${DLQ_TOPIC_ID:-alfabetizacao-eventos-dlq}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VENV_DIR="${ROOT_DIR}/.venv-streaming"
REQUIREMENTS_FILE="${ROOT_DIR}/src/streaming/requirements.txt"
PIPELINE_FILE="${ROOT_DIR}/src/streaming/pipeline.py"
EVIDENCE_DIR="${ROOT_DIR}/docs/evidencias/etapa-07"

JOB_NAME="${JOB_NAME:-alfabetizacao-stream-$(date -u +'%Y%m%d-%H%M%S')}"
STAGING_LOCATION="gs://${BUCKET}/dataflow/staging/${JOB_NAME}"
TEMP_LOCATION="gs://${BUCKET}/dataflow/temp/${JOB_NAME}"

mkdir -p "${EVIDENCE_DIR}"

if [[ ! -d "${VENV_DIR}" ]]; then
  python3 -m venv "${VENV_DIR}"
fi

# shellcheck disable=SC1091
source "${VENV_DIR}/bin/activate"
python -m pip install --upgrade pip
python -m pip install -r "${REQUIREMENTS_FILE}"

python "${PIPELINE_FILE}" \
  --runner=DataflowRunner \
  --project="${PROJECT_ID}" \
  --region="${DATAFLOW_REGION}" \
  --job_name="${JOB_NAME}" \
  --staging_location="${STAGING_LOCATION}" \
  --temp_location="${TEMP_LOCATION}" \
  --service_account_email="${SA_STREAMING}" \
  --subscription="projects/${PROJECT_ID}/subscriptions/${SUBSCRIPTION_ID}" \
  --dlq_topic="projects/${PROJECT_ID}/topics/${DLQ_TOPIC_ID}" \
  --bronze_table="${PROJECT_ID}:alfabetizacao_bronze.streaming_eventos_raw" \
  --silver_table="${PROJECT_ID}:alfabetizacao_silver.streaming_eventos" \
  --quarantine_table="${PROJECT_ID}:alfabetizacao_quarantine.streaming_eventos" \
  --requirements_file="${REQUIREMENTS_FILE}" \
  --streaming \
  --num_workers=1 \
  --max_num_workers=1 \
  --autoscaling_algorithm=NONE \
  --machine_type=e2-standard-2 \
  --disk_size_gb=30 \
  --save_main_session

JOB_ID=""
for _ in $(seq 1 30); do
  JOB_ID="$(gcloud dataflow jobs list \
    --project="${PROJECT_ID}" \
    --region="${DATAFLOW_REGION}" \
    --filter="name=${JOB_NAME}" \
    --sort-by='~createTime' \
    --limit=1 \
    --format='value(id)')"
  [[ -n "${JOB_ID}" ]] && break
  sleep 10
done

if [[ -z "${JOB_ID}" ]]; then
  echo "Não foi possível localizar o job Dataflow ${JOB_NAME}." >&2
  exit 1
fi

STATE=""
for _ in $(seq 1 60); do
  STATE="$(gcloud dataflow jobs describe "${JOB_ID}" \
    --project="${PROJECT_ID}" \
    --region="${DATAFLOW_REGION}" \
    --format='value(currentState)')"
  echo "Estado do Dataflow: ${STATE}"
  if [[ "${STATE}" == "JOB_STATE_RUNNING" ]]; then
    break
  fi
  if [[ "${STATE}" == "JOB_STATE_FAILED" || "${STATE}" == "JOB_STATE_CANCELLED" ]]; then
    echo "O Dataflow terminou em estado ${STATE}. Consulte os logs do job." >&2
    exit 1
  fi
  sleep 10
done

if [[ "${STATE}" != "JOB_STATE_RUNNING" ]]; then
  echo "O job não alcançou JOB_STATE_RUNNING dentro do tempo esperado." >&2
  exit 1
fi

STARTED_AT="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
cat > /tmp/fiap_streaming.env <<EOF
export DATAFLOW_JOB_ID="${JOB_ID}"
export DATAFLOW_JOB_NAME="${JOB_NAME}"
export DATAFLOW_REGION="${DATAFLOW_REGION}"
export DATAFLOW_STAGING_LOCATION="${STAGING_LOCATION}"
export DATAFLOW_TEMP_LOCATION="${TEMP_LOCATION}"
export DATAFLOW_STARTED_AT="${STARTED_AT}"
EOF

cat > "${EVIDENCE_DIR}/dataflow_job_${JOB_NAME}.txt" <<EOF
job_id=${JOB_ID}
job_name=${JOB_NAME}
region=${DATAFLOW_REGION}
state=${STATE}
started_at=${STARTED_AT}
worker_service_account=${SA_STREAMING}
num_workers=1
max_num_workers=1
machine_type=e2-standard-2
EOF

cat <<EOF
============================================================
Dataflow em execução.
DATAFLOW_JOB_ID=${JOB_ID}
DATAFLOW_JOB_NAME=${JOB_NAME}
DATAFLOW_REGION=${DATAFLOW_REGION}

Próximo comando:
./src/streaming/run_simulator.sh
============================================================
EOF

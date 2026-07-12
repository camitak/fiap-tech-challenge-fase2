#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ID="${PROJECT_ID:-fiap-tc-f2-camila-takemoto}"
LOCATION="${LOCATION:-US}"
BUCKET="${BUCKET:-fiap-tc-f2-camila-takemoto-alfabetizacao-bronze}"
SA_STREAMING="${SA_STREAMING:-sa-streaming-dataflow@${PROJECT_ID}.iam.gserviceaccount.com}"
USER_ACCOUNT="${USER_ACCOUNT:-$(gcloud config get-value account 2>/dev/null)}"

TOPIC_ID="${TOPIC_ID:-alfabetizacao-eventos}"
SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-alfabetizacao-eventos-dataflow}"
DLQ_TOPIC_ID="${DLQ_TOPIC_ID:-alfabetizacao-eventos-dlq}"
DLQ_SUBSCRIPTION_ID="${DLQ_SUBSCRIPTION_ID:-alfabetizacao-eventos-dlq-sub}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE_SQL="${ROOT_DIR}/sql/streaming/create_streaming_tables.sql"
RENDERED_SQL="$(mktemp "/tmp/create_streaming_${PROJECT_ID}_XXXXXX.sql")"

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

create_topic_if_missing() {
  local topic_id="$1"
  if gcloud pubsub topics describe "${topic_id}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
    echo "Tópico já existe: ${topic_id}"
  else
    gcloud pubsub topics create "${topic_id}" --project="${PROJECT_ID}"
  fi
}

create_topic_if_missing "${TOPIC_ID}"
create_topic_if_missing "${DLQ_TOPIC_ID}"

PROJECT_NUMBER="$(gcloud projects describe "${PROJECT_ID}" --format='value(projectNumber)')"
PUBSUB_SERVICE_AGENT="service-${PROJECT_NUMBER}@gcp-sa-pubsub.iam.gserviceaccount.com"

gcloud pubsub topics add-iam-policy-binding "${DLQ_TOPIC_ID}" \
  --project="${PROJECT_ID}" \
  --member="serviceAccount:${PUBSUB_SERVICE_AGENT}" \
  --role="roles/pubsub.publisher" >/dev/null

if gcloud pubsub subscriptions describe "${SUBSCRIPTION_ID}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
  echo "Assinatura já existe: ${SUBSCRIPTION_ID}"
else
  gcloud pubsub subscriptions create "${SUBSCRIPTION_ID}" \
    --project="${PROJECT_ID}" \
    --topic="${TOPIC_ID}" \
    --ack-deadline=60 \
    --message-retention-duration=7d \
    --dead-letter-topic="projects/${PROJECT_ID}/topics/${DLQ_TOPIC_ID}" \
    --max-delivery-attempts=5
fi

if gcloud pubsub subscriptions describe "${DLQ_SUBSCRIPTION_ID}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
  echo "Assinatura DLQ já existe: ${DLQ_SUBSCRIPTION_ID}"
else
  gcloud pubsub subscriptions create "${DLQ_SUBSCRIPTION_ID}" \
    --project="${PROJECT_ID}" \
    --topic="${DLQ_TOPIC_ID}" \
    --ack-deadline=60 \
    --message-retention-duration=7d
fi

gcloud pubsub subscriptions add-iam-policy-binding "${SUBSCRIPTION_ID}" \
  --project="${PROJECT_ID}" \
  --member="serviceAccount:${PUBSUB_SERVICE_AGENT}" \
  --role="roles/pubsub.subscriber" >/dev/null

gcloud pubsub subscriptions add-iam-policy-binding "${SUBSCRIPTION_ID}" \
  --project="${PROJECT_ID}" \
  --member="serviceAccount:${SA_STREAMING}" \
  --role="roles/pubsub.subscriber" >/dev/null

gcloud pubsub topics add-iam-policy-binding "${DLQ_TOPIC_ID}" \
  --project="${PROJECT_ID}" \
  --member="serviceAccount:${SA_STREAMING}" \
  --role="roles/pubsub.publisher" >/dev/null

gcloud storage buckets add-iam-policy-binding "gs://${BUCKET}" \
  --member="serviceAccount:${SA_STREAMING}" \
  --role="roles/storage.objectAdmin" >/dev/null

gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SA_STREAMING}" \
  --role="roles/dataflow.worker" >/dev/null

gcloud iam service-accounts add-iam-policy-binding "${SA_STREAMING}" \
  --member="user:${USER_ACCOUNT}" \
  --role="roles/iam.serviceAccountUser" >/dev/null

if [[ ! -f "${SOURCE_SQL}" ]]; then
  echo "Arquivo SQL não encontrado: ${SOURCE_SQL}" >&2
  exit 1
fi

sed -e "s/__PROJECT_ID__/${PROJECT_ID}/g" "${SOURCE_SQL}" > "${RENDERED_SQL}"

bq query \
  --project_id="${PROJECT_ID}" \
  --location="${LOCATION}" \
  --use_legacy_sql=false \
  < "${RENDERED_SQL}"

cat <<EOF
============================================================
Infraestrutura streaming preparada.
TOPIC_ID=${TOPIC_ID}
SUBSCRIPTION_ID=${SUBSCRIPTION_ID}
DLQ_TOPIC_ID=${DLQ_TOPIC_ID}
DLQ_SUBSCRIPTION_ID=${DLQ_SUBSCRIPTION_ID}
SA_STREAMING=${SA_STREAMING}

Permissões BigQuery que ainda devem ser confirmadas no Console:
- alfabetizacao_bronze: BigQuery Data Editor para ${SA_STREAMING}
- alfabetizacao_silver: BigQuery Data Editor para ${SA_STREAMING}
- alfabetizacao_quarantine: BigQuery Data Editor para ${SA_STREAMING}
============================================================
EOF

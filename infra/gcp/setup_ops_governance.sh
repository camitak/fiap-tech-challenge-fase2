#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ID="${PROJECT_ID:-fiap-tc-f2-camila-takemoto}"
BUCKET="${BUCKET:-fiap-tc-f2-camila-takemoto-alfabetizacao-bronze}"
SA_BATCH="${SA_BATCH:-sa-batch-ingestion@${PROJECT_ID}.iam.gserviceaccount.com}"
SA_STREAMING="${SA_STREAMING:-sa-streaming-dataflow@${PROJECT_ID}.iam.gserviceaccount.com}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LIFECYCLE_FILE="${SCRIPT_DIR}/storage-lifecycle.json"
POLICY_DIR="${SCRIPT_DIR}/alert-policies"
EVIDENCE_DIR="${REPO_ROOT}/docs/evidencias/etapa-08"

mkdir -p "${EVIDENCE_DIR}"

for REQUIRED_FILE in \
  "${LIFECYCLE_FILE}" \
  "${POLICY_DIR}/pubsub-backlog.json" \
  "${POLICY_DIR}/pubsub-oldest-unacked.json" \
  "${POLICY_DIR}/dataflow-system-lag.json"; do
  [[ -f "${REQUIRED_FILE}" ]] || { echo "Arquivo ausente: ${REQUIRED_FILE}" >&2; exit 1; }
done

gcloud config set project "${PROJECT_ID}" --quiet
gcloud config unset auth/impersonate_service_account --quiet || true

echo "Concedendo BigQuery Resource Viewer à conta batch..."
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SA_BATCH}" \
  --role="roles/bigquery.resourceViewer" \
  --quiet >/dev/null

echo "Protegendo o bucket contra acesso público..."
gcloud storage buckets update "gs://${BUCKET}" \
  --public-access-prevention \
  --quiet

echo "Aplicando lifecycle somente ao prefixo tmp/..."
gcloud storage buckets update "gs://${BUCKET}" \
  --lifecycle-file="${LIFECYCLE_FILE}" \
  --quiet

declare -A DATASET_LAYER=(
  [alfabetizacao_bronze]="bronze"
  [alfabetizacao_silver]="silver"
  [alfabetizacao_gold]="gold"
  [alfabetizacao_quarantine]="quarantine"
  [alfabetizacao_ops]="ops"
)

echo "Adicionando labels aos datasets..."
for DATASET in "${!DATASET_LAYER[@]}"; do
  bq update \
    --project_id="${PROJECT_ID}" \
    --set_label="project:fiap_fase2" \
    --set_label="environment:dev" \
    --set_label="layer:${DATASET_LAYER[$DATASET]}" \
    "${PROJECT_ID}:${DATASET}" >/dev/null
done

echo "Adicionando labels às tabelas e views..."
for DATASET in "${!DATASET_LAYER[@]}"; do
  LAYER="${DATASET_LAYER[$DATASET]}"

  while IFS= read -r TABLE_ID; do
    [[ -z "${TABLE_ID}" ]] && continue

    bq update \
      --project_id="${PROJECT_ID}" \
      --set_label="project:fiap_fase2" \
      --set_label="environment:dev" \
      --set_label="layer:${LAYER}" \
      "${PROJECT_ID}:${DATASET}.${TABLE_ID}" >/dev/null
  done < <(
    bq ls \
      --project_id="${PROJECT_ID}" \
      --format=prettyjson \
      "${PROJECT_ID}:${DATASET}" \
    | python3 -c '
import json
import sys
for item in json.load(sys.stdin):
    table_id = item.get("tableReference", {}).get("tableId")
    if table_id:
        print(table_id)
'
  )
done

create_policy_if_missing() {
  local display_name="$1"
  local policy_file="$2"

  local count
  count="$(
    gcloud monitoring policies list \
      --project="${PROJECT_ID}" \
      --filter="displayName=\"${display_name}\"" \
      --format="value(name)" \
    | wc -l \
    | tr -d ' '
  )"

  if [[ "${count}" == "0" ]]; then
    echo "Criando alerta: ${display_name}"
    gcloud monitoring policies create \
      --project="${PROJECT_ID}" \
      --policy-from-file="${policy_file}" \
      >/dev/null
  else
    echo "Alerta já existe: ${display_name}"
  fi
}

create_policy_if_missing \
  "FIAP - PubSub backlog alto" \
  "${POLICY_DIR}/pubsub-backlog.json"

create_policy_if_missing \
  "FIAP - PubSub mensagem antiga" \
  "${POLICY_DIR}/pubsub-oldest-unacked.json"

create_policy_if_missing \
  "FIAP - Dataflow system lag alto" \
  "${POLICY_DIR}/dataflow-system-lag.json"

echo "Auditando papéis amplos nas contas de serviço..."
AUDIT_FILE="${EVIDENCE_DIR}/auditoria_iam_service_accounts.txt"
: > "${AUDIT_FILE}"
HAS_BROAD_ROLE=0

for SERVICE_ACCOUNT in "${SA_BATCH}" "${SA_STREAMING}"; do
  echo "Conta: ${SERVICE_ACCOUNT}" | tee -a "${AUDIT_FILE}"

  ROLES="$(
    gcloud projects get-iam-policy "${PROJECT_ID}" \
      --flatten="bindings[].members" \
      --filter="bindings.members:serviceAccount:${SERVICE_ACCOUNT}" \
      --format="value(bindings.role)" \
    | sort -u
  )"

  if [[ -z "${ROLES}" ]]; then
    echo "  Nenhum papel no nível do projeto." | tee -a "${AUDIT_FILE}"
  else
    while IFS= read -r ROLE; do
      [[ -z "${ROLE}" ]] && continue
      echo "  ${ROLE}" | tee -a "${AUDIT_FILE}"
      if [[ "${ROLE}" == "roles/owner" || "${ROLE}" == "roles/editor" ]]; then
        HAS_BROAD_ROLE=1
      fi
    done <<< "${ROLES}"
  fi
done

gcloud storage buckets describe "gs://${BUCKET}" \
  --format="yaml(name,location,uniform_bucket_level_access,public_access_prevention,lifecycle_config,soft_delete_policy)" \
| tee "${EVIDENCE_DIR}/bucket_governanca.txt"

gcloud monitoring policies list \
  --project="${PROJECT_ID}" \
  --filter="displayName:FIAP" \
  --format="table(displayName,enabled,name)" \
| tee "${EVIDENCE_DIR}/alertas_monitoramento.txt"

if [[ "${HAS_BROAD_ROLE}" != "0" ]]; then
  echo "Foram encontrados papéis básicos amplos em contas de serviço." >&2
  exit 1
fi

echo "Governança e alertas básicos configurados com sucesso."

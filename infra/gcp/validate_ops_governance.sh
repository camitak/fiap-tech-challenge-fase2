#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ID="${PROJECT_ID:-fiap-tc-f2-camila-takemoto}"
BUCKET="${BUCKET:-fiap-tc-f2-camila-takemoto-alfabetizacao-bronze}"
SA_BATCH="${SA_BATCH:-sa-batch-ingestion@${PROJECT_ID}.iam.gserviceaccount.com}"
SA_STREAMING="${SA_STREAMING:-sa-streaming-dataflow@${PROJECT_ID}.iam.gserviceaccount.com}"

PAP="$(gcloud storage buckets describe "gs://${BUCKET}" --format="value(public_access_prevention)")"
UNIFORM_ACCESS="$(gcloud storage buckets describe "gs://${BUCKET}" --format="value(uniform_bucket_level_access)")"
BUCKET_JSON="$(gcloud storage buckets describe "gs://${BUCKET}" --format=json)"

[[ "${PAP}" == "enforced" ]] || {
  echo "ERRO: public_access_prevention=${PAP}" >&2
  exit 1
}

[[ "${UNIFORM_ACCESS}" == "true" || "${UNIFORM_ACCESS}" == "True" ]] || {
  echo "ERRO: uniform bucket-level access não está habilitado." >&2
  exit 1
}

if ! python3 - "${BUCKET_JSON}" <<'PY'
import json
import sys

data = json.loads(sys.argv[1])
rules = data.get("lifecycle_config", {}).get("rule", [])
ok = any(
    rule.get("action", {}).get("type") == "Delete"
    and rule.get("condition", {}).get("age") == 1
    and "tmp/" in rule.get("condition", {}).get("matchesPrefix", [])
    for rule in rules
)
raise SystemExit(0 if ok else 1)
PY
then
  echo "ERRO: lifecycle de tmp/ não encontrado." >&2
  exit 1
fi

for SERVICE_ACCOUNT in "${SA_BATCH}" "${SA_STREAMING}"; do
  ROLES="$(
    gcloud projects get-iam-policy "${PROJECT_ID}" \
      --flatten="bindings[].members" \
      --filter="bindings.members:serviceAccount:${SERVICE_ACCOUNT}" \
      --format="value(bindings.role)"
  )"

  if grep -Eq '^roles/(owner|editor)$' <<< "${ROLES}"; then
    echo "ERRO: papel amplo encontrado para ${SERVICE_ACCOUNT}." >&2
    exit 1
  fi
done

POLICY_COUNT="$(
  gcloud monitoring policies list \
    --project="${PROJECT_ID}" \
    --filter="displayName:FIAP" \
    --format="value(name)" \
  | wc -l \
  | tr -d ' '
)"

(( POLICY_COUNT >= 3 )) || {
  echo "ERRO: apenas ${POLICY_COUNT} alertas FIAP encontrados." >&2
  exit 1
}

echo "Validação de governança concluída sem falhas."
echo "public_access_prevention=${PAP}"
echo "uniform_bucket_level_access=${UNIFORM_ACCESS}"
echo "monitoring_policies=${POLICY_COUNT}"

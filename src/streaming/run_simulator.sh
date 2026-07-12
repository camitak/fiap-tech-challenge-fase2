#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ID="${PROJECT_ID:-fiap-tc-f2-camila-takemoto}"
TOPIC_ID="${TOPIC_ID:-alfabetizacao-eventos}"
COUNT_VALID="${COUNT_VALID:-12}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VENV_DIR="${ROOT_DIR}/.venv-streaming"
EVIDENCE_DIR="${ROOT_DIR}/docs/evidencias/etapa-07"
SIMULATION_RUN_ID="${SIMULATION_RUN_ID:-sim_$(date -u +'%Y%m%dT%H%M%SZ')}"
MANIFEST_PATH="${EVIDENCE_DIR}/simulacao_${SIMULATION_RUN_ID}.json"

mkdir -p "${EVIDENCE_DIR}"

if [[ ! -d "${VENV_DIR}" ]]; then
  echo "Ambiente virtual ausente. Execute ./src/streaming/run_streaming.sh primeiro." >&2
  exit 1
fi

# shellcheck disable=SC1091
source "${VENV_DIR}/bin/activate"

python "${ROOT_DIR}/src/streaming/simulator.py" \
  --project-id="${PROJECT_ID}" \
  --topic-id="${TOPIC_ID}" \
  --count-valid="${COUNT_VALID}" \
  --simulation-run-id="${SIMULATION_RUN_ID}" \
  --manifest-path="${MANIFEST_PATH}"

source /tmp/fiap_simulation.env

echo "Aguarde aproximadamente 60 segundos antes da validação."
echo "Depois execute: ./src/streaming/validate_streaming.sh"

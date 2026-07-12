#!/usr/bin/env bash

set -euo pipefail

: "${PROJECT_ID:"fiap-tc-f2-camila-takemoto"}"
: 
gcloud config set project "$PROJECT_ID"

gcloud services enable \
  bigquery.googleapis.com \
  storage.googleapis.com \
  pubsub.googleapis.com \
  dataflow.googleapis.com \
  monitoring.googleapis.com \
  logging.googleapis.com \
  iam.googleapis.com

echo "APIs habilitadas."
echo "Os datasets e o bucket são criados por comandos documentados separadamente."
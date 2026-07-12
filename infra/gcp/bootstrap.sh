#!/usr/bin/env bash

set -Eeuo pipefail

PROJECT_ID="${PROJECT_ID:-fiap-tc-f2-camila-takemoto}"

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
echo "Este script não provisiona datasets, bucket ou IAM."
echo "O provisionamento complementar está documentado em docs/gcp/."

#!/usr/bin/env bash
# Habilita APIs y crea el bucket de estado remoto. Correr una sola vez.
set -euo pipefail
PROJECT=${1:?uso: tf-bootstrap.sh PROJECT_ID}
gcloud services enable compute.googleapis.com container.googleapis.com --project "$PROJECT"
gcloud storage buckets create "gs://pipeline-devops-tfstate" --project "$PROJECT" --location southamerica-east1 --uniform-bucket-level-access || true
gcloud storage buckets update "gs://pipeline-devops-tfstate" --versioning

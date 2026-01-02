#!/usr/bin/env bash
set -euo pipefail

PROJECT=${1:-saas-app-001}
REGION=${2:-us-central1}
BUCKET="${PROJECT}-tf-state"

echo "Checking for Terraform backend bucket: gs://${BUCKET} (project=${PROJECT}, region=${REGION})"

if gsutil ls -b "gs://${BUCKET}" >/dev/null 2>&1; then
  echo "Bucket gs://${BUCKET} already exists. Skipping creation."
else
  echo "Creating bucket gs://${BUCKET}..."
  gsutil mb -p "${PROJECT}" -l "${REGION}" "gs://${BUCKET}"
  echo "Enabling versioning on gs://${BUCKET}"
  gsutil versioning set on "gs://${BUCKET}"
  echo "Bucket gs://${BUCKET} created and versioning enabled."
fi

echo "Backend bucket ready: gs://${BUCKET}" 

#!/usr/bin/env bash
# ==============================================================================
# Step 5 (Alternative 5A): Deploy Executive Data App to Google Cloud Run
# Enforces @skill:building-data-apps deployment workflow
# ==============================================================================
set -euo pipefail

export CLOUDSDK_METRICS_ENVIRONMENT="${CLOUDSDK_METRICS_ENVIRONMENT:+$CLOUDSDK_METRICS_ENVIRONMENT }datacloud.antigravity"

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
fi

PROJECT_ID="${GCP_PROJECT_ID:-your-gcp-project-id}"
REGION="${GCP_REGION:-us-central1}"
SERVICE_NAME="clarity-search-intelligence-app"
SERVICE_ACCOUNT="${DEMO_SERVICE_ACCOUNT:-dak-demo-runner@${PROJECT_ID}.iam.gserviceaccount.com}"

CMD="gcloud run deploy ${SERVICE_NAME} \
  --source=05_presentation_app/alt_a_react_cloud_run \
  --project=${PROJECT_ID} \
  --region=${REGION} \
  --service-account=${SERVICE_ACCOUNT} \
  --port=8080 \
  --memory=2Gi \
  --cpu=1 \
  --min-instances=0 \
  --max-instances=10 \
  --concurrency=80 \
  --timeout=300s \
  --quiet \
  --allow-unauthenticated \
  --set-env-vars=GCP_PROJECT_ID=${PROJECT_ID},GCP_REGION=${REGION},DEMO_OFFLINE_FALLBACK=false,DATA_AGENT_ID=clarity-retail-search-agent"

if [[ "$DRY_RUN" == "true" ]]; then
  echo "[DRY-RUN] ${CMD}"
else
  echo "[EXEC] ${CMD}"
  eval "${CMD}"
fi

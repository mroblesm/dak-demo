#!/usr/bin/env bash
# ==============================================================================
# Google Cloud Data Agent Kit (DAK) — Idempotent Infrastructure Provisioning
# Enforces @skill:gcloud-auth-verification, @skill:biglake-management,
# @skill:gcp-spark & @skill:gcp-data-cloud-pipeline-orchestration-definition-skill
#
# Automatically loads `.env` if present in the repository root.
# Provisions:
#   1. Required GCP APIs (BigQuery, BigLake, Dataplex, Dataproc, Vertex AI,
#      Composer, Cloud Run, Compute, IAM, CRM, Artifact Registry, Notebooks)
#   2. Dedicated VPC (`dak-demo-vpc`), PGA Subnet (`dataproc-serverless-subnet`),
#      Internal Firewall, and Cloud Router + Cloud NAT (`dak-nat-router`)
#   3. 3-Tier Data Mesh BigQuery Datasets & 4 GCS Buckets:
#      - gs://${PROJECT_ID}-iceberg-lakehouse (GCP Native LRC Catalog)
#      - gs://${PROJECT_ID}-iceberg-dbx-lakehouse (Federated LRC Catalog)
#      - gs://${PROJECT_ID}-orchestration-artifacts (Composer / Orchestration)
#      - gs://${PROJECT_ID}-spark-staging (Dataproc Serverless staging)
#   4. Service Accounts (`s8s-spark-interactive` & `dak-demo-runner`) + IAM
#   5. GCP-Native BigLake Iceberg REST Catalog (`${PROJECT_ID}-iceberg-lakehouse`)
#      with vended credentials + `blirc-*` service agent bucket IAM
#   6. Dual-Catalog Dataproc Serverless Spark Runtime 2.3 Session Templates
#      (`clarity-lrc-spark-template` & `lrc-spark-template`)
#   7. BigQuery Enterprise Edition Autoscale Reservation (0 baseline / 50 max
#      slots, required for BigQuery Property Graph queries) & Vertex AI Connection
#   8. Artifact Registry (`clarity-data-apps`) & Optional Cloud Composer 3
# ==============================================================================
set -euo pipefail

if [[ -f ".env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source ".env"
  set +a
fi

DRY_RUN=false
SETUP_LRC=true
SETUP_COMPOSER=false
for arg in "$@"; do
  case "$arg" in
    --dry-run)
      DRY_RUN=true
      ;;
    --setup-lrc)
      SETUP_LRC=true
      ;;
    --skip-lrc)
      SETUP_LRC=false
      ;;
    --setup-composer)
      SETUP_COMPOSER=true
      ;;
  esac
done

PROJECT_ID="${GCP_PROJECT_ID:-your-gcp-project-id}"
REGION="${GCP_REGION:-us-central1}"
BQ_LOCATION="${BQ_LOCATION:-US}"
RAW_DATASET="${RAW_DATASET_ID:-raw_retail_core}"
MODELED_DATASET="${MODELED_DATASET_ID:-modeled_search_warehouse}"
SERVING_DATASET="${SERVING_DATASET_ID:-serving_clarity_intelligence}"

NATIVE_LAKEHOUSE_BUCKET="${LAKEHOUSE_BUCKET:-gs://${PROJECT_ID}-iceberg-lakehouse}"
DBX_LAKEHOUSE_BUCKET="${DBX_LAKEHOUSE_BUCKET:-gs://${PROJECT_ID}-iceberg-dbx-lakehouse}"
ORCHESTRATION_BUCKET="${ORCHESTRATION_BUCKET:-gs://${PROJECT_ID}-orchestration-artifacts}"
SPARK_STAGING_BUCKET="${SPARK_STAGING_BUCKET:-gs://${PROJECT_ID}-spark-staging}"

NATIVE_LRC_CATALOG="${NATIVE_LRC_CATALOG_ID:-${PROJECT_ID}-iceberg-lakehouse}"
FEDERATED_CATALOG="${FEDERATED_CATALOG_ID:-biglakefederated}"
VPC_NAME="${VPC_NAME:-dak-demo-vpc}"
SUBNET_NAME="${SUBNET_NAME:-dataproc-serverless-subnet}"
COMPOSER_ENV_NAME="${COMPOSER_ENVIRONMENT_NAME:-${COMPOSER_ENV_NAME:-clarity-composer-dev}}"

run_cmd() {
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[DRY-RUN] $*"
  else
    echo "[EXEC] $*"
    eval "$@"
  fi
}

echo "========================================================================"
echo " Step 0.1: @skill:gcloud-auth-verification — Checking GCP Auth & Project"
echo "========================================================================"
run_cmd "gcloud auth list --filter=status:ACTIVE --format='value(account)'"
run_cmd "gcloud projects describe ${PROJECT_ID} >/dev/null 2>&1 || gcloud projects create ${PROJECT_ID} --name='Data Agent Kit Demo'"
run_cmd "gcloud config set project ${PROJECT_ID}"

if [[ "$DRY_RUN" == "false" ]]; then
  BILLING_ACCT="${GCP_BILLING_ACCOUNT:-$(gcloud billing accounts list --filter='open=true' --format='value(ACCOUNT_ID)' --limit=1 2>/dev/null || true)}"
  if [[ -n "${BILLING_ACCT}" ]]; then
    run_cmd "gcloud billing projects link ${PROJECT_ID} --billing-account=${BILLING_ACCT}"
  fi
fi

echo ""
echo "========================================================================"
echo " Step 0.2: Enabling Required Google Cloud Data, Spark, Composer & AI APIs"
echo "========================================================================"
run_cmd "gcloud services enable \
  compute.googleapis.com \
  iam.googleapis.com \
  cloudresourcemanager.googleapis.com \
  composer.googleapis.com \
  artifactregistry.googleapis.com \
  cloudbuild.googleapis.com \
  notebooks.googleapis.com \
  documentai.googleapis.com \
  bigquery.googleapis.com \
  bigqueryreservation.googleapis.com \
  biglake.googleapis.com \
  bigqueryconnection.googleapis.com \
  dataplex.googleapis.com \
  dataproc.googleapis.com \
  aiplatform.googleapis.com \
  run.googleapis.com \
  geminidataanalytics.googleapis.com \
  --project=${PROJECT_ID}"

echo ""
echo "========================================================================"
echo " Step 0.3: Provisioning VPC Network, PGA Subnet & Cloud NAT (${REGION})"
echo "========================================================================"
run_cmd "gcloud compute networks describe ${VPC_NAME} --project=${PROJECT_ID} >/dev/null 2>&1 || gcloud compute networks create ${VPC_NAME} --subnet-mode=custom --project=${PROJECT_ID}"
run_cmd "gcloud compute networks subnets describe ${SUBNET_NAME} --region=${REGION} --project=${PROJECT_ID} >/dev/null 2>&1 || gcloud compute networks subnets create ${SUBNET_NAME} --network=${VPC_NAME} --region=${REGION} --range=10.10.0.0/20 --enable-private-ip-google-access --project=${PROJECT_ID}"
run_cmd "gcloud compute firewall-rules describe dak-demo-allow-internal --project=${PROJECT_ID} >/dev/null 2>&1 || gcloud compute firewall-rules create dak-demo-allow-internal --network=${VPC_NAME} --allow=tcp,udp,icmp --source-ranges=10.10.0.0/20 --project=${PROJECT_ID}"
run_cmd "gcloud compute routers describe dak-nat-router --region=${REGION} --project=${PROJECT_ID} >/dev/null 2>&1 || gcloud compute routers create dak-nat-router --network=${VPC_NAME} --region=${REGION} --project=${PROJECT_ID}"
run_cmd "gcloud compute routers nats describe dak-nat-config --router=dak-nat-router --region=${REGION} --project=${PROJECT_ID} >/dev/null 2>&1 || gcloud compute routers nats create dak-nat-config --router=dak-nat-router --region=${REGION} --auto-allocate-nat-external-ips --nat-all-subnet-ip-ranges --project=${PROJECT_ID}"

echo ""
echo "========================================================================"
echo " Step 0.4: Provisioning 3-Tier Data Mesh Datasets & 4 Lakehouse/Ops Buckets"
echo "========================================================================"
run_cmd "bq --location=${BQ_LOCATION} mk -f --dataset --description='Bronze Tier: Raw Search Telemetry & Iceberg' ${PROJECT_ID}:${RAW_DATASET}"
run_cmd "bq --location=${BQ_LOCATION} mk -f --dataset --description='Silver Tier: Cleaned & Sessionized Warehouse' ${PROJECT_ID}:${MODELED_DATASET}"
run_cmd "bq --location=${BQ_LOCATION} mk -f --dataset --description='Gold Tier: AI/ML & Serving Layer' ${PROJECT_ID}:${SERVING_DATASET}"

for BUCKET in "${NATIVE_LAKEHOUSE_BUCKET}" "${DBX_LAKEHOUSE_BUCKET}" "${ORCHESTRATION_BUCKET}" "${SPARK_STAGING_BUCKET}"; do
  run_cmd "gcloud storage buckets create ${BUCKET} --location=${REGION} --uniform-bucket-level-access --project=${PROJECT_ID} 2>/dev/null || true"
done

echo ""
echo "========================================================================"
echo " Step 0.5: Provisioning Service Accounts & IAM (Spark, BigLake, Composer)"
echo "========================================================================"
for SA_NAME in s8s-spark-interactive dak-demo-runner; do
  SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
  run_cmd "gcloud iam service-accounts describe ${SA_EMAIL} --project=${PROJECT_ID} >/dev/null 2>&1 || gcloud iam service-accounts create ${SA_NAME} --display-name='DAK Demo ${SA_NAME} SA' --project=${PROJECT_ID}"
  run_cmd "gcloud iam service-accounts add-iam-policy-binding ${SA_EMAIL} --member='serviceAccount:${SA_EMAIL}' --role='roles/iam.serviceAccountUser' --project=${PROJECT_ID} --quiet >/dev/null"
  for ROLE in roles/bigquery.admin roles/biglake.admin roles/dataplex.admin roles/dataproc.worker roles/dataproc.editor roles/storage.objectAdmin roles/aiplatform.user; do
    run_cmd "gcloud projects add-iam-policy-binding ${PROJECT_ID} --member='serviceAccount:${SA_EMAIL}' --role='${ROLE}' --quiet >/dev/null"
  done
done

echo ""
echo "========================================================================"
echo " Step 0.6: @skill:biglake-management — GCP-Native BigLake Iceberg REST Catalog"
echo " Catalog ID: ${NATIVE_LRC_CATALOG} (${NATIVE_LAKEHOUSE_BUCKET})"
echo "========================================================================"
if [[ "$DRY_RUN" == "true" || "$SETUP_LRC" == "true" ]]; then
  run_cmd "gcloud biglake iceberg catalogs describe ${NATIVE_LRC_CATALOG} --project=${PROJECT_ID} >/dev/null 2>&1 || gcloud biglake iceberg catalogs create ${NATIVE_LRC_CATALOG} \
    --project=${PROJECT_ID} \
    --catalog-type=gcs-bucket \
    --credential-mode=vended-credentials"
  if [[ "$DRY_RUN" == "false" ]]; then
    LRC_SA=$(gcloud biglake iceberg catalogs describe "${NATIVE_LRC_CATALOG}" --project="${PROJECT_ID}" --format="value(biglake-service-account)")
    if [[ -n "${LRC_SA}" ]]; then
      run_cmd "gcloud storage buckets add-iam-policy-binding ${NATIVE_LAKEHOUSE_BUCKET} --member='serviceAccount:${LRC_SA}' --role='roles/storage.objectAdmin' --project=${PROJECT_ID} >/dev/null"
    fi
  fi
fi

echo ""
echo "========================================================================"
echo " Step 0.7: @skill:gcp-spark — Dual-Catalog Spark Runtime 2.3 Session Templates"
echo " Templates: clarity-lrc-spark-template & lrc-spark-template"
echo "========================================================================"
for TMPL_NAME in clarity-lrc-spark-template lrc-spark-template; do
  run_cmd "PROJECT_ID=${PROJECT_ID} REGION=${REGION} TEMPLATE_NAME=${TMPL_NAME} DISPLAY_NAME='Retail Search Dual-Catalog LRC (${TMPL_NAME})' SPARK_SA=s8s-spark-interactive@${PROJECT_ID}.iam.gserviceaccount.com SUBNET_URI=projects/${PROJECT_ID}/regions/${REGION}/subnetworks/${SUBNET_NAME} NATIVE_LAKEHOUSE_BUCKET=${NATIVE_LAKEHOUSE_BUCKET} FEDERATED_CATALOG=${FEDERATED_CATALOG} envsubst < infra/spark_session_template.yaml | gcloud beta dataproc session-templates import ${TMPL_NAME} --project=${PROJECT_ID} --location=${REGION} --quiet"
done

echo ""
echo "========================================================================"
echo " Step 0.8: BigQuery Enterprise Reservation (for Property Graph) & Connections"
echo "========================================================================"
run_cmd "bq mk --reservation --project_id=${PROJECT_ID} --location=${BQ_LOCATION} --edition=ENTERPRISE --slots=0 --autoscale_max_slots=50 clarity-enterprise-us 2>/dev/null || true"
run_cmd "bq mk --reservation_assignment --reservation_id=${PROJECT_ID}:${BQ_LOCATION}.clarity-enterprise-us --job_type=QUERY --assignee_type=PROJECT --assignee_id=${PROJECT_ID} 2>/dev/null || true"
run_cmd "bq show --connection --project_id=${PROJECT_ID} --location=${BQ_LOCATION} vertex-ai-connection >/dev/null 2>&1 || bq mk --connection --connection_type=CLOUD_RESOURCE --project_id=${PROJECT_ID} --location=${BQ_LOCATION} vertex-ai-connection"
if [[ "$DRY_RUN" == "false" ]]; then
  CONN_SA=$(bq show --format=json --connection "${PROJECT_ID}.${BQ_LOCATION}.vertex-ai-connection" | python3 -c "import sys,json; print(json.load(sys.stdin)['cloudResource']['serviceAccountId'])" 2>/dev/null || true)
  if [[ -n "${CONN_SA}" ]]; then
    run_cmd "gcloud projects add-iam-policy-binding ${PROJECT_ID} --member='serviceAccount:${CONN_SA}' --role='roles/aiplatform.user' --quiet >/dev/null"
    run_cmd "gcloud projects add-iam-policy-binding ${PROJECT_ID} --member='serviceAccount:${CONN_SA}' --role='roles/storage.objectViewer' --quiet >/dev/null"
  fi
fi
run_cmd "gcloud artifacts repositories describe clarity-data-apps --location=${REGION} --project=${PROJECT_ID} >/dev/null 2>&1 || gcloud artifacts repositories create clarity-data-apps --repository-format=docker --location=${REGION} --description='Retail Search Cloud Run Data Apps' --project=${PROJECT_ID}"

echo ""
echo "========================================================================"
echo " Step 0.9: @skill:gcp-data-cloud-pipeline-orchestration-definition-skill — Composer 3"
echo "========================================================================"
if [[ "$DRY_RUN" == "true" || "$SETUP_COMPOSER" == "true" ]]; then
  run_cmd "gcloud composer environments describe ${COMPOSER_ENV_NAME} --location=${REGION} --project=${PROJECT_ID} >/dev/null 2>&1 || gcloud composer environments create ${COMPOSER_ENV_NAME} \
    --location=${REGION} \
    --project=${PROJECT_ID} \
    --image-version=composer-3-airflow-2.11.1 \
    --service-account=dak-demo-runner@${PROJECT_ID}.iam.gserviceaccount.com \
    --network=projects/${PROJECT_ID}/global/networks/${VPC_NAME} \
    --subnetwork=projects/${PROJECT_ID}/regions/${REGION}/subnetworks/${SUBNET_NAME} \
    --async"
else
  echo "[INFO] Pass --setup-composer to initiate Cloud Composer 3 environment creation (${COMPOSER_ENV_NAME})."
fi

echo ""
echo "[SUCCESS] Infrastructure provisioning sequence completed for ${PROJECT_ID} (DRY_RUN=${DRY_RUN})."

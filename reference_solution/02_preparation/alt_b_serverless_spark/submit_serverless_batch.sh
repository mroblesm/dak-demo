#!/usr/bin/env bash
# ==============================================================================
# Alternative 2B: Submit Serverless Spark Batch with FinOps Guardrails & Dual-LRC
# Enforces @skill:gcp-spark & @skill:dataproc-Operations:
#   - Explicit executor upper bound (`spark.dynamicAllocation.maxExecutors=8`)
#   - Automatic batch TTL (`--ttl=1800s`) to prevent zombie jobs
#   - Dedicated PGA subnet (`dataproc-serverless-subnet`) & Spark SA (`s8s-spark-interactive`)
#   - Dual-catalog Iceberg properties (`lrc` GCP Native + `biglakefederated` DBX Federated)
# ==============================================================================
set -euo pipefail

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
fi

PROJECT_ID="${GCP_PROJECT_ID:-your-gcp-project-id}"
REGION="${GCP_REGION:-us-central1}"
SUBNET="${SPARK_SUBNET:-projects/${PROJECT_ID}/regions/${REGION}/subnetworks/dataproc-serverless-subnet}"
SPARK_SA="${SPARK_SERVICE_ACCOUNT:-s8s-spark-interactive@${PROJECT_ID}.iam.gserviceaccount.com}"
NATIVE_LAKEHOUSE_BUCKET="${LAKEHOUSE_BUCKET:-gs://${PROJECT_ID}-iceberg-lakehouse}"
FEDERATED_CATALOG="${FEDERATED_CATALOG_NAME:-biglakefederated}"
BATCH_ID="clarity-medallion-prep-$(date +%Y%m%d-%H%M%S)"
SCRIPT_PATH="02_preparation/alt_b_serverless_spark/spark_medallion_prep.py"

SPARK_PROPS="spark.dynamicAllocation.enabled=true#spark.dynamicAllocation.initialExecutors=2#spark.dynamicAllocation.maxExecutors=8"
SPARK_PROPS="${SPARK_PROPS}#spark.jars.packages=org.apache.iceberg:iceberg-spark-runtime-3.5_2.13:1.5.0,org.apache.iceberg:iceberg-gcp-bundle:1.5.0,io.delta:delta-spark_2.13:3.2.0"
SPARK_PROPS="${SPARK_PROPS}#spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions"
SPARK_PROPS="${SPARK_PROPS}#spark.sql.catalog.lrc=org.apache.iceberg.spark.SparkCatalog#spark.sql.catalog.lrc.type=rest#spark.sql.catalog.lrc.uri=https://biglake.googleapis.com/iceberg/v1/restcatalog#spark.sql.catalog.lrc.warehouse=${NATIVE_LAKEHOUSE_BUCKET}#spark.sql.catalog.lrc.header.x-goog-user-project=${PROJECT_ID}#spark.sql.catalog.lrc.header.X-Iceberg-Access-Delegation=vended-credentials#spark.sql.catalog.lrc.io-impl=org.apache.iceberg.gcp.gcs.GCSFileIO"
SPARK_PROPS="${SPARK_PROPS}#spark.sql.catalog.${FEDERATED_CATALOG}=org.apache.iceberg.spark.SparkCatalog#spark.sql.catalog.${FEDERATED_CATALOG}.type=rest#spark.sql.catalog.${FEDERATED_CATALOG}.uri=https://biglake.googleapis.com/iceberg/v1/restcatalog#spark.sql.catalog.${FEDERATED_CATALOG}.warehouse=bl://projects/${PROJECT_ID}/catalogs/${FEDERATED_CATALOG}#spark.sql.catalog.${FEDERATED_CATALOG}.header.x-goog-user-project=${PROJECT_ID}#spark.sql.catalog.${FEDERATED_CATALOG}.header.X-Iceberg-Access-Delegation=vended-credentials#spark.sql.catalog.${FEDERATED_CATALOG}.io-impl=org.apache.iceberg.gcp.gcs.GCSFileIO"

CMD="gcloud dataproc batches submit pyspark ${SCRIPT_PATH} \
  --project=${PROJECT_ID} \
  --region=${REGION} \
  --batch=${BATCH_ID} \
  --version=2.3 \
  --subnet=${SUBNET} \
  --service-account=${SPARK_SA} \
  --ttl=1800s \
  --properties=^#^${SPARK_PROPS}"

if [[ "$DRY_RUN" == "true" ]]; then
  echo "[DRY-RUN] ${CMD}"
else
  echo "[EXEC] ${CMD}"
  eval "${CMD}"
fi

#!/usr/bin/env bash
# ==============================================================================
# Step 1: Data Discovery & Semantic Grounding via Google Cloud Data Agent Kit
# Explicitly implements:
#   - @skill:gcloud-auth-verification
#   - @skill:discovering-gcp-data-assets
#   - @skill:biglake-management
# ==============================================================================
set -euo pipefail

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
fi

PROJECT_ID="${GCP_PROJECT_ID:-your-gcp-project-id}"
LOCATION="${BQ_LOCATION:-US}"
REGION="${GCP_REGION:-us-central1}"

run_cmd() {
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[DRY-RUN] $*"
  else
    echo "[EXEC] $*"
    eval "$@"
  fi
}

echo "========================================================================"
echo " 1. @skill:discovering-gcp-data-assets — Natural-Language Semantic Search"
echo "    Discovering DBX Federated (biglakefederated) & GCP-Native LRC Tables"
echo "========================================================================"
run_cmd "gcloud dataplex entries search 'databricks federated shopper search telemetry and tail queries' \
  --project=${PROJECT_ID} \
  --semantic-search \
  --page-size=10"

run_cmd "gcloud dataplex entries search 'name:search_events parent:projects/${PROJECT_ID}' \
  --project=${PROJECT_ID} \
  --page-size=10"

run_cmd "gcloud dataplex entries search 'customer lifetime value CLV segment and repeat purchase propensity' \
  --project=${PROJECT_ID} \
  --semantic-search \
  --page-size=5"

echo ""
echo "========================================================================"
echo " 2. @skill:discovering-gcp-data-assets — Deep Entry & Context Lookup"
echo "    Inspects biglakefederated.raw_search_telemetry.search_events in KC"
echo "    (Overview, Contacts, Governance/PII Aspects, Schema & Glossary)"
echo "========================================================================"
FED_ENTRY="projects/${PROJECT_ID}/locations/${REGION}/entryGroups/@biglake/entries/biglake.googleapis.com/projects/${PROJECT_ID}/catalogs/biglakefederated/namespaces/raw_search_telemetry/tables/search_events"
run_cmd "gcloud dataplex entries lookup '${FED_ENTRY}' --project=${PROJECT_ID}"

ENTRY_PREFIX="projects/${PROJECT_ID}/locations/${LOCATION}/entryGroups/@bigquery/entries/bigquery.googleapis.com/projects/${PROJECT_ID}/datasets"
run_cmd "gcloud dataplex context lookup \
  '${FED_ENTRY},${ENTRY_PREFIX}/raw_retail_core/tables/search_impressions,${ENTRY_PREFIX}/raw_retail_core/tables/catalog_items' \
  --project=${PROJECT_ID} \
  --format=yaml"

echo ""
echo "========================================================================"
echo " 3. @skill:biglake-management — Inspect Federated & Native LRC Catalogs"
echo "========================================================================"
run_cmd "gcloud beta biglake iceberg catalogs describe biglakefederated --project=${PROJECT_ID}"
run_cmd "gcloud beta biglake iceberg catalogs describe ${PROJECT_ID}-iceberg-lakehouse --project=${PROJECT_ID}"
run_cmd "gcloud beta biglake iceberg catalogs list --project=${PROJECT_ID}"

echo ""
echo "========================================================================"
echo " 4. DEA in IDE & @skill:data-autocleaning — AI-Driven Metadata Enrichment,"
echo "    Semantic Tagging & Quality Scorecard Publishing to Knowledge Catalog"
echo "========================================================================"
run_cmd "gcloud dataplex datascans describe clarity-search-events-profile --location=${REGION} --project=${PROJECT_ID} >/dev/null 2>&1 || gcloud dataplex datascans create data-profile clarity-search-events-profile \
  --project=${PROJECT_ID} \
  --location=${REGION} \
  --data-source-resource='//bigquery.googleapis.com/projects/${PROJECT_ID}/datasets/raw_retail_core/tables/search_impressions'"

run_cmd "gcloud dataplex datascans describe clarity-search-events-quality-scorecard --location=${REGION} --project=${PROJECT_ID} >/dev/null 2>&1 || gcloud dataplex datascans create data-quality clarity-search-events-quality-scorecard \
  --project=${PROJECT_ID} \
  --location=${REGION} \
  --data-source-resource='//bigquery.googleapis.com/projects/${PROJECT_ID}/datasets/modeled_search_warehouse/tables/fct_search_conversions' \
  --data-quality-spec-file=infra/dataplex_data_quality_spec.yaml"

echo ""
echo "========================================================================"
echo " 5. @skill:bigquery-graph-author & @skill:bigquery-graph-query —"
echo "    Discover BigQuery Property Graph (.bq.graph) in Knowledge Catalog"
echo "========================================================================"
run_cmd "gcloud dataplex entries search 'retail_search_graph customer search session SKU property graph' \
  --project=${PROJECT_ID} \
  --semantic-search \
  --page-size=5"

echo ""
echo "[SUCCESS] Step 1 DAK Semantic Discovery, KC Scorecard Publishing & BQ Graph lookup completed (DRY_RUN=${DRY_RUN})."


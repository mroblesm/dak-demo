# 02 — Greenfield Infrastructure Provisioning & Synthetic Data Seeding

This guide explains how to configure `.env` and provision all required Google Cloud infrastructure in a **greenfield GCP project** using either **Terraform (`infra/`)** or the **automated CLI bootstrap script (`infra/provision_demo_infra.sh`)**, followed by seeding the synthetic e-commerce search datasets.

---

## 1. Configure `.env`

Copy `.env.example` to `.env` at the root of the repository and replace `your-gcp-project-id` with your target Google Cloud Project ID:

```bash
cp .env.example .env
```

Edit `.env`:
```ini
GCP_PROJECT_ID=your-gcp-project-id
GCP_REGION=us-central1
BQ_LOCATION=US

# 3-Tier Data Mesh Datasets
RAW_DATASET_ID=raw_retail_core
MODELED_DATASET_ID=modeled_search_warehouse
SERVING_DATASET_ID=serving_clarity_intelligence

# Dual-Catalog BigLake Managed Apache Iceberg (`lrc` GCP Native + `biglakefederated` Federated)
LAKEHOUSE_BUCKET=gs://your-gcp-project-id-iceberg-lakehouse
DBX_LAKEHOUSE_BUCKET=gs://your-gcp-project-id-iceberg-dbx-lakehouse
NATIVE_LRC_CATALOG_ID=your-gcp-project-id-iceberg-lakehouse
FEDERATED_CATALOG_ID=biglakefederated
BIGLAKE_CATALOG_NAME=lrc
SPARK_SESSION_TEMPLATE=clarity-lrc-spark-template
SPARK_SERVICE_ACCOUNT=s8s-spark-interactive@your-gcp-project-id.iam.gserviceaccount.com
VERTEX_CONNECTION_ID=us.vertex-ai-connection

# Orchestration & Cloud Composer 3 Settings
ORCHESTRATION_ARTIFACT_BUCKET=your-gcp-project-id-orchestration-artifacts
COMPOSER_ENVIRONMENT_NAME=clarity-composer-dev
DEMO_SERVICE_ACCOUNT=dak-demo-runner@your-gcp-project-id.iam.gserviceaccount.com
```

Load `.env` into your current shell session:
```bash
set -a && source .env && set +a
```

---

## 2. Provision Google Cloud Infrastructure (Option A: Terraform + Session Template)

The [`infra/`](../infra/) directory contains a complete Terraform configuration ([`infra/main.tf`](../infra/main.tf), [`infra/variables.tf`](../infra/variables.tf), [`infra/outputs.tf`](../infra/outputs.tf)) that provisions:
1. **Google Cloud APIs**: BigQuery, BigLake, BigQuery Connection, BigQuery Reservation, Dataplex, Dataproc, Vertex AI, Cloud Run, Artifact Registry, Compute, IAM, and Cloud Composer.
2. **Networking for Serverless Spark & Composer**: Dedicated VPC (`dak-demo-vpc`), Private Google Access subnet (`dataproc-serverless-subnet`), internal firewall rules, and Cloud Router + Cloud NAT.
3. **Cloud Storage Buckets**:
   - `gs://<GCP_PROJECT_ID>-iceberg-lakehouse` (GCP-Native BigLake Iceberg REST Catalog warehouse)
   - `gs://<GCP_PROJECT_ID>-iceberg-dbx-lakehouse` (Cross-Cloud Federated Iceberg warehouse)
   - `gs://<GCP_PROJECT_ID>-orchestration-artifacts` (Declarative Orchestration Pipeline bundles)
   - `gs://<GCP_PROJECT_ID>-spark-staging` (Dataproc Serverless staging)
4. **3-Tier Data Mesh BigQuery Datasets**: `raw_retail_core` (Bronze), `modeled_search_warehouse` (Silver), and `serving_clarity_intelligence` (Gold).
5. **Service Accounts & IAM**: `s8s-spark-interactive`, `dak-demo-runner`, and the BigQuery Cloud Resource Connection (`vertex-ai-connection`).
6. **Artifact Registry**: `clarity-data-apps` Docker repository.
7. **Cloud Composer 3** *(optional via `enable_composer = true`, takes ~20 minutes)*.

### Run Terraform
```bash
cd infra
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars to set project_id = "your-gcp-project-id"

terraform init
terraform plan -out=tfplan
terraform apply tfplan
cd ..
```

### Register the BigLake Iceberg REST Catalog, Spark Session Template & BigQuery Enterprise Reservation
After `terraform apply` completes, run `infra/provision_demo_infra.sh` to register the BigLake Iceberg REST Catalog (`vended-credentials`), import the Dataproc Serverless Runtime `2.3` session template (`infra/spark_session_template.yaml`), and create the BigQuery Enterprise Edition autoscale reservation (`0` baseline / `50` max slots, required for BigQuery Property Graph queries):

```bash
bash infra/provision_demo_infra.sh
```

> **Alternative (Option B — Pure CLI Provisioning)**: `bash infra/provision_demo_infra.sh` is fully idempotent and can also provision the entire stack directly via `gcloud` and `bq` without Terraform (pass `--setup-composer` if you also want it to create the Cloud Composer 3 environment).

---

## 3. Generate & Seed the Synthetic Retail Search Datasets

### Step 3.1: Generate Local Datasets & Verify Statistical Quality Gates
Generate the deterministic synthetic datasets (`catalog_items`, `customer_clv`, `search_events`, `search_impressions`) and run the automated statistical quality gate (`data_setup/insight_gate.py`):

```bash
make generate-data
make verify-gates
```

`make verify-gates` validates three embedded statistical properties required for the demo:
- **Position-Bias Decay**: Click-through rate (CTR) decays monotonically from Rank 1 to Rank 10.
- **Long-Tail Zero-Result Anomaly**: 4+ token `tail` queries exhibit a >30% zero-result rate under legacy lexical search vs. <5% on 1–2 token `head` queries.
- **Zero Target Leakage**: Feature columns contain zero post-purchase target leakage.

### Step 3.2: Load Datasets into BigQuery, GCS & Remote Vertex AI Models
Execute the seeding script to load the Bronze tables into `raw_retail_core`, stage the Iceberg seed files into GCS, and register the remote Vertex AI models (`gemini_flash_intent_model` and `text_embedding_005_model`) in `serving_clarity_intelligence`:

```bash
python3 -m data_setup.seed_bigquery_and_iceberg --execute
```

---

## 4. Optional: Cross-Cloud Databricks Unity Catalog Federation (`biglakefederated`)

The Stage 2.1 Spark pipeline (`spark_medallion_prep.py`) and Stage 2.2 `dbt-bigquery` pipeline (`_sources.yml`) automatically fall back to the GCS/BigQuery seed data if you do not have an external Databricks workspace.

If you want to demonstrate live cross-cloud federation from **Databricks Unity Catalog** into Google Cloud BigLake (`biglakefederated`):
1. Open [`data_setup/dbx_load_iceberg_tables.sql`](../data_setup/dbx_load_iceberg_tables.sql) in your Databricks SQL Editor.
2. Replace `your-gcp-project-id` with your project ID and execute the script to create `raw_search_telemetry.search_events` with Delta UniForm (`delta.universalFormat.enabledFormats = 'iceberg'`) backed by `gs://<GCP_PROJECT_ID>-iceberg-dbx-lakehouse`.

---

## Next Step
Proceed to **[03 — End-to-End Walkthrough Guide (VS Code + AGY + DAK)](03_E2E_WALKTHROUGH_GUIDE.md)**.

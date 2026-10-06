# Google Cloud Data Agent Kit (DAK) — End-to-End Retail Search & Conversion Intelligence

An end-to-end reference project demonstrating how to build, govern, orchestrate, and serve a multi-engine Open Lakehouse & AI/ML solution on Google Cloud using **VS Code + Antigravity (AGY)** (or Gemini CLI / Claude Code) powered by the **Google Cloud Data Agent Kit (DAK)**.

---

## Overview & Business Use Case

Retail e-commerce search engines frequently suffer from **"The Long-Tail Conversion Desert"**: while 1–2 word head queries (`"office chair"`) convert well (`4.82%` CVR), high-intent 4+ word long-tail queries (`"ergonomic mesh home office chair under 300"`) experience a **`>30%` zero-result rate** and **`1.10%` CVR** due to lexical vocabulary mismatch and historical rank position bias.

This repository walks through solving that challenge end-to-end across **five architectural stages**, showcasing how **DAK Skills (`@skill:...`), MCP servers, and the VS Code Data Cloud Extension (`GoogleCloudTools.datacloud`)** accelerate every persona:

1. **Stage 1 — Semantic Discovery & Property Graph (`01_discovery/`)**:
   - Semantic search and governance lookup via **Dataplex Knowledge Catalog** (`@skill:gcp-data-assets-discovery`).
   - Partition-pruned profiling and **BigQuery Property Graph (`retail_search_graph`)** visual exploration (`@skill:bigquery-optimization`).
2. **Stage 2 — Medallion Lakehouse Preparation (`02_preparation/`)**:
   - **Stage 2A (Serverless Spark Runtime 2.3 + BigLake Iceberg `lrc`)**: Salted SHA-256 PII pseudonymisation at the Bronze boundary, 30-minute sessionization, Git-style Iceberg Write-Audit-Publish (`audit_branch`) table branching, and zero-scan metadata rollbacks (`@skill:gcp-spark`, `@skill:biglake-management`).
   - **Stage 2B (`dbt-bigquery` + Knowledge Catalog Scorecards)**: 4-part BigLake Iceberg source resolution, automated data cleaning, `WHERE EXISTS` semi-join optimization, `dbt` 1.8+ unit tests, and Dataplex Data Quality Scorecards (`@skill:dbt-bigquery`, `@skill:data-autocleaning`).
3. **Stage 3 — Model Training & Inference (`03_ml_training_inference/`)**:
   - **Path 3A (The BigQuery World)**: Chains `AI.GENERATE_TABLE` (Gemini 2.5 Flash intent extraction), Hybrid `VECTOR_SEARCH` + `SEARCH()` Reciprocal Rank Fusion (RRF), `BigFrames` (`XGBClassifier`) / `BQML` (`BOOSTED_TREE_CLASSIFIER`) with counterfactual Rank-1 position-bias debiasing, and zero-shot `AI.FORECAST` (TimesFM 2.0) 30-day demand forecasting (`@skill:bigframes-codegen`, `@skill:bigquery-ai-rules`, `@skill:ml-best-practices`).
   - **Path 3B (The Spark World)**: Distributed PySpark MLlib `GBTClassifier` re-ranker on Serverless Spark Runtime 2.3 with `vector_to_array()` serialization, live `SparkMonitor` telemetry, and **Vertex AI Experiments** tracking (`@skill:gcp-spark`).
4. **Stage 4 — Declarative Orchestration & Composer RCA (`04_orchestration/`)**:
   - **Alternative 4A**: Declarative `deployment.yaml` and `orchestration-pipeline.yaml` (`modelVersion: "1.0"`) compiling onto **Cloud Composer 3** (`@skill:gcp-data-cloud-pipeline-orchestration-definition-skill`).
   - **Alternative 4B**: Automated Root-Cause Analysis (RCA) and remediation of a failing Cloud Composer Airflow DAG (`@skill:gcp-composer-troubleshooting`).
5. **Stage 5 — Executive Application on Cloud Run & Conversational Analytics (`05_presentation_app/`)**:
   - Full-stack **FastAPI + React 18 + Tailwind CSS + Apache ECharts** application (plus a companion **Streamlit** app) containerized for **Google Cloud Run**, featuring a Slide-Out Multi-Hypothesis & 4D Data Trust Investigation Drawer, FinOps Cost/Byte Ledger, and embedded **BigQuery Conversational Analytics (`DataChatServiceClient`)** supporting both `custom_data_agent` and `inline_context` modes (`@skill:web-app-development`, `@skill:streamlit-data-app`).

---

## Repository Structure

To separate the **agentic prompts and infrastructure bootstrap** from the **generated solution code**, this repository is organized as follows:

```text
├── .env.example              # Template environment variables for greenfield GCP setup
├── GEMINI.md                 # Minimal agentic workspace rules for VS Code + AGY / Gemini CLI
├── Makefile                  # Convenience targets for data generation, validation, testing, and local app preview
├── prompts/                  # Step-by-step Agentic Prompts (the primary build-time specifications)
│   ├── README.md
│   ├── 00_environment_and_catalog_check.md
│   ├── 01_discovery_and_property_graph.md
│   ├── 02a_spark_bronze_medallion_iceberg.md
│   ├── 02b_dbt_silver_gold_and_scorecards.md
│   ├── 03a_bigquery_ml_and_bigframes.md
│   ├── 03b_spark_mllib_and_experiments.md
│   ├── 03c_compare_bigquery_vs_spark_ml.md
│   ├── 04a_declarative_orchestration_pipeline.md
│   ├── 04b_composer_rca_troubleshooting.md
│   └── 05_cloud_run_app_and_conversational_analytics.md
├── reference_solution/       # Complete, runtime-verified reference implementation for comparison
│   ├── 01_discovery/
│   ├── 02_preparation/
│   ├── 03_ml_training_inference/
│   ├── 04_orchestration/
│   └── 05_presentation_app/
├── infra/                    # Greenfield GCP Terraform modules, CLI bootstrap, & Spark 2.3 session template
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars.example
│   ├── provision_demo_infra.sh
│   └── spark_session_template.yaml
├── data_setup/               # Deterministic synthetic data generator, statistical gates, & BQ/Iceberg seeder
│   ├── generate_demo_data.py
│   ├── insight_gate.py
│   ├── seed_bigquery_and_iceberg.py
│   └── dbx_load_iceberg_tables.sql
├── docs/                     # Setup, provisioning, E2E walkthrough, and architecture documentation
│   ├── 01_PREREQUISITES_AND_SETUP.md
│   ├── 02_INFRASTRUCTURE_PROVISIONING.md
│   ├── 03_E2E_WALKTHROUGH_GUIDE.md
│   └── 04_ARCHITECTURE_AND_DESIGN.md
└── tests/                    # Automated compliance, statistical gate, and application unit tests
```

---

## Quickstart

### 1. Prerequisites & IDE Setup
Follow **[docs/01_PREREQUISITES_AND_SETUP.md](docs/01_PREREQUISITES_AND_SETUP.md)** to configure the Google Cloud SDK (`gcloud`, `bq`), Application Default Credentials (ADC), Python `.venv`, the **Google Cloud Data Cloud VS Code Extension**, and the **Data Agent Kit (DAK)** skills.

### 2. Provision Greenfield GCP Infrastructure & Seed Data
Follow **[docs/02_INFRASTRUCTURE_PROVISIONING.md](docs/02_INFRASTRUCTURE_PROVISIONING.md)**:

```bash
# 1. Configure your project ID in .env
cp .env.example .env
# Edit .env and set GCP_PROJECT_ID=your-gcp-project-id
set -a && source .env && set +a

# 2. Provision GCP infrastructure (via Terraform or idempotent CLI script)
bash infra/provision_demo_infra.sh

# 3. Generate synthetic datasets, verify statistical gates, and seed BigQuery & GCS
make generate-data
make verify-gates
python3 -m data_setup.seed_bigquery_and_iceberg --execute
```

### 3. Run the End-to-End Agentic Walkthrough in VS Code + AGY
Follow **[docs/03_E2E_WALKTHROUGH_GUIDE.md](docs/03_E2E_WALKTHROUGH_GUIDE.md)** and execute the prompts in **[`prompts/`](prompts/)** sequentially inside AGY. Compare the files generated in `workspace/` with the verified working assets in **[`reference_solution/`](reference_solution/)**.

### 4. Run the Verification Test Suite & Preview the Executive App Locally
```bash
# Run all unit, schema, and statistical compliance tests
make test

# Start the FastAPI + React 18 + Apache ECharts executive dashboard on http://localhost:8080
make run-react-app
```

---

## Documentation Index

| Document | Description |
| :--- | :--- |
| **[01 — Prerequisites & Setup](docs/01_PREREQUISITES_AND_SETUP.md)** | Installing `gcloud`, ADC, Python environment, VS Code + AGY, DAK extension/skills, and SSL certificate proxy fixes. |
| **[02 — Infrastructure Provisioning](docs/02_INFRASTRUCTURE_PROVISIONING.md)** | Configuring `.env`, running Terraform (`infra/`) or `provision_demo_infra.sh`, and seeding BigQuery & BigLake Iceberg. |
| **[03 — End-to-End Walkthrough Guide](docs/03_E2E_WALKTHROUGH_GUIDE.md)** | Step-by-step instructions to run every prompt in `prompts/` from VS Code + AGY and use the DAK visual tools. |
| **[04 — Architecture & Design Patterns](docs/04_ARCHITECTURE_AND_DESIGN.md)** | Business context, Medallion Lakehouse architecture, and how `BigQuery AI`, `BigFrames`, and `Spark MLlib` work together. |
| **[Prompts Catalog (`prompts/README.md`)](prompts/README.md)** | Index of all 10 modular agentic prompts (`00` through `05`). |

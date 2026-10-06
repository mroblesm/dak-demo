# Agentic Prompts Library — Context, Purpose & Usage Guide

Each `.md` file in this directory (`00_environment_and_catalog_check.md` through `05_cloud_run_app_and_conversational_analytics.md`) contains **only the direct agent prompt instructions** so that you can invoke them cleanly in **VS Code + Antigravity (AGY)** (or Gemini CLI / Claude Code) with a single command:

```text
Follow instructions from @prompts/01_discovery_and_property_graph.md
```

By default, each prompt reads environment configuration from `.env` (falling back to `.env.example`) and generates code into `workspace/` (mirroring the structure of [`../reference_solution/`](../reference_solution/)) so you can compare your freshly generated code against the verified reference implementation.

> **Note — You Don't Need to Write Long Prompts Like These by Hand!**
> The prompts in this directory are intentionally detailed and prescriptive so that anyone cloning this repository can reproduce the exact directory structure, file names, and table schemas in a single shot. **These prompts were themselves generated and iteratively refined with AI** starting from simple, conversational requests (e.g., *"Search the catalog for our retail tables and profile zero-result queries"* or *"Build a dbt staging and mart pipeline over our Iceberg search events"*). Because the **Google Cloud Data Agent Kit (DAK)** skills (`@skill:...`) already encode Google Cloud architectural best practices, syntax rules, and FinOps guardrails, you can interact with AGY using brief, natural-language prompts in your day-to-day workflow.

---

## Prompt Catalog & Detailed Context

| Step | Prompt File | DAK Skills Activated | Target Output Directory (`workspace/`) | Reference Solution (`reference_solution/`) |
| :--- | :--- | :--- | :--- | :--- |
| **Step 0** | [`00_environment_and_catalog_check.md`](00_environment_and_catalog_check.md) | `@skill:gcloud-auth-verification` `@skill:gcp-data-assets-discovery` `@skill:biglake-management` | *(Read-only verification)* | N/A |
| **Step 1** | [`01_discovery_and_property_graph.md`](01_discovery_and_property_graph.md) | `@skill:gcp-data-assets-discovery` `@skill:bigquery-optimization` | `workspace/01_discovery/` | [`reference_solution/01_discovery/`](../reference_solution/01_discovery/) |
| **Step 2A** | [`02a_spark_bronze_medallion_iceberg.md`](02a_spark_bronze_medallion_iceberg.md) | `@skill:gcp-spark` `@skill:biglake-management` `@skill:notebook-best-practices` | `workspace/02_preparation/alt_b_serverless_spark/` | [`reference_solution/02_preparation/alt_b_serverless_spark/`](../reference_solution/02_preparation/alt_b_serverless_spark/) |
| **Step 2B** | [`02b_dbt_silver_gold_and_scorecards.md`](02b_dbt_silver_gold_and_scorecards.md) | `@skill:dbt-bigquery` `@skill:data-autocleaning` `@skill:bigquery-optimization` | `workspace/02_preparation/alt_a_dbt_dea/` | [`reference_solution/02_preparation/alt_a_dbt_dea/`](../reference_solution/02_preparation/alt_a_dbt_dea/) |
| **Step 3A** | [`03a_bigquery_ml_and_bigframes.md`](03a_bigquery_ml_and_bigframes.md) | `@skill:bigframes-codegen` `@skill:bigquery-ai-rules` `@skill:ml-best-practices` `@skill:notebook-best-practices` | `workspace/03_ml_training_inference/alt_a_bqml_ai_sql/` & `alt_b_bigframes/` | [`reference_solution/03_ml_training_inference/`](../reference_solution/03_ml_training_inference/) |
| **Step 3B** | [`03b_spark_mllib_and_experiments.md`](03b_spark_mllib_and_experiments.md) | `@skill:gcp-spark` `@skill:ml-best-practices` `@skill:notebook-best-practices` | `workspace/03_ml_training_inference/alt_c_spark_mllib/` | [`reference_solution/03_ml_training_inference/alt_c_spark_mllib/`](../reference_solution/03_ml_training_inference/alt_c_spark_mllib/) |
| **Step 3C** | [`03c_compare_bigquery_vs_spark_ml.md`](03c_compare_bigquery_vs_spark_ml.md) | `@skill:ml-best-practices` `@skill:bigframes-codegen` `@skill:bigquery-ai-rules` `@skill:gcp-spark` | *(Live SQL + Architectural Comparison)* | N/A |
| **Step 4A** | [`04a_declarative_orchestration_pipeline.md`](04a_declarative_orchestration_pipeline.md) | `@skill:gcp-data-cloud-pipeline-orchestration-definition-skill` | `workspace/04_orchestration/alt_a_orchestration_pipelines/` | [`reference_solution/04_orchestration/alt_a_orchestration_pipelines/`](../reference_solution/04_orchestration/alt_a_orchestration_pipelines/) |
| **Step 4B** | [`04b_composer_rca_troubleshooting.md`](04b_composer_rca_troubleshooting.md) | `@skill:gcp-composer-troubleshooting` | `workspace/04_orchestration/alt_b_cloud_composer/` | [`reference_solution/04_orchestration/alt_b_cloud_composer/`](../reference_solution/04_orchestration/alt_b_cloud_composer/) |
| **Step 5** | [`05_cloud_run_app_and_conversational_analytics.md`](05_cloud_run_app_and_conversational_analytics.md) | `@skill:web-app-development` `@skill:streamlit-data-app` | `workspace/05_presentation_app/` | [`reference_solution/05_presentation_app/`](../reference_solution/05_presentation_app/) |

---

## Stage-by-Stage Context & Runtime Notes

### Step 0: [`00_environment_and_catalog_check.md`](00_environment_and_catalog_check.md)
- **Purpose**: Pre-flight verification of `gcloud` and Application Default Credentials (ADC), Dataplex Knowledge Catalog semantic search, and inspection of the 3-tier BigQuery datasets (`raw_retail_core`, `modeled_search_warehouse`, `serving_clarity_intelligence`) alongside the BigLake Apache Iceberg REST Catalogs (`lrc` and optional cross-cloud `biglakefederated`).

### Step 1: [`01_discovery_and_property_graph.md`](01_discovery_and_property_graph.md)
- **Purpose**: Generates the Dataplex discovery CLI script (`dak_discovery_walkthrough.sh`) and partition-pruned BigQuery profiling + Property Graph SQL script (`discovery_inspection_queries.sql`) to diagnose the **Long-Tail Conversion Desert** (where 4+ word queries suffer a >30% zero-result rate and 1.10% conversion rate) and create the `retail_search_graph` Property Graph (`Customer` $\to$ `SearchEvent` $\to$ `CatalogItem`).
- **Runtime Note**: Executing `GRAPH ... MATCH ...` queries in BigQuery requires an `ENTERPRISE` or `ENTERPRISE_PLUS` slot reservation in the dataset's location (`US`). `infra/provision_demo_infra.sh` (`Step 0.8`) provisions a `0`-baseline autoscale reservation (`--slots=0 --autoscale_max_slots=50`) automatically.

### Step 2A: [`02a_spark_bronze_medallion_iceberg.md`](02a_spark_bronze_medallion_iceberg.md)
- **Purpose**: Generates `spark_medallion_prep.py`, the self-contained interactive notebook `spark_medallion_prep.ipynb`, and `submit_serverless_batch.sh` on **Dataproc Serverless Runtime `2.3`** (Spark 3.5 + Iceberg `1.5.0`). Applies salted SHA-256 PII pseudonymisation (`pseudonymized_customer_id`), filters scraper bots, computes 30-minute session boundaries (`clarity_session_id`), and writes to `lrc.modeled_search_warehouse.sessionized_searches` using **Git-style Write-Audit-Publish (`audit_branch`)** branching and **zero-scan metadata rollbacks (`CALL lrc.system.rollback_to_snapshot`)**.
- **Runtime Notes**:
  - Dataproc Serverless `jupyterSession` (used when selecting a remote Serverless Spark kernel in VS Code) requires **Runtime `2.3`** (Scala 2.13).
  - All helper functions in `spark_medallion_prep.ipynb` are defined inline so the remote Dataproc Serverless VM never fails with `ModuleNotFoundError`.
  - Refreshing ADC (`google.auth.default()`) and injecting `Bearer <token>` into `spark.sql.catalog.{lrc,biglakefederated}.header.Authorization` authenticates Iceberg `1.5.0` against BigLake REST catalogs.

### Step 2B: [`02b_dbt_silver_gold_and_scorecards.md`](02b_dbt_silver_gold_and_scorecards.md)
- **Purpose**: Generates the `dbt-bigquery` project (`dbt_project.yml`, `profiles.yml`, `macros/generate_schema_name.sql`, `models/staging/_sources.yml`, `stg_search_events.sql`, `stg_catalog_items.sql`, `models/marts/fct_search_conversions.sql`, `_test.yml`, and `dea_a2a_workflow_request.json`).
- **Runtime Note**: `macros/generate_schema_name.sql` overrides dbt's default schema concatenation so `+schema: modeled_search_warehouse` resolves directly to `modeled_search_warehouse` (instead of `modeled_search_warehouse_modeled_search_warehouse`) when executed locally or on a Cloud Composer Airflow worker.

### Step 3A: [`03a_bigquery_ml_and_bigframes.md`](03a_bigquery_ml_and_bigframes.md)
- **Purpose**: Generates the 3-stage **BigQuery World** search intelligence pipeline:
  1. **Candidate Retrieval & Intent Extraction**: `01_ai_intent_enrichment.sql` (`AI.GENERATE_TABLE` with Gemini 2.5 Flash) and `02_hybrid_vector_search_rrf.sql` (`AI.GENERATE_EMBEDDING` + `VECTOR_SEARCH` + `SEARCH()` Reciprocal Rank Fusion).
  2. **Position-Debiased Conversion Re-Ranking**: `conversion_modeling_bigframes.ipynb` (`bigframes.ml.ensemble.XGBClassifier` with zero `.to_pandas()` calls) and `03_bqml_conversion_reranker.sql` (`BOOSTED_TREE_CLASSIFIER` with `DATA_SPLIT_METHOD = 'SEQ'` and counterfactual `1 AS displayed_rank_position`).
  3. **Zero-Shot 30-Day Demand Forecasting**: `04_ai_forecast_demand.sql` (`AI.FORECAST` powered by TimesFM 2.0).

### Step 3B: [`03b_spark_mllib_and_experiments.md`](03b_spark_mllib_and_experiments.md)
- **Purpose**: Generates the **Spark World** distributed `GBTClassifier` re-ranker (`spark_mllib_reranker.py` and self-contained `spark_mllib_reranker.ipynb`), enforcing chronological train/test splitting, converting `VectorUDT` `probability` columns via `vector_to_array()` before BigQuery/Iceberg export, and logging run parameters and `ROC AUC` metrics to **Vertex AI Experiments**.

### Step 3C: [`03c_compare_bigquery_vs_spark_ml.md`](03c_compare_bigquery_vs_spark_ml.md)
- **Purpose**: Performs a head-to-head architectural and live BigQuery SQL comparison between **Path 3A (`serving_clarity_intelligence.clarity_reranked_search_results`)** and **Path 3B (`serving_clarity_intelligence.spark_mllib_reranked_results`)**, explaining why `AUTO_CLASS_WEIGHTS = TRUE` in BQML spreads probabilities across `0.45–0.95` for top-K separation while unweighted `GBTClassifier` in Spark MLlib stays calibrated to the ~4–5% empirical base rate.

### Step 4A: [`04a_declarative_orchestration_pipeline.md`](04a_declarative_orchestration_pipeline.md)
- **Purpose**: Generates `deployment.yaml`, `orchestration-pipeline.yaml`, and `validate_and_deploy.sh` conforming to the `modelVersion: "1.0"` `gcloud beta orchestration-pipelines` schema (`composer_environment:` in `deployment.yaml`; `- pyspark:`, `- pipeline:`, and `- sql:` action blocks in `orchestration-pipeline.yaml`).

### Step 4B: [`04b_composer_rca_troubleshooting.md`](04b_composer_rca_troubleshooting.md)
- **Purpose**: Diagnoses a broken Cloud Composer Airflow DAG (`broken_dag_for_rca_demo.py`) from Cloud Logging error payloads (`simulated_composer_error_logs.json`) and generates the remediated production DAG (`clarity_search_pipeline_dag.py`).

### Step 5: [`05_cloud_run_app_and_conversational_analytics.md`](05_cloud_run_app_and_conversational_analytics.md)
- **Purpose**: Generates and containerizes the executive web application (`FastAPI` + `React 18` + `Tailwind CSS` + `Apache ECharts` on port `8080`) with 4 KPI cards, 2 ECharts visualizations, an interactive query cohort table with a Slide-Out Multi-Hypothesis & 4D Data Trust Investigation Drawer, FinOps Cost/Byte Ledger, and **BigQuery Conversational Analytics (`DataChatServiceClient`)** supporting both `custom_data_agent` (`data_agent_context`) and `inline_context` modes.

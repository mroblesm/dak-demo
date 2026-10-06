# 03 — End-to-End Walkthrough Guide (VS Code + AGY + DAK)

This guide walks through executing the 5-stage **Retail Search & Conversion Intelligence** workflow from **VS Code + Antigravity (AGY)** using the prompts in [`prompts/`](../prompts/) and the visual tools in the **Google Cloud Data Cloud (DAK) VS Code Extension**.

> **How to Invoke the Prompts (and Why They Are So Detailed)**:
> - To execute any stage in AGY, simply type: `Follow instructions from @prompts/<prompt_file>.md`
> - The files in [`prompts/`](../prompts/) are detailed so they reproduce the exact directory layout and table names in [`reference_solution/`](../reference_solution/) in one shot—**these prompts were themselves generated and refined with AI** starting from simple, natural-language requests. Because DAK skills (`@skill:...`) already encode Google Cloud best practices and guardrails, you do **not** need complex prompt engineering in everyday use.

---

## Stage 0: Environment & Multi-Catalog Verification

1. **In the VS Code DAK Sidebar**:
   - Expand your Google Cloud project (`GCP_PROJECT_ID`).
   - Browse both **BigQuery Datasets** (`raw_retail_core`, `modeled_search_warehouse`, `serving_clarity_intelligence`) and **BigLake Iceberg Catalogs** (`lrc` / `<GCP_PROJECT_ID>-iceberg-lakehouse` and `biglakefederated`).
2. **In the AGY Chat Pane**:
   - Run the prompt in [`prompts/00_environment_and_catalog_check.md`](../prompts/00_environment_and_catalog_check.md):
     ```text
     Read and execute @prompts/00_environment_and_catalog_check.md using @.env
     ```

---

## Stage 1: Semantic Data Discovery & BigQuery Property Graph (`01_discovery/`)

1. **Generate or Inspect Discovery Assets**:
   - Run [`prompts/01_discovery_and_property_graph.md`](../prompts/01_discovery_and_property_graph.md) in AGY (or open [`reference_solution/01_discovery/discovery_inspection_queries.sql`](../reference_solution/01_discovery/discovery_inspection_queries.sql)).
2. **Execute & Visualize in the DAK VS Code Extension**:
   - Run **Query 1B** in `discovery_inspection_queries.sql` to observe the **Long-Tail Conversion Desert**:
     - `head` queries (1–2 words): `2.7%` zero-result rate.
     - `torso` queries (3 words): `11.5%` zero-result rate.
     - `tail` queries (4+ words): **`32.5%` zero-result rate**, plus `42` automated `PriceScraperBot` sessions and `113` NULL `device_type` rows.
   - Run **Query 1C** (`CREATE OR REPLACE PROPERTY GRAPH ... retail_search_graph`) and **Query 1D** (`GRAPH ... MATCH (c:Customer)-[e1:INITIATED]->(s:SearchEvent)-[e2:DISPLAYED_ITEM]->(i:CatalogItem) WHERE s.query_tier = 'tail' RETURN c, e1, s, e2, i LIMIT 50;`) in the DAK SQL editor to explore the interactive **BigQuery Property Graph visualization** inside VS Code.

---

## Stage 2: Data Preparation — Serverless Spark (Bronze-to-Silver) & `dbt-bigquery` (Silver-to-Gold)

### Step 2A: Serverless Spark PII Pseudonymisation & Iceberg Branching (`02_preparation/alt_b_serverless_spark/`)
1. **Generate or Open the Spark Notebook**:
   - Run [`prompts/02a_spark_bronze_medallion_iceberg.md`](../prompts/02a_spark_bronze_medallion_iceberg.md) in AGY, or open [`reference_solution/02_preparation/alt_b_serverless_spark/spark_medallion_prep.ipynb`](../reference_solution/02_preparation/alt_b_serverless_spark/spark_medallion_prep.ipynb).
2. **Connect to Interactive Serverless Spark in VS Code**:
   - Click **Select Kernel** (top right of the notebook) $\to$ **Google Cloud Data Cloud / Dataproc Serverless**.
   - Select the **`clarity-lrc-spark-template`** session template (**Runtime `2.3`**, Spark 3.5 + Iceberg `1.5.0`).
3. **Execute the 3 Code Cells**:
   - **Cell 1**: Authenticates to both `biglakefederated` and `lrc` Iceberg REST catalogs using OAuth Bearer token headers and prints the raw schema (`bronze_df.printSchema()`).
   - **Cell 2**: Applies salted SHA-256 PII pseudonymisation (`pseudonymized_customer_id`), drops raw `user_email` / `ip_address`, filters scraper bots, computes 30-minute session IDs (`clarity_session_id`), and writes `lrc.modeled_search_warehouse.sessionized_searches`. Observe the **`SparkMonitor`** widget rendering live stage and executor timelines below the cell.
   - **Cell 3**: Creates an isolated Git-style Iceberg branch (`ALTER TABLE ... CREATE BRANCH IF NOT EXISTS audit_branch`), audits data quality on `.branch_audit_branch`, fast-forwards `main` (`CALL lrc.system.fast_forward(...)`), and demonstrates an instant zero-scan metadata rollback (`CALL lrc.system.rollback_to_snapshot(...)`).

### Step 2B: Modular ELT with `dbt-bigquery` & Knowledge Catalog Scorecards (`02_preparation/alt_a_dbt_dea/`)
1. **Generate or Inspect the `dbt-bigquery` Project**:
   - Run [`prompts/02b_dbt_silver_gold_and_scorecards.md`](../prompts/02b_dbt_silver_gold_and_scorecards.md) in AGY, or inspect [`reference_solution/02_preparation/alt_a_dbt_dea/`](../reference_solution/02_preparation/alt_a_dbt_dea/).
2. **Key Highlights to Review**:
   - [`models/staging/_sources.yml`](../reference_solution/02_preparation/alt_a_dbt_dea/models/staging/_sources.yml) & [`macros/generate_schema_name.sql`](../reference_solution/02_preparation/alt_a_dbt_dea/macros/generate_schema_name.sql): 4-part BigLake Iceberg table resolution alongside native BigQuery tables, plus clean target schema resolution.
   - [`models/staging/stg_search_events.sql`](../reference_solution/02_preparation/alt_a_dbt_dea/models/staging/stg_search_events.sql): Automated cleaning summary, string normalization, bot removal, and `QUALIFY ROW_NUMBER() OVER (...) = 1` deduplication.
   - [`models/marts/fct_search_conversions.sql`](../reference_solution/02_preparation/alt_a_dbt_dea/models/marts/fct_search_conversions.sql) & [`_test.yml`](../reference_solution/02_preparation/alt_a_dbt_dea/models/marts/_test.yml): Daily partitioning on `event_date`, clustering on `query_tier, search_algorithm_arm`, `WHERE EXISTS` semi-join optimization, and native `dbt` 1.8+ `unit_tests:`.

---

## Stage 3: Model Training & Inference — Two Customer Paths (`03_ml_training_inference/`)

### Step 3A: The BigQuery World (`BigQuery AI` + `BigFrames` `XGBClassifier` + `BQML`)
1. Run [`prompts/03a_bigquery_ml_and_bigframes.md`](../prompts/03a_bigquery_ml_and_bigframes.md) in AGY, or open:
   - [`reference_solution/03_ml_training_inference/alt_a_bqml_ai_sql/01_ai_intent_enrichment.sql`](../reference_solution/03_ml_training_inference/alt_a_bqml_ai_sql/01_ai_intent_enrichment.sql) (`AI.GENERATE_TABLE` extracting typed catalog filters from long-tail queries).
   - [`02_hybrid_vector_search_rrf.sql`](../reference_solution/03_ml_training_inference/alt_a_bqml_ai_sql/02_hybrid_vector_search_rrf.sql) (`AI.GENERATE_EMBEDDING` + `VECTOR_SEARCH` + `SEARCH()` Reciprocal Rank Fusion).
   - [`alt_b_bigframes/conversion_modeling_bigframes.ipynb`](../reference_solution/03_ml_training_inference/alt_b_bigframes/conversion_modeling_bigframes.ipynb) & [`03_bqml_conversion_reranker.sql`](../reference_solution/03_ml_training_inference/alt_a_bqml_ai_sql/03_bqml_conversion_reranker.sql) (Chronological split on `event_timestamp`, in-warehouse `XGBClassifier` / `BOOSTED_TREE_CLASSIFIER`, and counterfactual Rank-1 position-bias debiasing: `1 AS displayed_rank_position`).
   - [`04_ai_forecast_demand.sql`](../reference_solution/03_ml_training_inference/alt_a_bqml_ai_sql/04_ai_forecast_demand.sql) (30-day category demand forecast using zero-shot `AI.FORECAST` / TimesFM 2.0).

### Step 3B: The Spark World (`Managed Spark MLlib` + `SparkMonitor` + Vertex AI Experiments)
1. Run [`prompts/03b_spark_mllib_and_experiments.md`](../prompts/03b_spark_mllib_and_experiments.md) in AGY, or open [`reference_solution/03_ml_training_inference/alt_c_spark_mllib/spark_mllib_reranker.ipynb`](../reference_solution/03_ml_training_inference/alt_c_spark_mllib/spark_mllib_reranker.ipynb).
2. Review the chronological 80/20 split, distributed `GBTClassifier` pipeline, `vector_to_array(F.col("probability")).getItem(1)` serialization, and `google.cloud.aiplatform` experiment logging.

### Step 3C: Head-to-Head Comparison (BigQuery World vs. Spark World)
1. Run [`prompts/03c_compare_bigquery_vs_spark_ml.md`](../prompts/03c_compare_bigquery_vs_spark_ml.md) in AGY to compare both approaches architecturally and execute a live SQL comparison across `serving_clarity_intelligence.clarity_reranked_search_results` and `serving_clarity_intelligence.spark_mllib_reranked_results`.

---

## Stage 4: Declarative Orchestration Pipelines & Cloud Composer RCA (`04_orchestration/`)

### Step 4A: Declarative Orchestration Pipelines (`04_orchestration/alt_a_orchestration_pipelines/`)
1. Run [`prompts/04a_declarative_orchestration_pipeline.md`](../prompts/04a_declarative_orchestration_pipeline.md) in AGY, or inspect [`reference_solution/04_orchestration/alt_a_orchestration_pipelines/deployment.yaml`](../reference_solution/04_orchestration/alt_a_orchestration_pipelines/deployment.yaml) and [`orchestration-pipeline.yaml`](../reference_solution/04_orchestration/alt_a_orchestration_pipelines/orchestration-pipeline.yaml).
2. Validate the schema locally:
   ```bash
   make validate-orchestration
   ```
3. If your Cloud Composer 3 environment is active, deploy from the repository root:
   ```bash
   cp reference_solution/04_orchestration/alt_a_orchestration_pipelines/deployment.yaml .
   cp reference_solution/04_orchestration/alt_a_orchestration_pipelines/orchestration-pipeline.yaml .
   gcloud beta orchestration-pipelines deploy --environment=dev --local --validate
   gcloud beta orchestration-pipelines deploy --environment=dev --local --no-paused
   ```
4. Open the **Orchestration Pipelines** panel in the VS Code DAK extension to view the DAG graph (`stage_2_1_spark_bronze_pii_pseudonymisation` $\to$ `stage_2_2_dbt_silver_gold_transformation` $\to$ `step_3_reranker_scoring`).

### Step 4B: Cloud Composer Airflow DAG Root-Cause Analysis (`04_orchestration/alt_b_cloud_composer/`)
1. Run [`prompts/04b_composer_rca_troubleshooting.md`](../prompts/04b_composer_rca_troubleshooting.md) in AGY to diagnose [`broken_dag_for_rca_demo.py`](../reference_solution/04_orchestration/alt_b_cloud_composer/broken_dag_for_rca_demo.py) from [`simulated_composer_error_logs.json`](../reference_solution/04_orchestration/alt_b_cloud_composer/simulated_composer_error_logs.json) and verify the remediated DAG [`clarity_search_pipeline_dag.py`](../reference_solution/04_orchestration/alt_b_cloud_composer/clarity_search_pipeline_dag.py).

---

## Stage 5: Executive Application on Cloud Run & BigQuery Conversational Analytics (`05_presentation_app/`)

1. **Generate or Inspect the Full-Stack App**:
   - Run [`prompts/05_cloud_run_app_and_conversational_analytics.md`](../prompts/05_cloud_run_app_and_conversational_analytics.md) in AGY, or inspect [`reference_solution/05_presentation_app/alt_a_react_cloud_run/`](../reference_solution/05_presentation_app/alt_a_react_cloud_run/).
2. **Run Locally**:
   ```bash
   make run-react-app
   ```
   Open `http://localhost:8080` in your browser to explore:
   - **4 Executive KPI Cards** and the collapsible **FinOps Cost/Byte Ledger Banner**.
   - **2 Interactive Apache ECharts Visualizations** (A/B/C Conversion Rate Lift by Query Tier & 30-Day `AI.FORECAST` Category Revenue Projection).
   - **Interactive Query Cohort Table & Slide-Out Investigation Drawer**: Click cohort `Q-TAIL-01` to inspect Multi-Hypothesis Root-Cause evidence, 4D Data Trust scores, and the FinOps query receipt.
   - **BigQuery Conversational Analytics (`DataChatServiceClient`)**: Switch between **Custom BQ CA Data Agent (`data_agent_context`)** and **Stateless CA API (`inline_context`)**, ask natural-language questions, and inspect the reasoning thoughts and generated SQL.
3. **Deploy to Google Cloud Run**:
   ```bash
   bash reference_solution/05_presentation_app/alt_a_react_cloud_run/deploy_cloud_run.sh
   ```

---

## Comparing Your Generated Code Against `reference_solution/`

After running any prompt in `prompts/` (which writes to `workspace/`), compare your agent's output against the verified reference implementation:

```bash
diff -ru reference_solution/ workspace/
```

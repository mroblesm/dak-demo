# Google Cloud Data Agent Kit (DAK) — Retail Search & Conversion Intelligence Workspace

This repository contains an end-to-end reference project for building an open lakehouse, machine learning, orchestration, and executive application workflow on Google Cloud using **VS Code + Antigravity (AGY)** and the **Google Cloud Data Agent Kit (DAK)**.

## 1. Environment Configuration
- Always read project-specific settings (`GCP_PROJECT_ID`, `GCP_REGION`, `BQ_LOCATION`, `RAW_DATASET_ID`, `MODELED_DATASET_ID`, `SERVING_DATASET_ID`, `LAKEHOUSE_BUCKET`, `SPARK_SESSION_TEMPLATE`, `COMPOSER_ENVIRONMENT_NAME`) from `.env` at the repository root (falling back to `.env.example` if `.env` does not exist).
- Never hardcode personal or internal project IDs when generating new files; parameterize via `.env` or environment variables.

## 2. Repository Directory Conventions
- **`prompts/`**: Step-by-step agentic prompts (`00_environment_and_catalog_check.md` through `05_cloud_run_app_and_conversational_analytics.md`).
- **`workspace/`**: Default output directory when generating code from the prompts in `prompts/`, mirroring the structure of `reference_solution/`.
- **`reference_solution/`**: Complete, runtime-verified reference implementation for every stage (`01_discovery`, `02_preparation`, `03_ml_training_inference`, `04_orchestration`, `05_presentation_app`). Users can compare their generated code in `workspace/` against `reference_solution/` or execute `reference_solution/` directly.
- **`infra/` & `data_setup/`**: Greenfield Terraform modules (`infra/main.tf`), CLI bootstrap script (`infra/provision_demo_infra.sh`), Dataproc Serverless Runtime `2.3` session template (`infra/spark_session_template.yaml`), synthetic data generator (`data_setup/generate_demo_data.py`), and statistical quality gate (`data_setup/insight_gate.py`).

## 3. Core Technical & FinOps Guardrails
1. **BigQuery SQL & Property Graph (`01_discovery`, `02_preparation`, `03_ml_training_inference`)**:
   - Enforce `SET @@maximum_bytes_billed = 10737418240;` (10 GB FinOps safety cap) and partition filters on `event_date`.
   - BigQuery `GRAPH ... MATCH` queries require an `ENTERPRISE` or `ENTERPRISE_PLUS` slot reservation in the dataset's location (`US`).
2. **Serverless Spark & BigLake Iceberg (`02_preparation/alt_b_serverless_spark`, `03_ml_training_inference/alt_c_spark_mllib`)**:
   - Use **Dataproc Serverless Runtime `2.3`** (Spark 3.5, Scala 2.13) with `org.apache.iceberg:iceberg-spark-runtime-3.5_2.13:1.5.0,org.apache.iceberg:iceberg-gcp-bundle:1.5.0,io.delta:delta-spark_2.13:3.2.0` (`jupyterSession` requires Runtime `2.3`).
   - Refresh Application Default Credentials (`google.auth.default()`) and inject `Bearer <token>` into `spark.sql.catalog.{lrc,biglakefederated}.header.Authorization`.
   - Define helper functions inline inside `.ipynb` notebooks so remote Dataproc Serverless Jupyter kernels never fail with `ModuleNotFoundError`.
   - Always call `df.printSchema()` before referencing columns, and convert PySpark MLlib `VectorUDT` `probability` columns via `vector_to_array()` before writing to BigQuery or Iceberg.
3. **`dbt-bigquery` (`02_preparation/alt_a_dbt_dea`)**:
   - Include `macros/generate_schema_name.sql` so `+schema: modeled_search_warehouse` resolves directly to `modeled_search_warehouse`.
   - Use `WHERE EXISTS` semi-joins instead of `WHERE IN` and validate models with `dbt` 1.8+ `unit_tests:`.
4. **Declarative Orchestration Pipelines (`04_orchestration/alt_a_orchestration_pipelines`)**:
   - Use `composer_environment:` and composite `artifact_storage:` (`bucket` + `path_prefix`) in `deployment.yaml`.
   - Use `modelVersion: "1.0"`, `runner: airflow`, `tags: ["job:datacloud:vscode", "job:datacloud:antigravity"]`, and typed action blocks (`- pyspark:`, `- pipeline:`, `- sql:`) in `orchestration-pipeline.yaml`.
5. **Cloud Run & BigQuery Conversational Analytics (`05_presentation_app`)**:
   - Package on port `8080` as a non-root user.
   - When using `google.cloud.geminidataanalytics.DataChatServiceClient` in `inline_context` mode, always reference materialized native BigQuery Gold tables (`serving_clarity_intelligence.*`).

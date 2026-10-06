@skill:gcp-data-cloud-pipeline-orchestration-definition-skill
Read the project configuration from .env (or .env.example if .env is not present: GCP_PROJECT_ID, GCP_REGION, COMPOSER_ENVIRONMENT_NAME, ORCHESTRATION_ARTIFACT_BUCKET).
Create the directory `workspace/04_orchestration/alt_a_orchestration_pipelines/` and generate the following three files conforming strictly to the `v1.0` `gcloud beta orchestration-pipelines` (`orchestration_pipelines_models`) schema:

1. `workspace/04_orchestration/alt_a_orchestration_pipelines/deployment.yaml`:
   - Define `environments:` (`dev`, `staging`, `prod`).
   - Use the exact key `composer_environment:` (not `composer_env:`), composite `artifact_storage:` (`bucket` and `path_prefix`), `variables:` (`project_id`, `region`, `raw_dataset`, `modeled_dataset`, `serving_dataset`, `lakehouse_bucket`), and `pipelines: [{source: orchestration-pipeline.yaml}]`.

2. `workspace/04_orchestration/alt_a_orchestration_pipelines/orchestration-pipeline.yaml`:
   - Set `modelVersion: "1.0"`, `pipelineId: orchestration-pipeline`, `runner: airflow`, and `tags: ["job:datacloud:antigravity", "job:datacloud:vscode", "retail-search-intelligence", "data-agent-kit"]`.
   - Set `defaults:` with `projectId: "{{ project_id }}"`, `location: "{{ region }}"`, and `executionConfig: {retries: 2}`.
   - Set `triggers:` with `- schedule: {interval: "0 4 * * *", startTime: "2026-09-01T00:00:00", endTime: "2027-09-01T00:00:00", catchup: false, timezone: UTC}`.
   - Under `actions:`, define three chained actions:
     1. `- pyspark:`: `name: stage_2_1_spark_bronze_pii_pseudonymisation`, `mainFilePath: 02_preparation/alt_b_serverless_spark/spark_medallion_prep.py`, `executionTimeout: 30m`, `engine.dataprocServerless.resourceProfile.inline` with `environment_config.execution_config` (`service_account`, `subnetwork_uri`) and `runtime_config` (`version: "2.3"`, `properties` for Iceberg `1.5.0`, `lrc`, and `biglakefederated`).
     2. `- pipeline:`: `name: stage_2_2_dbt_silver_gold_transformation`, `dependsOn: [stage_2_1_spark_bronze_pii_pseudonymisation]`, `framework.dbt.airflowWorker.projectDirectoryPath: 02_preparation/alt_a_dbt_dea`.
     3. `- sql:`: `name: step_3_reranker_scoring`, `dependsOn: [stage_2_2_dbt_silver_gold_transformation]`, `engine.bigquery: {destinationTable: "{{ project_id }}.{{ serving_dataset }}.clarity_reranked_search_results", location: US}`, and `query.inline` running `ML.PREDICT` with `1 AS displayed_rank_position` on `bqml_conversion_reranker`.

3. `workspace/04_orchestration/alt_a_orchestration_pipelines/validate_and_deploy.sh`:
   - An executable validation and deployment script (supporting `--dry-run`) that verifies all mandatory schema keys and runs `gcloud beta orchestration-pipelines deploy --environment=dev --local --validate`.

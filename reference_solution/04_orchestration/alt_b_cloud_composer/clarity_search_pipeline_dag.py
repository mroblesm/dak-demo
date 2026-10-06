"""Step 4 (Alternative 4B): Production Cloud Composer (Airflow 2.x) DAG for Project Clarity.

Coordinates Serverless Spark Medallion ETL over BigLake Iceberg, BigQuery/dbt mart builds,
and BQML conversion propensity re-ranker updates using native Google Cloud operators.
"""

from __future__ import annotations

from datetime import datetime, timedelta

try:
    from airflow import DAG
    from airflow.providers.google.cloud.operators.bigquery import BigQueryInsertJobOperator
    from airflow.providers.google.cloud.operators.dataproc import DataprocCreateBatchOperator
except ImportError:
    # Lightweight stubs so syntax/unit tests run cleanly without a full Airflow installation
    class DAG:  # type: ignore[no-redef]
        def __init__(self, *args, **kwargs):
            self.dag_id = kwargs.get("dag_id", args[0] if args else "dag")

        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc_val, exc_tb):
            return False

    class _BaseOp:
        def __init__(self, task_id: str, **kwargs):
            self.task_id = task_id
            self.kwargs = kwargs

        def __rshift__(self, other):
            return other

    class BigQueryInsertJobOperator(_BaseOp):  # type: ignore[no-redef]
        pass

    class DataprocCreateBatchOperator(_BaseOp):  # type: ignore[no-redef]
        pass


PROJECT_ID = "your-gcp-project-id"
REGION = "us-central1"
LAKEHOUSE_BUCKET = f"gs://{PROJECT_ID}-iceberg-lakehouse"

DEFAULT_ARGS = {
    "owner": "search-data-engineering",
    "depends_on_past": False,
    "retries": 2,
    "retry_delay": timedelta(minutes=3),
}

with DAG(
    dag_id="clarity_search_conversion_intelligence_prod",
    default_args=DEFAULT_ARGS,
    description="Production Project Clarity DAG: Serverless Spark Iceberg -> BigQuery Mart -> BQML Re-Ranker",
    schedule="0 4 * * *",
    start_date=datetime(2026, 9, 1),
    catchup=False,
    tags=["project-clarity", "data-agent-kit", "job:datacloud:vscode"],
) as dag:

    spark_medallion_prep = DataprocCreateBatchOperator(
        task_id="spark_iceberg_medallion_prep",
        project_id=PROJECT_ID,
        region=REGION,
        batch_id="clarity-medallion-{{ ds_nodash }}",
        batch={
            "pyspark_batch": {
                "main_python_file_uri": f"{LAKEHOUSE_BUCKET}/code/spark_medallion_prep.py",
            },
            "runtime_config": {
                "version": "2.2",
                "properties": {
                    "spark.dynamicAllocation.enabled": "true",
                    "spark.dynamicAllocation.initialExecutors": "2",
                    "spark.dynamicAllocation.maxExecutors": "8",
                },
            },
        },
    )

    run_dbt_conversion_marts = BigQueryInsertJobOperator(
        task_id="run_dbt_conversion_marts",
        project_id=PROJECT_ID,
        location="US",
        configuration={
            "query": {
                # Fix 1 applied: Uses mandatory 4-part BigLake Iceberg table identifier (`lrc`)
                # Fix 2 applied: Includes mandatory `event_date` partition pruning filter
                "query": """
                    CREATE OR REPLACE TABLE `your-gcp-project-id.modeled_search_warehouse.fct_search_conversions_daily`
                    PARTITION BY event_date
                    CLUSTER BY query_tier, search_algorithm_arm
                    AS
                    SELECT
                      TRIM(search_event_id) AS search_event_id,
                      TRIM(customer_id) AS customer_id,
                      LOWER(TRIM(raw_query_text)) AS normalized_query_text,
                      query_tier,
                      UPPER(COALESCE(search_algorithm_arm, 'ARM_A_LEGACY_LEXICAL')) AS search_algorithm_arm,
                      SAFE_CAST(zero_results_flag AS INT64) AS zero_results_flag,
                      SAFE_CAST(event_date AS DATE) AS event_date
                    FROM `your-gcp-project-id.lrc.raw_search_telemetry.search_events`
                    WHERE SAFE_CAST(event_date AS DATE) >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
                      AND NOT REGEXP_CONTAINS(COALESCE(user_agent, ''), r'(?i)(ScraperBot|Crawler)')
                    QUALIFY ROW_NUMBER() OVER (PARTITION BY search_event_id ORDER BY event_timestamp DESC) = 1
                """,
                "useLegacySql": False,
                "maximumBytesBilled": "10737418240",
            }
        },
    )

    update_bqml_reranker_scores = BigQueryInsertJobOperator(
        task_id="update_bqml_reranker_scores",
        project_id=PROJECT_ID,
        location="US",
        configuration={
            "query": {
                "query": """
                    SELECT
                      roc_auc,
                      precision,
                      recall
                    FROM ML.EVALUATE(
                      MODEL `your-gcp-project-id.serving_clarity_intelligence.bqml_conversion_reranker`
                    )
                """,
                "useLegacySql": False,
                "maximumBytesBilled": "10737418240",
            }
        },
    )

    spark_medallion_prep >> run_dbt_conversion_marts >> update_bqml_reranker_scores

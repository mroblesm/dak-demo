"""Step 4 (Alternative 4B — Live RCA Demo Target): Broken Cloud Composer DAG.

Used during the live VS Code + Antigravity (`AGY`) walkthrough of
`@skill:gcp-composer-troubleshooting` and `@skill:pipeline-troubleshooting`.

Intentional Defects Embedded for Agentic Root-Cause Analysis (RCA):
  1. Defect 1 (Missing BigLake Iceberg Catalog in Table Path):
     References 3-part `your-gcp-project-id.raw_search_telemetry.search_events`
     instead of the 4-part BigLake Iceberg table
     `your-gcp-project-id.lrc.raw_search_telemetry.search_events`.
  2. Defect 2 (Missing Partition Filter on `event_date`):
     Omits the `WHERE event_date >= ...` predicate on a table configured with
     `require_partition_filter = true`.
"""

from __future__ import annotations

from datetime import datetime, timedelta
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from clarity_search_pipeline_dag import BigQueryInsertJobOperator, DAG

PROJECT_ID = "your-gcp-project-id"

with DAG(
    dag_id="broken_dag_for_rca_demo",
    default_args={"owner": "search-data-engineering", "retries": 0, "retry_delay": timedelta(minutes=1)},
    schedule="0 4 * * *",
    start_date=datetime(2026, 9, 1),
    catchup=False,
    tags=["rca-demo", "data-agent-kit"],
) as dag:

    run_dbt_conversion_marts = BigQueryInsertJobOperator(
        task_id="run_dbt_conversion_marts",
        project_id=PROJECT_ID,
        location="US",
        configuration={
            "query": {
                # BUG 1: Missing `.lrc.` BigLake Iceberg catalog segment
                # BUG 2: Missing `WHERE event_date >= ...` partition filter
                "query": """
                    CREATE OR REPLACE TABLE `your-gcp-project-id.modeled_search_warehouse.fct_search_conversions_daily`
                    AS
                    SELECT
                      search_event_id,
                      customer_id,
                      raw_query_text,
                      query_tier,
                      event_date
                    FROM `your-gcp-project-id.raw_search_telemetry.search_events`
                """,
                "useLegacySql": False,
            }
        },
    )

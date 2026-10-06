@skill:gcp-composer-troubleshooting
Inspect the Cloud Composer error logs in `reference_solution/04_orchestration/alt_b_cloud_composer/simulated_composer_error_logs.json` and the failing Airflow DAG in `reference_solution/04_orchestration/alt_b_cloud_composer/broken_dag_for_rca_demo.py`.

1. Generate a structured Root Cause Analysis (RCA) report identifying the two root causes of the `BigQueryInsertJobOperator` failure (`Cannot query over table ... without a filter over column(s) 'event_date' that can be used for partition elimination` and hardcoded `legacy-hardcoded-project-999`).
2. Generate the remediated Airflow DAG in `workspace/04_orchestration/alt_b_cloud_composer/clarity_search_pipeline_dag.py` that:
   - Reads `GCP_PROJECT_ID` dynamically from `os.environ.get("GCP_PROJECT_ID", "your-gcp-project-id")`.
   - Adds the mandatory partition filter `WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)`.
   - Enforces `maximumBytesBilled: "10737418240"` on `BigQueryInsertJobOperator` and `maxExecutors=8` on `DataprocCreateBatchOperator`.

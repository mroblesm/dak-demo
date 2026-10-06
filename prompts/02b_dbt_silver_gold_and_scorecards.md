@skill:dbt-bigquery @skill:data-autocleaning @skill:bigquery-optimization
Read the project configuration from .env (or .env.example if .env is not present: GCP_PROJECT_ID, BQ_LOCATION, RAW_DATASET_ID, MODELED_DATASET_ID).
Create the directory structure `workspace/02_preparation/alt_a_dbt_dea/` and generate the following files:

1. `workspace/02_preparation/alt_a_dbt_dea/dbt_project.yml`:
   - Project name `clarity_search_dbt`, profile `clarity_bigquery_oauth`, `+persist_docs: {relation: true, columns: true}`, staging models materialized as `view` in `+schema: modeled_search_warehouse`, and marts models materialized as `table` in `+schema: modeled_search_warehouse`.

2. `workspace/02_preparation/alt_a_dbt_dea/profiles.yml`:
   - Configure `clarity_bigquery_oauth` (`type: bigquery`, `method: oauth`, `project: "{{ env_var('GCP_PROJECT_ID', 'your-gcp-project-id') }}"`, `dataset: "{{ env_var('MODELED_DATASET_ID', 'modeled_search_warehouse') }}"`, `location: "{{ env_var('BQ_LOCATION', 'US') }}"`, `maximum_bytes_billed: 10737418240`).

3. `workspace/02_preparation/alt_a_dbt_dea/macros/generate_schema_name.sql`:
   - Override `generate_schema_name(custom_schema_name, node)` so that when `custom_schema_name` is specified (`modeled_search_warehouse`), dbt uses `{{ custom_schema_name | trim }}` directly instead of concatenating `modeled_search_warehouse_modeled_search_warehouse`.

4. `workspace/02_preparation/alt_a_dbt_dea/models/staging/_sources.yml`:
   - Configure `raw_iceberg` (`database: "{{ env_var('GCP_PROJECT_ID', 'your-gcp-project-id') }}"`, `schema: "{{ env_var('ICEBERG_CATALOG_SCHEMA', 'raw_retail_core') }}"`, table `search_events`) so it supports both 4-part federated Iceberg (`ICEBERG_CATALOG_SCHEMA=biglakefederated.raw_search_telemetry`) and standard BigQuery/Airflow worker execution (`raw_retail_core`).
   - Configure `spark_curated_iceberg` (`schema: "{{ env_var('NATIVE_LRC_CATALOG_ID', 'your-gcp-project-id-iceberg-lakehouse') }}.modeled_search_warehouse"`, table `sessionized_searches`) for the 4-part GCP-native LRC table written by Stage 2.1 Spark.
   - Configure `raw_bigquery` (`schema: "{{ env_var('RAW_DATASET_ID', 'raw_retail_core') }}"`, tables `search_impressions`, `catalog_items`, `customer_clv`).

5. `workspace/02_preparation/alt_a_dbt_dea/models/staging/stg_search_events.sql` & `stg_catalog_items.sql`:
   - Include the mandatory `@skill:data-autocleaning` `/* Automatic Cleaning Summary */` comment block at the top of `stg_search_events.sql`.
   - Standardize strings with `LOWER(TRIM(CAST(raw_query_text AS STRING)))`, coalesce NULL `device_type` to `'unknown_device'`, safely parse `event_timestamp` and `event_date`, filter scraper bots (`NOT REGEXP_CONTAINS(COALESCE(user_agent, ''), r'(?i)(ScraperBot|Bot|Crawler|Spider)')`), and deduplicate retry events using `QUALIFY ROW_NUMBER() OVER (PARTITION BY TRIM(CAST(search_event_id AS STRING)) ORDER BY event_timestamp DESC) = 1`.

6. `workspace/02_preparation/alt_a_dbt_dea/models/marts/fct_search_conversions.sql`:
   - Materialize as `table` partitioned by `event_date` (day) and clustered by `["query_tier", "search_algorithm_arm"]`.
   - Enforce `@skill:bigquery-optimization`: filter `event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)` and use a `WHERE EXISTS (SELECT 1 FROM {{ ref('stg_catalog_items') }} AS cat WHERE cat.item_id = imp.item_id AND cat.in_stock = TRUE)` semi-join instead of `WHERE IN`.

7. `workspace/02_preparation/alt_a_dbt_dea/models/marts/_test.yml` & `dea_a2a_workflow_request.json`:
   - Define column descriptions, semantic metadata tags (`meta: {datacatalog_aspect: "data-quality-scorecard"}`), schema tests (`not_null`, `unique`, `accepted_values`), and two native `dbt` 1.8+ `unit_tests:` (`test_stg_search_events_autocleaning_and_dedup` and `test_fct_search_conversions_metrics_and_semi_join`).

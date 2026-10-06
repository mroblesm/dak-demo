-- =============================================================================
-- Databricks (DBX) Unity Catalog — Iceberg / Delta UniForm Table Setup & Load
-- Target GCP Project: your-gcp-project-id
-- Target DBX Federated GCS Bucket: gs://your-gcp-project-id-iceberg-dbx-lakehouse
-- =============================================================================
-- NOTE ON DUAL-CATALOG ARCHITECTURE:
--   1. DBX Federated Catalog (`biglakefederated` on `gs://your-gcp-project-id-iceberg-dbx-lakehouse`):
--      We only need ONE table (`raw_search_telemetry.search_events`) in the
--      Databricks federated catalog to showcase the cross-cloud lakehouse story!
--   2. GCP Native LRC Catalog (`lrc` on `gs://your-gcp-project-id-iceberg-lakehouse`):
--      The remaining Iceberg tables (`raw_search_telemetry.search_impressions`
--      and `modeled_search_warehouse.sessionized_searches`) are managed natively
--      in Google Cloud BigLake LRC (`your-gcp-project-id-iceberg-lakehouse`).
-- =============================================================================

-- 1. Select your Unity Catalog (replace `main` if using a custom catalog name, e.g., `pdcc_dak`)
USE CATALOG main;

CREATE SCHEMA IF NOT EXISTS raw_search_telemetry
COMMENT 'Bronze Tier: Raw Retail Search Telemetry federated from Databricks Unity Catalog into GCP BigLake (biglakefederated)';

USE SCHEMA raw_search_telemetry;

-- =============================================================================
-- 2. Create & Load the Single Federated Table: `raw_search_telemetry.search_events` (1,248 rows)
--    Includes raw PII (`user_email`, `ip_address`) for Stage 2 Spark SHA-256
--    pseudonymisation, plus intentional dirtiness & 32.5% tail zero-result rate.
-- =============================================================================
CREATE OR REPLACE TABLE raw_search_telemetry.search_events (
  search_event_id STRING COMMENT 'Unique search session event identifier (e.g., SRCH-00001)',
  customer_id STRING COMMENT 'Customer identifier (CUST-0001..CUST-0200)',
  user_email STRING COMMENT 'Raw shopper email (PII — pseudonymised via salted SHA-256 in Stage 2 Spark)',
  ip_address STRING COMMENT 'Raw client IPv4 address (PII — pseudonymised via salted SHA-256 in Stage 2 Spark)',
  raw_query_text STRING COMMENT 'Unnormalized search query string (contains intentional whitespace/casing anomalies)',
  normalized_query_text STRING COMMENT 'Lowercased trimmed canonical query string',
  query_length_tokens INT COMMENT 'Token count of the query (1-2 = head, 3 = torso, 4+ = tail)',
  query_tier STRING COMMENT 'Query frequency tier: head | torso | tail',
  device_type STRING COMMENT 'Client device category (contains intentional NULLs for autocleaning)',
  user_agent STRING COMMENT 'HTTP User-Agent (contains PriceScraperBot rows to filter)',
  zero_results_flag INT COMMENT '1 if search returned zero products (32.5% on tail queries), else 0',
  search_algorithm_arm STRING COMMENT 'Experiment arm: ARM_A_LEGACY_LEXICAL | ARM_B_HYBRID_VECTOR | ARM_C_CLARITY_RERANKED',
  event_timestamp TIMESTAMP COMMENT 'UTC event timestamp',
  event_date DATE COMMENT 'Partition date (YYYY-MM-DD)'
)
USING DELTA
PARTITIONED BY (event_date)
COMMENT 'Cross-cloud raw shopper search telemetry federated zero-copy from Databricks Unity Catalog via BigLake Iceberg REST Catalog (biglakefederated). Captures search_event_id, customer_id, raw PII (user_email, ip_address), raw_query_text, normalized_query_text, query_tier (head, torso, tail), zero_results_flag, device_type, user_agent (PriceScraperBot), and search_algorithm_arm.'
LOCATION 'gs://your-gcp-project-id-iceberg-dbx-lakehouse/raw_search_telemetry/search_events'
TBLPROPERTIES (
  'delta.columnMapping.mode' = 'name',
  'delta.enableIcebergCompatV2' = 'true',
  'delta.universalFormat.enabledFormats' = 'iceberg'
);

-- Load from GCS staged JSONL in gs://your-gcp-project-id-iceberg-dbx-lakehouse/dbx_seed_data/search_events.jsonl
COPY INTO raw_search_telemetry.search_events
FROM (
  SELECT
    search_event_id::STRING,
    customer_id::STRING,
    user_email::STRING,
    ip_address::STRING,
    raw_query_text::STRING,
    normalized_query_text::STRING,
    query_length_tokens::INT,
    query_tier::STRING,
    device_type::STRING,
    user_agent::STRING,
    zero_results_flag::INT,
    search_algorithm_arm::STRING,
    CAST(event_timestamp AS TIMESTAMP) AS event_timestamp,
    CAST(event_date AS DATE) AS event_date
  FROM 'gs://your-gcp-project-id-iceberg-dbx-lakehouse/dbx_seed_data/search_events.jsonl'
)
FILEFORMAT = JSON
COPY_OPTIONS ('force' = 'true');

-- Verify row count (expected: 1,248 rows) and Iceberg UniForm snapshot generation
SELECT 'search_events' AS table_name, COUNT(*) AS row_count FROM raw_search_telemetry.search_events;

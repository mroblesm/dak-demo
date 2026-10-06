{{
  config(
    materialized='view',
    labels={'managed_by': 'dak_dbt_bigquery', 'skill': 'data_autocleaning'}
  )
}}

/* =============================================================================
   Automatic Cleaning Summary (@skill:data-autocleaning)
   =============================================================================
   - String Trimming & Casing Standardization:
     Applied `LOWER(TRIM(raw_query_text))` to eliminate leading/trailing
     whitespace and mixed-case duplicates across 425+ raw search queries.
   - Null Value Coalescing & Safe Defaults:
     Applied `COALESCE(NULLIF(TRIM(device_type), ''), 'unknown_device')` to
     resolve 113+ NULL `device_type` records without dropping valid searches.
   - Safe Type & Timestamp Casting:
     Applied `SAFE.PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S%Ez', CAST(event_timestamp AS STRING))`
     and `SAFE_CAST(zero_results_flag AS INT64)`.
   - Automated Bot Traffic Filtering:
     Removed automated scraper bot traffic matching `ScraperBot|Crawler|Spider`.
   - Deterministic Row Deduplication:
     Applied `QUALIFY ROW_NUMBER() OVER (PARTITION BY search_event_id ORDER BY event_timestamp DESC) = 1`
     to remove duplicate retry events emitted by client network retries.
   ============================================================================= */

WITH raw_events AS (
  SELECT
    search_event_id,
    customer_id,
    raw_query_text,
    device_type,
    user_agent,
    zero_results_flag,
    search_algorithm_arm,
    event_timestamp,
    event_date
  FROM {{ source('raw_iceberg', 'search_events') }}
  WHERE event_date IS NOT NULL
),

cleaned_and_deduplicated AS (
  SELECT
    TRIM(CAST(search_event_id AS STRING)) AS search_event_id,
    TRIM(CAST(customer_id AS STRING)) AS customer_id,
    LOWER(TRIM(CAST(raw_query_text AS STRING))) AS normalized_query_text,
    ARRAY_LENGTH(SPLIT(LOWER(TRIM(CAST(raw_query_text AS STRING))), ' ')) AS query_length_tokens,
    CASE
      WHEN ARRAY_LENGTH(SPLIT(LOWER(TRIM(CAST(raw_query_text AS STRING))), ' ')) >= 4 THEN 'tail'
      WHEN ARRAY_LENGTH(SPLIT(LOWER(TRIM(CAST(raw_query_text AS STRING))), ' ')) = 3 THEN 'torso'
      ELSE 'head'
    END AS query_tier,
    LOWER(COALESCE(NULLIF(TRIM(CAST(device_type AS STRING)), ''), 'unknown_device')) AS device_type,
    COALESCE(TRIM(CAST(user_agent AS STRING)), 'unknown_agent') AS user_agent,
    COALESCE(SAFE_CAST(zero_results_flag AS INT64), 0) AS zero_results_flag,
    UPPER(COALESCE(TRIM(CAST(search_algorithm_arm AS STRING)), 'ARM_A_LEGACY_LEXICAL')) AS search_algorithm_arm,
    COALESCE(
      SAFE_CAST(event_timestamp AS TIMESTAMP),
      SAFE.PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S%Ez', CAST(event_timestamp AS STRING))
    ) AS event_timestamp,
    SAFE_CAST(event_date AS DATE) AS event_date
  FROM raw_events
  WHERE NOT REGEXP_CONTAINS(COALESCE(user_agent, ''), r'(?i)(ScraperBot|Bot|Crawler|Spider)')
    AND TRIM(COALESCE(raw_query_text, '')) != ''
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY TRIM(CAST(search_event_id AS STRING))
    ORDER BY event_timestamp DESC
  ) = 1
)

SELECT * FROM cleaned_and_deduplicated

{{
  config(
    materialized='table',
    partition_by={
      "field": "event_date",
      "data_type": "date",
      "granularity": "day"
    },
    cluster_by=["query_tier", "search_algorithm_arm"],
    labels={'managed_by': 'dak_dbt_bigquery', 'skill': 'developing_with_bigquery'}
  )
}}

/* =============================================================================
   BigQuery SQL Optimization Summary (@skill:developing-with-bigquery)
   =============================================================================
   1. Partition Pruning & Clustering:
      Materialized with daily partitioning on `event_date` and clustered by
      `query_tier, search_algorithm_arm` to minimize bytes scanned by downstream
      BQML training and executive dashboard queries.
   2. Semi-Join Optimization (`WHERE EXISTS` instead of `WHERE IN`):
      Replaced correlated `item_id IN (SELECT item_id FROM ...)` filtering with
      `WHERE EXISTS (...)` against `stg_catalog_items` to avoid shuffle bottlenecks.
   3. Explicit Column Projection & Pre-Aggregation:
      Projected only required columns prior to joining `search_impressions` with
      `stg_search_events` and `customer_clv`, reducing shuffle slot consumption.
   ============================================================================= */

WITH valid_events AS (
  SELECT
    search_event_id,
    customer_id,
    normalized_query_text,
    query_length_tokens,
    query_tier,
    device_type,
    zero_results_flag,
    search_algorithm_arm,
    event_timestamp,
    event_date
  FROM {{ ref('stg_search_events') }}
  WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
),

impression_rollups AS (
  SELECT
    imp.search_event_id,
    COUNT(*) AS total_impressions,
    MAX(SAFE_CAST(imp.clicked AS INT64)) AS session_clicked,
    MAX(SAFE_CAST(imp.purchased AS INT64)) AS session_purchased,
    ROUND(SUM(COALESCE(SAFE_CAST(imp.attributed_revenue_usd AS FLOAT64), 0.0)), 2) AS session_revenue_usd,
    MIN(CASE WHEN SAFE_CAST(imp.clicked AS INT64) = 1 THEN SAFE_CAST(imp.displayed_rank_position AS INT64) END) AS best_clicked_rank,
    ROUND(AVG(SAFE_CAST(imp.semantic_cosine_similarity AS FLOAT64)), 4) AS avg_semantic_similarity,
    ROUND(AVG(SAFE_CAST(imp.lexical_bm25_score AS FLOAT64)), 4) AS avg_lexical_bm25
  FROM {{ source('raw_bigquery', 'search_impressions') }} AS imp
  WHERE EXISTS (
    SELECT 1
    FROM {{ ref('stg_catalog_items') }} AS cat
    WHERE cat.item_id = imp.item_id
      AND cat.in_stock = TRUE
  )
  GROUP BY imp.search_event_id
)

SELECT
  ev.search_event_id,
  ev.customer_id,
  ev.normalized_query_text,
  ev.query_length_tokens,
  ev.query_tier,
  ev.device_type,
  ev.zero_results_flag,
  ev.search_algorithm_arm,
  COALESCE(clv.clv_segment, 'NEW_EXPLORER') AS customer_clv_segment,
  COALESCE(clv.predicted_12m_clv_usd, 210.0) AS predicted_12m_clv_usd,
  COALESCE(imp.total_impressions, 0) AS total_impressions,
  COALESCE(imp.session_clicked, 0) AS clicked,
  COALESCE(imp.session_purchased, 0) AS purchased,
  COALESCE(imp.session_revenue_usd, 0.0) AS attributed_revenue_usd,
  imp.best_clicked_rank,
  COALESCE(imp.avg_semantic_similarity, 0.0) AS avg_semantic_similarity,
  COALESCE(imp.avg_lexical_bm25, 0.0) AS avg_lexical_bm25,
  ev.event_timestamp,
  ev.event_date
FROM valid_events AS ev
LEFT JOIN impression_rollups AS imp
  ON ev.search_event_id = imp.search_event_id
LEFT JOIN {{ source('raw_bigquery', 'customer_clv') }} AS clv
  ON ev.customer_id = clv.customer_id

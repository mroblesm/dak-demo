-- =============================================================================
-- Step 1: Cost-Guarded Data Discovery & Single-Scan Quality Profiling
-- Enforces @skill:discovering-gcp-data-assets & @skill:developing-with-bigquery
--   1. Enforces FinOps cap (`@@ maximum_bytes_billed = 1073741824`)
--   2. Inspects INFORMATION_SCHEMA.PARTITIONS (zero table data scan cost)
--   3. Profiles cardinality, NULLs, whitespace/casing dirtiness, duplicates,
--      and scraper bot traffic in a SINGLE table scan using APPROX_TOP_COUNT
-- =============================================================================

SET @@maximum_bytes_billed = 1073741824; -- 1 GB FinOps safety cap

-- Query 1A: Zero-Scan Partition & Storage Metadata Inspection
SELECT
  table_name,
  partition_id,
  total_rows,
  ROUND(total_logical_bytes / POW(1024, 2), 2) AS logical_mb,
  last_modified_time
FROM `your-gcp-project-id.raw_retail_core.INFORMATION_SCHEMA.PARTITIONS`
WHERE table_name IN ('search_impressions')
  AND partition_id IS NOT NULL
ORDER BY table_name, partition_id DESC
LIMIT 20;

-- Query 1B: Single-Scan Telemetry Quality & Anomaly Profile (@skill:data-autocleaning input)
-- Queries the 4-part Databricks Federated BigLake Iceberg REST Catalog (`biglakefederated`)
SELECT
  COUNT(*) AS total_raw_rows,
  APPROX_COUNT_DISTINCT(search_event_id) AS approx_distinct_events,
  COUNT(*) - APPROX_COUNT_DISTINCT(search_event_id) AS approx_duplicate_retries,
  COUNTIF(raw_query_text != TRIM(raw_query_text) OR raw_query_text != LOWER(raw_query_text)) AS dirty_whitespace_or_casing_rows,
  COUNTIF(device_type IS NULL) AS null_device_type_rows,
  COUNTIF(REGEXP_CONTAINS(user_agent, r'(?i)(ScraperBot|Bot|Crawler)')) AS scraper_bot_rows,
  APPROX_TOP_COUNT(query_tier, 5) AS top_query_tiers,
  APPROX_TOP_COUNT(device_type, 5) AS top_device_types
FROM `your-gcp-project-id.biglakefederated.raw_search_telemetry.search_events`
WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY);

-- =============================================================================
-- Query 1C: BigQuery Property & Semantic Graph Authoring (@skill:bigquery-graph-author)
-- Exposes multi-hop relationships across Customers, Search Sessions, and Catalog SKUs
-- as a first-class `.bq.graph` asset in the VS Code Knowledge Catalog Explorer &
-- Ogma interactive graph visualizer (`bigquery_graph_visualizer`).
-- =============================================================================
CREATE OR REPLACE PROPERTY GRAPH `your-gcp-project-id.modeled_search_warehouse.retail_search_graph`
  NODE TABLES (
    `your-gcp-project-id.modeled_search_warehouse.dim_customers` AS Customer
      KEY (customer_id)
      LABEL Customer
      PROPERTIES (
        customer_id,
        pseudonymized_customer_id,
        clv_segment,
        clv_tier
      ),
    `your-gcp-project-id.modeled_search_warehouse.fct_search_conversions` AS SearchSession
      KEY (search_event_id)
      LABEL SearchSession
      PROPERTIES (
        search_event_id,
        customer_id,
        normalized_query_text,
        query_tier,
        attributed_revenue_usd,
        realized_order_value_usd
      ),
    `your-gcp-project-id.raw_retail_core.catalog_items` AS ProductSKU
      KEY (item_id)
      LABEL ProductSKU
      PROPERTIES (
        item_id,
        product_title,
        category_hierarchy,
        price_usd
      )
  )
  EDGE TABLES (
    `your-gcp-project-id.modeled_search_warehouse.fct_search_conversions` AS InitiatedSearch
      KEY (search_event_id)
      SOURCE KEY (customer_id) REFERENCES Customer (customer_id)
      DESTINATION KEY (search_event_id) REFERENCES SearchSession (search_event_id)
      LABEL INITIATED_SEARCH
      PROPERTIES (device_type, event_date),
    `your-gcp-project-id.raw_retail_core.search_impressions` AS ImpressedProduct
      KEY (impression_id)
      SOURCE KEY (search_event_id) REFERENCES SearchSession (search_event_id)
      DESTINATION KEY (item_id) REFERENCES ProductSKU (item_id)
      LABEL IMPRESSED_PRODUCT
      PROPERTIES (displayed_rank_position, clicked, purchased)
  );

-- =============================================================================
-- Query 1D: Native GQL Path Visualization & Semantic GRAPH_EXPAND (@skill:bigquery-graph-query)
-- Returns JSON graph paths (`TO_JSON(p)`) rendered directly by the DAK VS Code
-- interactive graph viewer (`bigquery_graph_visualizer`).
-- =============================================================================
GRAPH `your-gcp-project-id.modeled_search_warehouse.retail_search_graph`
MATCH p = (c:Customer)-[s:INITIATED_SEARCH]->(q:SearchSession)-[i:IMPRESSED_PRODUCT {purchased: 1}]->(sku:ProductSKU)
WHERE q.query_tier = 'tail'
RETURN
  TO_JSON(p) AS interactive_graph_path,
  c.clv_tier,
  q.normalized_query_text,
  sku.category_hierarchy,
  i.displayed_rank_position
LIMIT 100;

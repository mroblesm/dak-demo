@skill:gcp-data-assets-discovery @skill:bigquery-optimization
Read the environment variables from .env (or .env.example if .env is not present: GCP_PROJECT_ID, RAW_DATASET_ID, MODELED_DATASET_ID, SERVING_DATASET_ID).
Create the directory `workspace/01_discovery/` and generate the following two files:

1. `workspace/01_discovery/dak_discovery_walkthrough.sh`:
   - An executable bash script (supporting `--dry-run`) that reads `GCP_PROJECT_ID` from `.env` / environment variables.
   - Runs `gcloud dataplex entries search " retail search conversion impressions " --project=${PROJECT_ID} --semantic-search --limit=10`.
   - Runs `gcloud dataplex entries lookup` on `raw_retail_core.search_impressions` to inspect data quality and governance aspects.
   - Runs `gcloud dataplex context lookup` to fetch rich schema, lineage, and glossary context for `search_events`, `search_impressions`, and `catalog_items`.

2. `workspace/01_discovery/discovery_inspection_queries.sql`:
   - Enforce `SET @@maximum_bytes_billed = 10737418240;` (10 GB FinOps safety cap) at the top of the script.
   - Query 1A: Zero-scan partition metadata check querying `raw_retail_core.INFORMATION_SCHEMA.PARTITIONS` for `search_impressions`.
   - Query 1B: Partition-pruned (`event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)`) statistical profile of `search_events` (using `raw_retail_core.search_events` or 4-part federated Iceberg `biglakefederated.raw_search_telemetry.search_events`) grouped by `query_tier` (`head`, `torso`, `tail`), computing `COUNT(*)`, `zero_result_rate_pct`, `null_device_type_rows`, `scraper_bot_rows` (`REGEXP_CONTAINS(user_agent, r'(?i)scraperbot|crawler')`), and `APPROX_TOP_COUNT(raw_query_text, 3)`.
   - Query 1C (DDL): Create the BigQuery Property Graph `CREATE OR REPLACE PROPERTY GRAPH <GCP_PROJECT_ID>.modeled_search_warehouse.retail_search_graph` with:
     - `NODE TABLES`: `raw_retail_core.customer_clv` (`KEY (customer_id)` LABEL `Customer`), `modeled_search_warehouse.stg_search_events` (`KEY (search_event_id)` LABEL `SearchEvent`), and `raw_retail_core.catalog_items` (`KEY (item_id)` LABEL `CatalogItem`).
     - `EDGE TABLES`: `modeled_search_warehouse.stg_search_events AS InitiatedSearch` (`SOURCE KEY (customer_id) REFERENCES Customer`, `DESTINATION KEY (search_event_id) REFERENCES SearchEvent`, LABEL `INITIATED`) and `raw_retail_core.search_impressions AS ImpressionInteraction` (`SOURCE KEY (search_event_id) REFERENCES SearchEvent`, `DESTINATION KEY (item_id) REFERENCES CatalogItem`, LABEL `DISPLAYED_ITEM`).
   - Query 1D (GQL): A `GRAPH <GCP_PROJECT_ID>.modeled_search_warehouse.retail_search_graph MATCH (c:Customer)-[:INITIATED]->(s:SearchEvent)-[r:DISPLAYED_ITEM]->(i:CatalogItem) WHERE s.query_tier = 'tail' RETURN ...` query that returns graph paths and also aggregates conversion rate by `clv_segment`, `category_hierarchy`, and `displayed_rank_position`.

Finally, verify `bash workspace/01_discovery/dak_discovery_walkthrough.sh --dry-run` and execute Query 1B in BigQuery to report the zero-result rate and bot count across `head`, `torso`, and `tail` queries.

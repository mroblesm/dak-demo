# Step 1: Data Discovery & Semantic Grounding (`01_discovery/`)

## Explicit DAK Enablement
1. **VS Code Data Cloud Extension (`GoogleCloudTools.datacloud`)**:
   - **BigQuery Datasets Tree**: Visual exploration of the 3-tier Data Mesh (`raw_search_telemetry` $\to$ `modeled_search_warehouse` $\to$ `serving_clarity_intelligence`).
   - **`.bq.table` Custom Viewer**: Zero-cost table schema, partitioning metadata, and row preview without executing `SELECT *`.
   - **Dataplex Search & GCS Buckets Tree**: Direct inspection of the Dataplex Knowledge Catalog and BigLake Apache Iceberg storage (`gs://your-gcp-project-id-iceberg-lakehouse`).
2. **Packaged Agentic Skills Invoked in Antigravity (`AGY`)**:
   - `@skill:gcloud-auth-verification`
   - `@skill:discovering-gcp-data-assets` (`gcloud dataplex entries search --semantic-search`, `gcloud dataplex context lookup --format=yaml`)
   - `@skill:biglake-management` (BigLake Iceberg `lrc` REST catalog verification)
   - `@skill:developing-with-bigquery` (Single-scan `APPROX_TOP_COUNT` profiling with `maximum_bytes_billed`)

## Live AGY Prompt
> `@skill:discovering-gcp-data-assets @skill:biglake-management Search Dataplex Knowledge Catalog for tables related to retail search conversion and customer lifetime value, look up the verified business glossary definitions for CVR, RPSS, and Position Bias, and write a cost-guarded single-scan data quality profiling query.`

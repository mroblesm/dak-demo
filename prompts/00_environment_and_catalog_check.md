@skill:gcloud-auth-verification @skill:gcp-data-assets-discovery @skill:biglake-management
Read the project configuration from .env (or .env.example if .env is not present).

1. Verify that gcloud and Application Default Credentials (ADC) are active and pointing to the configured GCP_PROJECT_ID.
2. Search the Dataplex Knowledge Catalog for "search_events", "search_impressions", and "catalog_items" across our project.
3. Inspect our BigLake Iceberg REST Catalogs (the GCP-native lakehouse catalog and, if configured, the federated catalog `biglakefederated`) alongside our native BigQuery dataset (`raw_retail_core`).
4. Summarize the Bronze, Silver, and Gold datasets and confirm which tables are stored as BigLake Apache Iceberg tables vs. native BigQuery tables.

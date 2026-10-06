output "project_id" {
  description = "Configured GCP Project ID"
  value       = var.project_id
}

output "native_iceberg_lakehouse_bucket" {
  description = "GCS bucket backing the GCP-Native BigLake Iceberg REST Catalog (lrc)"
  value       = google_storage_bucket.iceberg_lakehouse.url
}

output "federated_iceberg_lakehouse_bucket" {
  description = "GCS bucket backing the federated Iceberg catalog (biglakefederated)"
  value       = google_storage_bucket.iceberg_dbx_lakehouse.url
}

output "orchestration_artifacts_bucket" {
  description = "GCS bucket for Declarative Orchestration Pipelines bundles"
  value       = google_storage_bucket.orchestration_artifacts.url
}

output "spark_interactive_service_account" {
  description = "Service account for Dataproc Serverless Spark interactive & batch sessions"
  value       = google_service_account.s8s_spark_interactive.email
}

output "demo_runner_service_account" {
  description = "Service account for Cloud Run and Cloud Composer workloads"
  value       = google_service_account.dak_demo_runner.email
}

output "vertex_ai_connection_service_account" {
  description = "BigQuery Cloud Resource Connection service account for AI.GENERATE_TABLE / AI.FORECAST"
  value       = google_bigquery_connection.vertex_ai_connection.cloud_resource[0].service_account_id
}

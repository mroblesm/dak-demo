variable "project_id" {
  description = "Google Cloud Project ID for the Data Agent Kit demo"
  type        = string
  default     = "your-gcp-project-id"
}

variable "region" {
  description = "Primary GCP region for Cloud Run, Serverless Spark, and Composer"
  type        = string
  default     = "us-central1"
}

variable "bq_location" {
  description = "BigQuery dataset multi-region or region location"
  type        = string
  default     = "US"
}

variable "raw_dataset_id" {
  description = "Bronze tier dataset ID"
  type        = string
  default     = "raw_retail_core"
}

variable "modeled_dataset_id" {
  description = "Silver tier dataset ID"
  type        = string
  default     = "modeled_search_warehouse"
}

variable "serving_dataset_id" {
  description = "Gold tier dataset ID"
  type        = string
  default     = "serving_clarity_intelligence"
}

variable "composer_env_name" {
  description = "Cloud Composer 3 environment name for DAK Orchestration Pipelines"
  type        = string
  default     = "clarity-composer-dev"
}

variable "enable_composer" {
  description = "Whether to provision the Cloud Composer 3 environment (~20 min creation time)"
  type        = bool
  default     = false
}

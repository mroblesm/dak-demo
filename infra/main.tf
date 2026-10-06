terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.30.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

locals {
  required_apis = [
    "compute.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "notebooks.googleapis.com",
    "bigquery.googleapis.com",
    "biglake.googleapis.com",
    "bigqueryconnection.googleapis.com",
    "bigqueryreservation.googleapis.com",
    "dataplex.googleapis.com",
    "dataproc.googleapis.com",
    "aiplatform.googleapis.com",
    "run.googleapis.com",
    "geminidataanalytics.googleapis.com",
    "composer.googleapis.com",
  ]

  spark_and_runner_roles = [
    "roles/bigquery.admin",
    "roles/biglake.admin",
    "roles/dataplex.admin",
    "roles/dataproc.worker",
    "roles/dataproc.editor",
    "roles/storage.objectAdmin",
    "roles/aiplatform.user",
  ]
}

# 0. Enable Required Google Cloud APIs
resource "google_project_service" "enabled_apis" {
  for_each           = toset(local.required_apis)
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# 1. Dedicated VPC Network, PGA Subnet & Cloud NAT (Required for Serverless Spark & Composer 3)
resource "google_compute_network" "dak_demo_vpc" {
  name                    = "dak-demo-vpc"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.enabled_apis]
}

resource "google_compute_subnetwork" "dataproc_serverless_subnet" {
  name                     = "dataproc-serverless-subnet"
  ip_cidr_range            = "10.10.0.0/20"
  region                   = var.region
  network                  = google_compute_network.dak_demo_vpc.id
  private_ip_google_access = true
}

resource "google_compute_firewall" "dak_demo_allow_internal" {
  name    = "dak-demo-allow-internal"
  network = google_compute_network.dak_demo_vpc.name
  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }
  source_ranges = ["10.10.0.0/20"]
}

resource "google_compute_router" "dak_nat_router" {
  name    = "dak-nat-router"
  region  = var.region
  network = google_compute_network.dak_demo_vpc.id
}

resource "google_compute_router_nat" "dak_nat_config" {
  name                               = "dak-nat-config"
  router                             = google_compute_router.dak_nat_router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# 2. GCS Buckets: GCP Native LRC, Cross-Cloud Federated LRC, Orchestration Artifacts & Spark Staging
resource "google_storage_bucket" "iceberg_lakehouse" {
  name                        = "${var.project_id}-iceberg-lakehouse"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true

  labels = {
    environment = "demo"
    managed_by  = "data-agent-kit"
    catalog     = "gcp-native-lrc"
  }
  depends_on = [google_project_service.enabled_apis]
}

resource "google_storage_bucket" "iceberg_dbx_lakehouse" {
  name                        = "${var.project_id}-iceberg-dbx-lakehouse"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true

  labels = {
    environment = "demo"
    managed_by  = "data-agent-kit"
    catalog     = "dbx-federated-lrc"
  }
  depends_on = [google_project_service.enabled_apis]
}

resource "google_storage_bucket" "orchestration_artifacts" {
  name                        = "${var.project_id}-orchestration-artifacts"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true

  labels = {
    environment = "demo"
    managed_by  = "data-agent-kit"
  }
  depends_on = [google_project_service.enabled_apis]
}

resource "google_storage_bucket" "spark_staging" {
  name                        = "${var.project_id}-spark-staging"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true

  labels = {
    environment = "demo"
    managed_by  = "data-agent-kit"
  }
  depends_on = [google_project_service.enabled_apis]
}

# 3. 3-Tier Data Mesh BigQuery Datasets (Bronze -> Silver -> Gold)
resource "google_bigquery_dataset" "raw_search_telemetry" {
  dataset_id  = var.raw_dataset_id
  location    = var.bq_location
  description = "Bronze Tier: Raw e-commerce search telemetry, catalog items, and BigLake Iceberg tables"

  labels = {
    mesh_tier  = "bronze"
    managed_by = "data-agent-kit"
  }
  depends_on = [google_project_service.enabled_apis]
}

resource "google_bigquery_dataset" "modeled_search_warehouse" {
  dataset_id  = var.modeled_dataset_id
  location    = var.bq_location
  description = "Silver Tier: Cleaned, deduplicated, and sessionized search conversion marts (dbt & Serverless Spark)"

  labels = {
    mesh_tier  = "silver"
    managed_by = "data-agent-kit"
  }
  depends_on = [google_project_service.enabled_apis]
}

resource "google_bigquery_dataset" "serving_clarity_intelligence" {
  dataset_id  = var.serving_dataset_id
  location    = var.bq_location
  description = "Gold Tier: Hybrid vector search RRF rankings, BQML re-ranker scores, AI.FORECAST demand, and diagnostic audit tables"

  labels = {
    mesh_tier  = "gold"
    managed_by = "data-agent-kit"
  }
  depends_on = [google_project_service.enabled_apis]
}

# 4. BigQuery Cloud Resource Connection for Vertex AI & BigLake Iceberg
resource "google_bigquery_connection" "vertex_ai_connection" {
  connection_id = "vertex-ai-connection"
  location      = var.bq_location
  friendly_name = "Retail Search Vertex AI & BigLake Connection"
  description   = "Used by AI.GENERATE_TABLE, AI.GENERATE_EMBEDDING, AI.FORECAST, and BigLake Iceberg"
  cloud_resource {}
  depends_on = [google_project_service.enabled_apis]
}

resource "google_project_iam_member" "vertex_connection_aiplatform" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_bigquery_connection.vertex_ai_connection.cloud_resource[0].service_account_id}"
}

resource "google_project_iam_member" "vertex_connection_storage" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_bigquery_connection.vertex_ai_connection.cloud_resource[0].service_account_id}"
}

# 5. Service Accounts & IAM for Interactive Serverless Spark, Composer 3 & Cloud Run
resource "google_service_account" "dak_demo_runner" {
  account_id   = "dak-demo-runner"
  display_name = "Google Cloud Data Agent Kit Demo Runner SA"
  depends_on   = [google_project_service.enabled_apis]
}

resource "google_service_account" "s8s_spark_interactive" {
  account_id   = "s8s-spark-interactive"
  display_name = "Serverless Spark Interactive LRC Session SA"
  depends_on   = [google_project_service.enabled_apis]
}

resource "google_project_iam_member" "dak_demo_runner_roles" {
  for_each = toset(local.spark_and_runner_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.dak_demo_runner.email}"
}

resource "google_project_iam_member" "s8s_spark_interactive_roles" {
  for_each = toset(local.spark_and_runner_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.s8s_spark_interactive.email}"
}

# 6. Artifact Registry Repository for Cloud Run Data Apps
resource "google_artifact_registry_repository" "clarity_data_apps" {
  location      = var.region
  repository_id = "clarity-data-apps"
  description   = "Container repository for Retail Search Intelligence Cloud Run Apps"
  format        = "DOCKER"
  depends_on    = [google_project_service.enabled_apis]
}

# 7. Optional Cloud Composer 3 Environment for DAK Orchestration Pipelines
resource "google_composer_environment" "clarity_composer_dev" {
  count  = var.enable_composer ? 1 : 0
  name   = var.composer_env_name
  region = var.region

  config {
    software_config {
      image_version = "composer-3-airflow-2.11.1"
    }
    node_config {
      network         = google_compute_network.dak_demo_vpc.id
      subnetwork      = google_compute_subnetwork.dataproc_serverless_subnet.id
      service_account = google_service_account.dak_demo_runner.email
    }
  }
  depends_on = [google_project_iam_member.dak_demo_runner_roles]
}

terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }

  # Uncomment to use remote state (recommended for production)
  # backend "gcs" {
  #   bucket = "YOUR_TERRAFORM_STATE_BUCKET"
  #   prefix = "edgequake"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable required APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "compute.googleapis.com",
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "vpcaccess.googleapis.com",
    "secretmanager.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
  ])

  service            = each.value
  disable_on_destroy = false
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  project_id           = var.project_id
  region               = var.region
  app_name             = var.app_name
  vpc_cidr             = var.vpc_cidr
  enable_direct_egress = var.enable_direct_vpc_egress
  labels               = var.labels

  depends_on = [google_project_service.required_apis]
}

# Compute Engine VM Module (Database)
module "compute" {
  source = "./modules/compute"

  project_id           = var.project_id
  region               = var.region
  app_name             = var.app_name
  machine_type         = var.db_vm_machine_type
  boot_disk_size       = var.db_vm_boot_disk_size
  vpc_network_name     = module.vpc.vpc_name
  vpc_subnet_name      = module.vpc.subnet_name
  db_port              = var.db_port
  postgresql_version   = var.postgresql_version
  enable_wal_archiving = var.enable_wal_archiving
  gcs_backup_bucket    = var.gcs_backup_bucket
  labels               = var.labels
  use_spot_vm          = var.use_spot_vm

  depends_on = [
    google_project_service.required_apis,
    module.vpc,
  ]
}

# Artifact Registry Repository
resource "google_artifact_registry_repository" "app_images" {
  location      = var.region
  repository_id = "${var.app_name}-images"
  description   = "Container images for ${var.app_name}"
  format        = "DOCKER"

  labels = var.labels

  depends_on = [google_project_service.required_apis]
}


# Cloud Run Module (Rust API)
module "cloud_run_rust_api" {
  source = "./modules/cloud_run"

  project_id            = var.project_id
  region                = var.region
  service_name          = var.rust_api_service_name
  image_url             = var.rust_api_image_url != "" ? var.rust_api_image_url : "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.app_images.repository_id}/rust-api:latest"
  memory                = var.cloud_run_memory
  cpu                   = var.cloud_run_cpu
  min_instances         = var.cloud_run_min_instances
  max_instances         = var.cloud_run_max_instances
  vpc_network_name      = module.vpc.vpc_name
  vpc_subnet_name       = module.vpc.subnet_name
  enable_direct_egress  = var.enable_direct_vpc_egress
  vpc_connector_name    = !var.enable_direct_vpc_egress ? module.vpc.vpc_connector_name : null
  allow_unauthenticated = true # Allow public access for browser-based WebUI
  labels                = var.labels

  environment_variables = {
    # Simple database connection that matches working configuration
    "DATABASE_URL"   = "postgresql://postgres:postgres@${module.compute.vm_private_ip}:${var.db_port}/graph_db"
    "RUST_LOG"       = "info,edgequake=debug"
    "OPENAI_API_KEY" = var.openai_api_key
    "ENVIRONMENT"    = "production" # Match working revision
  }
  service_account_name = google_service_account.cloud_run_sa.email

  depends_on = [
    google_project_service.required_apis,
    module.vpc,
    module.compute,
  ]
}

# Cloud Run Module (Next.js WebUI)
module "cloud_run_nextjs_webui" {
  source = "./modules/cloud_run"

  project_id            = var.project_id
  region                = var.region
  service_name          = var.nextjs_service_name
  image_url             = var.nextjs_image_url != "" ? var.nextjs_image_url : "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.app_images.repository_id}/edgequake-webui:latest"
  memory                = var.cloud_run_memory
  cpu                   = var.cloud_run_cpu
  min_instances         = var.cloud_run_min_instances
  max_instances         = var.cloud_run_max_instances
  vpc_network_name      = module.vpc.vpc_name
  vpc_subnet_name       = module.vpc.subnet_name
  enable_direct_egress  = var.enable_direct_vpc_egress
  vpc_connector_name    = !var.enable_direct_vpc_egress ? module.vpc.vpc_connector_name : null
  allow_unauthenticated = true # Allow public access for browser-based WebUI
  labels                = var.labels

  environment_variables = {
    "NEXT_PUBLIC_API_URL" = module.cloud_run_rust_api.service_uri
    "NODE_ENV"            = "production"
  }
  service_account_name = google_service_account.cloud_run_sa.email

  depends_on = [
    google_project_service.required_apis,
    module.vpc,
    module.cloud_run_rust_api,
  ]
}

# Service Account for Cloud Run (least privilege)
resource "google_service_account" "cloud_run_sa" {
  account_id   = "${var.app_name}-cloud-run"
  display_name = "Cloud Run service account for ${var.app_name}"

  depends_on = [google_project_service.required_apis]
}

# Grant secret accessor permission
resource "google_project_iam_member" "secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"

  depends_on = [google_service_account.cloud_run_sa]
}

# ----------------------
# Logging optimizations
# ----------------------
# Create a short-retention log bucket for non-prod (reduces storage costs)
resource "google_logging_project_bucket_config" "dev_logs" {
  count          = var.environment == "dev" ? 1 : 0
  project        = var.project_id
  bucket_id      = "dev-logs"
  location       = var.region
  retention_days = var.log_retention_days_dev
  description    = "Low-retention bucket for development logs to reduce Cloud Logging storage costs"
}

# Conservative exclusions: drop DEBUG logs for noisy resources (Cloud Run, GCE, Cloud Build)
# These run only when enabled and help cut noisy debug logs from ingestion
resource "google_logging_project_exclusion" "exclude_cloud_run_debug" {
  count       = var.enable_log_exclusions ? 1 : 0
  project     = var.project_id
  name        = "exclude_cloud_run_debug"
  description = "Exclude DEBUG logs from Cloud Run to reduce noise and cost"
  filter      = "resource.type=\"cloud_run_revision\" AND severity=DEBUG"
}

resource "google_logging_project_exclusion" "exclude_gce_debug" {
  count       = var.enable_log_exclusions ? 1 : 0
  project     = var.project_id
  name        = "exclude_gce_debug"
  description = "Exclude DEBUG logs from GCE instances"
  filter      = "resource.type=\"gce_instance\" AND severity=DEBUG"
}

resource "google_logging_project_exclusion" "exclude_cloud_build_debug" {
  count       = var.enable_log_exclusions ? 1 : 0
  project     = var.project_id
  name        = "exclude_cloud_build_debug"
  description = "Exclude DEBUG logs from Cloud Build"
  filter      = "resource.type=\"build\" AND severity=DEBUG"
}

resource "google_logging_project_exclusion" "exclude_health_checks" {
  count       = var.enable_log_exclusions ? 1 : 0
  project     = var.project_id
  name        = "exclude_health_checks"
  description = "Exclude health check probe logs (load balancer / http health endpoints) to reduce noise"
  filter      = "(resource.type=\"http_load_balancer\" AND (httpRequest.requestUrl:(\"/health\" OR \"/healthz\") OR jsonPayload.request.path:(\"/health\" OR \"/healthz\"))) OR (jsonPayload.methodName: \"compute.healthChecks\")"
}

# Optional: Exclude Cloud Monitoring metrics/logs that are informational only (commented example)
# resource "google_logging_project_exclusion" "exclude_monitoring_info" {
#   project     = var.project_id
#   name        = "exclude_monitoring_info"
#   description = "Example to exclude informational monitoring logs"
#   filter      = "resource.type=\"cloud_monitoring\" AND severity=INFO"
# }

# Output a short summary to make it easy to confirm logging resources
output "logging_summary" {
  value = {
    dev_logs_bucket       = try(google_logging_project_bucket_config.dev_logs[0].id, "")
    exclude_cloud_run     = try(google_logging_project_exclusion.exclude_cloud_run_debug[0].name, "")
    exclude_gce           = try(google_logging_project_exclusion.exclude_gce_debug[0].name, "")
    exclude_cloud_build   = try(google_logging_project_exclusion.exclude_cloud_build_debug[0].name, "")
    exclude_health_checks = try(google_logging_project_exclusion.exclude_health_checks[0].name, "")
  }
  description = "Summary of logging resources created (dev-only)"
  depends_on  = [google_project_service.required_apis]
  sensitive   = false
}

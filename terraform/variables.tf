variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "saas-app-001"
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "edgequake"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "db_vm_machine_type" {
  description = "Machine type for database VM (use small machine by default for dev; override for prod)"
  type        = string
  default     = "e2-small"
}

variable "db_vm_boot_disk_size" {
  description = "Boot disk size in GB"
  type        = number
  default     = 20
}

variable "use_spot_vm" {
  description = "Use Spot (preemptible) VM for the database VM to minimize cost in dev environments"
  type        = bool
  default     = true
}

variable "db_port" {
  description = "PostgreSQL port"
  type        = number
  default     = 5432
}

variable "rust_api_service_name" {
  description = "Rust API Cloud Run service name"
  type        = string
  default     = "rust-api"
}

variable "cloud_run_memory" {
  description = "Cloud Run memory (e.g., '512Mi', '1Gi')"
  type        = string
  default     = "512Mi"
}

variable "cloud_run_cpu" {
  description = "Cloud Run CPU (e.g., '1', '2'). Must be >= 1 when concurrency > 1"
  type        = string
  default     = "1"
}

variable "cloud_run_min_instances" {
  description = "Minimum instances for Cloud Run"
  type        = number
  default     = 0
}

variable "cloud_run_max_instances" {
  description = "Maximum instances for Cloud Run"
  type        = number
  default     = 10
}

variable "rust_api_image_url" {
  description = "Rust API image URL in Artifact Registry"
  type        = string
  default     = ""
}

variable "enable_direct_vpc_egress" {
  description = "Enable Direct VPC egress for Cloud Run (recommended over VPC connectors)"
  type        = bool
  default     = true
}

variable "postgresql_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "16"
}

variable "enable_wal_archiving" {
  description = "Enable WAL archiving to Cloud Storage (recommended for production; set to true and provide gcs_backup_bucket)"
  type        = bool
  default     = false
}

variable "gcs_backup_bucket" {
  description = "GCS bucket for backups and WAL archiving"
  type        = string
  default     = ""
}

variable "labels" {
  description = "Labels for all resources"
  type        = map(string)
  default = {
    "managed_by" = "terraform"
    "env"        = "dev"
    "app"        = "edgequake"
  }
}

# Logging / cost-minimization variables
variable "enable_log_exclusions" {
  description = "Enable conservative log exclusions to reduce logging volume (recommended for dev). Excludes DEBUG logs for Cloud Run, Compute, and Cloud Build."
  type    = bool
  default = true
}

variable "log_retention_days_dev" {
  description = "Retention days for dev logs (lower keeps costs down)"
  type        = number
  default     = 7
}

variable "log_retention_days_prod" {
  description = "Retention days for prod logs (increase as needed)"
  type        = number
  default     = 30
}

variable "openai_api_key" {
  description = "OpenAI API Key for LLM operations"
  type        = string
  default     = ""
  sensitive   = true
}

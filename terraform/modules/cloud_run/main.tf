variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "service_name" {
  type = string
}

variable "image_url" {
  type = string
}

variable "memory" {
  type = string
}

variable "cpu" {
  type = string
}

variable "min_instances" {
  type = number
}

variable "max_instances" {
  type = number
}

variable "vpc_network_name" {
  type = string
}

variable "vpc_subnet_name" {
  type = string
}

variable "enable_direct_egress" {
  type = bool
}

variable "vpc_connector_name" {
  type = string
  default = null
}

variable "allow_unauthenticated" {
  type = bool
  default = false
}

variable "labels" {
  type = map(string)
}

variable "environment_variables" {
  type = map(string)
  default = {}
}

variable "service_account_name" {
  description = "Email of the service account to run the Cloud Run service as. If empty, defaults to project id (legacy)."
  type        = string
  default     = ""
}

# Cloud Run Service
resource "google_cloud_run_service" "service" {
  name     = var.service_name
  location = var.region
  project  = var.project_id

  template {
    spec {
      containers {
        image = var.image_url

        resources {
          limits = {
            memory = var.memory
            cpu    = var.cpu
          }
        }

        env {
          name  = "ENVIRONMENT"
          value = "production"
        }

        dynamic "env" {
          for_each = var.environment_variables
          content {
            name  = env.key
            value = env.value
          }
        }
      }

      # Use explicitly provided service account when available, otherwise keep legacy behavior
      service_account_name = var.service_account_name != "" ? var.service_account_name : var.project_id

      timeout_seconds = 300
    }

    metadata {
      annotations = var.enable_direct_egress ? {} : {
        "run.googleapis.com/vpc-access-connector" = var.vpc_connector_name
        "run.googleapis.com/vpc-access-egress"    = "all-traffic"
      }

      labels = var.labels
    }
  }

  metadata {
    labels = var.labels
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  lifecycle {
    ignore_changes = [template[0].spec[0].containers[0].image]
  }
}

# IAM binding for unauthenticated access (if allowed)
resource "google_cloud_run_service_iam_member" "unauthenticated" {
  count   = var.allow_unauthenticated ? 1 : 0
  service = google_cloud_run_service.service.name
  role    = "roles/run.invoker"
  member  = "allUsers"
  location = var.region
  project = var.project_id
}

output "service_name" {
  value = google_cloud_run_service.service.name
}

output "service_uri" {
  value = google_cloud_run_service.service.status[0].url
}

output "revision_name" {
  value = google_cloud_run_service.service.status[0].latest_ready_revision_name
}

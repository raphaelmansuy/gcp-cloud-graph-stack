variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "app_name" {
  type = string
}

variable "machine_type" {
  type = string
}

variable "boot_disk_size" {
  type = number
}

variable "vpc_network_name" {
  type = string
}

variable "vpc_subnet_name" {
  type = string
}

variable "db_port" {
  type = number
}

variable "postgresql_version" {
  type = string
}

variable "enable_wal_archiving" {
  type = bool
}

variable "gcs_backup_bucket" {
  type = string
}

variable "labels" {
  type = map(string)
}

variable "use_spot_vm" {
  description = "Whether to use a Spot (preemptible) VM for the database VM"
  type        = bool
  default     = true
}

# Service account for VM
resource "google_service_account" "vm_sa" {
  account_id   = "${var.app_name}-vm"
  display_name = "Service account for ${var.app_name} VM"
}

# IAM binding for Cloud Logging
resource "google_project_iam_member" "vm_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.vm_sa.email}"
}

# IAM binding for GCS bucket access (if WAL archiving is enabled)
resource "google_storage_bucket_iam_member" "vm_gcs_access" {
  count  = var.enable_wal_archiving && var.gcs_backup_bucket != "" ? 1 : 0
  bucket = var.gcs_backup_bucket
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${google_service_account.vm_sa.email}"
}

# Compute Instance - Database VM
resource "google_compute_instance" "db_vm" {
  name         = "${var.app_name}-db-vm"
  machine_type = var.machine_type
  zone         = "${var.region}-a"

  boot_disk {
    initialize_params {
      image = "ubuntu-2204-lts"
      size  = var.boot_disk_size
      type  = "pd-standard"
    }
  }

  network_interface {
    network            = var.vpc_network_name
    subnetwork         = var.vpc_subnet_name
    subnetwork_project = var.project_id

    access_config {
      # Ephemeral public IP for initial setup; can be removed after
    }
  }

  service_account {
    email  = google_service_account.vm_sa.email
    # Use narrow OAuth scopes where necessary; prefer IAM roles over broad cloud-platform scope.
    scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/devstorage.read_write"
    ]
  }

  tags = ["postgresql", "allow-ssh"]

  scheduling {
    preemptible       = var.use_spot_vm
    automatic_restart = var.use_spot_vm ? false : true
    on_host_maintenance = var.use_spot_vm ? "TERMINATE" : "MIGRATE"
  }

  # Startup script: install PostgreSQL, AGE, pgvector
  metadata_startup_script = base64encode(templatefile("${path.module}/startup-script.sh", {
    postgresql_version = var.postgresql_version
    db_port            = var.db_port
    gcs_backup_bucket  = var.gcs_backup_bucket
    enable_wal_archiving = var.enable_wal_archiving
  }))

  depends_on = [google_service_account.vm_sa]
}

output "instance_name" {
  value = google_compute_instance.db_vm.name
}

output "instance_id" {
  value = google_compute_instance.db_vm.id
}

output "vm_private_ip" {
  value = google_compute_instance.db_vm.network_interface[0].network_ip
}

output "vm_external_ip" {
  value = try(google_compute_instance.db_vm.network_interface[0].access_config[0].nat_ip, null)
}

output "service_account_email" {
  value = google_service_account.vm_sa.email
}

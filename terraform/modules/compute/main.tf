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

variable "create_data_disk" {
  description = "Create a separate persistent data disk for the database VM"
  type        = bool
  default     = true
}

variable "existing_data_disk_self_link" {
  description = "If you manage the disk outside Terraform, provide the disk self_link to attach"
  type        = string
  default     = ""
}

variable "data_disk_size" {
  description = "Size of the data disk in GB"
  type        = number
  default     = 50
}

variable "data_disk_type" {
  description = "PD disk type (pd-standard, pd-ssd, pd-balanced)"
  type        = string
  default     = "pd-standard"
}

variable "data_disk_prevent_destroy" {
  description = "If true, Terraform will prevent accidental deletion of the data disk (recommended: true)"
  type        = bool
  default     = true
}

variable "data_disk_device_name" {
  description = "Device name for the attached data disk (used in fstab/mounts)"
  type        = string
  default     = "data-disk"
}

variable "data_disk_mount_point" {
  description = "Local mount point for the data disk"
  type        = string
  default     = "/mnt/data"
}

variable "enable_snapshot_schedule" {
  description = "Enable daily snapshot schedule for the data disk"
  type        = bool
  default     = true
}

variable "snapshot_retention_days" {
  description = "Maximum number of days to retain snapshots"
  type        = number
  default     = 3
}

variable "snapshot_start_time" {
  description = "UTC start time for the daily snapshot (allowed: 00:00,04:00,08:00,12:00,16:00,20:00)"
  type        = string
  default     = "04:00"
}

variable "snapshot_storage_locations" {
  description = "Optional list of storage locations for snapshots (regional names)"
  type        = list(string)
  default     = []
}

variable "use_spot_vm" {
  description = "Whether to use a Spot (preemptible) VM for the database VM. For production, set to false to ensure reliability."
  type        = bool
  default     = false  # Changed from true - use standard VM for database reliability
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

# Data disk (persistent, detached from instance lifecycle)
# Two resource variants: one with `prevent_destroy = true` and one without.
resource "google_compute_disk" "data_disk" {
  count = var.create_data_disk && !var.data_disk_prevent_destroy ? 1 : 0

  name  = "${var.app_name}-data-disk"
  size  = var.data_disk_size
  type  = var.data_disk_type
  zone  = "${var.region}-a"

  labels = var.labels
}

resource "google_compute_disk" "data_disk_protected" {
  count = var.create_data_disk && var.data_disk_prevent_destroy ? 1 : 0

  name  = "${var.app_name}-data-disk"
  size  = var.data_disk_size
  type  = var.data_disk_type
  zone  = "${var.region}-a"

  labels = var.labels

  lifecycle {
    prevent_destroy = true
  }
}

# ResourcePolicy: daily snapshot schedule (keep a small number of daily restores)
resource "google_compute_resource_policy" "daily_snap" {
  count  = var.enable_snapshot_schedule ? 1 : 0
  name   = "${var.app_name}-daily-snap-policy"
  region = var.region

  snapshot_schedule_policy {
    schedule {
      daily_schedule {
        days_in_cycle = 1
        start_time    = var.snapshot_start_time
      }
    }

    retention_policy {
      max_retention_days    = var.snapshot_retention_days
      on_source_disk_delete = "KEEP_AUTO_SNAPSHOTS"
    }

    snapshot_properties {
      guest_flush = true
      storage_locations = var.snapshot_storage_locations
      labels = var.labels
    }
  }
}

locals {
  data_disk_self_link = (var.create_data_disk && var.data_disk_prevent_destroy) ? try(google_compute_disk.data_disk_protected[0].self_link, null) : (var.create_data_disk ? try(google_compute_disk.data_disk[0].self_link, null) : (var.existing_data_disk_self_link != "" ? var.existing_data_disk_self_link : null))
}

# Attach the snapshot schedule policy to the created disk via the attachment resource
resource "google_compute_disk_resource_policy_attachment" "data_disk_attachment" {
  count = var.create_data_disk && var.enable_snapshot_schedule ? 1 : 0

  name = google_compute_resource_policy.daily_snap[0].name
  disk = var.data_disk_prevent_destroy ? google_compute_disk.data_disk_protected[0].name : google_compute_disk.data_disk[0].name
  zone = "${var.region}-a"
}


# Reserve a static internal IP for the DB VM
resource "google_compute_address" "db_vm_internal" {
  name         = "${var.app_name}-db-vm-ip"
  subnetwork   = var.vpc_subnet_name
  address_type = "INTERNAL"
  region       = var.region
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

  # Attach persistent data disk when available; auto_delete=false ensures the disk
  # survives instance replacement and can be reattached to a new instance.
  dynamic "attached_disk" {
    for_each = local.data_disk_self_link != null ? [local.data_disk_self_link] : []
    content {
      source      = attached_disk.value
      device_name = var.data_disk_device_name
    }
  }

  network_interface {
    network            = var.vpc_network_name
    subnetwork         = var.vpc_subnet_name
    subnetwork_project = var.project_id
    network_ip         = google_compute_address.db_vm_internal.address

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
  metadata_startup_script = templatefile("${path.module}/startup-script.sh", {
    postgresql_version   = var.postgresql_version
    db_port              = var.db_port
    gcs_backup_bucket    = var.gcs_backup_bucket
    enable_wal_archiving = var.enable_wal_archiving

    # Data disk info for startup script - use device_name to match attached_disk
    data_disk_name       = var.data_disk_device_name
    data_disk_mount_point = var.data_disk_mount_point
    data_disk_device_name = var.data_disk_device_name
    create_data_disk      = var.create_data_disk
  })

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

output "data_disk_name" {
  value = var.create_data_disk ? (var.data_disk_prevent_destroy ? try(google_compute_disk.data_disk_protected[0].name, "") : try(google_compute_disk.data_disk[0].name, "")) : (var.existing_data_disk_self_link != "" ? var.existing_data_disk_self_link : "")
}

output "data_disk_self_link" {
  value = local.data_disk_self_link
}

output "snapshot_policy_name" {
  value = var.enable_snapshot_schedule && length(google_compute_resource_policy.daily_snap) > 0 ? google_compute_resource_policy.daily_snap[0].name : ""
}

output "snapshot_policy_self_link" {
  value = var.enable_snapshot_schedule && length(google_compute_resource_policy.daily_snap) > 0 ? try(google_compute_resource_policy.daily_snap[0].self_link, "") : ""
}

output "snapshot_attachment" {
  value = var.create_data_disk && var.enable_snapshot_schedule ? try(google_compute_disk_resource_policy_attachment.data_disk_attachment[0].id, "") : ""
}

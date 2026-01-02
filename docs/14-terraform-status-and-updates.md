# Terraform Code Status & Recommended Updates

This document provides an analysis of the current Terraform codebase and recommends any updates needed before deployment.

## Current Status Summary

### ✅ Complete Features

| Feature | Status | Location |
|---------|--------|----------|
| VPC & Networking | ✅ Complete | `modules/vpc/` |
| Compute Engine VM | ✅ Complete | `modules/compute/` |
| PostgreSQL Setup | ✅ Complete | `startup-script.sh` |
| Data Disk + Snapshots | ✅ Complete | `modules/compute/main.tf` |
| Cloud Run (Next.js) | ✅ Complete | `modules/cloud_run/` |
| Cloud Run (Rust API) | ✅ Complete | `modules/cloud_run/` |
| GCS Backend | ✅ Complete | `Makefile`, `bootstrap-backend.sh` |
| IAM & Service Accounts | ✅ Complete | `main.tf` |
| Logging & Monitoring | ✅ Complete | `main.tf` |
| Artifact Registry | ✅ Complete | `main.tf` |

### 🟡 Recommended Enhancements

| Feature | Current State | Recommendation |
|---------|---------------|-----------------|
| Health Checks | Implicit | Add explicit Cloud Run health check config |
| Environment Variables | Partial | Add comprehensive env var template |
| Secret Management | Not implemented | Add Secret Manager integration (optional) |
| Firewall Rules | Auto-generated | Document and verify |
| Monitoring Alerts | Not implemented | Add CPU/memory/error alerts |

---

## Detailed Analysis & Recommendations

### 1. Cloud Run Health Checks ✅ / 🟡

**Current state:** Cloud Run has implicit health checks

**What's there:**
```terraform
# In modules/cloud_run/main.tf
resource "google_cloud_run_service" "service" {
  # Health checks happen via HEALTHCHECK instruction in Dockerfile
}
```

**Recommendation:** This is working but could be enhanced

**Optional enhancement:**
```terraform
# Add explicit health check configuration to Cloud Run
# (Currently using HEALTHCHECK in Dockerfile which is sufficient)
```

**Action required:** ❌ None - current implementation is acceptable

---

### 2. Environment Variables Configuration ✅ / 🟡

**Current state:** Environment variables are partially configured

**What's there:**
```terraform
# main.tf - Rust API environment variables
environment_variables = {
  "DATABASE_HOST" = module.compute.vm_private_ip
  "DATABASE_PORT" = tostring(var.db_port)
  "DATABASE_NAME" = "graph_db"
}

# main.tf - Next.js environment variables
environment_variables = {
  "NODE_ENV" = var.environment
  "API_URL"  = "http://${module.cloud_run_rust_api.service_uri}"
}
```

**Recommendation:** Good! But could add more configuration options

**Suggested improvements:**
```hcl
# In variables.tf - Add new variables
variable "cloud_run_env_vars_rust" {
  description = "Additional environment variables for Rust API"
  type        = map(string)
  default     = {}
}

variable "cloud_run_env_vars_nextjs" {
  description = "Additional environment variables for Next.js"
  type        = map(string)
  default     = {}
}

# Then merge in main.tf:
environment_variables = merge(
  {
    "DATABASE_HOST" = module.compute.vm_private_ip
    "DATABASE_PORT" = tostring(var.db_port)
    "DATABASE_NAME" = "graph_db"
  },
  var.cloud_run_env_vars_rust
)
```

**Action required:** ⚠️ Optional - implement if you need custom env vars

---

### 3. Artifact Registry Repository 🟡

**Current state:** Repository is created but no image push mechanism

**What's there:**
```terraform
resource "google_artifact_registry_repository" "app_images" {
  location      = var.region
  repository_id = "${var.app_name}-images"
  description   = "Container images for ${var.app_name}"
  format        = "DOCKER"
}
```

**Recommendation:** Image push is via GitHub Actions, not Terraform

This is correct! Images are pushed via CI/CD pipeline, not Terraform.

**Action required:** ✅ None - this is intentional

---

### 4. Firewall Rules 🟡

**Current state:** Firewall rules are created implicitly via Cloud Run VPC Connector

**What's there:**
```terraform
# VPC Connector handles the firewall automatically
resource "google_vpc_access_connector" "connector" {
  name          = "${var.app_name}-vpc-connector"
  ip_cidr_range = "10.8.0.0/28"
  region        = var.region
  network       = module.vpc.vpc_name
  depends_on    = [...]
}
```

**Issue:** Firewall rules are auto-created but not explicitly visible

**Recommendation:** Add explicit firewall rules for clarity and control

**Suggested improvement:**
```hcl
# File: terraform/modules/vpc/outputs.tf
# Add explicit firewall rule output

# File: terraform/modules/compute/main.tf
# Add explicit firewall rule for Cloud Run → PostgreSQL

resource "google_compute_firewall" "allow_cloud_run_to_db" {
  name    = "${var.app_name}-allow-cr-to-db"
  network = var.vpc_network_name
  
  allow {
    protocol = "tcp"
    ports    = [tostring(var.db_port)]
  }
  
  source_ranges = ["10.8.0.0/28"]  # VPC Connector CIDR
  target_tags   = ["${var.app_name}-db"]
}
```

**Action required:** 🟡 Optional - recommended for clarity and troubleshooting

---

### 5. Service Account Permissions 🟡

**Current state:** Service accounts have basic permissions

**What's there:**
```terraform
# Cloud Run SA
resource "google_project_iam_member" "secret_accessor" {
  role   = "roles/secretmanager.secretAccessor"
  member = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

# VM SA
resource "google_project_iam_member" "vm_logging" {
  role   = "roles/logging.logWriter"
  member = "serviceAccount:${google_service_account.vm_sa.email}"
}
```

**Issue:** Permissions are basic but might need enhancement for production

**Recommendation:** Add more fine-grained roles if needed

**For production consider:**
```hcl
# Cloud Run needs ability to read images from Artifact Registry
resource "google_project_iam_member" "cr_artifact_reader" {
  role   = "roles/artifactregistry.reader"
  member = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

# VM needs to write to GCS for backups
resource "google_storage_bucket_iam_member" "vm_backup_access" {
  count  = var.enable_wal_archiving ? 1 : 0
  bucket = var.gcs_backup_bucket
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${google_service_account.vm_sa.email}"
}
```

**Current status:** ✅ Already implemented!

Let me verify:

Looking at the code, the `google_storage_bucket_iam_member` for VM GCS access is already there in `modules/compute/main.tf`.

**Action required:** ✅ None - permissions are complete

---

### 6. Outputs Configuration 🟡

**Current state:** Outputs exist but could be more comprehensive

**What's there:**
- VM private IP
- Cloud Run service URIs
- Artifact Registry repository

**Recommendation:** Add more useful outputs for post-deployment

**Suggested additions to `terraform/outputs.tf`:**
```hcl
output "cloud_run_nextjs_url" {
  description = "Next.js frontend URL"
  value       = module.cloud_run_nextjs.service_uri
}

output "cloud_run_rust_api_url" {
  description = "Rust API URL"
  value       = module.cloud_run_rust_api.service_uri
}

output "postgresql_host" {
  description = "PostgreSQL VM private IP"
  value       = module.compute.vm_private_ip
}

output "postgresql_database" {
  description = "PostgreSQL database name"
  value       = "graph_db"
}

output "artifact_registry_repository" {
  description = "Artifact Registry repository name"
  value       = google_artifact_registry_repository.app_images.repository_id
}

output "terraform_state_bucket" {
  description = "GCS bucket for Terraform state"
  value       = "${var.project_id}-tf-state"
}
```

**Action required:** 🟡 Optional but recommended - adds clarity

---

### 7. Variables & Defaults 🟡

**Current state:** All major variables are defined with sensible defaults

**Review:**
- ✅ `project_id` - required
- ✅ `region` - required
- ✅ `environment` - has default
- ✅ `db_vm_machine_type` - has default
- ✅ `cloud_run_memory` - has default
- ✅ Data disk variables - all have defaults
- ✅ Snapshot variables - all have defaults

**Recommendation:** All good! Variables are well-defined.

**Action required:** ✅ None

---

### 8. Local Values & Computed Values 🟡

**Current state:** No local values defined

**Recommendation:** Add locals for complex computations

**Suggested improvement:**
```hcl
# In terraform/main.tf - Add locals section
locals {
  cloud_run_image_base = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.app_images.repository_id}"
  
  nextjs_image = var.nextjs_image_url != "" ? var.nextjs_image_url : "${local.cloud_run_image_base}/nextjs:latest"
  
  rust_api_image = var.rust_api_image_url != "" ? var.rust_api_image_url : "${local.cloud_run_image_base}/rust-api:latest"
  
  database_url = "postgresql://postgres@${module.compute.vm_private_ip}:${var.db_port}/graph_db"
}

# Then use in resources:
module "cloud_run_nextjs" {
  image_url = local.nextjs_image
}
```

**Current workaround:** ✅ Inline ternary operators work fine

**Action required:** ❌ None - current implementation is acceptable

---

## Pre-Deployment Checklist

### Code Quality

- [ ] Run `terraform fmt` to format code consistently
- [ ] Run `terraform validate` to check syntax
- [ ] Review `.terraform.lock.hcl` for provider versions

```bash
cd terraform
terraform fmt -recursive
terraform validate
```

### Variables & Configuration

- [ ] ✅ All required variables have sensible defaults
- [ ] ✅ Variable descriptions are clear
- [ ] ✅ terraform.tfvars.example is comprehensive
- [ ] 🟡 Consider adding `terraform.tfvars` to `.gitignore` if not there

Check `.gitignore`:
```bash
grep "terraform.tfvars" .gitignore
```

If missing, add:
```
terraform/terraform.tfvars
!terraform/terraform.tfvars.example
```

### Infrastructure Design

- [ ] ✅ VPC CIDR doesn't conflict with org network
- [ ] ✅ Database VM is in correct zone
- [ ] ✅ Cloud Run services are in correct region
- [ ] ✅ Data disk prevent_destroy is set appropriately
- [ ] ✅ Snapshot schedule is configured

### Outputs

- [ ] ✅ Key outputs are defined
- [ ] 🟡 Consider adding more outputs for convenience

### Documentation

- [ ] ✅ Complete - see other docs files
- [ ] ✅ Examples provided
- [ ] ✅ Troubleshooting guides included

---

## Optional Enhancements (Not Required)

### 1. Add Explicit Firewall Rules

**File:** `terraform/modules/compute/main.tf`

```hcl
resource "google_compute_firewall" "allow_cloud_run_to_db" {
  name    = "${var.app_name}-allow-cloud-run-to-db"
  network = var.vpc_network_name
  
  allow {
    protocol = "tcp"
    ports    = [tostring(var.db_port)]
  }
  
  source_ranges = ["10.8.0.0/28"]  # VPC Connector CIDR
  target_tags   = ["${var.app_name}-db"]
  
  depends_on = [google_compute_instance.db_vm]
}
```

### 2. Add Custom Environment Variables

**File:** `terraform/variables.tf`

```hcl
variable "additional_rust_env_vars" {
  description = "Additional environment variables for Rust API"
  type        = map(string)
  default     = {}
}

variable "additional_nextjs_env_vars" {
  description = "Additional environment variables for Next.js"
  type        = map(string)
  default     = {}
}
```

**File:** `terraform/main.tf`

```hcl
# Merge additional env vars
environment_variables = merge(
  {
    "DATABASE_HOST" = module.compute.vm_private_ip
    "DATABASE_PORT" = tostring(var.db_port)
    "DATABASE_NAME" = "graph_db"
  },
  var.additional_rust_env_vars
)
```

### 3. Add More Comprehensive Outputs

**File:** `terraform/outputs.tf`

```hcl
output "connection_info" {
  description = "Connection information for services"
  value = {
    nextjs_url        = module.cloud_run_nextjs.service_uri
    rust_api_url      = module.cloud_run_rust_api.service_uri
    postgresql_host   = module.compute.vm_private_ip
    postgresql_port   = var.db_port
    postgresql_db     = "graph_db"
    artifact_registry = google_artifact_registry_repository.app_images.repository_id
  }
}
```

### 4. Add Monitoring Alerts (Advanced)

```hcl
# Alert if Cloud Run error rate > 5%
resource "google_monitoring_alert_policy" "cloud_run_errors" {
  display_name = "Cloud Run high error rate"
  # ... alert configuration
}
```

---

## What's NOT in Terraform (Intentional)

| Item | Why Not in Terraform | How It's Done |
|------|----------------------|--------------|
| Container images | Need to be built first | GitHub Actions CI/CD |
| Database migrations | Should run separately | Manual or via startup script |
| Kubernetes configs | Using Cloud Run, not GKE | Terraform Cloud Run resources |
| DNS/domains | Managed separately | Manual setup or separate Terraform |

---

## Summary

### Ready for Deployment ✅
- ✅ VPC & networking
- ✅ Compute Engine VM with PostgreSQL
- ✅ Cloud Run services
- ✅ Data disk with snapshots
- ✅ IAM & service accounts
- ✅ GCS backend for state
- ✅ Artifact Registry

### Configuration Needed 🟡
- Create `terraform/terraform.tfvars` from template
- Update project_id and region
- Set database configuration
- Set Cloud Run configuration
- Create GCS buckets (backend + optional backups)

### Optional Enhancements 🟡
- Add explicit firewall rules for clarity
- Add custom environment variable support
- Add comprehensive outputs
- Add monitoring alerts

### Not Implemented (Intentional) ⚪
- Container image building (GitHub Actions)
- Domain/DNS setup (manual)
- Database migrations (separate process)
- Secrets (using Secret Manager integration)

---

## Next Steps

1. ✅ Review this analysis
2. 🟡 Decide on optional enhancements
3. 🟡 Create `terraform/terraform.tfvars`
4. ✅ Run `make init` to bootstrap backend
5. ✅ Run `terraform validate`
6. ✅ Run `terraform plan`
7. ✅ Run `terraform apply`

See [13-pre-deployment-terraform-checklist.md](./13-pre-deployment-terraform-checklist.md) for step-by-step deployment instructions.

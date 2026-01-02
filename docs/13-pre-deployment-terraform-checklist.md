# Pre-Deployment Terraform Configuration Checklist

This document provides a step-by-step guide for preparing the Terraform configuration for deployment.

## 📋 Quick Checklist

- [ ] **1. Create/Copy terraform.tfvars from template**
- [ ] **2. Update project_id and region**
- [ ] **3. Configure database settings**
- [ ] **4. Configure Cloud Run services**
- [ ] **5. Set up GCS backup bucket**
- [ ] **6. Prepare GCP credentials**
- [ ] **7. Run terraform validate**
- [ ] **8. Run terraform plan**
- [ ] **9. Review and apply**

---

## Step-by-Step Configuration

### 1. Create terraform.tfvars File

Copy the example file and customize it:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

### 2. Update Core Variables

**File:** `terraform/terraform.tfvars`

```hcl
# REQUIRED: Update these with your actual values
project_id = "saas-app-001"                    # Your GCP project ID
region     = "us-central1"                     # GCP region
environment = "dev"                            # dev, staging, or prod
app_name   = "edgequake"                       # Application name

# RECOMMENDED: Adjust for your environment
labels = {
  "managed_by" = "terraform"
  "env"        = "dev"
  "app"        = "edgequake"
  "team"       = "your-team-name"
  "cost_center" = "your-cost-center"           # Add if tracking costs
}
```

| Variable | Purpose | Dev Value | Prod Value |
|----------|---------|-----------|------------|
| `project_id` | GCP project | `saas-app-001` | Your prod project |
| `region` | GCP region | `us-central1` | Same or different region |
| `environment` | Deployment env | `dev` | `prod` |
| `app_name` | Resource prefix | `edgequake` | `edgequake` |

---

### 3. Database VM Configuration

**What it controls:** The machine running PostgreSQL

```hcl
# Machine type (balance cost vs. performance)
db_vm_machine_type = "e2-standard-2"    # For production
# Options: e2-small (dev), e2-standard-2 (prod), n2-standard-2 (high performance)

# Boot disk size
db_vm_boot_disk_size = 50               # 50 GB for most cases

# PostgreSQL version
postgresql_version = "16"               # Keep current; update carefully

# Port
db_port = 5432                          # Default; change if conflicts exist

# Use Spot VMs (preemptible) for cost savings
use_spot_vm = true                      # true for dev, false for prod

# WAL archiving (for disaster recovery)
enable_wal_archiving = true             # Recommended for production
gcs_backup_bucket = ""                  # Must create separately (see below)
```

**Guidance:**

| Setting | Dev | Prod |
|---------|-----|------|
| `db_vm_machine_type` | `e2-small` | `e2-standard-2` |
| `db_vm_boot_disk_size` | 20 | 50-100 |
| `use_spot_vm` | true | false |
| `enable_wal_archiving` | false | true |

---

### 4. Data Disk Configuration

**What it controls:** Persistent storage for PostgreSQL data

```hcl
# Create a separate persistent disk (RECOMMENDED)
create_data_disk = true

# Protect from accidental Terraform destruction
data_disk_prevent_destroy = true        # ⚠️ Set to true in prod!

# Disk size and type
data_disk_size = 50                     # Start small, expand as needed
data_disk_type = "pd-standard"          # Options: pd-standard, pd-ssd, pd-balanced

# Mount point on VM
data_disk_mount_point = "/mnt/data"     # Don't change unless you know why

# Snapshot schedule (for backups)
enable_snapshot_schedule = true         # ✓ Highly recommended
snapshot_retention_days = 3             # Keep 3 days of snapshots
snapshot_start_time = "04:00"           # UTC time (options: 00:00, 04:00, 08:00, 12:00, 16:00, 20:00)
```

**What happens:**
- Disk created separate from VM (survives VM deletion)
- Mounted at `/mnt/data` on startup
- PostgreSQL data moved to disk automatically
- Daily snapshots created at 04:00 UTC
- Old snapshots auto-deleted after 3 days

⚠️ **Production note:** Set `data_disk_prevent_destroy = true` to prevent accidental deletion!

---

### 5. Cloud Run Services Configuration

**What it controls:** Next.js frontend and Rust API deployments

```hcl
# Service names
nextjs_service_name  = "nextjs-frontend"
rust_api_service_name = "rust-api"

# Resource allocation (adjust based on load)
cloud_run_memory = "512Mi"              # Options: 128Mi, 256Mi, 512Mi, 1Gi, 2Gi, 4Gi
cloud_run_cpu = "0.25"                  # Options: 0.25, 0.5, 1, 2, 4
cloud_run_min_instances = 0             # 0 for dev (no cost when not used), 1+ for prod
cloud_run_max_instances = 10            # Autoscaling limit

# Networking
enable_direct_vpc_egress = true         # ✓ Recommended over VPC connectors

# Container images (leave empty for now, fill after pushing images)
nextjs_image_url = ""                   # Will be: us-central1-docker.pkg.dev/.../nextjs:sha
rust_api_image_url = ""                 # Will be: us-central1-docker.pkg.dev/.../rust-api:sha
```

**Guidance:**

| Setting | Dev | Prod |
|---------|-----|------|
| `cloud_run_memory` | `256Mi` | `512Mi` |
| `cloud_run_cpu` | `0.25` | `0.5-1` |
| `cloud_run_min_instances` | `0` | `1` |
| `cloud_run_max_instances` | `10` | `100+` |

---

### 6. Logging & Cost Optimization

**What it controls:** Cloud Logging verbosity and cost

```hcl
# Enable log exclusions to reduce noise and cost
enable_log_exclusions = true            # Recommended: excludes DEBUG logs

# Log retention for development
log_retention_days_dev = 7              # Keep logs for 1 week (lower cost)
```

---

### 7. GCS Backend Configuration

**What it controls:** Terraform state storage

The Terraform backend (GCS bucket) is configured via `make init`:

```bash
make init
```

This automatically:
1. Creates GCS bucket: `${PROJECT_ID}-tf-state`
2. Enables versioning
3. Initializes Terraform with remote backend

**Manual setup (if needed):**

```bash
# Create bucket
gsutil mb gs://saas-app-001-tf-state

# Enable versioning
gsutil versioning set on gs://saas-app-001-tf-state

# Initialize Terraform
cd terraform
terraform init \
  -backend-config="bucket=saas-app-001-tf-state" \
  -backend-config="prefix=terraform/state"
```

---

### 8. GCS Backup Bucket (Optional but Recommended)

**What it controls:** WAL archiving for disaster recovery

```bash
# Create a separate bucket for backups
gsutil mb gs://saas-app-001-backups

# Enable versioning
gsutil versioning set on gs://saas-app-001-backups

# Then update terraform.tfvars:
gcs_backup_bucket = "saas-app-001-backups"
```

In `terraform.tfvars`:
```hcl
enable_wal_archiving = true
gcs_backup_bucket = "saas-app-001-backups"
```

---

## Configuration Checklist with Values

### Example Dev Configuration

```hcl
# terraform/terraform.tfvars (DEV)

project_id = "saas-app-001"
region     = "us-central1"
environment = "dev"
app_name   = "edgequake"

# VPC
vpc_cidr = "10.0.0.0/16"

# Database VM
db_vm_machine_type = "e2-small"         # Smaller for dev
db_vm_boot_disk_size = 20
db_port = 5432
postgresql_version = "16"
use_spot_vm = true                      # Save costs with preemptible

# Cloud Run
nextjs_service_name  = "nextjs-frontend"
rust_api_service_name = "rust-api"
cloud_run_memory = "256Mi"              # Smaller for dev
cloud_run_cpu = "0.25"
cloud_run_min_instances = 0             # No cost when idle
cloud_run_max_instances = 5

# Images (fill after pushing)
nextjs_image_url = ""
rust_api_image_url = ""

# Networking
enable_direct_vpc_egress = true

# Data disk
create_data_disk = true
data_disk_prevent_destroy = true        # Still protect in dev!
data_disk_size = 50
data_disk_type = "pd-standard"
enable_snapshot_schedule = true
snapshot_retention_days = 3
snapshot_start_time = "04:00"

# Backups (optional for dev)
enable_wal_archiving = false            # Save costs
gcs_backup_bucket = ""

# Logging
enable_log_exclusions = true
log_retention_days_dev = 7

# Labels
labels = {
  "managed_by" = "terraform"
  "env"        = "dev"
  "app"        = "edgequake"
  "team"       = "platform"
}
```

### Example Production Configuration

```hcl
# terraform/terraform.tfvars (PROD)

project_id = "saas-app-001-prod"
region     = "us-central1"
environment = "prod"
app_name   = "edgequake"

# VPC
vpc_cidr = "10.0.0.0/16"

# Database VM
db_vm_machine_type = "e2-standard-2"    # Larger for prod
db_vm_boot_disk_size = 100
db_port = 5432
postgresql_version = "16"
use_spot_vm = false                     # Reliability over cost

# Cloud Run
nextjs_service_name  = "nextjs-frontend"
rust_api_service_name = "rust-api"
cloud_run_memory = "512Mi"              # More resources
cloud_run_cpu = "0.5"
cloud_run_min_instances = 1             # Always running
cloud_run_max_instances = 50            # Higher scaling limit

# Images (fill after pushing)
nextjs_image_url = ""
rust_api_image_url = ""

# Networking
enable_direct_vpc_egress = true

# Data disk
create_data_disk = true
data_disk_prevent_destroy = true        # ⚠️ CRITICAL for prod
data_disk_size = 100                    # Larger in prod
data_disk_type = "pd-ssd"               # SSD for performance
enable_snapshot_schedule = true
snapshot_retention_days = 7             # Keep 1 week
snapshot_start_time = "04:00"

# Backups (essential for prod)
enable_wal_archiving = true             # ✓ Required
gcs_backup_bucket = "saas-app-001-prod-backups"

# Logging
enable_log_exclusions = true
log_retention_days_prod = 30            # Keep 1 month

# Labels
labels = {
  "managed_by"  = "terraform"
  "env"         = "prod"
  "app"         = "edgequake"
  "team"        = "platform"
  "cost_center" = "engineering"
}
```

---

## Pre-Deployment Validation Steps

### 1. Validate Terraform Syntax

```bash
cd terraform
terraform validate
```

**Expected output:**
```
Success! The configuration is valid.
```

### 2. Check for Required Variables

```bash
terraform plan
```

**Watch for:**
- ✓ All variables are set
- ✓ Image URLs are empty (will be filled later)
- ✓ Backup bucket exists (if enabled)

### 3. Review the Plan

```bash
terraform plan -out=tfplan
```

**Review output for:**
- Correct number of resources
- Correct machine types
- Correct disk sizes
- Correct Cloud Run memory/CPU
- Correct region and zones

### 4. Check GCS Backend

```bash
# Verify bucket exists
gsutil ls gs://saas-app-001-tf-state

# Verify versioning is enabled
gsutil versioning get gs://saas-app-001-tf-state
```

---

## Common Issues & Fixes

| Issue | Cause | Fix |
|-------|-------|-----|
| **"required_providers"** error | Terraform not initialized | Run `terraform init` |
| **"invalid region"** | Typo in region | Check `region = "us-central1"` |
| **"bucket does not exist"** | GCS bucket not created | Run `gsutil mb gs://...` |
| **"permission denied"** | Wrong GCP credentials | Run `gcloud auth application-default login` |
| **Plan shows >20 resources** | Wrong configuration | Review `terraform.tfvars` |

---

## Deployment Workflow

### Phase 1: Setup (Before terraform apply)

```bash
# 1. Authenticate to GCP
gcloud auth application-default login
gcloud config set project saas-app-001

# 2. Create/update terraform.tfvars
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform.tfvars with your values

# 3. Initialize Terraform and backend
make init

# 4. Validate configuration
terraform validate
terraform plan
```

### Phase 2: Deploy Infrastructure

```bash
cd terraform

# 1. Review plan
terraform plan -out=tfplan

# 2. Apply (creates all resources)
terraform apply tfplan

# Expected: 10-15 resources created
# Time: 5-10 minutes
```

### Phase 3: Verify Deployment

```bash
# 1. Check VM is running
gcloud compute instances list

# 2. Check Cloud Run services exist
gcloud run services list --region=us-central1

# 3. Check PostgreSQL is running
gcloud compute ssh db-vm --zone=us-central1-a
sudo systemctl status postgresql
```

### Phase 4: Prepare for CI/CD

After infrastructure is deployed:

1. **Build and push images** to Artifact Registry
   - See: [08-github-actions-deploy-edgequake.md](./08-github-actions-deploy-edgequake.md)

2. **Update terraform.tfvars** with image URLs:
   ```hcl
   nextjs_image_url = "us-central1-docker.pkg.dev/saas-app-001/edgequake-images/nextjs:abc123"
   rust_api_image_url = "us-central1-docker.pkg.dev/saas-app-001/edgequake-images/rust-api:abc123"
   ```

3. **Run terraform apply** again:
   ```bash
   terraform apply
   ```
   This updates Cloud Run services with the new images.

---

## Environment-Specific Guidance

### Development Deployment

**Goals:** Minimize cost, quick iteration, learning

```hcl
db_vm_machine_type = "e2-small"
use_spot_vm = true
cloud_run_min_instances = 0
enable_wal_archiving = false
data_disk_prevent_destroy = true  # Still protect!
```

**Cost estimate:** $10-20/month

### Staging Deployment

**Goals:** Test production configuration, integration testing

```hcl
db_vm_machine_type = "e2-standard-2"
use_spot_vm = false
cloud_run_min_instances = 1
enable_wal_archiving = true
data_disk_prevent_destroy = true
```

**Cost estimate:** $50-100/month

### Production Deployment

**Goals:** Reliability, performance, durability

```hcl
db_vm_machine_type = "e2-standard-2"  # Or larger
use_spot_vm = false
cloud_run_min_instances = 1
cloud_run_max_instances = 50+
enable_wal_archiving = true
data_disk_prevent_destroy = true
data_disk_type = "pd-ssd"
snapshot_retention_days = 7+
```

**Cost estimate:** $200-500+/month

---

## Next Steps

1. ✅ Create `terraform/terraform.tfvars` with your values
2. ✅ Run `make init` to bootstrap backend
3. ✅ Run `terraform validate` and `terraform plan`
4. ✅ Review the plan output
5. ✅ Run `terraform apply` to deploy infrastructure
6. ✅ Verify all resources are created
7. ✅ Follow Phase 4 to prepare images and CI/CD

See [11-edgequake-integration-summary.md](./11-edgequake-integration-summary.md) for application configuration.

# Edgequake & Edgequake_UI Deployment Ready Guide

This document confirms that the Terraform infrastructure is fully configured and ready for deploying the Edgequake applications.

## ✅ Status: Ready for Deployment

The infrastructure supports both:
- **edgequake** – Rust API backend
- **edgequake_ui** – Next.js frontend

---

## Configuration Summary

### Cloud Run Services Configured

#### 1. Next.js Frontend Service
**Service Name:** `nextjs-frontend`

**Configuration:**
```terraform
module "cloud_run_nextjs" {
  service_name = var.nextjs_service_name  # "nextjs-frontend"
  image_url    = var.nextjs_image_url     # To be filled with actual image
  
  environment_variables = {
    "NODE_ENV" = "dev"  # or "prod"
    "API_URL"  = "http://${module.cloud_run_rust_api.service_uri}"
  }
  
  allow_unauthenticated = true  # Allows public access
}
```

**Environment Variables Provided:**
- `NODE_ENV` – Set to deployment environment (dev/prod)
- `API_URL` – Automatically set to the Rust API service URL

**What you need to provide:**
- Docker image URL in Artifact Registry (after building)

**Access:**
- Public HTTPS endpoint
- No authentication required

---

#### 2. Rust API Backend Service
**Service Name:** `rust-api`

**Configuration:**
```terraform
module "cloud_run_rust_api" {
  service_name = var.rust_api_service_name  # "rust-api"
  image_url    = var.rust_api_image_url     # To be filled with actual image
  
  environment_variables = {
    "DATABASE_HOST" = "<PostgreSQL_VM_Private_IP>"
    "DATABASE_PORT" = "5432"
    "DATABASE_NAME" = "graph_db"
  }
  
  allow_unauthenticated = false  # Requires authentication
}
```

**Environment Variables Provided:**
- `DATABASE_HOST` – Private IP of PostgreSQL VM
- `DATABASE_PORT` – PostgreSQL port (5432)
- `DATABASE_NAME` – Database name (graph_db)

**What you need to provide:**
- Docker image URL in Artifact Registry (after building)
- Code that reads and uses these environment variables
- `/health` endpoint for Cloud Run health checks

**Access:**
- Private HTTPS endpoint
- Authentication required (from Next.js frontend)
- Internal access from Next.js via API_URL

---

### Database Configuration

**PostgreSQL 16 on Compute Engine VM**

```terraform
module "compute" {
  machine_type         = "e2-standard-2"    # Configurable
  postgresql_version   = "16"
  db_port              = 5432
  
  # Data disk configuration
  create_data_disk         = true
  data_disk_prevent_destroy = true
  data_disk_size           = 50
  
  # Snapshots for backup
  enable_snapshot_schedule = true
  snapshot_retention_days = 3
}
```

**Database Details:**
- **Host:** Private IP (only accessible from Cloud Run via VPC)
- **Port:** 5432
- **Database:** `graph_db` (created automatically)
- **Extensions:** age, pgvector (installed automatically)
- **Storage:** Separate persistent disk at `/mnt/data`
- **Backups:** Daily snapshots (3-day retention)

**WAL Archiving:**
- **Status:** Disabled by default (`enable_wal_archiving = false`)
- **To enable:** Set `enable_wal_archiving = true` and provide `gcs_backup_bucket`

---

## Configuration Checklist

### Before Deployment

- [ ] **Create terraform.tfvars**
  ```bash
  cp terraform/terraform.tfvars.example terraform/terraform.tfvars
  ```

- [ ] **Update values in terraform.tfvars**
  ```hcl
  project_id = "saas-app-001"
  region     = "us-central1"
  environment = "dev"
  app_name   = "edgequake"
  
  # Service names (match app names)
  nextjs_service_name     = "nextjs-frontend"  # or "edgequake-ui"
  rust_api_service_name   = "rust-api"        # or "edgequake-api"
  
  # Database
  db_vm_machine_type = "e2-standard-2"
  
  # WAL archiving (MUST be false or provide bucket)
  enable_wal_archiving = false
  gcs_backup_bucket = ""
  
  # Leave image URLs empty for now
  nextjs_image_url = ""
  rust_api_image_url = ""
  ```

- [ ] **Initialize Terraform backend**
  ```bash
  make init
  ```

- [ ] **Validate configuration**
  ```bash
  terraform validate
  ```

- [ ] **Review deployment plan**
  ```bash
  terraform plan
  ```

- [ ] **Deploy infrastructure**
  ```bash
  terraform apply
  ```

---

## After Infrastructure Deployment

### 1. Build and Push Docker Images

**For edgequake_ui (Next.js):**
```bash
# Build
docker build -t us-central1-docker.pkg.dev/saas-app-001/edgequake-images/nextjs:$(git rev-parse --short HEAD) \
  -f edgequake_webui/Dockerfile .

# Push
docker push us-central1-docker.pkg.dev/saas-app-001/edgequake-images/nextjs:$(git rev-parse --short HEAD)
```

**For edgequake (Rust API):**
```bash
# Build
docker build -t us-central1-docker.pkg.dev/saas-app-001/edgequake-images/rust-api:$(git rev-parse --short HEAD) \
  -f edgequake/Dockerfile .

# Push
docker push us-central1-docker.pkg.dev/saas-app-001/edgequake-images/rust-api:$(git rev-parse --short HEAD)
```

### 2. Update terraform.tfvars with Image URLs

```hcl
nextjs_image_url = "us-central1-docker.pkg.dev/saas-app-001/edgequake-images/nextjs:abc123"
rust_api_image_url = "us-central1-docker.pkg.dev/saas-app-001/edgequake-images/rust-api:abc123"
```

### 3. Apply Terraform with Images

```bash
terraform apply
```

This updates Cloud Run services with the new images.

---

## Networking & Connectivity

### Next.js ↔ Rust API

```
Next.js (public)
    ↓ HTTP request
API_URL = "http://rust-api-...run.app"
    ↓
Rust API (Cloud Run)
    ↓ Response
Next.js (renders)
```

**Configuration:** ✅ Automatic
- Next.js receives `API_URL` from Terraform
- Points to Rust API Cloud Run service URI

### Rust API ↔ PostgreSQL

```
Rust API (Cloud Run)
    ↓ TCP/SSL
VPC Connector (private)
    ↓
PostgreSQL VM (private IP: 10.0.1.x)
    ↓ Connection
graph_db
```

**Configuration:** ✅ Automatic
- Rust API receives `DATABASE_HOST`, `DATABASE_PORT`, `DATABASE_NAME`
- VPC routing and firewall rules auto-configured
- SSL enabled (self-signed cert)

---

## Environment Variables Reference

### Next.js Frontend

**Provided by Terraform:**
```
NODE_ENV = "dev" | "prod"
API_URL  = "http://rust-api-service.run.app"
```

**What the app needs:**
- Read `API_URL` for API calls
- Read `NODE_ENV` for feature flags
- No database credentials in frontend code

### Rust API Backend

**Provided by Terraform:**
```
DATABASE_HOST = "10.0.1.2"  (PostgreSQL VM private IP)
DATABASE_PORT = "5432"
DATABASE_NAME = "graph_db"
```

**What the app needs:**
- Read these three environment variables
- Build PostgreSQL connection string
- Create connection pool
- Implement `/health` endpoint
- All database access via these env vars

**Example (Rust with sqlx):**
```rust
let db_url = format!(
    "postgresql://postgres@{}:{}/{}?sslmode=require",
    env::var("DATABASE_HOST")?,
    env::var("DATABASE_PORT")?,
    env::var("DATABASE_NAME")?
);
let pool = PgPoolOptions::new()
    .max_connections(10)
    .connect(&db_url)
    .await?;
```

---

## Deployment Flow

### Step 1: Infrastructure Setup
```
1. Create terraform.tfvars
2. Run make init
3. Run terraform apply
   ├─ Creates VPC
   ├─ Creates PostgreSQL VM
   ├─ Creates Artifact Registry
   ├─ Creates Cloud Run services (without images)
   └─ Configures networking
```

### Step 2: Application Deployment
```
1. Build Docker images (edgequake + edgequake_ui)
2. Push to Artifact Registry
3. Update terraform.tfvars with image URLs
4. Run terraform apply
   ├─ Updates Cloud Run services with images
   ├─ Injects environment variables
   └─ Services become live
```

### Step 3: Verification
```
1. Test /health endpoints
2. Verify API connectivity
3. Check Cloud Logs for errors
4. Test full user flows
```

---

## Service Names & Addresses

After deployment, note:

| Service | Cloud Run URL | Accessibility |
|---------|---------------|---------------|
| Next.js | `https://nextjs-frontend-xxx.run.app` | Public HTTPS |
| Rust API | `https://rust-api-xxx.run.app` | Private (auth required) |
| PostgreSQL | `10.0.1.x:5432` (private) | Internal VPC only |

---

## Testing Connectivity

### After deployment, verify:

**1. Next.js Health Check**
```bash
curl https://nextjs-frontend-xxx.run.app/health
# Should return 200 OK
```

**2. Rust API Health Check**
```bash
curl https://rust-api-xxx.run.app/health
# Should return 200 OK (requires auth)
```

**3. PostgreSQL from VM**
```bash
gcloud compute ssh db-vm --zone=us-central1-a
sudo -u postgres psql -d graph_db -c "\dx"
# Should list extensions: age, vector
```

**4. API Connectivity from Next.js**
```javascript
// pages/api/test.js
const apiUrl = process.env.API_URL;
const response = await fetch(`${apiUrl}/health`);
// Should succeed
```

---

## Key Features Ready

✅ **For edgequake (Rust API):**
- PostgreSQL 16 with age + pgvector extensions
- Connection pooling support
- Health check endpoint support
- Automatic environment variable injection
- Private VPC connectivity to database
- Cloud Run scaling (0-10 instances)

✅ **For edgequake_ui (Next.js):**
- Public HTTPS endpoint
- API_URL environment variable injection
- Node.js runtime with npm/yarn support
- Cloud Run scaling (0-10 instances)
- Health check support

✅ **Infrastructure:**
- Private VPC with subnets
- PostgreSQL 16 with managed extensions
- Persistent data disk with daily snapshots
- Artifact Registry repository
- GCS backend for Terraform state
- Cloud Logging with cost optimizations
- IAM service accounts and roles
- Firewall rules auto-configured

---

## Cost Optimization Notes

**Current Configuration (Dev):**
- e2-small VM for database = low cost
- Preemptible (Spot) VM enabled = 70% cost savings
- Cloud Run min instances = 0 (no cost when idle)
- Log exclusions enabled (reduce logging volume)
- WAL archiving disabled (no backup costs)

**Estimated monthly cost:** $10-20 for dev environment

**To enable production features:**
```hcl
db_vm_machine_type = "e2-standard-2"
use_spot_vm = false
cloud_run_min_instances = 1
enable_wal_archiving = true
gcs_backup_bucket = "saas-app-001-backups"
```

**Estimated production cost:** $100-300/month

---

## Documentation References

| Topic | Document |
|-------|----------|
| Database connection setup | [09-database-connection-config.md](./09-database-connection-config.md) |
| Environment variables | [10-environment-configuration-examples.md](./10-environment-configuration-examples.md) |
| CI/CD integration | [08-github-actions-deploy-edgequake.md](./08-github-actions-deploy-edgequake.md) |
| Pre-deployment checklist | [13-pre-deployment-terraform-checklist.md](./13-pre-deployment-terraform-checklist.md) |
| Terraform status | [14-terraform-status-and-updates.md](./14-terraform-status-and-updates.md) |

---

## Quick Start Command Reference

```bash
# 1. Setup
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# 2. Initialize backend
make init

# 3. Deploy infrastructure
terraform validate
terraform plan
terraform apply

# 4. After images are built/pushed, update URLs in terraform.tfvars
# Then:
terraform apply

# 5. Verify deployment
gcloud run services list --region=us-central1
curl https://<nextjs-url>/health
```

---

## Summary

✅ **Terraform is fully configured and ready for:**
- Deploying edgequake (Rust API backend)
- Deploying edgequake_ui (Next.js frontend)
- Managing PostgreSQL 16 database
- Automatic environment variable injection
- CI/CD integration via image URLs

✅ **WAL archiving is disabled** (enable manually if needed)

✅ **Cost optimized** for development use

**Next step:** Follow [13-pre-deployment-terraform-checklist.md](./13-pre-deployment-terraform-checklist.md) to create `terraform.tfvars` and deploy.

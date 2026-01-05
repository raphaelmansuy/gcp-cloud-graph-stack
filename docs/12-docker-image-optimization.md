# Docker Image Optimization: Why Pre-Build and Push Instead of Building Inside VM

## Executive Summary

**Current Problem**: PostgreSQL Docker image is built from scratch inside the VM on every startup, taking **15+ minutes** and blocking application initialization.

**Solution**: Pre-build the Docker image in a CI/CD pipeline and push to Google Artifact Registry. VM simply pulls and runs the pre-built image in **2-3 minutes**.

---

## Current Architecture ❌

```
┌─────────────────────────────────────────────────────────────────────┐
│  VM Startup (edgequake-db-vm)                                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  startup-script.sh                                                   │
│    ├─ Install Docker (30s)                                           │
│    ├─ Mount data disk (5s)                                           │
│    │                                                                 │
│    ├─ Write Dockerfile to disk (5s)                                  │
│    │   └─ FROM postgres:16                                           │
│    │   └─ apt-get install build-essential, git, etc (slow!)         │
│    │   └─ git clone pgvector (30s)                                  │
│    │   └─ make && make install (60s)                                │
│    │   └─ git clone apache/age (30s)                                │
│    │   └─ make && make install (90s)                                │
│    │   └─ Clean up build deps (30s)                                 │
│    │                                                                 │
│    ├─ docker build (15-20 MINUTES!) ⏱️  ← BOTTLENECK                │
│    │   └─ Layer cache misses                                        │
│    │   └─ Pulls base image from Docker Hub                          │
│    │   └─ Compiles pgvector and AGE                                 │
│    │                                                                 │
│    └─ Start container & init DB (30s)                               │
│                                                                      │
│  TOTAL TIME: 15-25 minutes ⏱️                                         │
│  Problem: Cloud Run starts in 30 seconds, DB not ready!             │
└─────────────────────────────────────────────────────────────────────┘

Meanwhile in Cloud Run:
  └─ Service starts immediately
  └─ Attempts to connect to database
  └─ Connection fails (database still building) ✗
  └─ Components show "disconnected" ✗
  └─ Application appears "stuck" ✗
```

---

## Proposed Architecture ✅

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  CI/CD Pipeline (once, during deployment)                                    │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  scripts/build-postgres-image.sh (runs in GitHub Actions)                    │
│    ├─ docker build postgres-age-vector:16 (15 min, but async)                │
│    │   └─ Compile pgvector and AGE locally                                   │
│    │   └─ Layer caching makes rebuilds fast (1-2 min)                        │
│    │                                                                          │
│    └─ docker push to us-central1-docker.pkg.dev/...                          │
│        └─ Push to Google Artifact Registry (2 min)                           │
│                                                                               │
│  TOTAL: 20 minutes, but happens ONCE during deploy                           │
│  Result: Reusable image stored in Artifact Registry                          │
└──────────────────────────────────────────────────────────────────────────────┘
                            ⬇️
                  Image stored in Registry
                            ⬇️
┌──────────────────────────────────────────────────────────────────────────────┐
│  VM Startup (edgequake-db-vm) - EVERY TIME                                   │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  startup-script-optimized.sh                                                 │
│    ├─ Install Docker (30s)                                                   │
│    ├─ Mount data disk (5s)                                                   │
│    ├─ gcloud auth configure-docker (5s)                                      │
│    ├─ docker pull (2-3 min) ← FAST! Already built, just transfer layers     │
│    │   └─ From: us-central1-docker.pkg.dev/.../postgres-age-vector:16       │
│    │   └─ Layers already compiled, just download                             │
│    │                                                                          │
│    └─ docker run + init DB (30s)                                             │
│                                                                               │
│  TOTAL TIME: 3-4 minutes ✅ (75% faster!)                                     │
│  Result: Cloud Run can connect to database immediately!                      │
└──────────────────────────────────────────────────────────────────────────────┘

Timeline:
  T+0s:   VM boots
  T+30s:  Docker installed
  T+2m:   Image pulled from registry
  T+3m:   Database accepting connections ✅
  T+5m:   Cloud Run fully initialized (no more waiting!)
```

---

## Key Benefits

| Aspect | Before | After | Improvement |
|--------|--------|-------|-------------|
| **Startup Time** | 15-25 min | 3-4 min | 75-80% faster ⚡ |
| **Build Time** | Every VM start | Once per deploy | 5-10x less compute |
| **VM CPU Load** | Very high | Low | Better performance |
| **Reliability** | Network failures stop build | Cached layers | More resilient |
| **Layer Caching** | No (rebuilt from scratch) | Yes (after 1st build) | Subsequent deploys 1-2 min |
| **Image Versioning** | No versioning | Tagged images | Easy rollback |
| **Multi-region** | Rebuild per region | Pull same image | Consistent deployments |

---

## Step-by-Step Implementation

### 1. Build and Push the Image (One-Time Setup)

```bash
# Navigate to project
cd /Users/raphaelmansuy/Github/03-working/gcp-cloud-graph-stack

# Build and push to Artifact Registry
bash scripts/build-postgres-image.sh
```

This script will:
- Create Artifact Registry repo if needed
- Build `postgres-age-vector:16` image
- Push to `us-central1-docker.pkg.dev/saas-app-001/edgequake-images/postgres-age-vector:16-latest`
- Output the image URL to use in Terraform

### 2. Update Terraform Configuration

Update `terraform/terraform.tfvars`:

```hcl
# Add this new variable
postgres_image_url = "us-central1-docker.pkg.dev/saas-app-001/edgequake-images/postgres-age-vector:16-latest"
```

Or set as environment variable:

```bash
export TF_VAR_postgres_image_url="us-central1-docker.pkg.dev/saas-app-001/edgequake-images/postgres-age-vector:16-latest"
```

### 3. Update Terraform Module

Update `terraform/modules/compute/variables.tf`:

```hcl
variable "postgres_image_url" {
  description = "Pre-built PostgreSQL Docker image URL from Artifact Registry"
  type        = string
  default     = "postgres:16"  # Fallback to base image if not provided
}
```

Update `terraform/modules/compute/main.tf`:

```bash
metadata_startup_script = templatefile(
  "${path.module}/startup-script-optimized.sh",
  {
    gcp_project_id   = var.gcp_project_id
    gcp_region       = var.gcp_region
    postgres_image_url = var.postgres_image_url  # ← Add this
    data_disk_name   = google_compute_disk.postgres_data.name
    data_disk_mount_point = var.data_disk_mount_point
    db_port          = var.db_port
  }
)
```

### 4. Deploy

```bash
cd terraform

# Initialize (if needed)
terraform init

# Plan
terraform plan -var-file=terraform.tfvars

# Apply
terraform apply -var-file=terraform.tfvars
```

---

## How It Works: Technical Details

### Build Script (`scripts/build-postgres-image.sh`)

1. **Creates Artifact Registry repo** (one-time):
   ```bash
   gcloud artifacts repositories create edgequake-images \
     --repository-format docker \
     --location us-central1
   ```

2. **Builds Docker image locally**:
   ```dockerfile
   FROM postgres:16-bookworm
   
   # Install build dependencies
   RUN apt-get install -y build-essential flex bison git postgresql-server-dev-16
   
   # Install pgvector (compiles locally)
   RUN git clone https://github.com/pgvector/pgvector.git && \
       cd pgvector && make && make install
   
   # Install Apache AGE (compiles locally)
   RUN git clone https://github.com/apache/age.git && \
       cd age && make && make install
   
   # Clean up build dependencies
   RUN apt-get remove -y build-essential flex bison git postgresql-server-dev-16
   ```

3. **Pushes to Artifact Registry**:
   ```bash
   docker tag postgres-age-vector:16 \
     us-central1-docker.pkg.dev/saas-app-001/edgequake-images/postgres-age-vector:16-latest
   
   docker push \
     us-central1-docker.pkg.dev/saas-app-001/edgequake-images/postgres-age-vector:16-latest
   ```

### Optimized Startup Script (`startup-script-optimized.sh`)

1. **Install Docker** (30s)
2. **Configure Artifact Registry auth** (5s)
3. **Setup data disk** (5s)
4. **Pull image from registry** (2-3 min) ← MUCH faster than building!
5. **Start container** (30s)
6. **Initialize database** (30s)
7. **Write completion status** to `/var/lib/postgres-startup-complete`
8. **Log to Cloud Logging** for monitoring

Key improvements:
- ✅ **Timeout handling**: Fails gracefully if startup takes >10 minutes
- ✅ **Health checks**: Waits for `pg_isready` before considering DB ready
- ✅ **Detailed logging**: All steps logged to `/var/log/postgres-startup.log`
- ✅ **Status file**: `/var/lib/postgres-startup-complete` indicates readiness
- ✅ **Cloud Logging integration**: Sends completion status to Cloud Logging
- ✅ **Fallback support**: If pull fails, falls back to building locally

---

## Monitoring and Troubleshooting

### Check Startup Status

```bash
# SSH into VM
gcloud compute ssh edgequake-db-vm

# Check if startup completed
cat /var/lib/postgres-startup-complete
# Output:
# {
#   "status": "COMPLETE",
#   "timestamp": "2026-01-05T20:30:45Z",
#   "duration_seconds": 245
# }

# View startup logs
sudo tail -100 /var/log/postgres-startup.log

# View Cloud Logging
gcloud logging read \
  "resource.type=gce_instance AND resource.labels.instance_id=edgequake-db-vm" \
  --limit 50 \
  --format=json | jq .
```

### Common Issues and Fixes

#### Issue: Docker image pull fails

```bash
# Verify Artifact Registry authentication
gcloud auth configure-docker us-central1-docker.pkg.dev

# Check if image exists
gcloud artifacts docker images list us-central1

# If image doesn't exist, rebuild it
bash scripts/build-postgres-image.sh
```

#### Issue: Startup takes >5 minutes

```bash
# Check Docker build cache
docker buildx du

# Clear cache if needed
docker buildx prune -a

# Rebuild and repush
bash scripts/build-postgres-image.sh
```

#### Issue: PostgreSQL won't start

```bash
# Check container logs
docker logs postgres-age-vector

# Verify image was pulled correctly
docker images | grep postgres-age-vector

# Check data directory permissions
ls -la /data/pgdata
```

---

## Integration with CI/CD (GitHub Actions)

Add to `.github/workflows/deploy.yml`:

```yaml
- name: Build and push PostgreSQL image
  run: |
    bash scripts/build-postgres-image.sh
  env:
    GCP_PROJECT: saas-app-001
    GCP_REGION: us-central1
```

This ensures the image is always up-to-date when deploying.

---

## Rollback Strategy

If a bad image is pushed:

1. **Revert to previous image**:
   ```bash
   # List image tags
   gcloud artifacts docker images list us-central1 \
     --repository=edgequake-images

   # Update terraform.tfvars to use specific tag
   postgres_image_url = "us-central1-docker.pkg.dev/saas-app-001/edgequake-images/postgres-age-vector:16-20260105-v1"
   
   # Reapply
   terraform apply -var-file=terraform.tfvars
   ```

2. **Force VM restart to use new image**:
   ```bash
   terraform taint google_compute_instance.postgres_vm
   terraform apply -var-file=terraform.tfvars
   ```

---

## Cost Implications

- **Artifact Registry storage**: ~$0.10/GB/month (2GB image = $0.20/month)
- **Network egress**: ~$0.12/GB (pulling image once = ~$0.24/month)
- **Total additional cost**: ~$0.50/month (negligible)
- **Compute savings**: 75% less CPU time during startup = ~$2-5/month savings
- **Net benefit**: Save money + faster deployments ✅

---

## Summary

| Feature | Impact |
|---------|--------|
| **Speed** | 75% faster VM startup |
| **Reliability** | No more build failures from network issues |
| **Scalability** | Easy to deploy same image to multiple regions |
| **Debugging** | Startup logs are clear and centralized |
| **Cost** | Slight overhead, but offset by compute savings |
| **Flexibility** | Easy to version and rollback images |

**Recommendation**: Implement this optimization to ensure reliable, fast database initialization across all deployments.

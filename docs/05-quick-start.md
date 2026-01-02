# Quick Start Guide: Deploy gcp-cloud-graph-stack

This guide walks you through deploying the complete infrastructure and CI/CD pipeline to `saas-app-001` GCP project in under 30 minutes.

## Prerequisites

### Local Tools
- Terraform 1.5+ ([install](https://www.terraform.io/downloads))
- Google Cloud SDK (`gcloud` CLI) ([install](https://cloud.google.com/sdk/docs/install))
- Docker ([install](https://docs.docker.com/get-docker))
- Git

### GCP Setup
1. Set default project:
   ```bash
   gcloud config set project saas-app-001
   ```

2. Enable required APIs:
   ```bash
   gcloud services enable compute.googleapis.com \
     run.googleapis.com \
     artifactregistry.googleapis.com \
     cloudbuild.googleapis.com \
     cloudresourcemanager.googleapis.com \
     serviceusage.googleapis.com
   ```

3. Verify authentication:
   ```bash
   gcloud auth login
   gcloud auth application-default login
   ```

## Path A: Terraform + GitHub Actions (Recommended)

### Step 1: Configure Terraform Variables (5 min)

```bash
cd terraform

# Copy the example file
cp terraform.tfvars.example terraform.tfvars

# Edit with your settings (values are pre-filled for saas-app-001)
nano terraform.tfvars

# Key variables to verify:
# - project_id = "saas-app-001"
# - region = "us-central1"
# - environment = "dev"
# - gcs_backup_bucket = "saas-app-001-db-backups"  # Must be unique globally
```

### Step 2: Create GCS Bucket for Terraform State (3 min)

```bash
# Create bucket for storing Terraform state
gsutil mb -p saas-app-001 gs://saas-app-001-tf-state

# Enable versioning
gsutil versioning set on gs://saas-app-001-tf-state

# (Optional) Set up backend in terraform/main.tf:
# Uncomment the terraform block to use remote state
```

### Step 3: Provision Infrastructure with Terraform (10 min)

```bash
# Initialize Terraform
terraform init

# Plan the deployment
terraform plan -out=tfplan

# Review the plan output (should show ~20 resources)

# Apply the configuration
terraform apply tfplan

# Save the outputs
terraform output > outputs.txt
```

**What gets created:**
- ✅ VPC with subnet (10.0.0.0/16)
- ✅ Compute Engine VM (e2-standard-2) with PostgreSQL 16, AGE, pgvector
- ✅ Cloud Run service for Next.js frontend
- ✅ Cloud Run service for Rust API
- ✅ Artifact Registry repository
- ✅ Service accounts and IAM roles
- ✅ Firewall rules for secure communication

### Step 4: Verify Infrastructure (5 min)

```bash
# Get outputs
terraform output

# Check VM is running
gcloud compute instances describe edgequake-db-vm \
  --zone=us-central1-a

# Verify Cloud Run services exist
gcloud run services list --region=us-central1

# Check Artifact Registry
gcloud artifacts repositories describe edgequake-images \
  --location=us-central1
```

### Step 5: Verify PostgreSQL on VM (5 min)

```bash
# SSH into VM
gcloud compute ssh edgequake-db-vm \
  --zone=us-central1-a \
  --tunnel-through-iap

# Inside VM:
# Check PostgreSQL is running
sudo systemctl status postgresql

# Connect to database
sudo -u postgres psql -d graph_db -c \
  "SELECT * FROM pg_extension WHERE extname IN ('age', 'vector');"

# Expected output:
#     extname | extversion | extschema | extrelocatable
#  -----------+------------+-----------+----------------
#  age        | 1.3.0      | ag_catalog| t
#  vector     | 0.5.1      | public    | t

# Exit VM
exit
```

### Step 6: Build and Push Container Images (10 min)

```bash
# Set variables
PROJECT_ID=saas-app-001
REGION=us-central1
REGISTRY=${REGION}-docker.pkg.dev/${PROJECT_ID}

# Create .dockerconfigjson for Docker auth
gcloud auth configure-docker ${REGION}-docker.pkg.dev

# Build Next.js image
docker build -t ${REGISTRY}/edgequake-images/nextjs:latest \
  -f dockerfiles/Dockerfile.nextjs .

# Push Next.js image
docker push ${REGISTRY}/edgequake-images/nextjs:latest

# Build Rust API image
docker build -t ${REGISTRY}/edgequake-images/rust-api:latest \
  -f dockerfiles/Dockerfile.rust .

# Push Rust API image
docker push ${REGISTRY}/edgequake-images/rust-api:latest

# Verify images exist
gcloud artifacts docker images list ${REGISTRY}/edgequake-images
```

**Note**: If you don't have Next.js/Rust source code yet, create minimal example projects:

```bash
# Minimal Next.js app
mkdir -p apps/nextjs
cd apps/nextjs
npm init -y
npm install next react react-dom

# Minimal Rust API
mkdir -p apps/rust-api
cd apps/rust-api
cargo init --name rust-api
cargo add axum tokio
```

### Step 7: Deploy Services to Cloud Run (5 min)

```bash
# Update terraform variables with image URLs
# Edit terraform/terraform.tfvars:
# nextjs_image = "us-central1-docker.pkg.dev/saas-app-001/edgequake-images/nextjs:latest"
# rust_api_image = "us-central1-docker.pkg.dev/saas-app-001/edgequake-images/rust-api:latest"

# Reapply Terraform to update Cloud Run services
terraform apply

# Verify services are deployed
gcloud run services list --region=us-central1

# Get service URLs
gcloud run services describe nextjs-frontend --region=us-central1 --format='value(status.url)'
gcloud run services describe rust-api --region=us-central1 --format='value(status.url)'
```

### Step 8: Set Up GitHub Actions (Optional, for CI/CD)

Follow [03-deployment-github-actions.md](./03-deployment-github-actions.md) to:
1. Create GitHub Workload Identity Provider
2. Add GitHub secrets
3. Push code to GitHub
4. Trigger automatic deployments

## Path B: Cloud Build Only

### Step 1: Terraform Setup (Same as above Steps 1-5)

Follow Terraform steps 1-5 above.

### Step 2: Create Cloud Build Trigger

```bash
# Create trigger from GitHub/GitLab repository
gcloud builds connect GITHUB_OWNER/GITHUB_REPO \
  --region=us-central1

# Or use Cloud Build UI:
# 1. Cloud Build > Triggers
# 2. Create Trigger
# 3. Select repository
# 4. Point to cloudbuild.yaml
```

### Step 3: Trigger Build

```bash
# Manually trigger build
gcloud builds submit --config=cloudbuild.yaml

# Or commit to main branch (if trigger is set up):
git add .
git commit -m "deploy: trigger cloud build"
git push origin main
```

## Verification Checklist

```
Infrastructure:
  [x] Terraform apply completed successfully
  [x] VM is running (e2-standard-2)
  [x] PostgreSQL 16 accessible via SSH
  [x] AGE extension installed and working
  [x] pgvector extension installed and working
  [x] Cloud Run services deployed (2 services)
  [x] Artifact Registry has images

CI/CD:
  [x] Images built and pushed to Artifact Registry
  [x] Cloud Run services can be updated via image push
  [x] GitHub Actions workflow configured (if using Path A)
  [x] Cloud Build trigger configured (if using Path B)

Database:
  [x] SSH into VM successful
  [x] PostgreSQL responding to connections
  [x] graph_db database created
  [x] Extensions loaded (age, vector)
  [x] WAL archiving configured (if enabled)

Networking:
  [x] Cloud Run services have private VPC egress
  [x] Firewall rules allow Cloud Run → PostgreSQL
  [x] VPC Connector configured (if not using Direct VPC)
  [x] Services can communicate
```

## Testing the Deployment

### Test Next.js Frontend

```bash
NEXTJS_URL=$(gcloud run services describe nextjs-frontend \
  --region=us-central1 --format='value(status.url)')

curl ${NEXTJS_URL}

# Expected: HTML response or 200 OK
```

### Test Rust API

```bash
RUST_API_URL=$(gcloud run services describe rust-api \
  --region=us-central1 --format='value(status.url)')

curl ${RUST_API_URL}/health

# Expected: {"status":"healthy"} or 200 OK
```

### Test Database Connectivity

```bash
# SSH into VM
gcloud compute ssh edgequake-db-vm --zone=us-central1-a

# Test query with AGE
sudo -u postgres psql -d graph_db <<EOF
SELECT create_graph('demo_graph');
SELECT * FROM cypher('demo_graph', $$ RETURN 'Hello, AGE!' $$) as (result agtype);
EOF

# Test query with pgvector
sudo -u postgres psql -d graph_db <<EOF
CREATE TABLE IF NOT EXISTS embeddings (
  id SERIAL PRIMARY KEY,
  embedding vector(768)
);
INSERT INTO embeddings (embedding) VALUES ('[1,2,3]');
SELECT embedding FROM embeddings LIMIT 1;
EOF
```

## Cleaning Up

### Remove All Resources (Careful!)

```bash
# Delete Cloud Run services, VM, VPC, etc.
cd terraform
terraform destroy

# Delete GCS buckets
gsutil rm -r gs://saas-app-001-tf-state
gsutil rm -r gs://saas-app-001-db-backups

# Delete Artifact Registry
gcloud artifacts repositories delete edgequake-images \\
  --location=us-central1

# Disable APIs (optional)
gcloud services disable compute.googleapis.com \
  run.googleapis.com \
  artifactregistry.googleapis.com
```

## Troubleshooting

### Terraform Plan Fails

```bash
# Check for quota errors
gcloud compute project-info describe --project=saas-app-001

# Verify APIs are enabled
gcloud services list --enabled | grep compute
gcloud services list --enabled | grep run

# Check authentication
gcloud auth list
gcloud auth application-default print-access-token
```

### VM Startup Script Fails

```bash
# Check logs on VM
gcloud compute instances get-serial-port-output edgequake-db-vm \\
  --zone=us-central1-a

# SSH and check systemd logs
sudo journalctl -u google-startup-scripts.service -n 100 -f
```

### Cloud Run Service Unhealthy

```bash
# Check logs
gcloud run services describe nextjs-frontend --region=us-central1

# View logs
gcloud logging read \
  "resource.type=cloud_run_revision AND resource.labels.service_name=nextjs-frontend" \
  --limit=20 --format=json

# Check IAM permissions
gcloud run services get-iam-policy nextjs-frontend --region=us-central1
```

### Image Push Fails

```bash
# Verify Docker auth
gcloud auth configure-docker us-central1-docker.pkg.dev

# Check Artifact Registry permissions
gcloud artifacts repositories describe gcp-graph-stack-images \
  --location=us-central1

# Verify image exists locally
docker images | grep edgequake
```

## Next Steps

1. **Customize Application Code**: Replace example Next.js and Rust code with your actual application
2. **Set Up Database Schema**: Create tables and initial data in PostgreSQL
3. **Configure Custom Domain**: Set up Cloud Load Balancer + Cloud Armor with custom domain
4. **Enable Monitoring**: Set up Cloud Monitoring dashboards and alerts
5. **Implement Backups**: Configure WAL archiving and automated backups
6. **Scale to Production**: Add additional regions, load balancing, and managed database option

## Additional Resources

- [📘 Architecture Overview](./01-architecture.md)
- [🚀 Terraform Deployment Guide](./02-deployment-terraform.md)
- [🔄 GitHub Actions Setup](./03-deployment-github-actions.md)
- [🏗️ CI/CD Architecture](./04-ci-cd-architecture.md)
- [Terraform Registry: Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [GCP Cloud Run Documentation](https://cloud.google.com/run/docs)
- [PostgreSQL on Compute Engine](https://cloud.google.com/solutions/postgresql-on-compute-engine)

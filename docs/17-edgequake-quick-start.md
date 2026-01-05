# EdgeQuake Deployment: Quick Start Guide

**Deploy EdgeQuake (RAG + Knowledge Graph) to Google Cloud in 15 minutes**

---

## Overview

This guide walks you through deploying the EdgeQuake RAG system with knowledge graph capabilities to Google Cloud Platform using Terraform and Cloud Run.

### What You're Deploying

- **EdgeQuake API** (Rust) - High-performance RAG backend with knowledge graph
- **EdgeQuake WebUI** (Next.js) - Modern web interface with graph visualization
- **PostgreSQL 16** - Database with AGE (graph) and pgvector (embeddings) extensions

### Architecture

```
Internet → EdgeQuake WebUI (Cloud Run) → EdgeQuake API (Cloud Run) 
                                              ↓
                                    PostgreSQL VM (Compute Engine)
                                    ├─ AGE extension (knowledge graph)
                                    └─ pgvector extension (embeddings)
```

---

## Prerequisites

### 1. Tools Required

```bash
# macOS
brew install terraform gcloud docker git

# Verify installations
terraform version  # Should be >= 1.5
gcloud version     # Should be latest
docker --version   # Should be >= 20.10
```

### 2. GCP Project Setup

```bash
# Set your project
export PROJECT_ID="saas-app-001"
gcloud config set project $PROJECT_ID

# Authenticate
gcloud auth login
gcloud auth application-default login
gcloud auth configure-docker us-central1-docker.pkg.dev
```

### 3. Verify Repository Paths

```bash
# Infrastructure repo (you should be here)
cd /Users/raphaelmansuy/Github/03-working/gcp-cloud-graph-stack

# Verify edgequake repo exists
ls -la /Users/raphaelmansuy/Github/03-working/edgequake/edgequake
ls -la /Users/raphaelmansuy/Github/03-working/edgequake/edgequake_webui
```

If the edgequake repo is in a different location, update the `EDGEQUAKE_REPO` variable in the Makefile.

---

## Deployment Steps

### Step 1: Configure Terraform (2 minutes)

```bash
cd terraform

# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars
# Minimum required changes:
cat >> terraform.tfvars <<EOF

# EdgeQuake Configuration
rust_api_service_name  = "edgequake-api"
nextjs_service_name    = "edgequake-webui"

# Database
db_vm_machine_type = "e2-standard-2"
data_disk_size     = 50

# Network
vpc_cidr = "10.8.0.0/28"
EOF
```

### Step 2: Deploy Infrastructure (5 minutes)

```bash
# Initialize Terraform
terraform init

# Plan deployment
terraform plan -out=tfplan

# Apply infrastructure
terraform apply tfplan
```

This creates:
- ✅ VPC network and subnets
- ✅ VPC Connector for Cloud Run
- ✅ Compute Engine VM with PostgreSQL
- ✅ Persistent disk for database storage
- ✅ Artifact Registry for Docker images
- ✅ Firewall rules
- ✅ IAM permissions

**Expected time:** 5-7 minutes

### Step 3: Build and Deploy EdgeQuake (8 minutes)

```bash
# Return to repo root
cd ..

# Option A: One-command deployment (recommended)
make edgequake-full

# Option B: Step-by-step (for debugging)
make edgequake-check        # Verify paths
make edgequake-build        # Build images (~5 min)
make edgequake-push         # Push to registry
make edgequake-deploy       # Deploy to Cloud Run
make edgequake-status       # Check status
```

**Build times:**
- EdgeQuake API (Rust): ~5-6 minutes (first build, cached thereafter)
- EdgeQuake WebUI (Next.js): ~2-3 minutes

### Step 4: Verify Deployment (1 minute)

```bash
# Check service status
make edgequake-status

# Test API health
export API_URL=$(gcloud run services describe edgequake-api \
  --region us-central1 --format='value(status.url)')
curl $API_URL/health

# Test WebUI
export WEBUI_URL=$(gcloud run services describe edgequake-webui \
  --region us-central1 --format='value(status.url)')
open $WEBUI_URL
```

Expected output:
```json
{
  "status": "healthy",
  "database": "connected",
  "version": "0.1.0"
}
```

---

## Configuration

### Environment Variables (Automatic)

These are automatically injected by Terraform:

**EdgeQuake API:**
```env
HOST=0.0.0.0
PORT=8080
DATABASE_HOST=10.8.0.2        # VM private IP
DATABASE_PORT=5432
DATABASE_NAME=graph_db
OPENAI_API_KEY=<from-secrets> # Set separately
```

**EdgeQuake WebUI:**
```env
PORT=3000
NODE_ENV=production
NEXT_PUBLIC_API_URL=https://edgequake-api-xxx.run.app
API_URL=https://edgequake-api-xxx.run.app
```

### Setting OpenAI API Key

```bash
# Store in Secret Manager
echo -n "sk-your-openai-key" | gcloud secrets create openai-api-key \
  --data-file=- \
  --replication-policy="automatic"

# Grant Cloud Run access
gcloud secrets add-iam-policy-binding openai-api-key \
  --member="serviceAccount:${PROJECT_ID}@appspot.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"

# Update Cloud Run service
gcloud run services update edgequake-api \
  --region us-central1 \
  --update-secrets=OPENAI_API_KEY=openai-api-key:latest
```

---

## Usage Examples

### 1. Upload a Document

```bash
curl -X POST $API_URL/api/v1/documents \
  -H "Content-Type: multipart/form-data" \
  -F "file=@document.pdf" \
  -F "tenant_id=default"
```

### 2. Query the Knowledge Graph

```bash
curl -X POST $API_URL/api/v1/query \
  -H "Content-Type: application/json" \
  -d '{
    "query": "What are the main concepts in the document?",
    "mode": "hybrid",
    "tenant_id": "default"
  }'
```

### 3. Visualize Knowledge Graph

Open the WebUI at `$WEBUI_URL` and navigate to the Graph tab.

---

## Monitoring

### View Logs

```bash
# Combined logs
make edgequake-logs

# API logs only
gcloud logging read \
  "resource.type=cloud_run_revision AND resource.labels.service_name=edgequake-api" \
  --limit 50 \
  --format json

# WebUI logs only
gcloud logging read \
  "resource.type=cloud_run_revision AND resource.labels.service_name=edgequake-webui" \
  --limit 50 \
  --format json
```

### Check Metrics

```bash
# Open Cloud Console metrics
open "https://console.cloud.google.com/run/detail/us-central1/edgequake-api/metrics?project=$PROJECT_ID"
```

---

## Troubleshooting

### Issue: Rust Build Fails

**Symptom:**
```
error: failed to compile edgequake
```

**Solution:**
```bash
# Ensure Docker has enough resources
# Docker Desktop → Settings → Resources
# Set Memory to at least 4GB

# Clear Docker cache and retry
docker system prune -af
make edgequake-build-api
```

### Issue: Database Connection Refused

**Symptom:**
```
Error: Connection refused (os error 111)
```

**Solution:**
```bash
# 1. Verify PostgreSQL is running
gcloud compute ssh edgequake-db-vm --zone=us-central1-a \
  --command="docker ps | grep postgres"

# 2. Check firewall rules
gcloud compute firewall-rules list --filter="name~cloud-run"

# 3. Verify VPC connector
gcloud compute networks vpc-access connectors describe edgequake-vpc-connector \
  --region us-central1

# 4. Check database logs
gcloud compute ssh edgequake-db-vm --zone=us-central1-a \
  --command="docker logs postgres"
```

### Issue: Next.js Build Fails

**Symptom:**
```
Error: Cannot find module 'next'
```

**Solution:**
```bash
# The Dockerfile installs dependencies - ensure package.json is valid
cat /Users/raphaelmansuy/Github/03-working/edgequake/edgequake_webui/package.json

# Rebuild with cache cleared
docker build --no-cache \
  -f dockerfiles/Dockerfile.edgequake-webui \
  -t us-central1-docker.pkg.dev/saas-app-001/edgequake-images/edgequake-webui:latest \
  /Users/raphaelmansuy/Github/03-working/edgequake/edgequake_webui
```

### Issue: Image Push Permission Denied

**Symptom:**
```
denied: Permission denied for image
```

**Solution:**
```bash
# Re-authenticate with Artifact Registry
gcloud auth configure-docker us-central1-docker.pkg.dev

# Verify you have push permissions
gcloud artifacts repositories get-iam-policy edgequake-images \
  --location=us-central1
```

---

## Updates and Redeployment

### Update Code and Redeploy

```bash
# 1. Pull latest changes in edgequake repo
cd /Users/raphaelmansuy/Github/03-working/edgequake
git pull

# 2. Rebuild and redeploy
cd /Users/raphaelmansuy/Github/03-working/gcp-cloud-graph-stack
make edgequake-full
```

### Update Infrastructure Only

```bash
cd terraform

# Edit terraform.tfvars as needed

# Apply changes
terraform plan -out=tfplan
terraform apply tfplan
```

### Rollback to Previous Version

```bash
# List available image tags
gcloud artifacts docker images list \
  us-central1-docker.pkg.dev/saas-app-001/edgequake-images/edgequake-api

# Deploy specific version
cd terraform
terraform apply \
  -var="rust_api_image_url=us-central1-docker.pkg.dev/saas-app-001/edgequake-images/edgequake-api:abc123"
```

---

## Cost Optimization

### Development Environment

```hcl
# terraform.tfvars
db_vm_machine_type = "e2-small"          # $13/month
data_disk_size     = 20                   # $0.80/month
```

Set Cloud Run to scale to zero:
```bash
gcloud run services update edgequake-api \
  --region us-central1 \
  --min-instances 0 \
  --max-instances 1
```

**Total:** ~$20-30/month

### Production Environment

```hcl
# terraform.tfvars
db_vm_machine_type = "e2-standard-4"     # $122/month
data_disk_size     = 100                  # $4/month
```

Set Cloud Run for high availability:
```bash
gcloud run services update edgequake-api \
  --region us-central1 \
  --min-instances 1 \
  --max-instances 10
```

**Total:** ~$150-250/month (depending on traffic)

---

## Next Steps

1. **Configure LLM Provider:**
   - Set up OpenAI API key (see Configuration section)
   - Or configure alternative LLM provider

2. **Upload Documents:**
   - Use WebUI or API to upload documents
   - Documents are automatically processed and indexed

3. **Explore Knowledge Graph:**
   - Use the Graph Viewer in WebUI
   - Query relationships between entities

4. **Set Up Monitoring:**
   - Configure Cloud Monitoring alerts
   - Set up log-based metrics

5. **Enable HTTPS with Custom Domain:**
   - Register a domain
   - Configure Cloud Load Balancer
   - Set up SSL certificates

6. **Implement Authentication:**
   - Add Identity-Aware Proxy (IAP)
   - Configure OAuth 2.0

---

## Additional Resources

- [Complete Territory Map](16-edgequake-deployment-complete-guide.md)
- [Terraform Configuration](02-deployment-terraform.md)
- [Database Configuration](09-database-connection-config.md)
- [GitHub Actions CI/CD](03-deployment-github-actions.md)

---

## Support

### Common Commands Reference

```bash
# Quick reference card
make edgequake-help       # Show all EdgeQuake commands
make edgequake-status     # Check service status
make edgequake-logs       # View logs
make edgequake-full       # Full rebuild and deploy

# Debugging
make edgequake-check      # Verify repository paths
docker images | grep edgequake  # List local images
gcloud run services list  # List deployed services
```

### Getting Help

1. Check logs: `make edgequake-logs`
2. Verify status: `make edgequake-status`
3. Review documentation: `make docs`
4. Check GCP Console: Cloud Run and Compute Engine sections

---

**Last Updated:** January 4, 2026  
**Version:** 1.0  
**Tested On:** macOS with Docker Desktop, GCP Project saas-app-001

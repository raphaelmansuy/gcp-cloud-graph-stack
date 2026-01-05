# EdgeQuake Quick Deployment Guide

**Last Updated**: 2026-01-05  
**Target**: GCP Cloud Run (Production)

## One-Line Deploy

```bash
make edgequake-deploy
```

## Prerequisites

```bash
# Authenticate
gcloud auth login
gcloud config set project saas-app-001

# Verify Docker buildx
docker buildx inspect multiarch-builder || docker buildx create --name multiarch-builder --use
```

## Step-by-Step Deploy

### 1. Build Images (Required for code changes)

```bash
# Build API (~20 seconds with cache)
make edgequake-build-api-fast

# Build WebUI (~10 seconds with cache)
make edgequake-build-webui-fast
```

### 2. Deploy to Cloud Run

```bash
# Deploy via Terraform
make edgequake-deploy

# OR manually:
cd terraform
terraform apply
```

### 3. Verify Deployment

```bash
# Check services
gcloud run services list --region=us-central1 | grep edgequake

# Test API
curl https://edgequake-api-wszhkynzxa-uc.a.run.app/health | jq '.storage_mode'
# Should return: "postgresql"

# Test WebUI
open https://edgequake-webui-wszhkynzxa-uc.a.run.app
```

## Configuration Files

### Critical Settings

**terraform/terraform.tfvars**:
```terraform
nextjs_service_name  = "edgequake-webui"
rust_api_service_name = "edgequake-api"
nextjs_image_url = "us-central1-docker.pkg.dev/saas-app-001/edgequake-images/edgequake-webui:latest"
rust_api_image_url = "us-central1-docker.pkg.dev/saas-app-001/edgequake-images/edgequake-api:latest"
```

**terraform/main.tf** (API module):
```terraform
allow_unauthenticated = true  # Required for browser access

environment_variables = {
  "DATABASE_URL" = "postgresql://postgres:postgres@${module.compute.vm_private_ip}:${var.db_port}/graph_db"
  "RUST_LOG"     = "info,edgequake=debug"
}
```

## Architecture

```
┌──────────────┐
│   Browser    │ (Public Internet)
└───────┬──────┘
        │ HTTPS
        ▼
┌──────────────┐     ┌──────────────┐
│    WebUI     │────▶│     API      │ (Public Cloud Run)
│  Cloud Run   │     │  Cloud Run   │
└──────────────┘     └───────┬──────┘
                             │
                             │ VPC Connector
                             │ (Encrypted Tunnel)
                             ▼
                     ┌──────────────┐
                     │  PostgreSQL  │ (Private VM)
                     │  10.0.0.12   │
                     └──────────────┘
```

## Security

- ✅ **WebUI**: Public HTTPS
- ✅ **API**: Public HTTPS (add API keys for production)
- ✅ **Database**: Private VPC only
- ✅ **VPC Connector**: Encrypted Cloud Run → DB tunnel
- ⚠️ **TODO**: Add API key authentication
- ⚠️ **TODO**: Change default PostgreSQL password

## Troubleshooting

### WebUI shows "Connection Error"

```bash
# Check API is public
gcloud run services describe edgequake-api --region=us-central1 \
  --format="get(metadata.annotations.'run.googleapis.com/ingress')"
# Should show: all

# Check API health
curl https://edgequake-api-wszhkynzxa-uc.a.run.app/health
```

### API uses in-memory storage

```bash
# Check DATABASE_URL is set
gcloud run services describe edgequake-api --region=us-central1 \
  --format="value(spec.template.spec.containers[0].env)" | grep DATABASE_URL

# Should show: postgresql://postgres:postgres@10.0.0.12:5432/graph_db
```

### Database not accessible

```bash
# Check PostgreSQL is running
gcloud compute ssh edgequake-db-vm --zone=us-central1-a \
  --command="sudo docker ps | grep postgres"

# Check VPC connector
gcloud compute networks vpc-access connectors describe \
  edgequake-vpc-connector --region=us-central1
```

## URLs

- **WebUI**: https://edgequake-webui-wszhkynzxa-uc.a.run.app
- **API**: https://edgequake-api-wszhkynzxa-uc.a.run.app
- **API Health**: https://edgequake-api-wszhkynzxa-uc.a.run.app/health
- **API Docs**: https://edgequake-api-wszhkynzxa-uc.a.run.app/api/v1/docs

## Costs (Estimated)

- Cloud Run (WebUI): ~$5/month (low traffic)
- Cloud Run (API): ~$10/month (low traffic)
- Compute Engine (Database VM): ~$30/month (e2-standard-2)
- Persistent Disk: ~$5/month (50GB)
- VPC Connector: ~$10/month
- Network Egress: Variable

**Total**: ~$60-80/month for development workload

## Makefile Commands

```bash
# Full lifecycle
make edgequake-deploy          # Build + Deploy
make edgequake-destroy-services # Remove services (keep infra)

# Individual steps
make edgequake-check           # Verify repos exist
make edgequake-build-api-fast  # Build API only
make edgequake-build-webui-fast # Build WebUI only

# Infrastructure
make deploy                    # Deploy all Terraform
make destroy                   # Destroy everything
make verify-db                 # Check database
```

## Support

- **Documentation**: [docs/20-edgequake-database-fix-security.md](20-edgequake-database-fix-security.md)
- **Logs**: `/logs/2026-01-05-11-33-beastmode-database-connection-fix.md`
- **Architecture**: [docs/01-architecture.md](01-architecture.md)

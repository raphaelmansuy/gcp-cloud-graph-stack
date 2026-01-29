# EdgeQuake Deployment - Quick Reference

## 🚀 Deploy Latest Version

The simplest way to deploy the latest EdgeQuake version from the `edgequake-main` branch:

```bash
make edgequake-deploy-latest
```

This single command:
1. Pulls latest code from `edgequake-main` branch
2. Builds Docker images with version tags
3. Deploys to Cloud Run
4. Verifies deployment health

---

## 📋 Common Commands

### Deployment
```bash
# Deploy latest from edgequake-main (RECOMMENDED)
make edgequake-deploy-latest

# Deploy using Terraform
make edgequake-deploy

# Force redeploy current images
make edgequake-redeploy
```

### Build Only
```bash
# Build both API and WebUI (fast, linux/amd64 only)
make edgequake-build-api-fast
make edgequake-build-webui-fast

# Build multi-architecture images (slower)
make edgequake-build
```

### Monitoring
```bash
# Check service status and URLs
make edgequake-status

# View recent logs
make edgequake-logs

# Full system status
make status
```

### Help
```bash
# Show all EdgeQuake commands
make edgequake-help

# Show all Makefile commands
make help
```

---

## 🔍 Check Deployed Version

### Service Labels
```bash
gcloud run services describe edgequake-webui \
  --region=us-central1 \
  --format="value(metadata.labels.version)"

gcloud run services describe edgequake-api \
  --region=us-central1 \
  --format="value(metadata.labels.version)"
```

### Docker Images
```bash
# List all API images
gcloud artifacts docker images list \
  us-central1-docker.pkg.dev/saas-app-001/edgequake-images/edgequake-api

# List all WebUI images
gcloud artifacts docker images list \
  us-central1-docker.pkg.dev/saas-app-001/edgequake-images/edgequake-webui
```

---

## 🔄 Development Workflow

### 1. Make Changes in EdgeQuake Repository
```bash
cd /Users/raphaelmansuy/Github/03-working/edgequake
git checkout edgequake-main
git pull origin edgequake-main

# Make your changes
# ... edit files ...

git add .
git commit -m "feat: your changes"
git push origin edgequake-main
```

### 2. Deploy to Cloud Run
```bash
cd /Users/raphaelmansuy/Github/03-working/gcp-cloud-graph-stack
make edgequake-deploy-latest
```

### 3. Verify Deployment
```bash
# Check status
make edgequake-status

# Test API
curl https://edgequake-api-wszhkynzxa-uc.a.run.app/health

# Open WebUI
open https://edgequake-webui-wszhkynzxa-uc.a.run.app
```

---

## 🔧 Configuration

### Makefile Variables

Located in `/Makefile`:

```makefile
PROJECT_ID := saas-app-001
REGION := us-central1
EDGEQUAKE_REPO := /Users/raphaelmansuy/Github/03-working/edgequake
EDGEQUAKE_BRANCH := edgequake-main
```

### Environment Variables (Optional)

Override defaults:

```bash
export EDGEQUAKE_REPO="/custom/path"
export EDGEQUAKE_BRANCH="feature-branch"
export PROJECT_ID="my-project"
export REGION="europe-west1"
```

---

## 🐛 Troubleshooting

### Issue: "EdgeQuake repository not found"

**Solution**: Update `EDGEQUAKE_REPO` in Makefile or set environment variable:
```bash
export EDGEQUAKE_REPO="/correct/path/to/edgequake"
```

### Issue: "Failed to pull latest changes"

**Solution**: Check git status and resolve conflicts:
```bash
cd /Users/raphaelmansuy/Github/03-working/edgequake
git status
git pull origin edgequake-main
```

### Issue: "Build failed"

**Solution**: Check Docker is running and you have enough disk space:
```bash
docker info
df -h
```

### Issue: "Deployment succeeded but service returns errors"

**Solution**: Check service logs:
```bash
make edgequake-logs

# Or directly
gcloud logging read \
  "resource.type=cloud_run_revision AND resource.labels.service_name=edgequake-api" \
  --limit 50 \
  --format "table(timestamp,severity,textPayload)"
```

### Issue: "Old version still showing"

**Solution**: Cloud Run may have cached the old revision. Force redeploy:
```bash
make edgequake-redeploy
```

---

## 📚 Service URLs

### Production
- **WebUI**: https://edgequake-webui-wszhkynzxa-uc.a.run.app
- **API**: https://edgequake-api-wszhkynzxa-uc.a.run.app
- **API Health**: https://edgequake-api-wszhkynzxa-uc.a.run.app/health

### Internal URLs (VPC)
- **Database**: `postgresql://postgres@10.128.0.2:5432/graph_db`

---

## 🔐 Required Permissions

Your Google Cloud account needs these roles:
- `roles/run.admin` - Deploy Cloud Run services
- `roles/iam.serviceAccountUser` - Use service account
- `roles/artifactregistry.writer` - Push Docker images
- `roles/storage.objectViewer` - Access Terraform state

---

## 📦 Version Tracking

Every deployment creates:

1. **Docker Image Tags**:
   - `:latest` - Always the most recent
   - `:4dc81341` - Git SHA specific version

2. **Cloud Run Labels**:
   - `version=4dc81341` - Git commit hash
   - `deployed-at=20260129-155227` - Timestamp

3. **Git Commit**:
   - Full traceability to source code
   - Can checkout exact version: `git checkout 4dc81341`

---

## 🔄 Rollback

To rollback to a previous version:

### Method 1: Deploy Specific Version
```bash
# Find previous version
gcloud artifacts docker images list \
  us-central1-docker.pkg.dev/saas-app-001/edgequake-images/edgequake-webui

# Deploy specific version
gcloud run deploy edgequake-webui \
  --image us-central1-docker.pkg.dev/saas-app-001/edgequake-images/edgequake-webui:PREVIOUS_SHA \
  --region us-central1
```

### Method 2: Traffic Split
```bash
# Route traffic to previous revision
gcloud run services update-traffic edgequake-webui \
  --to-revisions=edgequake-webui-00005-4r8=100 \
  --region us-central1
```

---

## 💡 Tips

1. **Always deploy from clean state**: Make sure you've committed all changes in EdgeQuake repo
2. **Test locally first**: Use `docker build` locally before deploying
3. **Monitor after deploy**: Watch logs for the first few minutes
4. **Use version tags**: Tag Docker images with meaningful versions
5. **Document changes**: Update commit messages with clear descriptions

---

## 📞 Support

For issues or questions:
1. Check logs: `make edgequake-logs`
2. Review status: `make edgequake-status`
3. Verify configuration: `make edgequake-help`
4. Check deployment log: `/logs/2026-01-29-edgequake-continuous-deployment.md`

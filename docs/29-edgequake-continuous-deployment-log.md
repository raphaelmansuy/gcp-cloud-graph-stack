# EdgeQuake Continuous Deployment Integration

**Date**: 2026-01-29  
**Version**: 4dc81341 (deployed)  
**Objective**: Integrate EdgeQuake repository with automated deployment pipeline that always pulls and deploys the latest version from `edgequake-main` branch

---

## Summary

✅ **EdgeQuake deployment pipeline now automatically pulls the latest code from the `edgequake-main` branch before building and deploying.**

The system ensures that every deployment uses the most recent code, with proper version tracking using git SHA hashes for full traceability.

---

## Changes Implemented

### 1. Makefile Enhancements

**Location**: `/Makefile` (Lines 602-695)

#### Added Configuration Variables:
```makefile
EDGEQUAKE_REPO := /Users/raphaelmansuy/Github/03-working/edgequake
EDGEQUAKE_BRANCH := edgequake-main
EDGEQUAKE_VERSION := $(shell cd $(EDGEQUAKE_REPO) && git rev-parse --short HEAD)
```

#### Enhanced `edgequake-check` Target:
- Now validates repository existence
- Automatically pulls latest changes from `edgequake-main` branch
- Displays current version (git SHA) and commit message
- Gracefully handles git pull failures

#### Updated Build Targets:
- `edgequake-build-api-fast`: Now includes version tagging (`--build-arg BUILD_VERSION`)
- `edgequake-build-webui-fast`: Now includes version tagging
- Both targets tag images with both `:latest` and `:${VERSION}` (git SHA)

#### New Deployment Target:
- `edgequake-deploy-latest`: Single command to pull, build, and deploy latest version

---

### 2. Automated Deployment Script

**Location**: `/scripts/deploy-edgequake-latest.sh`

**Features**:
- Validates EdgeQuake repository exists
- Pulls latest changes from `edgequake-main` branch
- Captures version information (git SHA and commit message)
- Builds both API and WebUI images with version tags
- Deploys to Cloud Run with version labels
- Verifies deployment with health checks
- Provides detailed progress and status output

**Usage**:
```bash
# Direct execution
./scripts/deploy-edgequake-latest.sh

# Via Makefile
make edgequake-deploy-latest
```

---

### 3. Version Tracking

All deployments now include:

1. **Docker Image Tags**:
   - `:latest` - Always points to most recent build
   - `:${GIT_SHA}` - Specific version tag (e.g., `:4dc81341`)

2. **Cloud Run Labels**:
   - `version=${GIT_SHA}` - Git commit hash
   - `deployed-at=${TIMESTAMP}` - Deployment timestamp (YYYYMMDD-HHMMSS)

3. **Traceability**:
   - Each deployment is tied to a specific git commit
   - Easy rollback by deploying a previous version tag
   - Clear audit trail of what was deployed when

---

## Verification

### Deployment Test (2026-01-29 15:52:27)

```bash
./scripts/deploy-edgequake-latest.sh
```

**Results**:
- ✅ Successfully pulled latest from `edgequake-main` (already up-to-date)
- ✅ Built API image (4dc81341) - 297s build time
- ✅ Built WebUI image (4dc81341) - 98s build time
- ✅ Deployed API to Cloud Run (revision: edgequake-api-00027-x2k)
- ✅ Deployed WebUI to Cloud Run (revision: edgequake-webui-00006-rqt)
- ✅ API health check: HTTP 200
- ✅ WebUI health check: HTTP 200

**Service URLs**:
- API: https://edgequake-api-wszhkynzxa-uc.a.run.app
- WebUI: https://edgequake-webui-wszhkynzxa-uc.a.run.app

**Deployed Version**: 4dc81341
**Commit**: "docs: stage and commit all outstanding documentation and OODA changes (batch commit)"

---

## Workflow

### Standard Deployment Process

1. **Developer workflow** (in EdgeQuake repository):
   ```bash
   cd /Users/raphaelmansuy/Github/03-working/edgequake
   git checkout edgequake-main
   # Make changes
   git commit -m "feat: new feature"
   git push origin edgequake-main
   ```

2. **Deployment workflow** (in this repository):
   ```bash
   cd /Users/raphaelmansuy/Github/03-working/gcp-cloud-graph-stack
   make edgequake-deploy-latest
   ```

3. **What happens automatically**:
   - Script pulls latest code from `edgequake-main`
   - Captures version (git SHA): e.g., `4dc81341`
   - Builds Docker images with version tags
   - Pushes to Artifact Registry
   - Deploys to Cloud Run with version labels
   - Verifies deployment health

---

## Key Features

### 1. Always Latest Code
Every build automatically pulls the latest changes from the `edgequake-main` branch, ensuring you're never deploying stale code.

### 2. Version Traceability
Git SHA embedded in:
- Docker image tags
- Cloud Run service labels
- Deployment logs

### 3. Idempotent Operations
Running the deployment script multiple times is safe:
- If already at latest version, it proceeds with current code
- Docker images are rebuilt to ensure consistency
- Cloud Run gracefully handles redeployments

### 4. Rollback Capability
To rollback to a previous version:
```bash
# List available versions
gcloud artifacts docker images list \
  us-central1-docker.pkg.dev/saas-app-001/edgequake-images/edgequake-api

# Deploy specific version
gcloud run deploy edgequake-api \
  --image us-central1-docker.pkg.dev/saas-app-001/edgequake-images/edgequake-api:PREVIOUS_SHA \
  --region us-central1
```

---

## Configuration

### Environment Variables (Optional)

The deployment script respects these environment variables:

```bash
export EDGEQUAKE_REPO="/path/to/edgequake"
export EDGEQUAKE_BRANCH="edgequake-main"  # or feature branch
export PROJECT_ID="saas-app-001"
export REGION="us-central1"
```

### Makefile Variables

Edit `Makefile` to customize:

```makefile
EDGEQUAKE_REPO := /Users/raphaelmansuy/Github/03-working/edgequake
EDGEQUAKE_BRANCH := edgequake-main
PROJECT_ID := saas-app-001
REGION := us-central1
```

---

## Available Commands

### Quick Reference

```bash
# Deploy latest version (RECOMMENDED)
make edgequake-deploy-latest

# Check deployment status
make edgequake-status

# View service logs
make edgequake-logs

# Build only (no deploy)
make edgequake-build-api-fast
make edgequake-build-webui-fast

# Full build (multi-arch)
make edgequake-build

# Help
make edgequake-help
```

---

## Integration with Terraform

The Terraform configuration in `/terraform/` already supports:
- Dynamic image URLs
- Proper service naming
- IAM configuration
- VPC networking

To update infrastructure:
```bash
make edgequake-deploy  # Uses Terraform
```

---

## Lessons Learned

### 1. Separation of Concerns
- EdgeQuake source code lives in its own repository
- Deployment infrastructure (this repo) references it
- Clean separation enables independent development

### 2. Git-Based Versioning
- Using git SHA as version identifier is simple and effective
- No need for complex version management
- Direct traceability to source code

### 3. Health Verification
- Always verify deployment with health checks
- HTTP 200 response confirms service is running
- Catches deployment issues immediately

### 4. Automation Benefits
- Manual steps are error-prone
- Automated pulls prevent "forgot to pull" issues
- Consistent process every time

---

## Next Steps

### Potential Enhancements

1. **CI/CD Integration**
   - Add GitHub Actions workflow to auto-deploy on push to `edgequake-main`
   - Automatic smoke tests after deployment

2. **Blue-Green Deployment**
   - Deploy new version as separate revision
   - Gradually shift traffic from old to new
   - Quick rollback if issues detected

3. **Monitoring**
   - Add Cloud Monitoring alerts
   - Track deployment success/failure rates
   - Performance metrics comparison

4. **Multi-Environment**
   - Support dev/staging/prod environments
   - Environment-specific branches
   - Isolated testing before production

---

## File Changes Summary

### Modified Files
1. `/Makefile` - Enhanced EdgeQuake integration
2. `/scripts/deploy-edgequake-latest.sh` - New automated deployment script

### Integration Points
- EdgeQuake repo: `/Users/raphaelmansuy/Github/03-working/edgequake`
- Branch: `edgequake-main`
- Docker Registry: `us-central1-docker.pkg.dev/saas-app-001/edgequake-images`
- Cloud Run services: `edgequake-api`, `edgequake-webui`

---

## Conclusion

✅ **Successfully integrated EdgeQuake deployment pipeline with automatic version pulling**

The system now ensures that every deployment uses the latest code from the `edgequake-main` branch, with full version tracking and health verification. The deployment process is streamlined into a single command (`make edgequake-deploy-latest`) that handles the entire workflow.

**Current deployed version**: 4dc81341  
**Deployment status**: ✅ Healthy (all services responding)  
**Next deployment**: Will automatically pull latest changes

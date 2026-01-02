# GitHub Actions CI/CD Deployment Guide

## Overview

This guide explains how to use GitHub Actions to automatically build container images and deploy them to Cloud Run. The workflow triggers on every push to `main` or `develop` branches.

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│              GitHub Repository                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ Push to main/develop branch                            │  │
│  │ ├── Checkout code                                      │  │
│  │ ├── Authenticate to GCP (Workload Identity)           │  │
│  │ ├── Build Next.js Docker image                        │  │
│  │ ├── Push to Artifact Registry                         │  │
│  │ ├── Build Rust API Docker image                       │  │
│  │ ├── Push to Artifact Registry                         │  │
│  │ ├── Deploy Next.js to Cloud Run                       │  │
│  │ └── Deploy Rust API to Cloud Run                      │  │
│  └────────────────────────────────────────────────────────┘  │
│                           ↓                                   │
│                      Pull Request                             │
│                    (build only, no deploy)                    │
└──────────────────────────────────────────────────────────────┘
                           ↓
                ┌──────────────────────┐
                │   GCP Project        │
                │  (saas-app-001)      │
                ├──────────────────────┤
                │  Artifact Registry   │
                │  Cloud Run Services  │
                │  (updated)           │
                └──────────────────────┘
```

## Setup

### 1. Create GCP Service Account

```bash
gcloud iam service-accounts create github-actions-deployer \
  --display-name="GitHub Actions Deployer" \
  --project=saas-app-001
```

### 2. Grant IAM Roles

```bash
PROJECT_ID="saas-app-001"
SERVICE_ACCOUNT="github-actions-deployer@${PROJECT_ID}.iam.gserviceaccount.com"

# Roles needed for deployment
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member=serviceAccount:${SERVICE_ACCOUNT} \
  --role=roles/run.admin

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member=serviceAccount:${SERVICE_ACCOUNT} \
  --role=roles/artifactregistry.writer

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member=serviceAccount:${SERVICE_ACCOUNT} \
  --role=roles/iam.serviceAccountUser
```

### 3. Enable Workload Identity Federation

```bash
# Create Workload Identity Provider
gcloud iam workload-identity-pools create github-actions-pool \
  --project=saas-app-001 \
  --location=global \
  --display-name=GitHub

# Get the resource name
POOL_ID=$(gcloud iam workload-identity-pools list \
  --location=global \
  --project=saas-app-001 \
  --format='value(name)' \
  --filter='displayName:GitHub')

# Create Workload Identity Provider for GitHub
gcloud iam workload-identity-pools providers create-oidc github-provider \
  --project=saas-app-001 \
  --location=global \
  --workload-identity-pool=github-actions-pool \
  --display-name=GitHub \
  --attribute-mapping='google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.aud=assertion.aud,attribute.repository=assertion.repository' \
  --issuer-uri=https://token.actions.githubusercontent.com \
  --attribute-condition="assertion.repository == 'YOUR_GITHUB_ORG/gcp-cloud-graph-stack'"
```

### 4. Set Up Service Account Impersonation

```bash
# Allow GitHub Actions to impersonate the service account
gcloud iam service-accounts add-iam-policy-binding ${SERVICE_ACCOUNT} \
  --project=saas-app-001 \
  --role=roles/iam.workloadIdentityUser \
  --member="principalSet://iam.googleapis.com/${POOL_ID}/attribute.repository/YOUR_GITHUB_ORG/gcp-cloud-graph-stack"
```

### 5. Configure GitHub Secrets

Add the following secrets to your GitHub repository settings:

```bash
GCP_PROJECT_ID=saas-app-001
GCP_WORKLOAD_IDENTITY_PROVIDER=projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-actions-pool/providers/github-provider
GCP_SERVICE_ACCOUNT=github-actions-deployer@saas-app-001.iam.gserviceaccount.com
```

To get PROJECT_NUMBER:
```bash
gcloud projects describe saas-app-001 --format='value(projectNumber)'
```

## Workflow File

The workflow is defined in `.github/workflows/deploy.yml`. It:

1. **Builds** containers on every push to main/develop
2. **Pushes** images to Artifact Registry
3. **Deploys** to Cloud Run (only on main branch)

### Workflow Triggers

```yaml
on:
  push:
    branches:
      - main      # Auto-deploy on main
      - develop   # Also build on develop (no deploy)
  pull_request:
    branches:
      - main      # Build and test PRs
```

## Running the Workflow

### Automatic Trigger

Just push to main or create a PR:

```bash
git add .
git commit -m "feat: update API"
git push origin main
```

GitHub Actions automatically triggers the workflow.

### Manual Trigger

In GitHub repository > Actions > "Build and Deploy to Cloud Run" > "Run workflow"

## Monitoring Deployment

### GitHub Actions

View workflow progress:
1. Go to repository > Actions tab
2. Click the latest workflow run
3. Expand "build-and-deploy" job to see detailed steps

### Cloud Run

Verify deployment:

```bash
# Check Next.js service
gcloud run services describe nextjs-frontend \
  --region=us-central1 \
  --platform=managed

# Check Rust API service
gcloud run services describe rust-api \
  --region=us-central1 \
  --platform=managed

# View recent revisions
gcloud run revisions list \
  --region=us-central1 \
  --platform=managed
```

### Logs

```bash
# Cloud Run logs
gcloud logging read "resource.type=cloud_run_revision" \
  --limit 50 \
  --format json

# Filter by service
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=nextjs-frontend" \
  --limit 20
```

## Rollback

To rollback to a previous revision:

```bash
# List revisions
gcloud run revisions list --service=nextjs-frontend --region=us-central1

# Route traffic to a previous revision
gcloud run services update-traffic nextjs-frontend \
  --region=us-central1 \
  --to-revisions=REVISION_NAME=100
```

Or manually revert your git commit and push:

```bash
git revert <commit-hash>
git push origin main
```

## Testing Locally

### Build and Test Locally

```bash
# Build Next.js
docker build -t nextjs:dev -f dockerfiles/Dockerfile.nextjs .
docker run -p 3000:8080 nextjs:dev

# Build Rust API
docker build -t rust-api:dev -f dockerfiles/Dockerfile.rust .
docker run -p 8080:8080 rust-api:dev
```

### Run Workflow Locally (Optional)

Use [Act](https://github.com/nektos/act) to test locally:

```bash
act push -j build-and-deploy
```

## CI/CD Best Practices

### Branch Protection

Set up branch protection rules in GitHub:
1. Require status checks to pass before merge
2. Require code review before merge
3. Require branches to be up to date before merge

### Secrets Management

- Never commit `.env` files or secrets
- Use GitHub Secrets for all sensitive data
- Rotate credentials regularly

### Deployment Stages

Add additional workflows for staging:

```yaml
name: Deploy to Staging
on:
  push:
    branches: [develop]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      # ... same steps, but deploy to staging service
```

## Troubleshooting

### Workflow fails on authentication

**Error**: `google.auth.exceptions.DefaultCredentialsError`

**Solution**:
1. Verify GCP_WORKLOAD_IDENTITY_PROVIDER and GCP_SERVICE_ACCOUNT secrets
2. Ensure service account has correct IAM roles
3. Check Workload Identity Pool configuration

### Cloud Run deployment times out

**Error**: `ERROR: (gcloud.run.deploy) Cloud Run error: Build has failed`

**Solution**:
1. Check Docker image builds locally: `docker build -f dockerfiles/Dockerfile.nextjs .`
2. Verify base image is available
3. Check available disk space in Cloud Build

### Images not pushed to Artifact Registry

**Error**: `unauthorized: You don't have the needed permissions to perform this operation`

**Solution**:
1. Verify service account has `roles/artifactregistry.writer`
2. Ensure Artifact Registry repository exists: `gcloud artifacts repositories create edgequake-images --location=us-central1 --repository-format=docker`
3. Check Docker authentication: `gcloud auth configure-docker us-central1-docker.pkg.dev`

## References

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [GCP Workload Identity Federation](https://docs.cloud.google.com/iam/docs/workload-identity-federation)
- [Cloud Run Deployment Guide](https://docs.cloud.google.com/run/docs)
- [GitHub Actions for Google Cloud](https://github.com/google-github-actions)

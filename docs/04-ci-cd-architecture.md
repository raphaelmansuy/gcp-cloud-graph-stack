# CI/CD and Deployment Architecture

## End-to-End Deployment Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    Developer Workflow                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  1. Local Development                                            │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Developer edits code and commits                        │   │
│  │ $ git add .                                             │   │
│  │ $ git commit -m "feat: update API"                      │   │
│  │ $ git push origin main                                  │   │
│  └─────────────────────────────────────────────────────────┘   │
│                           ↓                                      │
│  2. GitHub Events                                               │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ GitHub detects push to main                             │   │
│  │ Triggers .github/workflows/deploy.yml                   │   │
│  └─────────────────────────────────────────────────────────┘   │
│                           ↓                                      │
│  3. GitHub Actions Execution                                    │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ ├── Checkout code                                       │   │
│  │ ├── Authenticate to GCP via Workload Identity          │   │
│  │ ├── Configure Docker for Artifact Registry             │   │
│  │ ├── Build Next.js Docker image                         │   │
│  │ ├── Build Rust API Docker image                        │   │
│  │ └── Push both images to Artifact Registry              │   │
│  └─────────────────────────────────────────────────────────┘   │
│                           ↓                                      │
└─────────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────────┐
│                    GCP Project (saas-app-001)                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  4. Image Registry                                              │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Artifact Registry (us-central1)                         │   │
│  │ ├── nextjs:latest                                       │   │
│  │ ├── nextjs:abc1234                                      │   │
│  │ ├── rust-api:latest                                     │   │
│  │ └── rust-api:abc1234                                    │   │
│  └─────────────────────────────────────────────────────────┘   │
│                           ↓                                      │
│  5. Deployment (on main branch only)                            │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ GitHub Actions deploys to Cloud Run:                    │   │
│  │                                                          │   │
│  │ gcloud run deploy nextjs-frontend \                     │   │
│  │   --image=us-central1-docker.pkg.dev/...               │   │
│  │   --region=us-central1                                  │   │
│  │                                                          │   │
│  │ gcloud run deploy rust-api \                            │   │
│  │   --image=us-central1-docker.pkg.dev/...               │   │
│  │   --region=us-central1                                  │   │
│  └─────────────────────────────────────────────────────────┘   │
│                           ↓                                      │
│  6. Running Services                                            │
│  ┌──────────────────┐          ┌──────────────────┐            │
│  │   Cloud Run      │          │   Cloud Run      │            │
│  │ nextjs-frontend  │◄────────►│  rust-api        │            │
│  │   (public)       │ Private  │  (authenticated) │            │
│  │                  │  VPC     │                  │            │
│  └────────┬─────────┘          └────────┬─────────┘            │
│           │                             │                       │
│           │            ┌────────────────┤                       │
│           │            │                │                       │
│           │            ↓                ↓                       │
│           │   ┌────────────────────┐                            │
│           │   │ PostgreSQL 16      │                            │
│           │   │ (Compute Engine VM)│                            │
│           │   │ ├── AGE (graphs)    │                            │
│           │   │ └── pgvector (vecs) │                            │
│           └──►└────────────────────┘                            │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

## Deployment Path: Terraform vs GitHub Actions

### Option 1: Terraform (Infrastructure) + GitHub Actions (CI/CD)

**Best for**: Full control, multi-environment setups, IaC best practices

**Flow**:
1. Use Terraform to provision infrastructure (VPC, VM, Cloud Run services)
2. Use GitHub Actions to build and deploy container images
3. Terraform manages infrastructure state in remote backend (GCS)

**Pros**:
- Complete IaC coverage
- Separate infrastructure and application concerns
- Repeatable deployments
- State management with Terraform

**Cons**:
- More moving parts
- Requires Terraform state backend setup

### Option 2: Cloud Build Only

**Best for**: Simple builds directly from source control

**Flow**:
1. Push to GitHub → Cloud Build trigger
2. Cloud Build builds images, pushes to Artifact Registry
3. Cloud Build can trigger Terraform apply or gcloud deploy

**Pros**:
- Native GCP integration
- Single configuration file (cloudbuild.yaml)
- Can deploy directly to Cloud Run

**Cons**:
- Less flexible for complex workflows
- Requires Cloud Build API and permissions setup

## Using Both Terraform and GitHub Actions (Recommended)

```
STEP 1: Infrastructure (One-time)
┌──────────────────────────────┐
│ Terraform (terraform/)       │
│ ├── VPC/Networking           │
│ ├── Compute Engine VM        │
│ ├── Cloud Run Services       │
│ └── IAM & Service Accounts   │
└──────────────────────────────┘
                ↓
         Run once or when infra changes:
         $ terraform apply

STEP 2: Application (Continuous)
┌──────────────────────────────┐
│ GitHub Actions (.github/)    │
│ ├── Build Docker images      │
│ ├── Push to Artifact Registry│
│ └── Deploy to Cloud Run      │
└──────────────────────────────┘
                ↓
         Run on every commit:
         $ git push origin main
```

## Configuration Parameters

All parameters are centralized in one place for easy updates:

### Terraform Variables (terraform/terraform.tfvars)

```hcl
project_id = "saas-app-001"
region      = "us-central1"
environment = "dev"
app_name    = "edgequake"

vpc_cidr                    = "10.0.0.0/16"
db_vm_machine_type          = "e2-standard-2"
cloud_run_memory            = "512Mi"
cloud_run_cpu               = "0.25"
enable_direct_vpc_egress    = true
enable_wal_archiving        = true
gcs_backup_bucket           = "saas-app-001-db-backups"
```

### GitHub Actions Secrets (GitHub Settings → Secrets and variables)

```
GCP_PROJECT_ID = saas-app-001
GCP_REGION = us-central1
GCP_WORKLOAD_IDENTITY_PROVIDER = projects/XXX/locations/global/...
GCP_SERVICE_ACCOUNT = github-actions-deployer@saas-app-001.iam.gserviceaccount.com
```

### Environment Variables in Cloud Run

Set via Terraform modules/cloud_run/main.tf:

```hcl
environment_variables = {
  "NODE_ENV"      = "production"
  "DATABASE_HOST" = "10.0.0.2"
  "DATABASE_PORT" = "5432"
  "API_URL"       = "https://rust-api-xxx.run.app"
}
```

## Multi-Environment Setup

To manage dev, staging, prod:

### Terraform Workspaces

```bash
# Create workspaces
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod

# Select workspace
terraform workspace select dev

# Apply with workspace-specific variables
terraform apply -var-file=tfvars/dev.tfvars
```

### GitHub Actions Environments

```yaml
jobs:
  deploy:
    environment: production  # Only deploy to prod on main
    if: github.ref == 'refs/heads/main'
    # ...
```

## Monitoring and Observability

### Cloud Monitoring Dashboards

```bash
gcloud monitoring dashboards create --config-from-file=monitoring-dashboard.json
```

### Logging

All logs are centralized in Cloud Logging:

```bash
gcloud logging read "resource.type=cloud_run_revision" --limit 50
gcloud logging read "resource.type=gce_instance" --limit 50
```

### Alerts

Configure alerts for:
- Cloud Run service errors (>10 in 5 min)
- VM CPU usage (>80%)
- Database connections (>80)
- Disk usage (>80%)

## Rollback Procedure

### Quick Rollback (No Code Changes)

```bash
# Cloud Run
gcloud run services update-traffic nextjs-frontend \
  --to-revisions=PREVIOUS_REVISION_NAME=100 \
  --region=us-central1

# VM database
# Restore from WAL archive or base backup
pg_restore -d graph_db /path/to/backup
```

### Code Rollback

```bash
# Revert Git commit
git revert <commit-hash>
git push origin main

# GitHub Actions automatically re-runs on new commit
# Deploys previous stable version
```

## Security Best Practices

### Secrets Management

- Use Google Secret Manager for database credentials
- Pass secrets to Cloud Run via environment variables
- Never commit secrets to Git

### IAM Least Privilege

Service accounts configured with minimal required permissions:
- `github-actions-deployer`: Only `run.admin` and `artifactregistry.writer`
- `cloud-run-sa`: Only `secretmanager.secretAccessor`
- `vm-sa`: Only `logging.logWriter` and GCS bucket writer

### Network Security

- Cloud Run services communicate via Private VPC only
- Direct VPC egress (no public internet)
- Firewall rules restrict DB access to 10.0.0.0/24

### Image Security

- Scan images for vulnerabilities via On-Demand Scanning
- Use specific tags, not `latest` in production
- Sign images with Binary Authorization (optional)

## Cost Optimization

### Estimated Monthly Costs

| Component | Cost | Notes |
|-----------|------|-------|
| Compute Engine VM | $30-50 | e2-standard-2 on-demand |
| Cloud Run Next.js | $3-10 | Pay-per-use, ~500k sec usage |
| Cloud Run Rust API | $3-10 | Pay-per-use, ~500k sec usage |
| Artifact Registry | $0.10/GB | First 0.5GB free |
| Secrets Manager | $0.06/month | Free for <6 secrets |
| Cloud Build | $0.01/min | ~10-20 min per build |
| **Total** | **$40-100** | Development/low-traffic |

### Cost Reduction Tips

- Use Spot VMs for dev environments (70% discount)
- Set Cloud Run min instances to 0 (scale to zero)
- Use smaller machine types (e2-medium instead of e2-standard-2)
- Archive old logs to Cloud Storage after 90 days

## References

- [Terraform Google Provider Documentation](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [GCP Workload Identity Federation](https://docs.cloud.google.com/iam/docs/workload-identity-federation)
- [Cloud Run Best Practices](https://docs.cloud.google.com/run/docs/configuring/container-runtimes)
- [Cloud Build Documentation](https://docs.cloud.google.com/build/docs)

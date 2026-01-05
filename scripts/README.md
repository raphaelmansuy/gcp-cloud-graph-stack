# EdgeQuake Deployment Scripts

This directory contains automation scripts for deploying and testing EdgeQuake.

## Scripts

### `deploy.sh` - Complete Deployment Automation

Automates the full EdgeQuake deployment process.

**Usage:**
```bash
./scripts/deploy.sh
```

**What it does:**
1. Checks prerequisites (gcloud, docker, terraform)
2. Verifies authentication
3. Builds API and WebUI Docker images
4. Deploys infrastructure with Terraform
5. Runs comprehensive test suite
6. Displays service URLs

**Prerequisites:**
- gcloud CLI installed and authenticated
- Docker installed with buildx support
- Terraform installed
- (Optional) OPENAI_API_KEY set: `export TF_VAR_openai_api_key="sk-..."`

---

### `test-deployment.sh` - Comprehensive Test Suite

Validates all components of the EdgeQuake deployment.

**Usage:**
```bash
./scripts/test-deployment.sh
```

**Test Categories:**
1. **Cloud Run Services** - Validates service URLs
2. **API Health Checks** - Tests API endpoints and status
3. **API Endpoints** - Tests document management
4. **WebUI Tests** - Tests web interface accessibility
5. **CORS Tests** - Validates cross-origin requests
6. **Database Connection** - Tests PostgreSQL connectivity
7. **Infrastructure Tests** - Validates VPC, IAM policies
8. **Security Tests** - Checks database security and disk protection

**Exit Codes:**
- `0` - All tests passed
- `1` - One or more tests failed

**Output:**
- Color-coded results (GREEN=pass, RED=fail, YELLOW=warning)
- Summary of failures and warnings
- Can be used in CI/CD pipelines

---

### `db-tunnel.sh` - Database Access Tunnel

Creates an SSH tunnel to the PostgreSQL database.

**Usage:**
```bash
./scripts/db-tunnel.sh
```

Connects to database at `localhost:5433`

---

### `bootstrap-backend.sh` - Backend Initialization

Initializes the Rust API backend.

**Usage:**
```bash
./scripts/bootstrap-backend.sh
```

---

### `secure-ssh-access.sh` - SSH Security Configuration

Configures secure SSH access to the database VM.

**Usage:**
```bash
./scripts/secure-ssh-access.sh
```

---

## Quick Start

### First Time Deployment

```bash
# 1. Set your OpenAI API key (optional but recommended)
export TF_VAR_openai_api_key="sk-your-key-here"

# 2. Run the deployment script
./scripts/deploy.sh
```

### Subsequent Deployments

```bash
# Rebuild and deploy
make edgequake-deploy

# Or use the deployment script
./scripts/deploy.sh
```

### Testing

```bash
# Run comprehensive tests
./scripts/test-deployment.sh

# View test results with color
./scripts/test-deployment.sh | less -R
```

---

## Environment Variables

### Required

None - all scripts work with defaults

### Optional

| Variable | Purpose | Example |
|----------|---------|---------|
| `TF_VAR_openai_api_key` | OpenAI API key for LLM features | `export TF_VAR_openai_api_key="sk-..."` |

---

## Service URLs

After deployment, scripts will display:

- **API**: https://edgequake-api-wszhkynzxa-uc.a.run.app
- **WebUI**: https://edgequake-webui-wszhkynzxa-uc.a.run.app

---

## Troubleshooting

### Tests Fail

1. Check service status:
```bash
gcloud run services list --region=us-central1
```

2. View logs:
```bash
gcloud run services logs read edgequake-api --region=us-central1 --limit=50
gcloud run services logs read edgequake-webui --region=us-central1 --limit=50
```

3. Verify database:
```bash
gcloud compute ssh edgequake-db-vm --zone=us-central1-a --command="sudo docker ps"
```

### WebUI Shows "Connection Error"

1. Verify API URL in WebUI build:
```bash
gcloud run services describe edgequake-webui --region=us-central1 --format='value(spec.template.spec.containers[0].env)'
```

2. Rebuild WebUI with correct URL:
```bash
make edgequake-build-webui-fast
cd terraform && terraform apply
```

### Database Connection Issues

1. Check VPC connector:
```bash
gcloud compute networks vpc-access connectors describe edgequake-vpc-connector --region=us-central1
```

2. Test database connectivity:
```bash
./scripts/db-tunnel.sh
psql -h localhost -p 5433 -U postgres -d graph_db
```

---

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Test Deployment
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Setup gcloud
        uses: google-github-actions/setup-gcloud@v0
        with:
          service_account_key: ${{ secrets.GCP_SA_KEY }}
      - name: Run tests
        run: ./scripts/test-deployment.sh
```

---

## Support

For issues or questions:
1. Check the main [README.md](../README.md)
2. View deployment logs in `logs/`
3. Review documentation in `docs/`

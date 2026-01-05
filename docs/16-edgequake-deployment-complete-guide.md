# EdgeQuake Deployment: Complete Territory Map & Strategy

**Last Updated:** January 4, 2026  
**Status:** Production Ready

## Table of Contents

1. [Territory Map](#territory-map)
2. [Architecture Overview](#architecture-overview)
3. [Deployment Strategies](#deployment-strategies)
4. [Quick Start](#quick-start)
5. [Alternative Approaches](#alternative-approaches)
6. [Configuration Reference](#configuration-reference)
7. [Troubleshooting](#troubleshooting)

---

## Territory Map

### Repository Structure

```
📁 Repositories Organization
│
├── 📦 gcp-cloud-graph-stack (Infrastructure Repo) ← YOU ARE HERE
│   ├── terraform/                    # Infrastructure as Code
│   │   ├── main.tf                   # Root Terraform config
│   │   ├── modules/
│   │   │   ├── vpc/                  # Network configuration
│   │   │   ├── compute/              # PostgreSQL VM
│   │   │   ├── cloud_run/            # Cloud Run services
│   │   │   └── artifact_registry/    # Container registry
│   │   ├── terraform.tfvars          # Configuration values
│   │   └── variables.tf              # Variable definitions
│   ├── dockerfiles/                  # Docker build configs
│   │   ├── Dockerfile.nextjs         # Next.js frontend
│   │   └── Dockerfile.rust           # Rust API backend
│   ├── Makefile                      # Build automation
│   ├── .github/workflows/            # CI/CD pipelines
│   └── docs/                         # Documentation
│
└── 📦 edgequake (Application Repo)
    ├── edgequake/                    # Rust API Backend
    │   ├── Cargo.toml                # Rust dependencies
    │   ├── src/main.rs               # API server entrypoint
    │   ├── crates/                   # Modular architecture
    │   │   ├── edgequake-api/        # REST API layer
    │   │   ├── edgequake-core/       # Core types
    │   │   ├── edgequake-storage/    # PostgreSQL + pgvector + AGE
    │   │   ├── edgequake-llm/        # LLM integrations
    │   │   ├── edgequake-pipeline/   # Document processing
    │   │   └── edgequake-query/      # Query engine
    │   └── docker/
    │       ├── Dockerfile            # Production build
    │       └── Dockerfile.postgres   # Local dev PostgreSQL
    │
    └── edgequake_webui/              # Next.js Frontend
        ├── package.json              # Node dependencies
        ├── src/app/                  # Next.js App Router
        │   ├── (dashboard)/
        │   │   ├── graph/            # Knowledge graph viewer
        │   │   ├── documents/        # Document management
        │   │   ├── query/            # Query interface
        │   │   └── api-explorer/     # API testing
        │   └── api/                  # API proxy routes
        ├── src/components/           # React components
        └── src/lib/                  # Utilities & API client
```

### Technology Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Frontend** | Next.js 16 + React 19 + Tailwind CSS | Web UI with knowledge graph visualization |
| **Backend** | Rust (Axum framework) | High-performance RAG API |
| **Database** | PostgreSQL 16 + AGE + pgvector | Graph database with vector embeddings |
| **Infrastructure** | Terraform + GCP | Infrastructure as Code |
| **Container Registry** | Artifact Registry | Docker image storage |
| **Compute** | Cloud Run (serverless) | Application hosting |
| **Database Host** | Compute Engine VM | PostgreSQL instance |
| **Networking** | VPC + VPC Connector | Private connectivity |

---

## Architecture Overview

### Runtime Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Internet Users                           │
└────────────────────┬────────────────────────────────────────────┘
                     │ HTTPS
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Google Cloud Platform                       │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              Cloud Run (Serverless)                       │  │
│  │                                                            │  │
│  │  ┌─────────────────────┐    ┌───────────────────────┐   │  │
│  │  │  edgequake_webui    │───▶│   edgequake API      │   │  │
│  │  │  (Next.js Frontend) │    │   (Rust Backend)     │   │  │
│  │  │  Port: 3000         │    │   Port: 8080         │   │  │
│  │  │  Env: API_URL       │    │   Env: DATABASE_*    │   │  │
│  │  └─────────────────────┘    └──────────┬────────────┘   │  │
│  └──────────────────────────────────────────┼───────────────┘  │
│                                              │                   │
│                                              │ VPC Connector     │
│                                              │ (Private)         │
│  ┌──────────────────────────────────────────▼───────────────┐  │
│  │           VPC Network (10.8.0.0/28)                       │  │
│  │                                                            │  │
│  │  ┌─────────────────────────────────────────────────────┐ │  │
│  │  │  Compute Engine VM (edgequake-db-vm)                │ │  │
│  │  │                                                       │ │  │
│  │  │  ┌─────────────────────────────────────────────┐   │ │  │
│  │  │  │  PostgreSQL 16 (Docker)                     │   │ │  │
│  │  │  │  - Database: graph_db                       │   │ │  │
│  │  │  │  - Extensions: AGE, pgvector                │   │ │  │
│  │  │  │  - Port: 5432 (private)                     │   │ │  │
│  │  │  │  - SSL: Enabled                             │   │ │  │
│  │  │  └─────────────────────────────────────────────┘   │ │  │
│  │  │                                                       │ │  │
│  │  │  ┌─────────────────────────────────────────────┐   │ │  │
│  │  │  │  Persistent Disk (/mnt/data)                │   │ │  │
│  │  │  │  - Size: 50GB                               │   │ │  │
│  │  │  │  - Type: pd-standard                        │   │ │  │
│  │  │  │  - Snapshots: Daily (3-day retention)       │   │ │  │
│  │  │  └─────────────────────────────────────────────┘   │ │  │
│  │  └─────────────────────────────────────────────────────┘ │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │         Artifact Registry (Container Images)              │  │
│  │  - edgequake-images/edgequake-api:latest                 │  │
│  │  - edgequake-images/edgequake-webui:latest               │  │
│  └──────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────┘
```

### Data Flow

1. **User Request** → Next.js Frontend (Cloud Run)
2. **Frontend** → Rust API (Cloud Run) via HTTPS
3. **Rust API** → PostgreSQL (VM) via VPC Connector (private network)
4. **PostgreSQL** processes query using:
   - **AGE extension** for graph traversal
   - **pgvector extension** for vector similarity search
5. **Response** flows back through the chain

---

## Deployment Strategies

### Strategy 1: Direct Build (Quick Start) ⚡

**Best for:** Immediate deployment, local development

**Architecture:**
```
[edgequake repo] ──build──▶ [Docker Images] ──push──▶ [Artifact Registry]
                                                              │
                                                              ▼
                                            [terraform apply] deploys to Cloud Run
```

**Steps:**
1. Build images from edgequake repo
2. Push to Artifact Registry
3. Update Terraform variables with image URLs
4. Deploy infrastructure

**Pros:**
- ✅ Simple and straightforward
- ✅ Works immediately
- ✅ Full control over build process

**Cons:**
- ❌ Manual coordination between repos
- ❌ No automated CI/CD

---

### Strategy 2: Git Submodules (Integrated) 🔗

**Best for:** Unified development, single-repo deployment

**Architecture:**
```
[infrastructure repo]
  └── submodules/
      └── edgequake/ (git submodule)
          ├── edgequake/
          └── edgequake_webui/
```

**Steps:**
1. Add edgequake as git submodule
2. Build from submodule paths
3. Automated CI/CD in infrastructure repo

**Pros:**
- ✅ Version-locked dependencies
- ✅ Single deployment trigger
- ✅ Unified CI/CD

**Cons:**
- ❌ Submodule management complexity
- ❌ Requires git submodule knowledge

---

### Strategy 3: Separate CI/CD (Production) 🚀

**Best for:** Production, team collaboration, microservices

**Architecture:**
```
[edgequake repo] ──CI──▶ [Build & Push Images] ──dispatch──▶ [infrastructure repo]
                                                                      │
                                                                      ▼
                                                          [Terraform Deploy]
```

**Flow:**
1. **Edgequake Repo:**
   - Commits trigger GitHub Actions
   - Builds Docker images
   - Pushes to Artifact Registry
   - Sends `repository_dispatch` event to infrastructure repo

2. **Infrastructure Repo:**
   - Receives dispatch event with image URLs
   - Runs Terraform with new image URLs
   - Deploys updated services to Cloud Run

**Pros:**
- ✅ Full separation of concerns
- ✅ Independent versioning
- ✅ Scalable for teams
- ✅ Production-ready

**Cons:**
- ❌ More complex setup
- ❌ Requires GitHub Actions configuration

---

## Quick Start

### Prerequisites

```bash
# Required tools
brew install terraform gcloud docker

# GCP Authentication
gcloud auth login
gcloud config set project saas-app-001
gcloud auth configure-docker us-central1-docker.pkg.dev
```

### Option 1: Direct Build (Fastest)

#### Step 1: Create Dockerfiles

Create optimized Dockerfiles in infrastructure repo that reference edgequake code:

```bash
# Create Dockerfile for edgequake API
cat > dockerfiles/Dockerfile.edgequake-api <<'EOF'
# See full Dockerfile below
EOF

# Create Dockerfile for edgequake WebUI
cat > dockerfiles/Dockerfile.edgequake-webui <<'EOF'
# See full Dockerfile below
EOF
```

#### Step 2: Build Images

```bash
# Build edgequake API
docker build \
  -f dockerfiles/Dockerfile.edgequake-api \
  -t us-central1-docker.pkg.dev/saas-app-001/edgequake-images/edgequake-api:latest \
  /Users/raphaelmansuy/Github/03-working/edgequake/edgequake

# Build edgequake WebUI
docker build \
  -f dockerfiles/Dockerfile.edgequake-webui \
  -t us-central1-docker.pkg.dev/saas-app-001/edgequake-images/edgequake-webui:latest \
  /Users/raphaelmansuy/Github/03-working/edgequake/edgequake_webui
```

#### Step 3: Push Images

```bash
docker push us-central1-docker.pkg.dev/saas-app-001/edgequake-images/edgequake-api:latest
docker push us-central1-docker.pkg.dev/saas-app-001/edgequake-images/edgequake-webui:latest
```

#### Step 4: Configure Terraform

```bash
cd terraform

# Update terraform.tfvars
cat >> terraform.tfvars <<EOF
# EdgeQuake Image URLs
rust_api_image_url  = "us-central1-docker.pkg.dev/saas-app-001/edgequake-images/edgequake-api:latest"
nextjs_image_url    = "us-central1-docker.pkg.dev/saas-app-001/edgequake-images/edgequake-webui:latest"

# Service Names
rust_api_service_name  = "edgequake-api"
nextjs_service_name    = "edgequake-webui"
EOF
```

#### Step 5: Deploy

```bash
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

#### Step 6: Get URLs

```bash
# Get deployed service URLs
echo "EdgeQuake API:"
gcloud run services describe edgequake-api \
  --region us-central1 \
  --format='value(status.url)'

echo "EdgeQuake WebUI:"
gcloud run services describe edgequake-webui \
  --region us-central1 \
  --format='value(status.url)'
```

---

## Alternative Approaches

### Using Makefile Automation

Add these targets to the existing Makefile:

```makefile
# EdgeQuake specific targets
EDGEQUAKE_REPO := /Users/raphaelmansuy/Github/03-working/edgequake

.PHONY: edgequake-build edgequake-push edgequake-deploy

edgequake-build:
	@echo "🔨 Building EdgeQuake images..."
	docker build \
		-f dockerfiles/Dockerfile.edgequake-api \
		-t ${REGISTRY}/edgequake-images/edgequake-api:latest \
		${EDGEQUAKE_REPO}/edgequake
	docker build \
		-f dockerfiles/Dockerfile.edgequake-webui \
		-t ${REGISTRY}/edgequake-images/edgequake-webui:latest \
		${EDGEQUAKE_REPO}/edgequake_webui

edgequake-push: edgequake-build
	@echo "📤 Pushing EdgeQuake images..."
	docker push ${REGISTRY}/edgequake-images/edgequake-api:latest
	docker push ${REGISTRY}/edgequake-images/edgequake-webui:latest

edgequake-deploy: edgequake-push
	@echo "🚀 Deploying EdgeQuake to Cloud Run..."
	cd terraform && terraform apply -auto-approve

edgequake-full: edgequake-deploy
	@echo "✅ EdgeQuake deployment complete!"
	@$(MAKE) edgequake-status

edgequake-status:
	@echo "📊 EdgeQuake Service Status:"
	@echo ""
	@echo "API URL:"
	@gcloud run services describe edgequake-api --region ${REGION} --format='value(status.url)' 2>/dev/null || echo "Not deployed"
	@echo ""
	@echo "WebUI URL:"
	@gcloud run services describe edgequake-webui --region ${REGION} --format='value(status.url)' 2>/dev/null || echo "Not deployed"
```

Usage:
```bash
make edgequake-full     # Build, push, and deploy
make edgequake-build    # Build images only
make edgequake-push     # Build and push
make edgequake-status   # Check deployment status
```

---

## Configuration Reference

### Environment Variables

#### EdgeQuake API (Rust Backend)

| Variable | Description | Source | Example |
|----------|-------------|--------|---------|
| `HOST` | Server bind address | Default | `0.0.0.0` |
| `PORT` | Server port | Cloud Run | `8080` |
| `DATABASE_HOST` | PostgreSQL VM private IP | Terraform | `10.8.0.2` |
| `DATABASE_PORT` | PostgreSQL port | Terraform | `5432` |
| `DATABASE_NAME` | Database name | Terraform | `graph_db` |
| `OPENAI_API_KEY` | OpenAI API key | Secret Manager | `sk-...` |

**Injected by Terraform:**
```hcl
environment_variables = {
  "DATABASE_HOST" = module.compute.db_internal_ip
  "DATABASE_PORT" = var.db_port
  "DATABASE_NAME" = "graph_db"
}
```

#### EdgeQuake WebUI (Next.js Frontend)

| Variable | Description | Source | Example |
|----------|-------------|--------|---------|
| `PORT` | Server port | Cloud Run | `3000` |
| `NODE_ENV` | Environment | Terraform | `production` |
| `NEXT_PUBLIC_API_URL` | Rust API URL | Terraform | `https://edgequake-api-xxx.run.app` |
| `API_URL` | Backend API URL (SSR) | Terraform | `https://edgequake-api-xxx.run.app` |

**Injected by Terraform:**
```hcl
environment_variables = {
  "NODE_ENV"            = var.environment
  "API_URL"             = module.cloud_run_rust_api.service_uri
  "NEXT_PUBLIC_API_URL" = module.cloud_run_rust_api.service_uri
}
```

### PostgreSQL Configuration

**Automatic Setup via Terraform:**
- Database: `graph_db`
- Extensions: `age`, `pgvector`
- Port: `5432` (private)
- SSL: Enabled with self-signed certificate
- User: `postgres` (no password, VM-only access)

**Connection String (from Rust API):**
```
postgresql://postgres@<VM_PRIVATE_IP>:5432/graph_db?sslmode=require
```

---

## Troubleshooting

### Build Issues

#### Error: Cannot find edgequake source code
```bash
# Verify path exists
ls -la /Users/raphaelmansuy/Github/03-working/edgequake/edgequake
ls -la /Users/raphaelmansuy/Github/03-working/edgequake/edgequake_webui

# Update EDGEQUAKE_REPO in Makefile if needed
```

#### Error: Docker build fails with permission denied
```bash
# Fix Docker socket permissions
sudo chmod 666 /var/run/docker.sock

# Or use Docker Desktop
```

### Deployment Issues

#### Error: Image not found in Artifact Registry
```bash
# Verify image exists
gcloud artifacts docker images list \
  us-central1-docker.pkg.dev/saas-app-001/edgequake-images

# Re-push if needed
make edgequake-push
```

#### Error: Cloud Run service fails to start
```bash
# Check logs
gcloud logging read \
  "resource.type=cloud_run_revision AND resource.labels.service_name=edgequake-api" \
  --limit 50 \
  --format json

# Common issues:
# 1. Missing environment variables
# 2. Database connection failure
# 3. Port mismatch (must listen on PORT env var)
```

### Database Connection Issues

#### Error: Connection refused from Rust API
```bash
# 1. Verify VPC connector
gcloud compute networks vpc-access connectors describe edgequake-vpc-connector \
  --region us-central1

# 2. Check firewall rules
gcloud compute firewall-rules list --filter="name~cloud-run"

# 3. Verify PostgreSQL is running
gcloud compute ssh edgequake-db-vm --zone=us-central1-a \
  --command="docker ps | grep postgres"

# 4. Test connection from VM
gcloud compute ssh edgequake-db-vm --zone=us-central1-a \
  --command="docker exec postgres psql -U postgres -d graph_db -c 'SELECT version();'"
```

#### Error: SSL certificate verification failed
```rust
// Update connection string in Rust code
// Development: disable SSL verification
"postgresql://postgres@host:5432/graph_db?sslmode=disable"

// Production: require SSL but skip verification
"postgresql://postgres@host:5432/graph_db?sslmode=require"
```

### Frontend Issues

#### Error: API URL not reachable from frontend
```bash
# 1. Verify Rust API is deployed
gcloud run services describe edgequake-api --region us-central1

# 2. Check environment variable
gcloud run services describe edgequake-webui --region us-central1 \
  --format='value(spec.template.spec.containers[0].env)'

# 3. Test API health endpoint
curl https://$(gcloud run services describe edgequake-api \
  --region us-central1 --format='value(status.url)')/health
```

---

## Cost Estimates

### Monthly Costs (Development)

| Resource | Configuration | Estimated Cost |
|----------|--------------|----------------|
| Cloud Run (API) | 512Mi RAM, 0.25 CPU, minimal traffic | $5-10 |
| Cloud Run (WebUI) | 512Mi RAM, 0.25 CPU, minimal traffic | $5-10 |
| Compute Engine VM | e2-standard-2 (2 vCPU, 8GB RAM) | $50-60 |
| Persistent Disk | 50GB pd-standard | $2 |
| VPC Connector | Serverless VPC Access | $10-15 |
| Artifact Registry | < 1GB storage | $0.10 |
| **Total** | | **~$75-100/month** |

### Monthly Costs (Production)

| Resource | Configuration | Estimated Cost |
|----------|--------------|----------------|
| Cloud Run (API) | 1Gi RAM, 1 CPU, moderate traffic | $20-40 |
| Cloud Run (WebUI) | 1Gi RAM, 1 CPU, moderate traffic | $20-40 |
| Compute Engine VM | e2-standard-4 (4 vCPU, 16GB RAM) | $100-120 |
| Persistent Disk | 100GB pd-ssd | $17 |
| VPC Connector | Serverless VPC Access | $15-20 |
| Cloud Load Balancer | External HTTPS | $18 |
| **Total** | | **~$190-255/month** |

### Cost Optimization Tips

1. **Use Committed Use Discounts** for Compute Engine VM (up to 57% savings)
2. **Enable Cloud Run autoscaling** to scale to zero during idle periods
3. **Use pd-standard instead of pd-ssd** for non-production environments
4. **Set Cloud Run minimum instances to 0** for development
5. **Use preemptible VMs** for non-critical workloads (up to 80% savings)

---

## Next Steps

1. **Choose your deployment strategy** (Direct Build, Submodules, or Separate CI/CD)
2. **Create Dockerfiles** (see next section for templates)
3. **Build and test locally** before deploying
4. **Deploy to GCP** using chosen strategy
5. **Monitor and iterate**

### Recommended Path

For immediate deployment:
```bash
# 1. Create Dockerfiles (next document)
# 2. Build images
make edgequake-build

# 3. Push to registry
make edgequake-push

# 4. Deploy infrastructure
cd terraform
terraform apply

# 5. Verify
make edgequake-status
```

---

## Additional Resources

- [Terraform Configuration](02-deployment-terraform.md)
- [GitHub Actions CI/CD](03-deployment-github-actions.md)
- [Database Configuration](09-database-connection-config.md)
- [Environment Variables](10-environment-configuration-examples.md)
- [Integration Summary](11-edgequake-integration-summary.md)

---

**Document Version:** 1.0  
**Last Review:** January 4, 2026  
**Reviewed By:** System Architect

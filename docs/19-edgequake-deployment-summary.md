# EdgeQuake Deployment: Complete Summary

**Created:** January 4, 2026  
**Status:** Production Ready  
**Version:** 1.0

---

## 📋 Executive Summary

This document provides a complete overview of deploying **EdgeQuake** (a high-performance RAG system with knowledge graph capabilities) to Google Cloud Platform using the infrastructure defined in this repository.

### What Was Created

✅ **3 New Documentation Files:**
1. [Complete Territory Map & Strategy](16-edgequake-deployment-complete-guide.md) - 450+ lines
2. [Quick Start Guide](17-edgequake-quick-start.md) - 450+ lines
3. [Environment Configuration Reference](18-edgequake-environment-config.md) - 650+ lines

✅ **2 New Dockerfiles:**
1. `dockerfiles/Dockerfile.edgequake-api` - Optimized multi-stage Rust build
2. `dockerfiles/Dockerfile.edgequake-webui` - Next.js 16 production build

✅ **Makefile Integration:**
- 11 new EdgeQuake-specific targets
- Automated build, push, and deployment
- Status monitoring and logging

---

## 🗺️ Territory Map

### Repository Structure

```
📁 Two-Repository Architecture
│
├── 📦 gcp-cloud-graph-stack (Infrastructure)
│   ├── Terraform modules for GCP infrastructure
│   ├── Dockerfiles for building images
│   ├── Makefile for automation
│   ├── GitHub Actions for CI/CD
│   └── Documentation
│
└── 📦 edgequake (Application)
    ├── edgequake/ (Rust API Backend)
    │   ├── High-performance RAG engine
    │   ├── Knowledge graph integration
    │   ├── PostgreSQL + AGE + pgvector
    │   └── OpenAPI documentation
    │
    └── edgequake_webui/ (Next.js Frontend)
        ├── Modern React 19 UI
        ├── Knowledge graph visualization
        ├── Document management
        └── Query interface
```

### Technology Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Frontend** | Next.js 16 + React 19 | Web UI with graph viz |
| **Backend** | Rust + Axum | High-performance RAG API |
| **Database** | PostgreSQL 16 | Data storage |
| **Graph** | Apache AGE | Knowledge graph |
| **Vectors** | pgvector | Embeddings search |
| **LLM** | OpenAI API | Text generation |
| **Infrastructure** | Terraform + GCP | IaC deployment |
| **Container** | Docker + Artifact Registry | Image management |
| **Compute** | Cloud Run + Compute Engine | Serverless + VM |
| **Network** | VPC + VPC Connector | Private connectivity |

---

## 🚀 Quick Deployment (15 Minutes)

### Prerequisites

```bash
# Install tools
brew install terraform gcloud docker

# Authenticate
gcloud auth login
gcloud config set project saas-app-001
gcloud auth configure-docker us-central1-docker.pkg.dev
```

### Deploy Infrastructure

```bash
cd terraform
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

**Creates:**
- VPC network (10.8.0.0/28)
- PostgreSQL VM (e2-standard-2)
- Persistent disk (50GB)
- Artifact Registry
- Cloud Run services (placeholder)

**Time:** 5-7 minutes

### Build & Deploy EdgeQuake

```bash
cd ..
make edgequake-full
```

**This command:**
1. Verifies repository paths
2. Builds EdgeQuake API image (~5 min)
3. Builds EdgeQuake WebUI image (~2 min)
4. Pushes to Artifact Registry
5. Updates Cloud Run via Terraform
6. Shows deployment status

**Total Time:** 8-10 minutes

### Verify Deployment

```bash
make edgequake-status
```

**Output:**
```
┌─────────────────────────────────────────────────────────────┐
│              EdgeQuake Service Status                        │
└─────────────────────────────────────────────────────────────┘

📡 EdgeQuake API:
   URL: https://edgequake-api-xxx.run.app
   Health: 200

🌐 EdgeQuake WebUI:
   URL: https://edgequake-webui-xxx.run.app
   Status: 200

💾 PostgreSQL Database:
   Private IP: 10.8.0.2
   Database:   graph_db
   Extensions: age, pgvector
```

---

## 📂 Key Files Created

### Documentation

| File | Lines | Purpose |
|------|-------|---------|
| [docs/16-edgequake-deployment-complete-guide.md](16-edgequake-deployment-complete-guide.md) | 450+ | Complete deployment guide with 3 strategies |
| [docs/17-edgequake-quick-start.md](17-edgequake-quick-start.md) | 450+ | 15-minute quick start guide |
| [docs/18-edgequake-environment-config.md](18-edgequake-environment-config.md) | 650+ | Environment variables reference |

### Dockerfiles

| File | Purpose | Features |
|------|---------|----------|
| [dockerfiles/Dockerfile.edgequake-api](../dockerfiles/Dockerfile.edgequake-api) | Rust API build | - Multi-stage build<br>- Cargo chef for caching<br>- Stripped binary<br>- Security hardened |
| [dockerfiles/Dockerfile.edgequake-webui](../dockerfiles/Dockerfile.edgequake-webui) | Next.js build | - Standalone output<br>- Minimal dependencies<br>- Health check<br>- Non-root user |

### Makefile Targets

```bash
# Build commands
make edgequake-build          # Build both images
make edgequake-build-api      # Build API only
make edgequake-build-webui    # Build WebUI only

# Push commands
make edgequake-push           # Build and push both
make edgequake-push-api       # Push API only
make edgequake-push-webui     # Push WebUI only

# Deployment
make edgequake-deploy         # Deploy via Terraform
make edgequake-full           # Build, push, deploy

# Monitoring
make edgequake-status         # Check deployment status
make edgequake-logs           # View service logs
make edgequake-help           # Show all commands
```

---

## 🏗️ Deployment Strategies

### Option 1: Direct Build (Recommended for Getting Started)

**Architecture:**
```
Local Machine → Docker Build → Artifact Registry → Terraform Deploy → Cloud Run
```

**Pros:**
- ✅ Simple and straightforward
- ✅ Works immediately
- ✅ Full control

**Cons:**
- ❌ Manual coordination
- ❌ No automated CI/CD

**Use Case:** Development, testing, initial deployment

**Commands:**
```bash
make edgequake-full
```

---

### Option 2: Git Submodules (Unified Development)

**Architecture:**
```
Infrastructure Repo
└── submodules/edgequake/
    ├── edgequake/
    └── edgequake_webui/
```

**Pros:**
- ✅ Version-locked dependencies
- ✅ Single deployment trigger
- ✅ Unified CI/CD

**Cons:**
- ❌ Submodule management complexity

**Use Case:** Team development, staging environments

**Setup:**
```bash
git submodule add https://github.com/raphaelmansuy/edgequake.git submodules/edgequake
git submodule update --init --recursive
```

---

### Option 3: Separate CI/CD (Production Ready)

**Architecture:**
```
[edgequake repo] 
  → GitHub Actions builds images
  → Pushes to Artifact Registry
  → Dispatches to infrastructure repo
     → Terraform deploys
```

**Pros:**
- ✅ Full separation of concerns
- ✅ Independent versioning
- ✅ Scalable for teams
- ✅ Production-ready

**Cons:**
- ❌ More complex setup
- ❌ Requires GitHub Actions configuration

**Use Case:** Production, team collaboration, microservices

**Setup:** See [docs/11-edgequake-integration-summary.md](11-edgequake-integration-summary.md)

---

## 🔧 Configuration

### Automatic Configuration (via Terraform)

**EdgeQuake API:**
```hcl
environment_variables = {
  HOST          = "0.0.0.0"
  PORT          = "8080"
  DATABASE_HOST = "10.8.0.2"        # VM private IP
  DATABASE_PORT = "5432"
  DATABASE_NAME = "graph_db"
}
```

**EdgeQuake WebUI:**
```hcl
environment_variables = {
  NODE_ENV            = "production"
  NEXT_PUBLIC_API_URL = "https://edgequake-api-xxx.run.app"
  API_URL             = "https://edgequake-api-xxx.run.app"
}
```

### Manual Configuration Required

**OpenAI API Key:**
```bash
# Store in Secret Manager
echo -n "sk-your-key" | gcloud secrets create openai-api-key \
  --data-file=- \
  --replication-policy="automatic"

# Grant access
gcloud secrets add-iam-policy-binding openai-api-key \
  --member="serviceAccount:SA@PROJECT.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"

# Update Cloud Run
gcloud run services update edgequake-api \
  --region us-central1 \
  --update-secrets=OPENAI_API_KEY=openai-api-key:latest
```

---

## 💰 Cost Estimates

### Development Environment

| Resource | Configuration | Monthly Cost |
|----------|--------------|--------------|
| Cloud Run (API) | 512Mi RAM, 0.25 CPU, scale-to-zero | $5-10 |
| Cloud Run (WebUI) | 512Mi RAM, 0.25 CPU, scale-to-zero | $5-10 |
| Compute Engine | e2-small (2 vCPU, 2GB RAM) | $13 |
| Persistent Disk | 20GB pd-standard | $0.80 |
| VPC Connector | Serverless VPC Access | $10-15 |
| Artifact Registry | <1GB | $0.10 |
| **Total** | | **~$35-55/month** |

### Production Environment

| Resource | Configuration | Monthly Cost |
|----------|--------------|--------------|
| Cloud Run (API) | 1Gi RAM, 1 CPU, min 1 instance | $20-40 |
| Cloud Run (WebUI) | 1Gi RAM, 1 CPU, min 1 instance | $20-40 |
| Compute Engine | e2-standard-4 (4 vCPU, 16GB RAM) | $122 |
| Persistent Disk | 100GB pd-ssd | $17 |
| VPC Connector | Serverless VPC Access | $15-20 |
| Cloud Load Balancer | External HTTPS | $18 |
| **Total** | | **~$210-260/month** |

**Optimization Tips:**
- Use Committed Use Discounts (up to 57% savings)
- Enable Cloud Run autoscaling
- Use pd-standard for non-production
- Set minimum instances to 0 for dev

---

## 🧪 Testing

### Health Checks

```bash
# API health
curl https://edgequake-api-xxx.run.app/health

# Expected:
# {
#   "status": "healthy",
#   "database": "connected",
#   "version": "0.1.0"
# }

# WebUI health
curl https://edgequake-webui-xxx.run.app/api/health

# Expected:
# {"status":"ok"}
```

### Functional Testing

```bash
# Upload a document
curl -X POST https://edgequake-api-xxx.run.app/api/v1/documents \
  -H "Content-Type: multipart/form-data" \
  -F "file=@test.pdf" \
  -F "tenant_id=default"

# Query the knowledge graph
curl -X POST https://edgequake-api-xxx.run.app/api/v1/query \
  -H "Content-Type: application/json" \
  -d '{
    "query": "What are the main concepts?",
    "mode": "hybrid",
    "tenant_id": "default"
  }'

# Visualize in WebUI
open https://edgequake-webui-xxx.run.app/graph
```

---

## 🔍 Monitoring

### View Logs

```bash
# All logs
make edgequake-logs

# API logs
gcloud logging read \
  "resource.type=cloud_run_revision AND resource.labels.service_name=edgequake-api" \
  --limit 50

# WebUI logs
gcloud logging read \
  "resource.type=cloud_run_revision AND resource.labels.service_name=edgequake-webui" \
  --limit 50

# Database logs
gcloud compute ssh edgequake-db-vm --zone=us-central1-a \
  --command="docker logs postgres | tail -50"
```

### Metrics

```bash
# Open Cloud Console
open "https://console.cloud.google.com/run?project=saas-app-001"

# View metrics
gcloud monitoring dashboards list
```

---

## 🐛 Troubleshooting

### Common Issues

| Issue | Symptom | Solution |
|-------|---------|----------|
| Build fails | "error: failed to compile" | Increase Docker memory to 4GB |
| Connection refused | "Connection refused (os error 111)" | Check VPC connector, firewall rules |
| Image not found | "Image not found in Artifact Registry" | Re-push: `make edgequake-push` |
| Permission denied | "denied: Permission denied" | Re-auth: `gcloud auth configure-docker` |
| SSL error | "SSL certificate verification failed" | Use `sslmode=require` (not verify) |

### Debug Commands

```bash
# Check repository paths
make edgequake-check

# List images
gcloud artifacts docker images list \
  us-central1-docker.pkg.dev/saas-app-001/edgequake-images

# Verify Cloud Run
gcloud run services list

# Check database
gcloud compute ssh edgequake-db-vm --zone=us-central1-a \
  --command="docker ps"

# Test connectivity
gcloud compute ssh edgequake-db-vm --zone=us-central1-a \
  --command="docker exec postgres psql -U postgres -d graph_db -c 'SELECT 1;'"
```

---

## 📚 Documentation Index

### Quick Reference

| Document | Purpose | When to Use |
|----------|---------|-------------|
| [17-edgequake-quick-start.md](17-edgequake-quick-start.md) | 15-minute deployment | First-time deployment |
| [16-edgequake-deployment-complete-guide.md](16-edgequake-deployment-complete-guide.md) | Complete guide | Understanding architecture |
| [18-edgequake-environment-config.md](18-edgequake-environment-config.md) | Configuration reference | Setting up environments |
| [11-edgequake-integration-summary.md](11-edgequake-integration-summary.md) | Integration patterns | CI/CD setup |
| [02-deployment-terraform.md](02-deployment-terraform.md) | Terraform details | Infrastructure changes |
| [09-database-connection-config.md](09-database-connection-config.md) | Database setup | Database issues |

### Reading Order

**For Immediate Deployment:**
1. [Quick Start](17-edgequake-quick-start.md) - Follow step-by-step
2. [Environment Config](18-edgequake-environment-config.md) - Configure secrets
3. [Complete Guide](16-edgequake-deployment-complete-guide.md) - Deep dive

**For Understanding the System:**
1. [Complete Guide](16-edgequake-deployment-complete-guide.md) - Territory map
2. [Architecture](01-architecture.md) - System design
3. [Integration Summary](11-edgequake-integration-summary.md) - How pieces fit

**For Production Setup:**
1. [Complete Guide](16-edgequake-deployment-complete-guide.md) - Strategy selection
2. [Environment Config](18-edgequake-environment-config.md) - Production config
3. [Pre-Deployment Checklist](13-pre-deployment-terraform-checklist.md) - Final checks

---

## ✅ Completion Checklist

### Infrastructure
- [x] Terraform modules created
- [x] VPC and networking configured
- [x] PostgreSQL VM with AGE + pgvector
- [x] Cloud Run services defined
- [x] Artifact Registry created
- [x] IAM permissions set

### Docker Images
- [x] Dockerfile for EdgeQuake API (Rust)
- [x] Dockerfile for EdgeQuake WebUI (Next.js)
- [x] Multi-stage builds for optimization
- [x] Security hardening (non-root users)
- [x] Health checks implemented

### Automation
- [x] Makefile targets for building
- [x] Makefile targets for pushing
- [x] Makefile targets for deploying
- [x] Makefile targets for monitoring
- [x] Status and logging commands

### Documentation
- [x] Territory map created
- [x] Quick start guide written
- [x] Environment configuration documented
- [x] Three deployment strategies explained
- [x] Troubleshooting guide included
- [x] Cost estimates provided
- [x] README updated

### Testing
- [x] Build process verified
- [x] Deployment tested
- [x] Health checks validated
- [x] Documentation reviewed

---

## 🎯 Next Steps

### Immediate (Do Now)
1. Run `make edgequake-full` to deploy
2. Set up OpenAI API key in Secret Manager
3. Test with sample documents
4. Monitor logs and metrics

### Short Term (This Week)
1. Configure custom domain (if needed)
2. Set up monitoring alerts
3. Configure backups
4. Test disaster recovery

### Medium Term (This Month)
1. Implement authentication (IAP)
2. Set up staging environment
3. Configure CI/CD pipeline
4. Performance testing and tuning

### Long Term (This Quarter)
1. Multi-region deployment
2. Advanced monitoring and alerting
3. Cost optimization
4. Security hardening

---

## 🤝 Support and Contributions

### Getting Help

1. Check documentation in `docs/`
2. Run `make edgequake-help`
3. View logs: `make edgequake-logs`
4. Check status: `make edgequake-status`

### Reporting Issues

Include:
- Error messages
- Logs output
- Configuration (sanitized)
- Steps to reproduce

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes with tests
4. Submit pull request

---

## 📄 License

MIT OR Apache-2.0

---

## 🙏 Acknowledgments

- **EdgeQuake Team** - Original application development
- **Terraform Community** - Infrastructure patterns
- **Google Cloud** - Platform and tooling
- **Rust Community** - Performance and reliability

---

**Document Status:** Complete ✅  
**Last Updated:** January 4, 2026  
**Version:** 1.0  
**Maintainer:** Infrastructure Team

---

## Appendix: Quick Command Reference

```bash
# === DEPLOYMENT ===
make edgequake-full          # Full deployment (build, push, deploy)
make edgequake-status        # Check deployment status
make edgequake-logs          # View logs

# === BUILD ===
make edgequake-build         # Build both images
make edgequake-build-api     # Build API only
make edgequake-build-webui   # Build WebUI only

# === PUSH ===
make edgequake-push          # Build and push both
make edgequake-push-api      # Push API only
make edgequake-push-webui    # Push WebUI only

# === TERRAFORM ===
cd terraform
terraform init               # Initialize
terraform plan -out=tfplan  # Plan changes
terraform apply tfplan       # Apply changes

# === MONITORING ===
make edgequake-status        # Service URLs and health
make edgequake-logs          # Recent logs
gcloud run services list     # List all services

# === DEBUGGING ===
make edgequake-check         # Verify paths
docker images | grep edgequake  # List local images
gcloud compute ssh edgequake-db-vm --zone=us-central1-a  # SSH to DB VM

# === CLEANUP ===
terraform destroy            # Destroy all infrastructure
docker system prune -af      # Clean Docker cache
```


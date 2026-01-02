# GCP Cloud Graph Stack: Complete Documentation Index

**About:** A concise, production-ready Terraform + CI/CD blueprint for deploying graph (Apache AGE) + vector (pgvector) applications on Google Cloud Platform. Includes Terraform modules, Dockerfiles, and example CI pipelines.

## Overview

This repository contains a **production-ready infrastructure and CI/CD setup** for deploying a graph + vector application on Google Cloud Platform using:
- **Terraform** for Infrastructure as Code (IaC)
- **Docker** for containerization (Next.js + Rust)
- **GitHub Actions** or **Cloud Build** for CI/CD
- **PostgreSQL 16** with AGE (graph) and pgvector (embeddings)
- **Cloud Run** for serverless container deployment
- **Compute Engine** for managed PostgreSQL

**Project ID**: `saas-app-001` (US-central1 region)

---

## Quick Navigation

### 🚀 Start Here

1. **[Quick Start Guide](./05-quick-start.md)** (30 minutes)
   - Step-by-step instructions to deploy everything
   - Two paths: Terraform + GitHub Actions OR Cloud Build
   - Verification checklist

### 📚 Understanding the Architecture

2. **[Architecture Overview](./01-architecture.md)** (5 minutes)
   - System design decisions
   - Why PostgreSQL vs Cloud SQL
   - Why self-managed vs managed options
   - Network design (Direct VPC egress)

3. **[CI/CD Architecture](./04-ci-cd-architecture.md)** (10 minutes)
   - End-to-end CI/CD flow with ASCII diagrams
   - Terraform vs Cloud Build comparison
   - Multi-environment setup (dev/staging/prod)
   - Monitoring and rollback procedures

### 🛠️ Implementation Guides

4. **[Terraform Deployment Guide](./02-deployment-terraform.md)** (20 minutes)
   - Complete Terraform walkthrough
   - Module structure explained
   - Database setup and verification
   - WAL archiving and backups
   - Troubleshooting

5. **[GitHub Actions Setup](./03-deployment-github-actions.md)** (30 minutes)
   - Workload Identity Federation configuration
   - GitHub secrets setup
   - Workflow monitoring and logs
   - Manual testing with Act
   - Best practices and rollback

### 📊 Planning & Operations

6. **[Roadmap & Cost Analysis](./06-roadmap-costs.md)** (15 minutes)
   - 12-week development roadmap (MVP → Production → Scale)
   - Detailed cost breakdown (dev vs production)
   - Cost optimization strategies
   - ROI analysis for different scenarios
   - Production readiness checklist

---

## File Structure

```
gcp-cloud-graph-stack/
├── docs/
│   ├── 01-architecture.md                 # System design & decisions
│   ├── 02-deployment-terraform.md         # Terraform walkthrough
│   ├── 03-deployment-github-actions.md    # GitHub Actions setup
│   ├── 04-ci-cd-architecture.md           # CI/CD patterns & flows
│   ├── 05-quick-start.md                  # Quick start guide (THIS FILE)
│   ├── 06-roadmap-costs.md                # Roadmap & cost analysis
│   └── README.md                          # This file
│
├── terraform/
│   ├── main.tf                            # Root configuration
│   ├── variables.tf                       # Input variables (40+)
│   ├── outputs.tf                         # Exported values
│   ├── terraform.tfvars.example           # Template (copy to .tfvars)
│   └── modules/
│       ├── vpc/main.tf                    # VPC, subnets, firewall
│       ├── compute/main.tf                # PostgreSQL VM
│       ├── compute/startup-script.sh      # PostgreSQL bootstrap
│       └── cloud_run/main.tf              # Cloud Run module
│
├── dockerfiles/
│   ├── Dockerfile.nextjs                  # Next.js multi-stage build
│   └── Dockerfile.rust                    # Rust Axum multi-stage build
│
├── .github/workflows/
│   └── deploy.yml                         # GitHub Actions CI/CD
│
├── cloudbuild.yaml                        # Cloud Build alternative
│
└── README.md (in root)                    # GitHub repository README
```

---

## Quick Commands Reference

### Setup (First Time)

```bash
# 1. Clone repository
git clone https://github.com/YOUR_ORG/gcp-cloud-graph-stack.git
cd gcp-cloud-graph-stack

# 2. Configure GCP
gcloud config set project saas-app-001
gcloud services enable compute.googleapis.com run.googleapis.com \
  artifactregistry.googleapis.com cloudbuild.googleapis.com

# 3. Configure Terraform
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your settings

# 4. Deploy infrastructure
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# 5. Build and push Docker images
docker build -t us-central1-docker.pkg.dev/saas-app-001/gcp-graph-stack-images/nextjs:latest \
  -f dockerfiles/Dockerfile.nextjs .
docker push us-central1-docker.pkg.dev/saas-app-001/gcp-graph-stack-images/nextjs:latest
# (repeat for Rust image)

# 6. Deploy to Cloud Run
terraform apply  # Updates Cloud Run services with new images
```

### Daily Operations

```bash
# View application logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=nextjs-frontend" \
  --limit=20 --format=json

# SSH into PostgreSQL VM
gcloud compute ssh gcp-graph-stack-db-vm --zone=us-central1-a

# Check Cloud Run service status
gcloud run services describe nextjs-frontend --region=us-central1

# Monitor resources
gcloud monitoring dashboards list

# View costs
gcloud billing accounts list
gcloud billing budgets list
```

### Troubleshooting

```bash
# Terraform errors
terraform plan -var-file=terraform.tfvars -lock=false

# Check Cloud Build logs
gcloud builds list --limit=10
gcloud builds log <BUILD_ID>

# Check Cloud Run logs
gcloud run services describe nextjs-frontend --region=us-central1
gcloud logging read "resource.type=cloud_run_revision" --limit=50

# SSH and check VM
gcloud compute ssh gcp-graph-stack-db-vm --zone=us-central1-a
sudo journalctl -u google-startup-scripts.service -f
```

---

## Decision Guide: Which Path to Choose?

### Choose **Terraform + GitHub Actions** if:
- ✅ You use GitHub for source control
- ✅ You want infrastructure as code
- ✅ You prefer GitHub's native CI/CD interface
- ✅ You want to run tests before deployment
- ✅ You need secrets management in GitHub

### Choose **Cloud Build** if:
- ✅ You want native GCP integration
- ✅ You prefer everything in one console
- ✅ You don't have GitHub yet
- ✅ You need on-demand builds from Cloud Console

### Choose **Both** (Recommended for Enterprise) if:
- ✅ You want infrastructure + application CI/CD separated
- ✅ You have both GitHub (app) and GCP Cloud Build (infrastructure) teams
- ✅ You need maximum flexibility

---

## Key Features Explained

### 🔗 PostgreSQL with AGE (Graphs)

```sql
-- Create a graph
SELECT create_graph('social_network');

-- Add vertices (nodes)
SELECT * FROM cypher('social_network', $$
  CREATE (alice:Person {name: 'Alice'}),
         (bob:Person {name: 'Bob'})
  RETURN alice, bob
$$) AS (alice agtype, bob agtype);

-- Add edges (relationships)
SELECT * FROM cypher('social_network', $$
  MATCH (alice:Person {name: 'Alice'}),
        (bob:Person {name: 'Bob'})
  CREATE (alice)-[:KNOWS]->(bob)
  RETURN alice, bob
$$) AS (alice agtype, bob agtype);

-- Query the graph
SELECT * FROM cypher('social_network', $$
  MATCH (a:Person)-[:KNOWS]->(b:Person)
  RETURN a.name AS person_a, b.name AS person_b
$$) AS (person_a text, person_b text);
```

### 🧠 pgvector (Vector Search)

```sql
-- Create embeddings table
CREATE TABLE document_embeddings (
  id BIGSERIAL PRIMARY KEY,
  document TEXT,
  embedding vector(768)
);

-- Add embedding
INSERT INTO document_embeddings (document, embedding)
VALUES ('Machine learning is...', '[0.1, 0.2, 0.3, ...]');

-- Similarity search (cosine distance)
SELECT id, document, 1 - (embedding <=> '[0.15, 0.19, 0.31, ...]') AS similarity
FROM document_embeddings
ORDER BY embedding <=> '[0.15, 0.19, 0.31, ...]'
LIMIT 5;
```

### 🌐 Direct VPC Egress (Recommended over VPC Connector)

**Why?**
- ✅ Lower latency (~10ms vs 50ms+)
- ✅ No additional compute costs
- ✅ Simpler networking
- ✅ Better for high-throughput workloads

**How?**
- Cloud Run uses direct VPC egress by default
- All traffic through shared VPC, not via connector
- Firewall rules restrict access (Cloud Run → PostgreSQL only)

### 📦 Multi-Stage Docker Builds

Reduces image size by 70%:

```dockerfile
# Builder stage (large, temporary)
FROM node:20 as builder
WORKDIR /build
COPY package*.json ./
RUN npm ci && npm run build

# Runtime stage (small, final image)
FROM node:20-alpine
COPY --from=builder /build/dist ./dist
CMD ["npm", "start"]
```

---

## Pre-flight Checklist

Before deploying to production, verify:

```
Infrastructure:
  [ ] Terraform state is backed up (GCS backend configured)
  [ ] All variables are parameterized (no hardcoded IPs/names)
  [ ] IAM roles follow least privilege principle
  [ ] Network policies are documented
  [ ] SSL/TLS certificates are valid
  [ ] Firewall rules are tested

CI/CD:
  [ ] GitHub Actions workflow tested on feature branch
  [ ] Cloud Build trigger configured and tested
  [ ] Secrets are in Secret Manager (not in code)
  [ ] Image scanning is enabled
  [ ] Rollback procedure is documented

Database:
  [ ] PostgreSQL version is pinned
  [ ] AGE and pgvector are installed
  [ ] Extensions are enabled on startup
  [ ] WAL archiving is configured
  [ ] Backup schedule is documented
  [ ] Recovery procedure is tested

Monitoring:
  [ ] Cloud Monitoring dashboards are created
  [ ] Alert policies are configured
  [ ] Log retention is set appropriately
  [ ] Error tracking is enabled
  [ ] Performance baselines are established

Security:
  [ ] Container images are scanned for vulnerabilities
  [ ] Service accounts have minimal permissions
  [ ] VPC is isolated from public internet
  [ ] Secrets rotation is configured
  [ ] Compliance requirements are met
```

---

## Support & Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| `terraform apply` fails with quota error | Increase GCP quotas or use smaller machine type |
| PostgreSQL won't start | SSH into VM, check `/var/log/google-startup-scripts.service` |
| Cloud Run service returns 503 | Check IAM permissions, VPC connectivity, and Artifact Registry access |
| GitHub Actions auth fails | Verify Workload Identity Provider configuration and service account impersonation |
| Docker image build fails | Ensure Dockerfile paths are correct, base images are available |

### Get Help

1. **Check logs**:
   ```bash
   gcloud logging read --limit=50 --format=json | jq
   ```

2. **Test connectivity**:
   ```bash
   gcloud compute ssh gcp-graph-stack-db-vm --zone=us-central1-a
   sudo systemctl status postgresql
   ```

3. **Review documentation**:
   - [Cloud Run Documentation](https://cloud.google.com/run/docs)
   - [Terraform Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
   - [PostgreSQL Documentation](https://www.postgresql.org/docs)
   - [Apache AGE Documentation](https://age.apache.org/age-manual/master/index.html)

---

## Next Steps

### Immediate (Days 1-3)
1. Read [Quick Start Guide](./05-quick-start.md)
2. Run Terraform apply
3. Verify infrastructure is working

### Short Term (Weeks 1-2)
1. Develop application code (Next.js + Rust)
2. Set up GitHub Actions CI/CD
3. Implement database schema
4. Write integration tests

### Medium Term (Weeks 3-8)
1. Set up monitoring and alerting
2. Implement backup and restore procedures
3. Harden security (Cloud Armor, VPC Service Controls)
4. Load test and optimize performance

### Long Term (Months 3-6)
1. Multi-region deployment
2. Advanced observability (APM, tracing)
3. Automated scaling and cost optimization
4. Compliance and audit readiness

---

## Contributing

Have suggestions to improve this setup? 

1. Create an issue describing the problem
2. Submit a pull request with improvements
3. Share feedback: feedback@gcp-graph-stack.dev

---

## License

This project is licensed under the MIT License - see LICENSE file for details.

---

## Acknowledgments

- [Apache AGE](https://age.apache.org/) - Graph database extension
- [pgvector](https://github.com/pgvector/pgvector) - Vector search
- [Terraform](https://www.terraform.io/) - Infrastructure as code
- [Google Cloud Platform](https://cloud.google.com/) - Cloud services

---

## Document Map

```
For different audiences:

📖 Product Manager / Business:
   → 06-roadmap-costs.md (roadmap, ROI, costs)

🏗️ DevOps / SRE:
   → 01-architecture.md → 05-quick-start.md → 02-deployment-terraform.md

👨‍💻 Developer:
   → 05-quick-start.md → 03-deployment-github-actions.md

🔒 Security Engineer:
   → 01-architecture.md → 04-ci-cd-architecture.md

💰 Finance / Procurement:
   → 06-roadmap-costs.md

📋 New Team Member:
   → This file (README.md) → 05-quick-start.md → Other docs as needed
```

---

**Last Updated**: 2024
**Project**: gcp-cloud-graph-stack
**Environment**: saas-app-001 GCP Project
**Region**: us-central1

# Documentation Index & Navigation Guide

This document provides a comprehensive index of all documentation and guides for the GCP Cloud Graph Stack infrastructure and Edgequake integration.

## 📋 Quick Navigation

### For Getting Started
1. [Quick Start (05)](./05-quick-start.md) – Start here if this is your first time
2. [Architecture Overview (01)](./01-architecture.md) – Understand the system design
3. [Deployment with Terraform (02)](./02-deployment-terraform.md) – Deploy to GCP

### For CI/CD & Deployment
1. [GitHub Actions to Infra Dispatch (08)](./08-github-actions-deploy-edgequake.md) – Complete CI/CD workflow setup
2. [CI/CD Architecture (04)](./04-ci-cd-architecture.md) – Design patterns for multi-repo deploys

### For Edgequake Integration
1. [Edgequake Integration Summary (11)](./11-edgequake-integration-summary.md) – Quick reference for Edgequake developers
2. [Database Connection Config (09)](./09-database-connection-config.md) – How the web connects to the database
3. [Environment Configuration Examples (10)](./10-environment-configuration-examples.md) – Complete `.env` files and code examples

### For Operations
1. [Database Disk Operations (07)](./07-db-disk-ops.md) – Snapshots, backups, restoration
2. [Roadmap & Cost Analysis (06)](./06-roadmap-costs.md) – Future directions and budget planning

---

## 📚 Complete Documentation Reference

### 01. Architecture Overview
**File:** [01-architecture.md](./01-architecture.md)

**Topics covered:**
- High-level system architecture
- GCP services (Compute Engine, Cloud Run, Cloud Logging, etc.)
- Network topology (VPC, subnet, firewall rules)
- Database design (PostgreSQL, AGE, pgvector)
- Security model

**Read this if:**
- You're new to the project
- You need to understand how components interact
- You're planning infrastructure changes

---

### 02. Deployment with Terraform
**File:** [02-deployment-terraform.md](./02-deployment-terraform.md)

**Topics covered:**
- Terraform directory structure
- Prerequisites (GCP account, credentials, tools)
- Step-by-step deployment instructions
- Backend configuration (GCS state storage)
- Variables and configuration
- Troubleshooting deployment issues

**Read this if:**
- You're deploying the infrastructure
- You need to understand Terraform modules
- You want to modify infrastructure code

---

### 03. GitHub Actions Deployment
**File:** [03-deployment-github-actions.md](./03-deployment-github-actions.md)

**Topics covered:**
- GitHub Actions setup for CI/CD
- Workflow structure and naming
- Secret management in GitHub
- Artifact creation and publishing
- Deployment automation

**Read this if:**
- You're setting up automated deployments
- You need to understand GitHub Actions workflows
- You're configuring CI/CD pipelines

---

### 04. CI/CD Architecture
**File:** [04-ci-cd-architecture.md](./04-ci-cd-architecture.md)

**Topics covered:**
- Different CI/CD deployment patterns (Option A, B, C)
- Pros and cons of each approach
- Architecture decisions
- Multi-repo coordination
- Workflow design patterns

**Read this if:**
- You're choosing a CI/CD strategy
- You need to understand deployment patterns
- You're implementing multi-repo deployments

---

### 05. Quick Start
**File:** [05-quick-start.md](./05-quick-start.md)

**Topics covered:**
- 5-minute setup guide
- Minimal prerequisites
- Key commands
- Expected outputs
- What to do next

**Read this if:**
- You're new and want a quick overview
- You want to get running immediately
- You need a reference for common commands

---

### 06. Roadmap & Cost Analysis
**File:** [06-roadmap-costs.md](./06-roadmap-costs.md)

**Topics covered:**
- Future features and enhancements
- Cost breakdown by service
- Budget optimization strategies
- Reserved capacity calculations
- Multi-environment setups

**Read this if:**
- You're planning budget
- You want to understand cost drivers
- You're designing future features

---

### 07. Database Disk Operations
**File:** [07-db-disk-ops.md](./07-db-disk-ops.md)

**Topics covered:**
- Disk snapshot creation and management
- Backup procedures
- Disk restoration steps
- Terraform import for existing disks
- Disaster recovery procedures

**Read this if:**
- You need to backup the database
- You're recovering from a failure
- You want to manage snapshots
- You're doing disk maintenance

---

### 08. GitHub Actions → Infra Dispatch (Option A)
**File:** [08-github-actions-deploy-edgequake.md](./08-github-actions-deploy-edgequake.md)

**Topics covered:**
- Complete CI/CD workflow for Edgequake
- Build and push workflow (edgequake repo)
- Dispatch receiver workflow (infra repo)
- Workload Identity Federation (OIDC) setup
- Terraform variable wiring
- Rollback and recovery procedures
- Verification checklist

**Read this if:**
- You're implementing the recommended CI/CD pattern
- You need to deploy Edgequake images automatically
- You want to understand OIDC authentication
- You're setting up multi-repo deployments

**Key diagram:**
```
edgequake repo (build + push)
    ↓
repository_dispatch (with image URLs)
    ↓
infra repo (terraform plan + apply)
    ↓
GCP (Cloud Run + VM updated)
```

---

### 09. Database Connection Configuration
**File:** [09-database-connection-config.md](./09-database-connection-config.md)

**Topics covered:**
- PostgreSQL setup (automatic via startup script)
- Database connection details (host, port, credentials)
- Rust API requirements (environment variables, libraries)
- Next.js frontend requirements (API_URL env var)
- Network & firewall configuration
- Secrets management (optional)
- Troubleshooting common issues
- Example Rust code for database connection

**Read this if:**
- You're building the Edgequake backend (Rust API)
- You're building the Edgequake frontend (Next.js)
- You need to understand how components connect
- You're troubleshooting database connectivity

**Quick reference:**
| Component | Env Vars | Responsibilities |
|-----------|----------|-----------------|
| Rust API | DATABASE_HOST, DATABASE_PORT, DATABASE_NAME | Connect to PostgreSQL, execute queries, expose via HTTP |
| Next.js | API_URL | Call Rust API, render UI, no direct DB access |
| PostgreSQL | N/A (managed) | Store data, run extensions (age, pgvector) |

---

### 10. Environment Configuration Examples
**File:** [10-environment-configuration-examples.md](./10-environment-configuration-examples.md)

**Topics covered:**
- `.env` files for development and production
- Cargo.toml dependencies for Rust API
- Next.js environment variables
- Docker Compose setup for local development
- Database initialization scripts
- Example Rust API startup code
- Example Next.js API routes
- Configuration checklist

**Read this if:**
- You're setting up local development
- You need example `.env` files
- You want to use Docker Compose locally
- You need complete code examples for Rust and Next.js

**Key files:**
- `.env.local` – Development configuration
- `.env.production` – Production configuration
- `docker-compose.yml` – Local services (PostgreSQL, Rust API, Next.js)
- `Cargo.toml` – Rust dependencies

---

### 11. Edgequake Integration Summary
**File:** [11-edgequake-integration-summary.md](./11-edgequake-integration-summary.md)

**Topics covered:**
- Quick start checklist for Edgequake developers
- What each component (Rust API, Next.js, PostgreSQL) needs
- Architecture flow diagram
- Implementation steps
- Network connectivity details
- Troubleshooting guide
- Production checklist

**Read this if:**
- You're a developer working on Edgequake
- You want a high-level overview of integration
- You're implementing database connections
- You need a quick reference guide

**Sections:**
- Rust API Configuration
- Next.js Frontend Configuration
- PostgreSQL Database Setup
- Network & Connectivity
- Implementation Steps
- Troubleshooting
- Production Checklist

---

## 🗺️ Documentation Dependency Map

```
05 - Quick Start
    ↓
01 - Architecture
    ├─→ 02 - Deployment (Terraform)
    │   ├─→ 07 - Database Operations
    │   └─→ 06 - Costs & Roadmap
    │
    └─→ 04 - CI/CD Architecture
        ├─→ 03 - GitHub Actions
        └─→ 08 - Infra Dispatch (Option A)
            ├─→ 09 - Database Connection
            ├─→ 10 - Environment Config
            └─→ 11 - Edgequake Summary
```

## 📋 Use Case Navigation

### I want to **deploy the infrastructure**
1. [05-quick-start.md](./05-quick-start.md) – Quick overview
2. [02-deployment-terraform.md](./02-deployment-terraform.md) – Detailed deployment
3. [01-architecture.md](./01-architecture.md) – Understand what's being deployed

### I want to **set up CI/CD for Edgequake**
1. [04-ci-cd-architecture.md](./04-ci-cd-architecture.md) – Choose a pattern
2. [08-github-actions-deploy-edgequake.md](./08-github-actions-deploy-edgequake.md) – Implement Option A
3. [11-edgequake-integration-summary.md](./11-edgequake-integration-summary.md) – Integration checklist

### I want to **develop the Edgequake application**
1. [09-database-connection-config.md](./09-database-connection-config.md) – Understand database connection
2. [10-environment-configuration-examples.md](./10-environment-configuration-examples.md) – Get code examples
3. [11-edgequake-integration-summary.md](./11-edgequake-integration-summary.md) – Implementation checklist

### I want to **manage the database**
1. [07-db-disk-ops.md](./07-db-disk-ops.md) – Snapshots, backups, restoration
2. [09-database-connection-config.md](./09-database-connection-config.md) – Connection details
3. [01-architecture.md](./01-architecture.md) – Database design

### I want to **plan for production**
1. [06-roadmap-costs.md](./06-roadmap-costs.md) – Budget and costs
2. [01-architecture.md](./01-architecture.md) – System design
3. [11-edgequake-integration-summary.md](./11-edgequake-integration-summary.md) – Production checklist

---

## 🔑 Key Concepts by Document

| Concept | Document | Section |
|---------|----------|---------|
| VPC & Networking | 01 | Network Topology |
| PostgreSQL Setup | 09 | Database Setup |
| Cloud Run Services | 01 | Services Overview |
| Terraform Modules | 02 | Directory Structure |
| GitHub Actions | 08 | Build & Push Workflow |
| Environment Variables | 10 | Configuration Examples |
| Database Backups | 07 | Snapshot Creation |
| Disaster Recovery | 07 | Restoration |
| Cost Optimization | 06 | Cost Analysis |
| Integration | 11 | Architecture Flow |

---

## 📞 Quick Reference

### Most Common Tasks

**Deploy infrastructure:**
```bash
cd terraform
terraform init -backend-config="bucket=saas-app-001-tf-state" -backend-config="prefix=terraform/state"
terraform plan
terraform apply
```

**Check PostgreSQL:**
```bash
gcloud compute ssh db-vm --zone=us-central1-a
sudo -u postgres psql -d graph_db -c "\dx"
```

**View Cloud Run logs:**
```bash
gcloud run services logs read <service-name> --region=us-central1
```

**Create snapshot manually:**
```bash
gcloud compute disks snapshot edgequake-data-disk --snapshot-names=manual-$(date +%s)
```

**Restore from snapshot:**
See [07-db-disk-ops.md](./07-db-disk-ops.md) – Snapshot Restoration section

---

## 📝 Contributing to Documentation

When adding new docs:
1. Use consistent formatting and naming convention (##, ###, etc.)
2. Add entry to this index document
3. Include high-signal diagrams where appropriate
4. Link to related documentation
5. Provide code examples for implementation topics

---

## ✅ Documentation Checklist

- [x] 01 - Architecture Overview
- [x] 02 - Deployment with Terraform
- [x] 03 - GitHub Actions Deployment
- [x] 04 - CI/CD Architecture
- [x] 05 - Quick Start
- [x] 06 - Roadmap & Costs
- [x] 07 - Database Disk Operations
- [x] 08 - GitHub Actions → Infra Dispatch
- [x] 09 - Database Connection Configuration
- [x] 10 - Environment Configuration Examples
- [x] 11 - Edgequake Integration Summary
- [x] 12 - Documentation Index (this file)

---

## 🚀 Getting Help

**For deployment issues:** → See [02-deployment-terraform.md](./02-deployment-terraform.md) – Troubleshooting

**For CI/CD issues:** → See [08-github-actions-deploy-edgequake.md](./08-github-actions-deploy-edgequake.md) – Verification Checklist

**For database issues:** → See [09-database-connection-config.md](./09-database-connection-config.md) – Troubleshooting

**For integration issues:** → See [11-edgequake-integration-summary.md](./11-edgequake-integration-summary.md) – Troubleshooting

---

Last updated: January 2, 2026

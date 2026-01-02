# Terraform Infrastructure Deployment Guide

## Overview

This guide explains how to deploy the `gcp-cloud-graph-stack` infrastructure using Terraform. The configuration will provision:

- **VPC Network** with subnets and firewall rules
- **Compute Engine VM** with PostgreSQL 16, Apache AGE, and pgvector
- **Cloud Run Services** for Next.js frontend and Rust API backend
- **Artifact Registry** for container image management
- **Service Accounts** with least-privilege IAM roles

## Prerequisites

1. **GCP Project**: `saas-app-001` (or your project ID)
2. **Tools**:
   - Terraform >= 1.5
   - Google Cloud SDK (gcloud)
   - Docker
   - Git

3. **Authentication**: 
   ```bash
   gcloud auth login
   gcloud config set project saas-app-001
   ```

## Quick Start

### 1. Initialize Terraform

```bash
cd terraform/
terraform init
```

Expected output:
```
Initializing the backend...
Initializing modules...
Initializing provider plugins...
Terraform has been successfully configured!
```

### 2. Prepare Configuration

Copy and customize the variables file:

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

**Key variables to set**:
- `project_id`: Your GCP project (saas-app-001)
- `region`: us-central1 (or your preferred region)
- `gcs_backup_bucket`: Create a bucket for WAL archiving
- `enable_direct_vpc_egress`: true (recommended)

### 3. Plan Deployment

Review the infrastructure changes:

```bash
terraform plan -out=tfplan
```

Example output:
```
Plan: 22 to add, 0 to change, 0 to destroy.
```

### 4. Apply Configuration

Deploy the infrastructure:

```bash
terraform apply tfplan
```

This will:
- Create VPC and subnet
- Create Compute Engine VM with PostgreSQL startup script
- Create Cloud Run services (placeholder images)
- Create Artifact Registry repository
- Set up IAM roles and service accounts

**Expected time**: 5-10 minutes

### 5. Verify Deployment

```bash
# Check VM creation
gcloud compute instances list

# Check Cloud Run services
gcloud run services list --region=us-central1

# Check Artifact Registry
gcloud artifacts repositories list --location=us-central1
```

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         GCP Project (saas-app-001)              │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              VPC (10.0.0.0/16)                           │   │
│  │  ┌────────────────────────────────────────────────────┐  │   │
│  │  │         Subnet (10.0.0.0/24)                       │  │   │
│  │  │                                                     │  │   │
│  │  │  ┌──────────────────────────────────────────────┐  │  │   │
│  │  │  │ Compute Engine VM                           │  │  │   │
│  │  │  │ - PostgreSQL 16                             │  │  │   │
│  │  │  │ - Apache AGE (graph)                        │  │  │   │
│  │  │  │ - pgvector (embeddings)                     │  │  │   │
│  │  │  │ - Cloud Ops agent (monitoring)             │  │  │   │
│  │  │  │ Private IP: 10.0.0.2                       │  │  │   │
│  │  │  └──────────────────────────────────────────────┘  │  │   │
│  │  │                          ↑                          │  │   │
│  │  │  ┌──────────────────────────────────────────────┐  │  │   │
│  │  │  │ Direct VPC Egress                           │  │  │   │
│  │  │  │ (recommended, lower latency)                │  │  │   │
│  │  │  │ Firewall: Allow 5432 from 10.0.0.0/24      │  │  │   │
│  │  │  └──────────────────────────────────────────────┘  │  │   │
│  │  │                                                     │  │   │
│  │  └────────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────┘   │
│                             ↑                                     │
├─────────────────────────────┼─────────────────────────────────────┤
│                             │                                     │
│                  ┌──────────┴──────────┐                          │
│                  │                     │                          │
│         ┌────────▼────────┐   ┌────────▼────────┐               │
│         │  Cloud Run      │   │  Cloud Run      │               │
│         │  Next.js        │   │  Rust API       │               │
│         │  Frontend       │   │  Backend        │               │
│         │  (public)       │   │  (private)      │               │
│         └─────────────────┘   └─────────────────┘               │
│                                                                   │
│         ┌─────────────────────────────────────────┐             │
│         │  Artifact Registry                      │             │
│         │  (Container Images)                    │             │
│         └─────────────────────────────────────────┘             │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

## Deploying Container Images

After infrastructure is created, build and push container images:

### Next.js Frontend

```bash
docker build -t nextjs:latest -f dockerfiles/Dockerfile.nextjs .

docker tag nextjs:latest \
  us-central1-docker.pkg.dev/saas-app-001/edgequake-images/nextjs:latest

docker push \
  us-central1-docker.pkg.dev/saas-app-001/edgequake-images/nextjs:latest
```

Then update Terraform:

```bash
terraform apply \
  -var='nextjs_image_url=us-central1-docker.pkg.dev/saas-app-001/edgequake-images/nextjs:latest'
```

### Rust API

```bash
docker build -t rust-api:latest -f dockerfiles/Dockerfile.rust .

docker tag rust-api:latest \
  us-central1-docker.pkg.dev/saas-app-001/edgequake-images/rust-api:latest

docker push \
  us-central1-docker.pkg.dev/saas-app-001/edgequake-images/rust-api:latest
```

Update Terraform:

```bash
terraform apply \
  -var='rust_api_image_url=us-central1-docker.pkg.dev/saas-app-001/edgequake-images/rust-api:latest'
```

## Database Setup

SSH into the VM to verify PostgreSQL and extensions:

```bash
gcloud compute ssh edgequake-db-vm --region=us-central1

# Inside VM:
sudo -u postgres psql -d graph_db
```

List extensions:

```sql
\dx
```

Verify AGE:

```sql
SELECT * FROM create_graph('test_graph');
SELECT * FROM cypher('test_graph', $$ MATCH (n) RETURN n $$) AS (v agtype);
```

Verify pgvector:

```sql
CREATE TABLE test_vectors (id SERIAL, embedding vector(1536));
CREATE INDEX ON test_vectors USING hnsw (embedding vector_cosine_ops);
```

## WAL Archiving Setup (Optional)

If `enable_wal_archiving = true`, create a GCS bucket:

```bash
gsutil mb -l us-central1 gs://saas-app-001-db-backups

# Allow VM service account to write to bucket:
gsutil iam ch \
  serviceAccount:edgequake-vm@saas-app-001.iam.gserviceaccount.com:roles/storage.objectCreator \\
  gs://saas-app-001-db-backups
```

## Cleanup

To destroy all infrastructure:

```bash
terraform destroy
```

**WARNING**: This will delete all resources including the VM and database. Ensure backups are in place.

## Troubleshooting

### Terraform validation fails
```bash
terraform fmt -recursive
terraform validate
```

### Module not found
```bash
terraform init -upgrade
```

### Cloud Run service won't start
Check logs:
```bash
gcloud run services describe nextjs-frontend --region=us-central1
gcloud logging read "resource.type=cloud_run_revision" --limit 50
```

## References

- [Terraform Google Cloud Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Cloud Run Documentation](https://docs.cloud.google.com/run/docs)
- [PostgreSQL Extensions in Cloud SQL](https://docs.cloud.google.com/sql/docs/postgres/extensions)

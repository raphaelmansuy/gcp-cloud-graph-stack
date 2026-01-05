# EdgeQuake Environment Configuration Reference

**Complete guide to environment variables, secrets, and configuration**

---

## Table of Contents

1. [Overview](#overview)
2. [EdgeQuake API (Rust Backend)](#edgequake-api-rust-backend)
3. [EdgeQuake WebUI (Next.js Frontend)](#edgequake-webui-nextjs-frontend)
4. [PostgreSQL Database](#postgresql-database)
5. [Secrets Management](#secrets-management)
6. [Local Development](#local-development)
7. [Production Configuration](#production-configuration)
8. [Configuration Templates](#configuration-templates)

---

## Overview

### Configuration Hierarchy

```
Production:  Cloud Run env vars → Terraform → terraform.tfvars
Development: .env.local → docker-compose → local settings
```

### Auto-Configuration

The following are **automatically configured** by Terraform:
- ✅ Database connection parameters
- ✅ Service URLs
- ✅ Network configuration
- ✅ IAM permissions

You need to manually configure:
- ⚠️ LLM API keys (OpenAI, etc.)
- ⚠️ Custom domain settings (if any)
- ⚠️ Additional secrets

---

## EdgeQuake API (Rust Backend)

### Required Environment Variables

| Variable | Type | Description | Example | Source |
|----------|------|-------------|---------|--------|
| `HOST` | String | Server bind address | `0.0.0.0` | Default |
| `PORT` | Integer | Server port | `8080` | Cloud Run |
| `DATABASE_HOST` | String | PostgreSQL host IP | `10.8.0.2` | Terraform |
| `DATABASE_PORT` | Integer | PostgreSQL port | `5432` | Terraform |
| `DATABASE_NAME` | String | Database name | `graph_db` | Terraform |
| `DATABASE_USER` | String | Database user | `postgres` | Default |
| `DATABASE_PASSWORD` | String | Database password | `""` (empty) | Default |

### Optional Environment Variables

| Variable | Type | Description | Default | Example |
|----------|------|-------------|---------|---------|
| `RUST_LOG` | String | Log level | `info` | `debug`, `warn`, `error` |
| `OPENAI_API_KEY` | String | OpenAI API key | Required | `sk-...` |
| `OPENAI_API_BASE` | String | API base URL | OpenAI default | Custom endpoint |
| `OPENAI_MODEL` | String | Model name | `gpt-4` | `gpt-3.5-turbo` |
| `MAX_CONNECTIONS` | Integer | DB pool size | `10` | `20` |
| `REQUEST_TIMEOUT` | Integer | Request timeout (s) | `300` | `600` |
| `MAX_DOCUMENT_SIZE` | Integer | Max file size (MB) | `50` | `100` |
| `CHUNK_SIZE` | Integer | Text chunk size | `512` | `1024` |
| `CHUNK_OVERLAP` | Integer | Chunk overlap | `50` | `100` |

### Terraform Configuration

**File:** `terraform/modules/cloud_run/main.tf`

```hcl
resource "google_cloud_run_v2_service" "api" {
  name     = var.service_name
  location = var.region

  template {
    containers {
      image = var.image_url

      env {
        name  = "HOST"
        value = "0.0.0.0"
      }

      env {
        name  = "PORT"
        value = "8080"
      }

      env {
        name  = "DATABASE_HOST"
        value = var.database_host  # From compute module
      }

      env {
        name  = "DATABASE_PORT"
        value = var.database_port
      }

      env {
        name  = "DATABASE_NAME"
        value = "graph_db"
      }

      env {
        name = "OPENAI_API_KEY"
        value_source {
          secret_key_ref {
            secret  = var.openai_secret_name
            version = "latest"
          }
        }
      }

      env {
        name  = "RUST_LOG"
        value = var.environment == "prod" ? "info" : "debug"
      }
    }
  }
}
```

### Connection String Format

The Rust application builds the connection string from environment variables:

```rust
use sqlx::postgres::PgPoolOptions;
use std::env;

async fn connect_database() -> Result<PgPool, sqlx::Error> {
    let database_url = format!(
        "postgresql://{}:{}@{}:{}/{}?sslmode=require",
        env::var("DATABASE_USER").unwrap_or_else(|_| "postgres".to_string()),
        env::var("DATABASE_PASSWORD").unwrap_or_else(|_| "".to_string()),
        env::var("DATABASE_HOST")?,
        env::var("DATABASE_PORT").unwrap_or_else(|_| "5432".to_string()),
        env::var("DATABASE_NAME")?,
    );

    let pool = PgPoolOptions::new()
        .max_connections(
            env::var("MAX_CONNECTIONS")
                .unwrap_or_else(|_| "10".to_string())
                .parse()
                .unwrap_or(10)
        )
        .connect(&database_url)
        .await?;

    Ok(pool)
}
```

---

## EdgeQuake WebUI (Next.js Frontend)

### Required Environment Variables

| Variable | Type | Description | Example | Source |
|----------|------|-------------|---------|--------|
| `PORT` | Integer | Server port | `3000` | Cloud Run |
| `NODE_ENV` | String | Environment | `production` | Terraform |
| `NEXT_PUBLIC_API_URL` | String | API URL (client-side) | `https://api.example.com` | Terraform |
| `API_URL` | String | API URL (server-side) | `https://api.example.com` | Terraform |

### Optional Environment Variables

| Variable | Type | Description | Default | Example |
|----------|------|-------------|---------|---------|
| `NEXT_PUBLIC_ENABLE_DEMO_MODE` | Boolean | Enable demo mode | `false` | `true` |
| `NEXT_PUBLIC_ENABLE_API_EXPLORER` | Boolean | Show API explorer | `true` | `false` |
| `NEXT_PUBLIC_ANALYTICS_ID` | String | Analytics ID | - | `G-XXXXXXXXXX` |
| `NEXT_TELEMETRY_DISABLED` | String | Disable telemetry | `1` | `1` |

### Terraform Configuration

**File:** `terraform/modules/cloud_run/main.tf`

```hcl
resource "google_cloud_run_v2_service" "webui" {
  name     = var.service_name
  location = var.region

  template {
    containers {
      image = var.image_url

      env {
        name  = "PORT"
        value = "3000"
      }

      env {
        name  = "NODE_ENV"
        value = var.environment
      }

      env {
        name  = "NEXT_PUBLIC_API_URL"
        value = var.api_service_url  # From rust-api service
      }

      env {
        name  = "API_URL"
        value = var.api_service_url
      }

      env {
        name  = "NEXT_TELEMETRY_DISABLED"
        value = "1"
      }
    }
  }
}
```

### Next.js API Proxy Configuration

**File:** `edgequake_webui/src/lib/api.ts`

```typescript
// API client configuration
const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || '/api/v1';

export const apiClient = {
  baseURL: API_BASE_URL,
  timeout: 30000,
  
  async fetch(endpoint: string, options?: RequestInit) {
    const url = `${API_BASE_URL}${endpoint}`;
    const response = await fetch(url, {
      ...options,
      headers: {
        'Content-Type': 'application/json',
        ...options?.headers,
      },
    });
    
    if (!response.ok) {
      throw new Error(`API error: ${response.status}`);
    }
    
    return response.json();
  },
};
```

---

## PostgreSQL Database

### Auto-Configuration (via Terraform)

```sql
-- Database: graph_db
-- User: postgres (superuser, no password required from VM)
-- Extensions: age, pgvector
-- SSL: Enabled with self-signed certificate
```

### Connection Parameters

| Parameter | Value | Notes |
|-----------|-------|-------|
| Host | `10.8.0.2` | Private IP in VPC |
| Port | `5432` | Standard PostgreSQL port |
| Database | `graph_db` | Created by startup script |
| User | `postgres` | Superuser |
| Password | Empty | VM-only access |
| SSL Mode | `require` | Self-signed cert |

### Extensions Configuration

Automatically installed by Terraform startup script:

```sql
-- AGE (Apache Graph Extension)
CREATE EXTENSION IF NOT EXISTS age;
LOAD 'age';
SET search_path = ag_catalog, "$user", public;

-- pgvector (Vector Similarity Search)
CREATE EXTENSION IF NOT EXISTS vector;

-- Verify extensions
\dx
```

### Schema Initialization

The EdgeQuake API handles schema initialization via migrations:

```bash
# Location: edgequake/migrations/
# Run automatically on first startup
```

---

## Secrets Management

### Using Google Secret Manager

#### 1. Create Secrets

```bash
# OpenAI API Key
echo -n "sk-your-openai-key-here" | \
  gcloud secrets create openai-api-key \
    --data-file=- \
    --replication-policy="automatic" \
    --project=saas-app-001

# Custom LLM API Key (if needed)
echo -n "your-custom-key" | \
  gcloud secrets create custom-llm-key \
    --data-file=- \
    --replication-policy="automatic" \
    --project=saas-app-001
```

#### 2. Grant Access to Cloud Run

```bash
# Get the Cloud Run service account
SERVICE_ACCOUNT=$(gcloud run services describe edgequake-api \
  --region us-central1 \
  --format='value(spec.template.spec.serviceAccountName)')

# Grant secret accessor role
gcloud secrets add-iam-policy-binding openai-api-key \
  --member="serviceAccount:${SERVICE_ACCOUNT}" \
  --role="roles/secretmanager.secretAccessor"
```

#### 3. Reference in Terraform

```hcl
# terraform/main.tf

resource "google_secret_manager_secret" "openai_key" {
  secret_id = "openai-api-key"

  replication {
    automatic = true
  }
}

# In cloud_run module
env {
  name = "OPENAI_API_KEY"
  value_source {
    secret_key_ref {
      secret  = google_secret_manager_secret.openai_key.secret_id
      version = "latest"
    }
  }
}
```

### Environment-Specific Secrets

```bash
# Development
gcloud secrets create openai-api-key-dev --data-file=-

# Production
gcloud secrets create openai-api-key-prod --data-file=-
```

---

## Local Development

### EdgeQuake API (.env)

**File:** `edgequake/edgequake/.env`

```bash
# Server
HOST=0.0.0.0
PORT=8080
RUST_LOG=debug

# Database (local Docker)
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_NAME=graph_db
DATABASE_USER=postgres
DATABASE_PASSWORD=postgres

# LLM Provider
OPENAI_API_KEY=sk-your-dev-key
OPENAI_MODEL=gpt-4

# Features
MAX_DOCUMENT_SIZE=50
CHUNK_SIZE=512
CHUNK_OVERLAP=50
```

### EdgeQuake WebUI (.env.local)

**File:** `edgequake/edgequake_webui/.env.local`

```bash
# API Configuration
NEXT_PUBLIC_API_URL=http://localhost:8080
API_URL=http://localhost:8080

# Development Settings
NODE_ENV=development
NEXT_TELEMETRY_DISABLED=1

# Features
NEXT_PUBLIC_ENABLE_DEMO_MODE=false
NEXT_PUBLIC_ENABLE_API_EXPLORER=true
```

### Docker Compose (Local Development)

**File:** `edgequake/docker-compose.yml`

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_DB: graph_db
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./docker/init-extensions.sql:/docker-entrypoint-initdb.d/init.sql

  edgequake-api:
    build:
      context: ./edgequake
      dockerfile: docker/Dockerfile
    ports:
      - "8080:8080"
    environment:
      DATABASE_HOST: postgres
      DATABASE_PORT: 5432
      DATABASE_NAME: graph_db
      OPENAI_API_KEY: ${OPENAI_API_KEY}
    depends_on:
      - postgres

  edgequake-webui:
    build:
      context: ./edgequake_webui
    ports:
      - "3000:3000"
    environment:
      NEXT_PUBLIC_API_URL: http://localhost:8080
      NODE_ENV: development
    depends_on:
      - edgequake-api

volumes:
  postgres_data:
```

Run locally:
```bash
docker-compose up -d
```

---

## Production Configuration

### Terraform Variables

**File:** `terraform/terraform.tfvars`

```hcl
# Project Configuration
project_id  = "saas-app-001"
region      = "us-central1"
environment = "prod"
app_name    = "edgequake"

# Cloud Run Services
rust_api_service_name = "edgequake-api"
nextjs_service_name   = "edgequake-webui"

# Container Images
rust_api_image_url = "us-central1-docker.pkg.dev/saas-app-001/edgequake-images/edgequake-api:latest"
nextjs_image_url   = "us-central1-docker.pkg.dev/saas-app-001/edgequake-images/edgequake-webui:latest"

# Database VM
db_vm_machine_type        = "e2-standard-4"
data_disk_size            = 100
data_disk_prevent_destroy = true
db_port                   = 5432

# Network
vpc_cidr                = "10.8.0.0/28"
enable_direct_vpc_egress = false

# Secrets
openai_secret_name = "openai-api-key-prod"

# Scaling
min_instances = 1
max_instances = 10

# Resources
memory_limit = "1Gi"
cpu_limit    = "1000m"

# Labels
labels = {
  environment = "prod"
  app         = "edgequake"
  managed_by  = "terraform"
}
```

### Production Checklist

- [ ] Set `openai_secret_name` to production secret
- [ ] Set `data_disk_prevent_destroy = true`
- [ ] Configure `min_instances >= 1` for high availability
- [ ] Set `memory_limit` and `cpu_limit` based on load testing
- [ ] Enable monitoring and alerting
- [ ] Configure custom domain and SSL
- [ ] Set up Cloud Armor (WAF) if needed
- [ ] Configure backup strategy
- [ ] Set up disaster recovery plan

---

## Configuration Templates

### Development Template

```hcl
# terraform/environments/dev.tfvars

environment = "dev"
db_vm_machine_type = "e2-small"
data_disk_size = 20
min_instances = 0
max_instances = 1
memory_limit = "512Mi"
cpu_limit = "500m"
openai_secret_name = "openai-api-key-dev"
```

### Staging Template

```hcl
# terraform/environments/staging.tfvars

environment = "staging"
db_vm_machine_type = "e2-standard-2"
data_disk_size = 50
min_instances = 0
max_instances = 3
memory_limit = "1Gi"
cpu_limit = "1000m"
openai_secret_name = "openai-api-key-staging"
```

### Production Template

```hcl
# terraform/environments/prod.tfvars

environment = "prod"
db_vm_machine_type = "e2-standard-4"
data_disk_size = 100
min_instances = 1
max_instances = 10
memory_limit = "2Gi"
cpu_limit = "2000m"
openai_secret_name = "openai-api-key-prod"
data_disk_prevent_destroy = true
enable_snapshot_schedule = true
snapshot_retention_days = 7
```

### Multi-Environment Deployment

```bash
# Deploy to development
terraform apply -var-file="environments/dev.tfvars"

# Deploy to staging
terraform apply -var-file="environments/staging.tfvars"

# Deploy to production
terraform apply -var-file="environments/prod.tfvars"
```

---

## Validation

### Verify Configuration

```bash
# Check environment variables in Cloud Run
gcloud run services describe edgequake-api \
  --region us-central1 \
  --format='value(spec.template.spec.containers[0].env)'

# Test database connection
gcloud compute ssh edgequake-db-vm --zone=us-central1-a \
  --command="docker exec postgres psql -U postgres -d graph_db -c 'SELECT version();'"

# Verify secrets
gcloud secrets versions access latest --secret="openai-api-key"
```

### Health Checks

```bash
# API health
curl https://edgequake-api-xxx.run.app/health

# Expected response:
# {
#   "status": "healthy",
#   "database": "connected",
#   "version": "0.1.0"
# }

# WebUI health
curl https://edgequake-webui-xxx.run.app/api/health

# Expected response:
# {"status":"ok"}
```

---

## Troubleshooting

### Missing Environment Variables

```bash
# List all environment variables
gcloud run services describe SERVICE_NAME \
  --region us-central1 \
  --format='table(spec.template.spec.containers[0].env[].name, spec.template.spec.containers[0].env[].value)'
```

### Secret Access Denied

```bash
# Verify service account has access
gcloud secrets get-iam-policy openai-api-key

# Grant access if needed
gcloud secrets add-iam-policy-binding openai-api-key \
  --member="serviceAccount:SERVICE_ACCOUNT" \
  --role="roles/secretmanager.secretAccessor"
```

### Database Connection Issues

```bash
# Test from Cloud Run
gcloud run services update edgequake-api \
  --region us-central1 \
  --set-env-vars="RUST_LOG=debug"

# Check logs
gcloud logging read \
  "resource.type=cloud_run_revision AND resource.labels.service_name=edgequake-api AND textPayload=~'database'" \
  --limit 50
```

---

**Last Updated:** January 4, 2026  
**Version:** 1.0  
**Related Docs:** 
- [Quick Start Guide](17-edgequake-quick-start.md)
- [Territory Map](16-edgequake-deployment-complete-guide.md)
- [Database Configuration](09-database-connection-config.md)

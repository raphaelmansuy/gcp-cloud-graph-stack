# Edgequake Integration: Complete Configuration Summary

This document provides a quick reference for configuring the Edgequake application to connect to the PostgreSQL database in the GCP infrastructure.

## Quick Start Checklist

### 1. Rust API (Backend) Configuration

**What it needs:**
- Read 3 environment variables from Cloud Run:
  - `DATABASE_HOST` (internal IP of PostgreSQL VM)
  - `DATABASE_PORT` (default: 5432)
  - `DATABASE_NAME` (hardcoded: graph_db)

**Key steps:**
1. Add `sqlx` crate with PostgreSQL driver to `Cargo.toml`
2. Build connection string: `postgresql://postgres@{HOST}:{PORT}/{DB}?sslmode=require`
3. Create connection pool using `sqlx::PgPoolOptions`
4. Implement `GET /health` endpoint (required by Cloud Run)
5. Expose API on `PORT` env var (default: 8080)

**Example code snippet:**
```rust
let db_url = format!(
    "postgresql://postgres@{}:{}/{}?sslmode=require",
    env::var("DATABASE_HOST")?,
    env::var("DATABASE_PORT")?,
    env::var("DATABASE_NAME")?
);
let pool = PgPoolOptions::new()
    .max_connections(10)
    .connect(&db_url)
    .await?;
```

**Status:** Terraform automatically passes these env vars to Cloud Run ✓

---

### 2. Next.js Frontend Configuration

**What it needs:**
- Read `API_URL` environment variable (injected by Terraform)
- Call Rust API via HTTP, **NOT** directly to the database
- No database credentials in frontend code

**Key steps:**
1. Read `NEXT_PUBLIC_API_URL` or `API_URL` env var
2. Create API routes (e.g., `/api/graphs`) that proxy calls to Rust API
3. Fetch from those routes in React components
4. No direct PostgreSQL connections

**Example:**
```javascript
// pages/api/graphs.js
const apiUrl = process.env.NEXT_PUBLIC_API_URL;
const response = await fetch(`${apiUrl}/graphs`);
```

**Status:** Terraform automatically passes API_URL (Rust service URI) to Cloud Run ✓

---

### 3. PostgreSQL Database Setup

**What's automatic:**
- PostgreSQL 16 installed on Compute Engine VM
- `graph_db` database created
- Extensions installed: `age`, `pgvector`
- SSL enabled with self-signed cert
- Firewall rules configured (Cloud Run → VM on port 5432)
- Daily snapshots created (3-day retention)
- Data persists on separate disk (`/mnt/data`)

**Configuration in Terraform:**
```hcl
db_port              = 5432              # Change if needed
postgresql_version   = "16"              # Update when upgrading
enable_wal_archiving = false             # Set true for GCS backups
create_data_disk     = true              # Persistent storage
data_disk_prevent_destroy = true         # Protect from deletion
```

**Status:** Fully automatic via startup script ✓

---

## Architecture Flow

```
┌─────────────────────────────────────────────────────────┐
│  GitHub (raphaelmansuy/edgequake)                       │
│  - Rust API code with DATABASE_* env var reading       │
│  - Next.js frontend with API_URL env var reading       │
└─────────────────────────────────────────────────────────┘
                        │
                        │ Git push → GitHub Actions
                        │ (build, test, push to Artifact Registry)
                        v
┌─────────────────────────────────────────────────────────┐
│  Artifact Registry (us-central1-docker.pkg.dev)         │
│  - nextjs:sha                                           │
│  - rust-api:sha                                         │
└─────────────────────────────────────────────────────────┘
                        │
                        │ repository_dispatch (with image URLs)
                        v
┌─────────────────────────────────────────────────────────┐
│  GitHub (raphaelmansuy/gcp-cloud-graph-stack)           │
│  - Deploy-on-dispatch workflow receives images          │
│  - Terraform plan/apply with image URLs                │
│  - Injects DATABASE_* vars to Rust API                 │
│  - Injects API_URL to Next.js                          │
└─────────────────────────────────────────────────────────┘
                        │
                        │ terraform apply
                        v
┌─────────────────────────────────────────────────────────┐
│  GCP: Cloud Run Services                                │
│  ├─ Next.js (front end, env: API_URL)                  │
│  └─ Rust API (backend, env: DATABASE_*)                │
└─────────────────────────────────────────────────────────┘
                        │
                        │ TCP/SSL via VPC Connector
                        v
┌─────────────────────────────────────────────────────────┐
│  GCP: Compute Engine VM                                 │
│  ├─ PostgreSQL 16 (graph_db)                           │
│  ├─ Extensions: age, pgvector                          │
│  └─ Persistent disk: /mnt/data                         │
└─────────────────────────────────────────────────────────┘
```

---

## Implementation Steps (For Edgequake Repo)

### Step 1: Update Rust API Codebase

**File: `edgequake/Cargo.toml`**
```toml
[dependencies]
sqlx = { version = "0.7", features = ["runtime-tokio-rustls", "postgres"] }
tokio = { version = "1", features = ["full"] }
axum = "0.7"
```

**File: `edgequake/src/main.rs`** (or wherever you initialize the app)
```rust
// Read env vars and create connection pool
let db_url = format!(
    "postgresql://postgres@{}:{}/{}?sslmode=require",
    std::env::var("DATABASE_HOST").unwrap_or("localhost".to_string()),
    std::env::var("DATABASE_PORT").unwrap_or("5432".to_string()),
    std::env::var("DATABASE_NAME").unwrap_or("graph_db".to_string()),
);

let pool = PgPoolOptions::new()
    .max_connections(10)
    .connect(&db_url)
    .await?;

// Implement /health endpoint
app.route("/health", get(|| async { (StatusCode::OK, "OK") }))
```

### Step 2: Update Next.js Codebase

**File: `edgequake_webui/.env.local` (for local dev)**
```bash
NEXT_PUBLIC_API_URL=http://localhost:8080
```

**File: `edgequake_webui/.env.production` (for Cloud Run)**
```bash
# This will be auto-injected by Terraform
NEXT_PUBLIC_API_URL=https://<rust-api-url>.run.app
```

**File: `edgequake_webui/pages/api/graphs.ts`** (create API proxy routes)
```typescript
export default async function handler(req, res) {
  const apiUrl = process.env.NEXT_PUBLIC_API_URL;
  const response = await fetch(`${apiUrl}/graphs`);
  res.json(await response.json());
}
```

### Step 3: Build & Push Images

Use the GitHub Actions workflow from `docs/08-github-actions-deploy-edgequake.md`:
```bash
# In .github/workflows/build-and-push.yml (in edgequake repo)
docker build -t us-central1-docker.pkg.dev/saas-app-001/edgequake-images/rust-api:$SHA -f edgequake/Dockerfile .
docker push us-central1-docker.pkg.dev/saas-app-001/edgequake-images/rust-api:$SHA
```

### Step 4: Deploy via Terraform

The dispatch workflow will run:
```bash
terraform plan \
  -var="nextjs_image_url=us-central1-docker.pkg.dev/.../nextjs:$SHA" \
  -var="rust_api_image_url=us-central1-docker.pkg.dev/.../rust-api:$SHA"
```

This automatically injects:
- `DATABASE_HOST` (VM private IP)
- `DATABASE_PORT` (5432 or custom)
- `DATABASE_NAME` (graph_db)
- `API_URL` (Rust service URI)

---

## Network & Connectivity

### Rust API → PostgreSQL

| Component | Type | Path | Port |
|-----------|------|------|------|
| Cloud Run | Managed service | VPC Connector | 5432 |
| Compute Engine VM | Internal | Private subnet | 5432 |
| Connection | Private VPC | Routed via VPC Connector | Encrypted SSL |

**Firewall rule (automatic):**
- Source: Cloud Run service account
- Destination: VM on port 5432
- Protocol: TCP
- Action: Allow

### Next.js → Rust API

| Component | Type | Path | Port |
|-----------|------|------|------|
| Next.js | Cloud Run public | Internet | 443 |
| Rust API | Cloud Run public | Internet | 443 |
| Connection | HTTPS | Google-managed DNS | Public |

---

## Troubleshooting

### "Connection refused" from Rust API to PostgreSQL

**Causes:**
- Firewall rule not applied (check VPC settings in Terraform)
- Wrong `DATABASE_HOST` or `DATABASE_PORT` env vars
- PostgreSQL not running on VM

**Fix:**
```bash
# Verify firewall rule
gcloud compute firewall-rules list --filter="name:cloud-run-to-vm"

# Verify env vars in Cloud Run
gcloud run services describe <rust-api-service> --region=us-central1 --format='value(spec.template.spec.containers[0].env)'

# Check PostgreSQL on VM
gcloud compute ssh <vm-name> --zone=us-central1-a
sudo systemctl status postgresql
```

### SSL certificate error

**Cause:** Self-signed cert not trusted

**Fix:** Ensure your Rust connection string uses `sslmode=require`:
```rust
let db_url = "postgresql://postgres@host:5432/graph_db?sslmode=require";
```

Or disable SSL cert verification (dev only):
```rust
let db_url = "postgresql://postgres@host:5432/graph_db?sslmode=disable";
```

### Database not found or extensions missing

**Check:**
```bash
gcloud compute ssh <vm-name> --zone=us-central1-a
sudo -u postgres psql -d graph_db -c "\dx"  # List extensions
sudo -u postgres psql -d graph_db -c "SELECT * FROM age_graph;"  # List graphs
```

**Common issues:**
- Startup script didn't run (check VM metadata)
- Extensions failed to install (check `/var/log/syslog`)
- Database not created (rare; should be automatic)

---

## Production Checklist

Before deploying to production:

- [ ] **Rust API**
  - [ ] Reads `DATABASE_HOST`, `DATABASE_PORT`, `DATABASE_NAME` from env
  - [ ] Implements connection pooling (10-20 max connections)
  - [ ] Has `/health` endpoint for Cloud Run monitoring
  - [ ] Uses `sslmode=require` for PostgreSQL
  - [ ] Proper error logging and tracing
  - [ ] Rate limiting on public endpoints

- [ ] **Next.js Frontend**
  - [ ] Reads `NEXT_PUBLIC_API_URL` from env
  - [ ] Uses API routes to call Rust API (not direct DB)
  - [ ] No hardcoded database credentials
  - [ ] No `DATABASE_*` env vars exposed to frontend

- [ ] **Infrastructure (Terraform)**
  - [ ] `db_port` set correctly (default 5432)
  - [ ] `data_disk_prevent_destroy = true` (protects from deletion)
  - [ ] `snapshot_retention_days = 3` (or more for production)
  - [ ] `enable_wal_archiving = true` (optional, for disaster recovery)
  - [ ] VPC CIDR doesn't conflict with existing networks
  - [ ] Cloud Run services have proper IAM roles

- [ ] **Monitoring & Logging**
  - [ ] Cloud Logging filters set for debug exclusions
  - [ ] Uptime monitoring enabled for Cloud Run services
  - [ ] Database backup/snapshot schedule verified
  - [ ] Alerts configured for high CPU/memory

---

## Documentation Files Reference

| File | Purpose |
|------|---------|
| [08-github-actions-deploy-edgequake.md](./08-github-actions-deploy-edgequake.md) | CI/CD workflow setup (build → push → deploy) |
| [09-database-connection-config.md](./09-database-connection-config.md) | Database connection details & Rust API code examples |
| [10-environment-configuration-examples.md](./10-environment-configuration-examples.md) | Complete `.env` files & Docker Compose setup |
| [07-db-disk-ops.md](./07-db-disk-ops.md) | Database disk operations (snapshots, backups) |
| [02-deployment-terraform.md](./02-deployment-terraform.md) | Terraform deployment instructions |

---

## Key Takeaways

1. **PostgreSQL is fully managed by Terraform** – no manual setup needed
2. **Rust API must implement DB connection pool** – template provided
3. **Next.js must call Rust API, not database** – API routes pattern shown
4. **Environment variables are auto-injected by Terraform** – no hardcoding
5. **SSL is enabled** – self-signed certs are OK for internal VPC
6. **Data is persistent** – separate disk with snapshots and protection
7. **CI/CD is fully documented** – see workflow files for automation

---

## Next Steps

1. **Update edgequake repo:**
   - Add sqlx to Cargo.toml
   - Implement DB connection pool in Rust
   - Add API routes in Next.js
   - Push to GitHub

2. **Trigger CI/CD:**
   - GitHub Actions builds and pushes images
   - Sends dispatch to infra repo
   - Terraform applies with image URLs
   - Services deployed with env vars

3. **Monitor & verify:**
   - Check `/health` endpoints
   - Query Cloud Logs for errors
   - Test API calls from Next.js
   - Verify database connectivity

---

For detailed implementation examples, see [10-environment-configuration-examples.md](./10-environment-configuration-examples.md).

# Database Connection Configuration for Edgequake

This guide explains how the Edgequake application (Next.js frontend + Rust API) connects to the PostgreSQL database, and what configuration is required.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│  Cloud Run: Next.js (edgequake_webui)                  │
│  - Communicates with Rust API via HTTP                 │
│  - No direct database connection                        │
│  - Environment: API_URL pointing to Rust API           │
└─────────────────────────────────────────────────────────┘
                        │
                        │ HTTP
                        v
┌─────────────────────────────────────────────────────────┐
│  Cloud Run: Rust API (edgequake)                        │
│  - Has direct PostgreSQL connection                     │
│  - Environment: DATABASE_HOST, DATABASE_PORT, etc.     │
│  - Manages all graph database operations                │
└─────────────────────────────────────────────────────────┘
                        │
                        │ TCP/SSL
                        v
┌─────────────────────────────────────────────────────────┐
│  Compute Engine VM (PostgreSQL 16)                      │
│  - graph_db database created at startup                 │
│  - Extensions: age, pgvector                           │
│  - Schema: graph (for graph tables)                     │
│  - Firewall rule: allows Cloud Run → VM on port 5432   │
└─────────────────────────────────────────────────────────┘
```

---

## 1. PostgreSQL Database Setup (Terraform)

### Automatic Initialization

The `terraform/modules/compute/startup-script.sh` automatically:

1. **Installs PostgreSQL 16** with dev packages
2. **Creates `graph_db` database**
3. **Installs extensions:**
   - `age` – Apache Graph Extension for graph queries
   - `vector` – pgvector for embeddings
4. **Creates `graph` schema** and sample tables
5. **Configures SSL** with self-signed certs
6. **Sets up WAL archiving** (if enabled) to GCS bucket
7. **Enables audit logging** (log_statement = 'all')

### Database Connection Details

| Parameter | Value | Notes |
|-----------|-------|-------|
| **Host** | VM private IP (internal network) | e.g., `10.0.1.2` |
| **Port** | Configurable via `db_port` variable | Default: `5432`, customizable |
| **Database** | `graph_db` | Hardcoded in startup script |
| **User** | `postgres` | Default system user, no password required (local connections) |
| **SSL** | Enabled | Self-signed certs; clients may need `sslmode=require` |
| **Network** | Private VPC | Accessible only via VPC Connector or Cloud Run → VPC bridge |

### Terraform Variables

In `terraform/terraform.tfvars`:

```hcl
# Database configuration
db_port              = 5432  # PostgreSQL listening port (can be custom)
postgresql_version   = "16"  # PostgreSQL version
enable_wal_archiving = false # Set to true for GCS WAL backup

# Data disk (for persistent storage)
create_data_disk      = true
data_disk_size        = 50                # GB
data_disk_prevent_destroy = true          # Prevent accidental deletion
snapshot_retention_days = 3               # Keep 3 days of daily snapshots
```

---

## 2. Rust API Configuration (edgequake)

### Environment Variables Passed by Terraform

The Rust API container receives these environment variables from Terraform:

```yaml
DATABASE_HOST: "<COMPUTE_ENGINE_VM_PRIVATE_IP>"  # e.g., 10.0.1.2
DATABASE_PORT: "5432"
DATABASE_NAME: "graph_db"
ENVIRONMENT: "production"
```

### What Rust API Needs to Implement

Your Rust API code must:

1. **Read environment variables:**
   ```rust
   let db_host = std::env::var("DATABASE_HOST").unwrap_or("localhost".to_string());
   let db_port = std::env::var("DATABASE_PORT").unwrap_or("5432".to_string());
   let db_name = std::env::var("DATABASE_NAME").unwrap_or("graph_db".to_string());
   ```

2. **Connect to PostgreSQL** using a connection string:
   ```
   postgresql://postgres@{DATABASE_HOST}:{DATABASE_PORT}/{DATABASE_NAME}?sslmode=require
   ```

3. **Recommended libraries:**
   - `sqlx` – async SQL toolkit with compile-time query verification
   - `tokio-postgres` – low-level async Postgres driver
   - `sqlx-postgres` – with connection pooling

4. **Example Cargo.toml**:
   ```toml
   [dependencies]
   sqlx = { version = "0.7", features = ["runtime-tokio-rustls", "postgres"] }
   tokio = { version = "1", features = ["full"] }
   axum = "0.7"  # or your chosen web framework
   ```

5. **Connection pool setup**:
   ```rust
   use sqlx::postgres::PgPoolOptions;

   let database_url = format!(
       "postgresql://postgres@{}:{}/{}?sslmode=require",
       std::env::var("DATABASE_HOST").unwrap(),
       std::env::var("DATABASE_PORT").unwrap(),
       std::env::var("DATABASE_NAME").unwrap(),
   );

   let pool = PgPoolOptions::new()
       .max_connections(10)
       .connect(&database_url)
       .await?;
   ```

6. **Health check endpoint** (required by Cloud Run):
   - Implement `GET /health` returning HTTP 200
   - Example: `SELECT 1 FROM pg_database WHERE datname='graph_db'`

### Database Queries in Rust

Once connected, your Rust API can:

```rust
// Example: Query a graph
sqlx::query_as::<_, (String,)>(
    "SELECT * FROM graph.sample_graph LIMIT 10"
)
.fetch_all(&pool)
.await?;

// Example: Vector similarity search
sqlx::query_as::<_, (i32, Vec<f32>)>(
    "SELECT id, embedding FROM graph.vectors \
     ORDER BY embedding <-> $1 LIMIT 10"
)
.bind(&query_vector)
.fetch_all(&pool)
.await?;

// Example: Graph traversal (using AGE)
sqlx::query("LOAD 'age'; SET search_path = graph, public;")
    .execute(&pool)
    .await?;
```

---

## 3. Next.js Frontend Configuration (edgequake_webui)

### Environment Variables

The Next.js frontend receives:

```yaml
NODE_ENV: "production"
API_URL: "http://<RUST_API_SERVICE_URI>"  # e.g., http://rust-api-abc123.run.app
```

### What Next.js Needs to Implement

Your Next.js application must:

1. **Fetch data from Rust API**, not directly from the database:
   ```javascript
   // Example: pages/api/graphs.js (API route that calls Rust API)
   export default async function handler(req, res) {
     const apiUrl = process.env.API_URL;
     const response = await fetch(`${apiUrl}/graphs`);
     const data = await response.json();
     res.status(200).json(data);
   }
   ```

2. **Never embed database credentials** in frontend code

3. **Use `API_URL` environment variable**:
   ```javascript
   const apiUrl = process.env.NEXT_PUBLIC_API_URL || process.env.API_URL;
   ```

4. **Example fetch in a React component**:
   ```jsx
   import { useEffect, useState } from 'react';

   export default function GraphsPage() {
     const [graphs, setGraphs] = useState([]);

     useEffect(() => {
       fetch('/api/graphs')
         .then(r => r.json())
         .then(data => setGraphs(data));
     }, []);

     return <div>{/* render graphs */}</div>;
   }
   ```

---

## 4. Network & Firewall Configuration

### VPC Setup

Terraform automatically creates:

1. **VPC Network** (`edgequake-vpc`)
   - CIDR: `10.0.0.0/16` (customizable)
   - Subnet: `edgequake-subnet-us-central1`

2. **Cloud Run VPC Connector**
   - Enables Cloud Run services to reach internal VMs via private IP
   - Throughput: 300-1000 Mbps (autoscaled)

3. **Firewall Rules**
   - Cloud Run → VM on port 5432 (PostgreSQL)
   - Allows traffic from Cloud Run service accounts to database

### Connectivity Flow

```
1. Next.js → Rust API
   - Public HTTPS (Cloud Run ingress)
   - Via: google-managed DNS
   - Port: 443 (HTTPS)

2. Rust API → PostgreSQL
   - Private VPC (VPC Connector)
   - Via: internal subnet routing
   - Port: 5432 (PostgreSQL)
   - SSL: enabled (self-signed cert)
```

---

## 5. Secrets Management (Optional but Recommended)

For production, consider using Google Secret Manager:

### Rust API Secret Configuration

If you need credentials (e.g., for external services or replication):

```hcl
# In terraform/main.tf
resource "google_secret_manager_secret" "db_password" {
  secret_id = "postgres-password"
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = var.postgres_password
}

# Grant Cloud Run service account access to secret
resource "google_secret_manager_secret_iam_member" "rust_api_secret_accessor" {
  secret_id = google_secret_manager_secret.db_password.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}
```

Then in your Rust code:

```rust
use google_authz::credentials::secret_manager;

let password = secret_manager::get_secret("postgres-password").await?;
```

---

## 6. Configuration Checklist for Edgequake

### Before Deploying Images

- [ ] **Rust API** reads `DATABASE_HOST`, `DATABASE_PORT`, `DATABASE_NAME` from environment
- [ ] **Rust API** implements `GET /health` endpoint for Cloud Run health checks
- [ ] **Rust API** uses SSL (`sslmode=require` or similar) when connecting to PostgreSQL
- [ ] **Rust API** has connection pooling (10-20 connections max)
- [ ] **Next.js** reads `API_URL` and calls Rust API (not database directly)
- [ ] **Next.js** implements API routes if needed to proxy Rust API calls

### During Terraform Apply

- [ ] `terraform.tfvars` specifies correct `db_port` and `postgresql_version`
- [ ] VPC CIDR does not conflict with your org's other networks
- [ ] `enable_wal_archiving` set to true if you want GCS WAL backups

### After Deployment

- [ ] Test Rust API connection: `curl https://<rust-api-url>/health`
- [ ] Check PostgreSQL logs on VM:
  ```bash
  gcloud compute ssh <vm-instance> --zone=us-central1-a
  sudo journalctl -u postgresql -f
  ```
- [ ] Query database directly (for testing):
  ```bash
  gcloud compute ssh <vm-instance> --zone=us-central1-a
  sudo -u postgres psql -d graph_db -c "\dx"  # List extensions
  ```

---

## 7. Common Issues & Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| **"Connection refused"** | Firewall rule missing or port wrong | Check VPC Connector → VM firewall rules; verify `db_port` in Terraform |
| **"SSL certificate problem"** | Self-signed cert not trusted | Use `sslmode=require` or add CA cert to container image |
| **"DATABASE_HOST not found"** | Cloud Run not receiving env vars | Check Terraform module `cloud_run_rust_api` → `environment_variables` block |
| **"Too many connections"** | Connection pool exhausted | Reduce `max_connections` in Rust code; scale Cloud Run instances |
| **"Extension 'age' not found"** | AGE not installed | Verify startup script ran; check `psql \dx` on VM |
| **Slow queries** | Missing indexes on vector columns | Verify HNSW index created in startup script |

---

## 8. Example: Complete Rust API Startup

```rust
use sqlx::postgres::PgPoolOptions;
use axum::{
    http::StatusCode,
    response::IntoResponse,
    routing::get,
    Router,
};
use std::net::SocketAddr;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Read environment variables
    let db_host = std::env::var("DATABASE_HOST").unwrap_or("localhost".to_string());
    let db_port = std::env::var("DATABASE_PORT").unwrap_or("5432".to_string());
    let db_name = std::env::var("DATABASE_NAME").unwrap_or("graph_db".to_string());
    let port = std::env::var("PORT").unwrap_or("8080".to_string());

    // Build connection string
    let database_url = format!(
        "postgresql://postgres@{}:{}/{}?sslmode=require",
        db_host, db_port, db_name
    );

    // Create connection pool
    let pool = PgPoolOptions::new()
        .max_connections(10)
        .connect(&database_url)
        .await?;

    // Verify connection
    sqlx::query("SELECT 1")
        .fetch_one(&pool)
        .await?;

    println!("✓ Connected to PostgreSQL at {}:{}/{}", db_host, db_port, db_name);

    // Build router
    let app = Router::new()
        .route("/health", get(health_check))
        .with_state(pool);

    // Listen
    let listener = tokio::net::TcpListener::bind(format!("0.0.0.0:{}", port)).await?;
    axum::serve(listener, app).await?;

    Ok(())
}

async fn health_check() -> impl IntoResponse {
    (StatusCode::OK, "OK")
}
```

---

## 9. References

- **PostgreSQL 16 Docs**: https://www.postgresql.org/docs/16/
- **Apache AGE**: https://github.com/apache/age
- **pgvector**: https://github.com/pgvector/pgvector
- **sqlx (Rust)**: https://github.com/launchbadge/sqlx
- **Google Cloud SQL Proxy** (alternative): https://cloud.google.com/sql/docs/postgres/sql-proxy
- **Cloud Run Networking**: https://cloud.google.com/run/docs/configuring/connecting-vpc
- **Terraform Google Provider**: https://registry.terraform.io/providers/hashicorp/google/latest/docs

---

## Next Steps

1. **Clone edgequake repo** and update Rust API code to:
   - Read the three environment variables
   - Build connection string dynamically
   - Implement connection pool
   - Add health check endpoint

2. **Update Next.js** to call Rust API (not database directly)

3. **Build & push images** using the GitHub Actions workflow from the CI/CD guide

4. **Verify in Cloud Run**: Check logs and `/health` endpoints

5. **Monitor in Cloud Logging**: Filter by `resource.type="cloud_run_revision"` to see connection logs

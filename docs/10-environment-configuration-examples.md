# Environment Configuration Files for Edgequake

This document provides example environment configuration files for both the Rust API and Next.js frontend.

## 1. Rust API Environment File (`.env.local` or `.env.production`)

### Development Environment (Local)

```bash
# File: .env.local (for local development with Docker Compose)

# Database connection
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_NAME=graph_db
DATABASE_USER=postgres

# API configuration
PORT=8080
ENVIRONMENT=development
LOG_LEVEL=debug

# CORS (if needed)
CORS_ORIGIN=http://localhost:3000

# Optional: External services
OPENAI_API_KEY=sk-...
```

### Production Environment (Cloud Run)

```bash
# File: .env.production (for Cloud Run on GCP)
# Note: Most of these are set by Terraform automatically

# Database connection (injected by Terraform)
DATABASE_HOST=10.0.1.2          # Private IP of Compute Engine VM
DATABASE_PORT=5432             # Or custom port from terraform.tfvars
DATABASE_NAME=graph_db         # Hardcoded in startup script

# API configuration
PORT=8080                       # Required by Cloud Run
ENVIRONMENT=production
LOG_LEVEL=info

# CORS
CORS_ORIGIN=https://edgequake-ui.run.app

# Optional: Secrets from Google Secret Manager
# These would be loaded from Secret Manager via Cloud Run env vars
OPENAI_API_KEY=<from-secret-manager>
DATABASE_PASSWORD=<from-secret-manager>  # if using password auth
```

---

## 2. Rust API `Cargo.toml` with Database Dependencies

```toml
[package]
name = "edgequake-api"
version = "0.1.0"
edition = "2021"

[dependencies]
# Web framework
axum = "0.7"
tokio = { version = "1", features = ["full"] }
tower = "0.4"
tower-http = { version = "0.5", features = ["trace", "cors"] }

# Database
sqlx = { version = "0.7", features = [
    "runtime-tokio-rustls",  # async runtime + TLS
    "postgres",              # PostgreSQL driver
    "chrono",                # date/time support
    "json",                  # JSONB support
    "uuid",                  # UUID support
] }
tokio-postgres = "0.7"      # Low-level driver (alternative)

# Environment & config
dotenv = "0.15"
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter"] }

# Error handling
thiserror = "1.0"
anyhow = "1.0"

# Utilities
uuid = { version = "1.0", features = ["v4", "serde"] }
chrono = { version = "0.4", features = ["serde"] }
```

---

## 3. Rust API Main.rs Initialization Code

```rust
// File: src/main.rs

use axum::{
    http::StatusCode,
    response::IntoResponse,
    routing::{get, post},
    Router,
    State,
};
use sqlx::postgres::PgPoolOptions;
use std::sync::Arc;
use tower_http::trace::TraceLayer;
use tracing::info;

#[derive(Clone)]
pub struct AppState {
    pub db_pool: sqlx::PgPool,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Initialize tracing (logging)
    tracing_subscriber::fmt()
        .with_env_filter(
            std::env::var("LOG_LEVEL")
                .unwrap_or_else(|_| "info".to_string())
                .parse()?,
        )
        .init();

    // Load environment variables from .env files
    dotenv::dotenv().ok();

    // Read database configuration from environment
    let db_host = std::env::var("DATABASE_HOST").unwrap_or("localhost".to_string());
    let db_port = std::env::var("DATABASE_PORT").unwrap_or("5432".to_string());
    let db_name = std::env::var("DATABASE_NAME").unwrap_or("graph_db".to_string());
    let db_user = std::env::var("DATABASE_USER").unwrap_or("postgres".to_string());

    // Build PostgreSQL connection string
    let database_url = format!(
        "postgresql://{}@{}:{}/{}?sslmode=require",
        db_user, db_host, db_port, db_name
    );

    info!("Connecting to database at {}:{}/{}", db_host, db_port, db_name);

    // Create connection pool
    let pool = PgPoolOptions::new()
        .max_connections(10)
        .acquire_timeout(std::time::Duration::from_secs(10))
        .connect(&database_url)
        .await?;

    // Test connection
    sqlx::query("SELECT 1")
        .fetch_one(&pool)
        .await?;

    info!("✓ Successfully connected to PostgreSQL");

    // Create application state
    let state = AppState { db_pool: pool };

    // Build router
    let app = Router::new()
        .route("/health", get(health_check))
        .route("/graphs", get(list_graphs))
        .route("/graphs", post(create_graph))
        .layer(TraceLayer::new_for_http())
        .with_state(state);

    // Start server
    let port = std::env::var("PORT").unwrap_or("8080".to_string());
    let listener = tokio::net::TcpListener::bind(format!("0.0.0.0:{}", port)).await?;
    
    info!("🚀 Server listening on 0.0.0.0:{}", port);

    axum::serve(listener, app).await?;

    Ok(())
}

// Health check endpoint (required by Cloud Run)
async fn health_check(State(state): State<AppState>) -> impl IntoResponse {
    match sqlx::query("SELECT 1")
        .fetch_one(&state.db_pool)
        .await
    {
        Ok(_) => (StatusCode::OK, "OK"),
        Err(_) => (StatusCode::SERVICE_UNAVAILABLE, "Database unavailable"),
    }
}

// Example: List graphs
async fn list_graphs(State(state): State<AppState>) -> impl IntoResponse {
    let result = sqlx::query_as::<_, (String,)>(
        "SELECT graph_name FROM age_graph ORDER BY graph_name"
    )
    .fetch_all(&state.db_pool)
    .await;

    match result {
        Ok(graphs) => (
            StatusCode::OK,
            axum::Json(
                serde_json::json!({
                    "graphs": graphs.into_iter().map(|(name,)| name).collect::<Vec<_>>()
                })
            ),
        ),
        Err(e) => (
            StatusCode::INTERNAL_SERVER_ERROR,
            axum::Json(serde_json::json!({"error": e.to_string()})),
        ),
    }
}

// Example: Create graph
async fn create_graph(
    State(state): State<AppState>,
    axum::Json(payload): axum::Json<serde_json::Value>,
) -> impl IntoResponse {
    let graph_name = match payload.get("name") {
        Some(serde_json::Value::String(name)) => name.clone(),
        _ => return (StatusCode::BAD_REQUEST, "Invalid name"),
    };

    match sqlx::query(&format!("SELECT * FROM create_graph('{}');", graph_name))
        .execute(&state.db_pool)
        .await
    {
        Ok(_) => (StatusCode::CREATED, "Graph created"),
        Err(e) => (
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("Error: {}", e),
        ),
    }
}
```

---

## 4. Next.js Frontend Environment File (`.env.local` and `.env.production`)

### Development Environment

```bash
# File: .env.local

# API endpoint (local development)
NEXT_PUBLIC_API_URL=http://localhost:8080
NEXT_PUBLIC_APP_NAME=Edgequake (Dev)

# Optional: Analytics
NEXT_PUBLIC_ANALYTICS_ID=

# Optional: Feature flags
NEXT_PUBLIC_ENABLE_ADMIN=true
NEXT_PUBLIC_DEBUG_MODE=true
```

### Production Environment (Cloud Run)

```bash
# File: .env.production

# API endpoint (injected by Terraform)
# This is the Rust API Cloud Run URL
NEXT_PUBLIC_API_URL=https://rust-api-abc123-us-central1.a.run.app
NEXT_PUBLIC_APP_NAME=Edgequake

# Analytics (if using)
NEXT_PUBLIC_ANALYTICS_ID=G-XXXXXXXXXX

# Feature flags
NEXT_PUBLIC_ENABLE_ADMIN=false
NEXT_PUBLIC_DEBUG_MODE=false

# Secret backend keys (never public)
# These are NOT sent to the browser
API_SECRET_KEY=<from-secret-manager>
```

---

## 5. Next.js API Route Example (Proxy to Rust API)

```typescript
// File: pages/api/graphs.ts

import type { NextApiRequest, NextApiResponse } from 'next';

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080';

  try {
    const response = await fetch(`${apiUrl}/graphs`, {
      method: req.method,
      headers: {
        'Content-Type': 'application/json',
        // Forward auth headers if needed
        ...(req.headers.authorization && {
          'Authorization': req.headers.authorization,
        }),
      },
      body: req.method !== 'GET' ? JSON.stringify(req.body) : undefined,
    });

    const data = await response.json();
    res.status(response.status).json(data);
  } catch (error) {
    console.error('API Error:', error);
    res.status(500).json({ error: 'Failed to fetch from API' });
  }
}
```

---

## 6. Docker Compose for Local Development

```yaml
# File: docker-compose.yml

version: '3.8'

services:
  postgres:
    image: postgres:16-alpine
    container_name: edgequake-postgres
    environment:
      POSTGRES_DB: graph_db
      POSTGRES_USER: postgres
      POSTGRES_HOST_AUTH_METHOD: trust
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./scripts/init-db.sql:/docker-entrypoint-initdb.d/init.sql
    networks:
      - edgequake-network

  rust-api:
    build:
      context: .
      dockerfile: edgequake/Dockerfile
    container_name: edgequake-rust-api
    environment:
      DATABASE_HOST: postgres
      DATABASE_PORT: 5432
      DATABASE_NAME: graph_db
      DATABASE_USER: postgres
      PORT: 8080
      LOG_LEVEL: debug
    ports:
      - "8080:8080"
    depends_on:
      - postgres
    networks:
      - edgequake-network

  nextjs:
    build:
      context: .
      dockerfile: edgequake_webui/Dockerfile
    container_name: edgequake-nextjs
    environment:
      NEXT_PUBLIC_API_URL: http://rust-api:8080
      NODE_ENV: development
    ports:
      - "3000:3000"
    depends_on:
      - rust-api
    networks:
      - edgequake-network

volumes:
  postgres_data:

networks:
  edgequake-network:
    driver: bridge
```

### Start Local Environment

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Connect to postgres
docker-compose exec postgres psql -U postgres -d graph_db

# Stop all services
docker-compose down
```

---

## 7. Database Initialization Script (Optional)

```sql
-- File: scripts/init-db.sql
-- Run automatically on container startup (via docker-compose)

-- Create extensions
CREATE EXTENSION IF NOT EXISTS age;
CREATE EXTENSION IF NOT EXISTS vector;

-- Load AGE
LOAD 'age';

-- Create graph schema
CREATE SCHEMA IF NOT EXISTS graph;
SET search_path = graph, public;

-- Create a sample graph
SELECT * FROM create_graph('main_graph');

-- Create sample tables
CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  username VARCHAR(255) NOT NULL UNIQUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS embeddings (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(id),
  embedding vector(1536),
  metadata JSONB,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create HNSW index for vector similarity
CREATE INDEX IF NOT EXISTS embeddings_hnsw_idx ON embeddings
USING hnsw (embedding vector_cosine_ops)
WITH (m = 16, ef_construction = 200);

-- Sample graph data
SELECT * FROM cypher('main_graph', $$
  CREATE (alice:User {name: 'Alice', age: 30})
  CREATE (bob:User {name: 'Bob', age: 25})
  CREATE (alice)-[:KNOWS]->(bob)
$$) AS (result agtype);
```

---

## 8. Configuration Checklist

### Before Running Locally

- [ ] Clone edgequake repository
- [ ] Copy `.env.local.example` to `.env.local` and update values
- [ ] Rust API `.env.local` points to localhost PostgreSQL
- [ ] Next.js `.env.local` points to localhost Rust API
- [ ] Run `docker-compose up` to start services

### Before Deploying to GCP

- [ ] Rust API `.env.production` reads from environment (no hardcoded values)
- [ ] Rust API implements `/health` endpoint
- [ ] Next.js `.env.production` points to Rust API Cloud Run URL
- [ ] Build Docker images and push to Artifact Registry
- [ ] Run `terraform apply` to deploy infrastructure
- [ ] Verify Cloud Run services are running with correct env vars

### Post-Deployment Verification

```bash
# Check Rust API health
curl https://<rust-api-url>/health

# Check Next.js frontend
curl https://<nextjs-url>/

# View Cloud Run env vars
gcloud run services describe <service-name> --region=us-central1 --format='value(spec.template.spec.containers[0].env)'

# Check database from VM
gcloud compute ssh <vm-name> --zone=us-central1-a
sudo -u postgres psql -d graph_db -c "\dx"  # List extensions
```

---

## 9. References

- **sqlx Postgres**: https://github.com/launchbadge/sqlx
- **Axum Web Framework**: https://github.com/tokio-rs/axum
- **Next.js Env Vars**: https://nextjs.org/docs/basic-features/environment-variables
- **Docker Compose**: https://docs.docker.com/compose/
- **Cloud Run Env Vars**: https://cloud.google.com/run/docs/configuring/environment-variables

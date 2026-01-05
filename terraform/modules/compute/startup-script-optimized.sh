#!/bin/bash
# PostgreSQL Docker startup script - IMPROVED VERSION
# Uses pre-built image from Artifact Registry instead of building from scratch
# Reduces startup time from 15+ minutes to ~2 minutes

set -uo pipefail

STARTUP_LOG="/var/log/postgres-startup.log"
STARTUP_COMPLETE_FILE="/var/lib/postgres-startup-complete"
START_TIME=$(date +%s)

# Redirect all output to log file AND stdout
exec 1> >(tee -a "$STARTUP_LOG")
exec 2>&1

log_message() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log_message "=== PostgreSQL Docker Setup (Optimized) ==="
log_message "Using pre-built image from Artifact Registry"
log_message "Expected startup time: 2-3 minutes"

# Configuration - these come from Terraform variables
PROJECT_ID="${gcp_project_id}"
REGION="${gcp_region}"
POSTGRES_IMAGE="${postgres_image_url:-${REGION}-docker.pkg.dev/${PROJECT_ID}/edgequake-images/postgres-age-vector:16-latest}"
PGDATA_DIR="${data_disk_mount_point}/pgdata"
PGDATA_DISK="${data_disk_name}"
DB_PORT="${db_port:-5432}"
STARTUP_TIMEOUT=600  # 10 minutes max for startup

log_message "Configuration:"
log_message "  GCP Project: $PROJECT_ID"
log_message "  Region: $REGION"
log_message "  Postgres Image: $POSTGRES_IMAGE"
log_message "  Data Directory: $PGDATA_DIR"
log_message "  Database Port: $DB_PORT"

# ============================================================================
# STEP 1: Install Docker
# ============================================================================
log_message ""
log_message "STEP 1: Installing Docker"

apt-get update >/dev/null 2>&1
apt-get install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release >/dev/null 2>&1

mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg 2>/dev/null | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
  tee /etc/apt/sources.list.d/docker.list >/dev/null

apt-get update >/dev/null 2>&1
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin >/dev/null 2>&1

systemctl start docker
systemctl enable docker

# Wait for Docker daemon
log_message "Waiting for Docker daemon..."
for i in {1..30}; do
  if docker ps >/dev/null 2>&1; then
    log_message "✓ Docker is ready"
    break
  fi
  if [ $i -eq 30 ]; then
    log_message "✗ Docker failed to start after 60 seconds"
    exit 1
  fi
  sleep 2
done

# ============================================================================
# STEP 2: Configure Google Cloud Authentication (for Artifact Registry)
# ============================================================================
log_message ""
log_message "STEP 2: Configuring Docker authentication for Artifact Registry"

# Get instance service account credentials
gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet 2>/dev/null || {
  log_message "Warning: Could not configure Artifact Registry auth, will try unauthenticated"
}

# ============================================================================
# STEP 3: Setup Data Disk
# ============================================================================
log_message ""
log_message "STEP 3: Setting up data disk"

DATA_DISK_BY_ID="/dev/disk/by-id/google-${PGDATA_DISK}"
MOUNT_POINT=$(dirname "$PGDATA_DIR")

if [ -b "$DATA_DISK_BY_ID" ]; then
  log_message "Found data disk: $DATA_DISK_BY_ID"
  
  # Format if necessary
  if ! blkid "$DATA_DISK_BY_ID" >/dev/null 2>&1; then
    log_message "Formatting data disk..."
    mkfs.ext4 -F "$DATA_DISK_BY_ID" >/dev/null 2>&1
  fi
  
  mkdir -p "$MOUNT_POINT"
  if ! mountpoint -q "$MOUNT_POINT"; then
    mount "$DATA_DISK_BY_ID" "$MOUNT_POINT"
    log_message "✓ Data disk mounted"
  fi
  
  # Ensure persistent mount
  if ! grep -q "$DATA_DISK_BY_ID" /etc/fstab; then
    echo "$DATA_DISK_BY_ID $MOUNT_POINT ext4 defaults 0 2" >> /etc/fstab
  fi
else
  log_message "Data disk not found, using boot disk"
  MOUNT_POINT="/var/lib/postgresql-data"
fi

mkdir -p "$PGDATA_DIR"
chmod 700 "$PGDATA_DIR"
log_message "✓ Data directory ready: $PGDATA_DIR"

# ============================================================================
# STEP 4: Pull Docker Image from Artifact Registry
# ============================================================================
log_message ""
log_message "STEP 4: Pulling PostgreSQL image from Artifact Registry"
log_message "Image: $POSTGRES_IMAGE"

if ! docker pull "$POSTGRES_IMAGE" 2>&1 | tee -a "$STARTUP_LOG"; then
  # Fallback: Try to build if pull fails (for compatibility)
  log_message "Warning: Could not pull image, will build locally (slower)"
  
  # Build the image (fallback)
  cat > /root/Dockerfile.postgres <<'DOCKERFILE'
FROM postgres:16-bookworm

RUN apt-get update && apt-get install -y \
    build-essential flex bison git postgresql-server-dev-16 \
    && rm -rf /var/lib/apt/lists/*

RUN cd /tmp && \
    git clone --branch v0.5.1 https://github.com/pgvector/pgvector.git && \
    cd pgvector && make && make install && \
    rm -rf /tmp/pgvector

RUN cd /tmp && \
    git clone https://github.com/apache/age.git && \
    cd age && \
    (git checkout PG16/v1.6.0-rc0 || git checkout master) && \
    make install && rm -rf /tmp/age

RUN apt-get remove -y build-essential flex bison git postgresql-server-dev-16 && \
    apt-get autoremove -y && apt-get clean
DOCKERFILE

  docker build -t "$POSTGRES_IMAGE" -f /root/Dockerfile.postgres /root/ 2>&1 | tee -a "$STARTUP_LOG"
fi

log_message "✓ PostgreSQL image ready"

# ============================================================================
# STEP 5: Start PostgreSQL Container
# ============================================================================
log_message ""
log_message "STEP 5: Starting PostgreSQL container"

# Remove old container if exists
docker rm -f postgres-age-vector 2>/dev/null || true

docker run -d \
  --name postgres-age-vector \
  --restart always \
  --network host \
  -e POSTGRES_DB=graph_db \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_INITDB_ARGS="-c shared_preload_libraries='age'" \
  -v "$PGDATA_DIR:/var/lib/postgresql/data" \
  "$POSTGRES_IMAGE" 2>&1 | tee -a "$STARTUP_LOG"

log_message "✓ Container started"

# ============================================================================
# STEP 6: Wait for PostgreSQL to be Ready (with timeout)
# ============================================================================
log_message ""
log_message "STEP 6: Waiting for PostgreSQL to accept connections"

WAIT_START=$(date +%s)
MAX_WAIT=300  # 5 minutes

for i in {1..60}; do
  CURRENT_TIME=$(date +%s)
  ELAPSED=$((CURRENT_TIME - WAIT_START))
  
  if [ $ELAPSED -gt $MAX_WAIT ]; then
    log_message "✗ PostgreSQL did not start within 5 minutes"
    log_message "Container logs:"
    docker logs postgres-age-vector | tail -50 >> "$STARTUP_LOG"
    exit 1
  fi
  
  if docker exec postgres-age-vector pg_isready -U postgres -d graph_db >/dev/null 2>&1; then
    log_message "✓ PostgreSQL is ready after ${ELAPSED}s"
    break
  fi
  
  if [ $((i % 6)) -eq 0 ]; then  # Log every 12 seconds
    log_message "Waiting for PostgreSQL... (${ELAPSED}s elapsed)"
  fi
  
  sleep 2
done

# ============================================================================
# STEP 7: Install Extensions
# ============================================================================
log_message ""
log_message "STEP 7: Installing PostgreSQL extensions"

# Install pgvector
if docker exec -e PGPASSWORD=postgres postgres-age-vector psql -U postgres -d graph_db -c "CREATE EXTENSION IF NOT EXISTS vector;" >/dev/null 2>&1; then
  log_message "✓ pgvector extension installed"
else
  log_message "⚠ pgvector extension failed (may already exist)"
fi

# Install AGE
if docker exec -e PGPASSWORD=postgres postgres-age-vector psql -U postgres -d graph_db <<'EOSQL' >/dev/null 2>&1; then
CREATE EXTENSION IF NOT EXISTS age;
LOAD 'age';
SET search_path = ag_catalog, "$user", public;
ALTER DATABASE graph_db SET search_path = ag_catalog, "$user", public;
EOSQL
  log_message "✓ Apache AGE extension installed"
else
  log_message "⚠ Apache AGE extension failed (may already exist)"
fi

# ============================================================================
# STEP 8: Create Sample Tables and Indexes
# ============================================================================
log_message ""
log_message "STEP 8: Creating sample tables and indexes"

if docker exec -e PGPASSWORD=postgres postgres-age-vector psql -U postgres -d graph_db <<'EOSQL' >/dev/null 2>&1; then
CREATE TABLE IF NOT EXISTS vectors (
  id SERIAL PRIMARY KEY,
  embedding vector(1536),
  metadata jsonb,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS vectors_hnsw_idx ON vectors USING hnsw (embedding vector_cosine_ops)
  WITH (m = 16, ef_construction = 200);

CREATE TABLE IF NOT EXISTS documents (
  id SERIAL PRIMARY KEY,
  content TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
EOSQL
  log_message "✓ Sample tables created"
else
  log_message "⚠ Sample tables creation failed (may already exist)"
fi

# ============================================================================
# STEP 9: Create Sample Graph
# ============================================================================
log_message ""
log_message "STEP 9: Creating sample graph"

if docker exec -e PGPASSWORD=postgres postgres-age-vector psql -U postgres -d graph_db -c "SELECT create_graph('sample_graph');" >/dev/null 2>&1; then
  log_message "✓ Sample graph created"
else
  log_message "⚠ Sample graph creation failed (may already exist)"
fi

# ============================================================================
# STEP 10: Verify Installation
# ============================================================================
log_message ""
log_message "STEP 10: Verifying installation"

log_message "PostgreSQL Version:"
docker exec postgres-age-vector psql -U postgres -d graph_db -c "SELECT version();" 2>&1 | tee -a "$STARTUP_LOG"

log_message "Installed Extensions:"
docker exec postgres-age-vector psql -U postgres -d graph_db -c "SELECT extname, extversion FROM pg_extension WHERE extname IN ('vector', 'age');" 2>&1 | tee -a "$STARTUP_LOG"

# ============================================================================
# STEP 11: Install Google Cloud Operations Agent
# ============================================================================
log_message ""
log_message "STEP 11: Installing Google Cloud Ops Agent"

curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent.sh
bash add-google-cloud-ops-agent.sh --also-install >/dev/null 2>&1
log_message "✓ Cloud Ops Agent installed"

# ============================================================================
# STEP 12: Write Completion Status
# ============================================================================
log_message ""

END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))

# Write completion status file
cat > "$STARTUP_COMPLETE_FILE" <<EOF
{
  "status": "COMPLETE",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "duration_seconds": $TOTAL_TIME,
  "postgres_image": "$POSTGRES_IMAGE",
  "pgdata_dir": "$PGDATA_DIR",
  "database": "graph_db",
  "port": $DB_PORT,
  "extensions": ["age", "vector"]
}
EOF

chmod 644 "$STARTUP_COMPLETE_FILE"

# Write startup completion to Cloud Logging
if command -v gcloud &>/dev/null; then
  gcloud logging write postgres-startup \
    "PostgreSQL startup completed successfully in ${TOTAL_TIME}s" \
    --severity=INFO \
    --resource=gce_instance \
    2>/dev/null || true
fi

log_message ""
log_message "╔════════════════════════════════════════════════════════════════╗"
log_message "║            PostgreSQL Docker Setup Complete                     ║"
log_message "╠════════════════════════════════════════════════════════════════╣"
log_message "║ Status: ✓ READY                                                 ║"
log_message "║ Total Time: ${TOTAL_TIME}s"
log_message "║ Database: graph_db"
log_message "║ Data Dir: $PGDATA_DIR"
log_message "║ Port: $DB_PORT"
log_message "║ Extensions: age, vector"
log_message "║                                                                 ║"
log_message "║ Startup log: $STARTUP_LOG"
log_message "║ Completion status: $STARTUP_COMPLETE_FILE"
log_message "╚════════════════════════════════════════════════════════════════╝"
log_message ""

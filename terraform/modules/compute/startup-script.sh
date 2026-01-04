#!/bin/bash
set -uo pipefail

# PostgreSQL + AGE + pgvector Docker installation script
# Executed on VM startup

echo "=== PostgreSQL Docker Setup ==="

# Update system and install Docker
apt-get update
apt-get install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release

# Install Docker
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /tmp/docker.gpg 2>/dev/null || true
gpg --dearmor -o /etc/apt/keyrings/docker.gpg < /tmp/docker.gpg 2>/dev/null || curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin || true

# Start Docker
systemctl start docker
systemctl enable docker

# Wait for Docker daemon to be ready
sleep 5
for i in {1..30}; do
  if docker ps >/dev/null 2>&1; then
    echo "Docker is ready"
    break
  fi
  echo "Waiting for Docker... ($i/30)"
  sleep 2
done

# Data disk configuration
DATA_DISK_BY_ID="/dev/disk/by-id/google-${data_disk_name}"
MOUNT_POINT="${data_disk_mount_point}"

echo "=== Data Disk Setup ==="
echo "Looking for disk: $DATA_DISK_BY_ID"
echo "Target mount point: $MOUNT_POINT"
ls -la /dev/disk/by-id/ | grep google || echo "No Google disks found"

if [ "${create_data_disk}" = "true" ] || [ -b "$DATA_DISK_BY_ID" ]; then
  if [ -b "$DATA_DISK_BY_ID" ]; then
    echo "Found data disk at $DATA_DISK_BY_ID"
    
    # Format if necessary
    if ! blkid "$DATA_DISK_BY_ID" >/dev/null 2>&1; then
      echo "Formatting data disk..."
      mkfs.ext4 -F "$DATA_DISK_BY_ID"
    fi

    mkdir -p "$MOUNT_POINT"
    if ! mountpoint -q "$MOUNT_POINT"; then
      mount "$DATA_DISK_BY_ID" "$MOUNT_POINT"
    fi

    # Ensure persistent mount in fstab
    if ! grep -q "$DATA_DISK_BY_ID" /etc/fstab; then
      echo "$DATA_DISK_BY_ID $MOUNT_POINT ext4 defaults 0 2" >> /etc/fstab
    fi
    
    echo "Data disk mounted successfully at $MOUNT_POINT"
    df -h "$MOUNT_POINT"
  else
    echo "WARNING: create_data_disk is true but device $DATA_DISK_BY_ID not found!"
    echo "Available devices:"
    ls -la /dev/disk/by-id/ | grep google
    echo "FALLBACK: Using boot disk at /var/lib/postgresql-data"
    MOUNT_POINT="/var/lib/postgresql-data"
    mkdir -p "$MOUNT_POINT"
  fi
else
  echo "No separate data disk configured. Using boot disk."
  MOUNT_POINT="/var/lib/postgresql-data"
  mkdir -p "$MOUNT_POINT"
fi

# Create PostgreSQL data directory
PGDATA_DIR="$MOUNT_POINT/pgdata"
echo "Creating Postgres data directory: $PGDATA_DIR"
mkdir -p "$PGDATA_DIR"
chmod 777 "$MOUNT_POINT"
chmod 700 "$PGDATA_DIR"
echo "Postgres data directory ready at $PGDATA_DIR"
ls -la "$MOUNT_POINT"

echo "=== Creating Dockerfile for PostgreSQL with AGE and pgvector ==="
cat > /root/Dockerfile.postgres <<'DOCKERFILE'
FROM postgres:16

# Install build dependencies including flex and bison for AGE
RUN apt-get update && apt-get install -y \
    build-essential \
    flex \
    bison \
    git \
    postgresql-server-dev-16 \
    && rm -rf /var/lib/apt/lists/*

# Install pgvector
RUN cd /tmp && \
    git clone --branch v0.5.1 https://github.com/pgvector/pgvector.git && \
    cd pgvector && \
    make && \
    make install && \
    cd / && \
    rm -rf /tmp/pgvector

# Install Apache AGE - use main branch if specific version not available
RUN cd /tmp && \
    git clone https://github.com/apache/age.git && \
    cd age && \
    (git checkout PG16/v1.6.0-rc0 || git checkout master) && \
    make install && \
    cd / && \
    rm -rf /tmp/age

# Clean up build dependencies
RUN apt-get remove -y build-essential flex bison git postgresql-server-dev-16 && \
    apt-get autoremove -y && \
    apt-get clean

DOCKERFILE

echo "=== Building PostgreSQL Docker image ==="
docker build -t postgres-age-vector:16 -f /root/Dockerfile.postgres /root/

echo "=== Starting PostgreSQL container ==="
# Pre-create data directory with correct permissions
mkdir -p "$PGDATA_DIR"
chmod 777 "$PGDATA_DIR"

# Start container WITHOUT init-scripts volume to allow clean initialization
docker run -d \
  --name postgres-age-vector \
  --restart always \
  --network host \
  -e POSTGRES_DB=graph_db \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_INITDB_ARGS="-c shared_preload_libraries='age'" \
  -v "$PGDATA_DIR:/var/lib/postgresql/data" \
  postgres-age-vector:16

echo "=== Waiting for PostgreSQL to start ==="
sleep 10

# Wait for PostgreSQL to be ready
for i in {1..30}; do
  if docker exec postgres-age-vector pg_isready -U postgres -d graph_db; then
    echo "PostgreSQL is ready!"
    break
  fi
  echo "Waiting for PostgreSQL... ($i/30)"
  sleep 2
done

echo "=== Installing extensions ==="
# Install pgvector extension
docker exec -e PGPASSWORD=postgres postgres-age-vector psql -U postgres -d graph_db -c "CREATE EXTENSION IF NOT EXISTS vector;" || echo "Note: vector extension may already exist"

# Install AGE extension with proper setup
docker exec -e PGPASSWORD=postgres postgres-age-vector psql -U postgres -d graph_db <<'EOSQL' || echo "Note: AGE extension may already exist"
CREATE EXTENSION IF NOT EXISTS age;
LOAD 'age';
SET search_path = ag_catalog, "$user", public;
ALTER DATABASE graph_db SET search_path = ag_catalog, "$user", public;
EOSQL

echo "=== Creating sample tables and indexes ==="
docker exec -e PGPASSWORD=postgres postgres-age-vector psql -U postgres -d graph_db <<'EOSQL' || echo "Note: sample tables may already exist"
-- Create sample vector table
CREATE TABLE IF NOT EXISTS vectors (
  id SERIAL PRIMARY KEY,
  embedding vector(1536),
  metadata jsonb
);

CREATE INDEX IF NOT EXISTS vectors_hnsw_idx ON vectors USING hnsw (embedding vector_cosine_ops)
  WITH (m = 16, ef_construction = 200);
EOSQL

echo "=== Creating sample graph ==="
docker exec -e PGPASSWORD=postgres postgres-age-vector psql -U postgres -d graph_db -c "SELECT create_graph('sample_graph');" || echo "Note: sample graph may already exist"

echo "=== Verifying installation ==="
docker exec postgres-age-vector psql -U postgres -d graph_db -c "SELECT version();" || true
docker exec postgres-age-vector psql -U postgres -d graph_db -c "SELECT extname, extversion FROM pg_extension WHERE extname IN ('vector', 'age');" || true

echo "=== Setting up WAL archiving ==="
# WAL archiving can be configured here if needed

# Install Google Cloud Ops Agent for monitoring
curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent.sh
sudo bash add-google-cloud-ops-agent.sh --also-install

echo "=== PostgreSQL Docker Setup Complete ==="
echo "Database: graph_db"
echo "Extensions: age, vector"
echo "Listening on port ${db_port}"
echo "Data directory: $PGDATA_DIR"

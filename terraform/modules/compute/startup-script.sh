#!/bin/bash
set -euo pipefail

# PostgreSQL + AGE + pgvector installation script
# Executed on VM startup

echo "=== PostgreSQL Installation & Setup ==="

# Update system
apt-get update
apt-get upgrade -y
apt-get install -y \
  build-essential \
  git \
  postgresql-${postgresql_version} \
  postgresql-server-dev-${postgresql_version} \
  postgresql-contrib-${postgresql_version} \
  libreadline-dev \
  zlib1g-dev \
  curl \
  wget \
  gnupg2 \
  lsb-release

# If a data disk is present, format/mount and migrate Postgres data into it
DATA_DISK_BY_ID="/dev/disk/by-id/google-${data_disk_name}"
MOUNT_POINT="${data_disk_mount_point}"

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

    chown -R postgres:postgres "$MOUNT_POINT"

    PG_DATA_DIR="/var/lib/postgresql/${postgresql_version}/main"

    # If PG_DATA_DIR exists and the mount is empty, move data into disk and symlink
    if [ -d "$PG_DATA_DIR" ] && [ -z "$(ls -A "$MOUNT_POINT")" ]; then
      echo "Migrating existing PostgreSQL data to $MOUNT_POINT"
      systemctl stop postgresql || true
      mv "$PG_DATA_DIR" "$MOUNT_POINT/"
      ln -s "$MOUNT_POINT/main" "$PG_DATA_DIR"
      chown -R postgres:postgres "$MOUNT_POINT"
    fi

    # If mount already contains DB data but PG_DATA_DIR missing, create symlink
    if [ ! -d "$PG_DATA_DIR" ] && [ -d "$MOUNT_POINT/main" ]; then
      ln -s "$MOUNT_POINT/main" "$PG_DATA_DIR"
      chown -R postgres:postgres "$MOUNT_POINT"
    fi

    # Ensure persistent mount in fstab
    if ! grep -q "$DATA_DISK_BY_ID" /etc/fstab; then
      echo "$DATA_DISK_BY_ID $MOUNT_POINT ext4 defaults 0 2" >> /etc/fstab
    fi
  else
    echo "create_data_disk is true but device $DATA_DISK_BY_ID not present yet; continuing"
  fi
else
  echo "No separate data disk configured. Using boot disk for DB data."
fi

# Start PostgreSQL
systemctl start postgresql
systemctl enable postgresql

echo "=== Installing AGE (Apache Graph Extension) ==="
cd /tmp
git clone https://github.com/apache/age.git
cd age
git checkout PG${postgresql_version}

# Build and install AGE
make install

echo "=== Installing pgvector Extension ==="
cd /tmp
git clone https://github.com/pgvector/pgvector.git
cd pgvector
make
make install

echo "=== Configuring PostgreSQL ==="
# Update postgresql.conf for WAL archiving and security
cat >> /etc/postgresql/${postgresql_version}/main/postgresql.conf <<EOF

# AGE and pgvector
shared_preload_libraries = 'age'

# WAL archiving
%{ if enable_wal_archiving }
archive_mode = on
archive_command = 'gsutil cp pg_wal/%f gs://${gcs_backup_bucket}/wal_archive/ && rm pg_wal/%f'
archive_timeout = 300
%{ endif }

# SSL/TLS
ssl = on
ssl_cert_file = '/etc/ssl/certs/ssl-cert-snakeoil.pem'
ssl_key_file = '/etc/ssl/private/ssl-cert-snakeoil.key'

# Security
password_encryption = scram-sha-256
max_connections = 100
%{ if db_port != 5432 }
port = ${db_port}
%{ endif }

# Monitoring
log_statement = 'all'
log_duration = on
log_min_duration_statement = 1000
EOF

# Create graph_db and install extensions
sudo -u postgres psql -c "CREATE DATABASE graph_db;" || true

sudo -u postgres psql -d graph_db <<EOFPG
CREATE EXTENSION IF NOT EXISTS age;
CREATE EXTENSION IF NOT EXISTS vector;
LOAD 'age';
CREATE SCHEMA IF NOT EXISTS graph;
SET search_path = graph, public;

-- Create a sample graph
SELECT * FROM create_graph('sample_graph');

-- Create sample vector table
CREATE TABLE IF NOT EXISTS vectors (
  id SERIAL PRIMARY KEY,
  embedding vector(1536),
  metadata jsonb
);

CREATE INDEX IF NOT EXISTS vectors_hnsw_idx ON vectors USING hnsw (embedding vector_cosine_ops)
  WITH (m = 16, ef_construction = 200);

EOFPG

# Restart PostgreSQL to load configs
systemctl restart postgresql

echo "=== PostgreSQL Setup Complete ==="
echo "Database: graph_db"
echo "Extensions: age, vector"
echo "Listening on port ${db_port}"

%{ if enable_wal_archiving }
echo "=== Setting up WAL archiving ==="
mkdir -p /var/lib/postgresql/${postgresql_version}/main/pg_wal
chown -R postgres:postgres /var/lib/postgresql/${postgresql_version}/main/pg_wal
%{ endif }

# Install Google Cloud Ops Agent for monitoring
curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent.sh
sudo bash add-google-cloud-ops-agent.sh --also-install

echo "=== Setup Complete ==="

# Developer Database Access Guide

This document provides multiple solutions for accessing the PostgreSQL database from your local developer computer.

## 🎯 Recommended Solution: SSH Port Forwarding (Simplest)

Use `gcloud compute ssh` with port forwarding to create a secure tunnel through the VM.

### Quick Start

```bash
# Create SSH tunnel to database (keeps connection open)
gcloud compute ssh db-vm \
  --zone=us-central1-a \
  --project=saas-app-001 \
  -- -L 5432:127.0.0.1:5432

# In another terminal, connect to local PostgreSQL
psql -h localhost -U postgres -d graph_db
```

That's it! You now have direct access to the database.

---

## Why This Solution?

| Criteria | SSH Tunnel | Other Solutions |
|----------|-----------|-----------------|
| **Simplicity** | ✅ No setup | Requires tools/proxy |
| **Security** | ✅ Encrypted via SSH | Depends |
| **Built-in** | ✅ Standard gcloud | May need additional tools |
| **Cost** | ✅ Free | Free/extra resources |
| **Speed** | ✅ Minimal latency | Potential extra hops |
| **Accessibility** | ✅ From anywhere with GCP access | Limited |

---

## Detailed Setup: SSH Tunnel

### Prerequisites

```bash
# Ensure you have:
# 1. GCP SDK installed
gcloud --version

# 2. PostgreSQL client (psql) installed
psql --version
# If not: brew install postgresql (macOS) or apt install postgresql-client (Linux)
```

### Step 1: Verify VM Name

```bash
gcloud compute instances list --zones=us-central1-a --project=saas-app-001
# Look for VM name (usually db-vm or edgequake-db-vm)
```

### Step 2: Create SSH Tunnel

```bash
gcloud compute ssh <VM_NAME> \
  --zone=us-central1-a \
  --project=saas-app-001 \
  -- -L 5432:127.0.0.1:5432
```

**What this does:**
- `-L 5432:127.0.0.1:5432` = Forward local port 5432 to VM's localhost:5432
- Your local machine: `localhost:5432` → SSH tunnel → VM's PostgreSQL
- Keeps running until you `Ctrl+C`

### Step 3: Connect from Local

In another terminal:

```bash
# Connect to local forwarded port (which tunnels to remote PostgreSQL)
psql -h localhost -U postgres -d graph_db

# You'll see the psql prompt
graph_db=> 
```

### Step 4: Use the Database

```sql
-- List extensions
\dx

-- List tables
\dt

-- Show database info
\l

-- Run queries
SELECT * FROM graph.sample_graph;
```

---

## Advanced: Create a Convenience Script

### Option A: Bash Script (Recommended)

**File:** `scripts/db-tunnel.sh`

```bash
#!/bin/bash
set -euo pipefail

# Configuration
PROJECT_ID="${1:-saas-app-001}"
ZONE="${2:-us-central1-a}"
VM_NAME="${3:-db-vm}"
LOCAL_PORT="${4:-5432}"
REMOTE_PORT="${5:-5432}"

echo "🚀 Creating SSH tunnel to PostgreSQL database..."
echo "   Local: localhost:${LOCAL_PORT}"
echo "   Remote: ${VM_NAME}:${REMOTE_PORT}"
echo "   Project: ${PROJECT_ID}"
echo ""
echo "Press Ctrl+C to stop the tunnel"
echo ""

gcloud compute ssh "${VM_NAME}" \
  --zone="${ZONE}" \
  --project="${PROJECT_ID}" \
  -- -L "${LOCAL_PORT}:127.0.0.1:${REMOTE_PORT}"
```

**Usage:**

```bash
# Basic usage (uses defaults)
./scripts/db-tunnel.sh

# Custom port
./scripts/db-tunnel.sh saas-app-001 us-central1-a db-vm 5433

# In another terminal, connect
psql -h localhost -p 5433 -U postgres -d graph_db
```

### Option B: Make Target

**File:** `Makefile`

Add to your existing Makefile:

```makefile
.PHONY: db-tunnel
db-tunnel:
	@echo "🚀 Creating SSH tunnel to PostgreSQL..."
	@echo "   Local: localhost:5432"
	@echo "   Database VM: db-vm"
	@echo "   Press Ctrl+C to stop"
	gcloud compute ssh db-vm --zone=us-central1-a --project=$${PROJECT_ID:-saas-app-001} -- -L 5432:127.0.0.1:5432

.PHONY: db-connect
db-connect:
	@echo "📦 Connecting to PostgreSQL (ensure tunnel is running in another terminal)..."
	psql -h localhost -U postgres -d graph_db

.PHONY: db-tunnel-custom
db-tunnel-custom:
	@echo "🚀 Creating SSH tunnel on custom port 5433..."
	gcloud compute ssh db-vm --zone=us-central1-a --project=$${PROJECT_ID:-saas-app-001} -- -L 5433:127.0.0.1:5432
	@echo "   Connect with: psql -h localhost -p 5433 -U postgres -d graph_db"
```

**Usage:**

```bash
# Terminal 1: Start tunnel
make db-tunnel

# Terminal 2: Connect
make db-connect
```

---

## Integration with Tools

### DBeaver (GUI Database Client)

1. **Download DBeaver:** https://dbeaver.io/download/
2. **Create new connection:**
   - File → New → Database Connection
   - Select "PostgreSQL"
   - Server Host: `localhost`
   - Server Port: `5432`
   - Database: `graph_db`
   - Username: `postgres`
   - Password: (leave empty - local auth)
3. **Test connection** (ensure tunnel is running)
4. **Browse** tables, run queries graphically

### VSCode with Remote-SSH Extension

1. **Install extension:** "Remote - SSH"
2. **Configure SSH host** (add to `~/.ssh/config`):
```
Host gcp-db-vm
  HostName <VM_EXTERNAL_IP>
  User <YOUR_GCP_USERNAME>
  IdentityFile ~/.ssh/google_compute_engine
```
3. **Connect** and use terminal with gcloud
4. **Open PostgreSQL in VSCode:**
   - Install "PostgreSQL Explorer" extension
   - Configure connection to `localhost:5432`

### Python (Local Development)

```python
import psycopg2

# Connect through SSH tunnel (localhost:5432)
conn = psycopg2.connect(
    host="localhost",
    port=5432,
    database="graph_db",
    user="postgres"
)

cursor = conn.cursor()
cursor.execute("SELECT * FROM graph.sample_graph;")
for row in cursor.fetchall():
    print(row)

cursor.close()
conn.close()
```

### Node.js (Local Development)

```javascript
const { Client } = require('pg');

const client = new Client({
  host: 'localhost',
  port: 5432,
  database: 'graph_db',
  user: 'postgres',
});

client.connect((err) => {
  if (err) {
    console.error('Connection error', err.stack);
  } else {
    console.log('✓ Connected to PostgreSQL');
  }
});

client.query('SELECT * FROM graph.sample_graph;', (err, res) => {
  if (err) {
    console.error(err.stack);
  } else {
    console.log('Results:', res.rows);
  }
  client.end();
});
```

### Rust (Local Development)

```rust
use sqlx::postgres::PgPoolOptions;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Connect through SSH tunnel (localhost:5432)
    let pool = PgPoolOptions::new()
        .max_connections(5)
        .connect("postgresql://postgres@localhost:5432/graph_db?sslmode=disable")
        .await?;

    let row: (i64,) = sqlx::query_as("SELECT 1")
        .fetch_one(&pool)
        .await?;

    println!("Query result: {:?}", row);
    Ok(())
}
```

---

## Troubleshooting

### "Permission denied (publickey)"

**Problem:** SSH key not found

**Solution:**
```bash
# Use gcloud's built-in SSH (handles authentication)
gcloud compute ssh db-vm --zone=us-central1-a --project=saas-app-001
```

### "Connection refused"

**Problem:** PostgreSQL not running on VM

**Solution:**
```bash
gcloud compute ssh db-vm --zone=us-central1-a --project=saas-app-001
sudo systemctl status postgresql
sudo systemctl start postgresql
```

### "Address already in use"

**Problem:** Local port 5432 is already in use

**Solution:**
```bash
# Use different port
gcloud compute ssh db-vm \
  --zone=us-central1-a \
  --project=saas-app-001 \
  -- -L 5433:127.0.0.1:5432

# Connect with
psql -h localhost -p 5433 -U postgres -d graph_db
```

### "Timeout" or "Network unreachable"

**Problem:** VPC/firewall blocking connection

**Solution:**
```bash
# Check firewall rules
gcloud compute firewall-rules list --filter="name:postgres"

# Verify VM is running
gcloud compute instances list --zones=us-central1-a
```

---

## Alternative Solutions

### Option 2: Cloud SQL Auth Proxy (If Using Cloud SQL)

If you migrate to Cloud SQL in the future:

```bash
# Download Cloud SQL Proxy
curl -o cloud_sql_proxy https://dl.google.com/cloudsql/cloud_sql_proxy.linux.amd64
chmod +x cloud_sql_proxy

# Run proxy
./cloud_sql_proxy -instances=saas-app-001:us-central1:postgres=tcp:5432
```

Not applicable now (using Compute Engine), but good to know.

### Option 3: Custom Python Proxy

**File:** `scripts/db-proxy.py`

```python
#!/usr/bin/env python3
"""
Simple TCP proxy for PostgreSQL database access
Forwards local connections to remote database through SSH
"""

import socket
import threading
import sys
from pathlib import Path

def proxy_connection(local_socket, remote_host, remote_port):
    """Forward data between local and remote sockets"""
    remote_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    remote_socket.connect((remote_host, remote_port))
    
    def forward(src, dst):
        while True:
            data = src.recv(4096)
            if not data:
                break
            dst.sendall(data)
    
    # Bidirectional forwarding
    threading.Thread(target=forward, args=(local_socket, remote_socket)).start()
    threading.Thread(target=forward, args=(remote_socket, local_socket)).start()

if __name__ == "__main__":
    local_port = int(sys.argv[1]) if len(sys.argv) > 1 else 5432
    remote_host = sys.argv[2] if len(sys.argv) > 2 else "127.0.0.1"
    remote_port = int(sys.argv[3]) if len(sys.argv) > 3 else 5432
    
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(("127.0.0.1", local_port))
    server.listen(5)
    
    print(f"🚀 Proxy listening on localhost:{local_port}")
    print(f"   Forwarding to {remote_host}:{remote_port}")
    
    try:
        while True:
            local_socket, _ = server.accept()
            threading.Thread(
                target=proxy_connection,
                args=(local_socket, remote_host, remote_port)
            ).start()
    except KeyboardInterrupt:
        print("\n⏹️  Proxy stopped")
```

**Usage:**
```bash
python3 scripts/db-proxy.py 5432 localhost 5432
```

More complex, not recommended unless you need features beyond SSH tunneling.

### Option 4: Cloud Run Proxy Service

Create a proxy service running on Cloud Run that forwards database connections.

**Not recommended** - adds complexity and extra infrastructure cost.

---

## Security Best Practices

### ✅ What SSH Tunneling Provides

- **Encryption:** All data encrypted over SSH
- **Authentication:** Uses GCP service account credentials
- **Isolation:** Database only accessible through authorized SSH connection
- **Auditability:** SSH connections logged in Cloud Logging

### ✅ Additional Security Steps

**Limit SSH access:**
```bash
# Only allow specific IPs if needed
gcloud compute firewall-rules update allow-ssh-from-gcp \
  --source-ranges=YOUR_IP/32
```

**Use `psql` with local auth (no password):**
```bash
# Works because SSH tunnel connects as local user
psql -h localhost -U postgres -d graph_db
```

**Disable public IP if not needed:**
```hcl
# In terraform/modules/compute/main.tf
access_config {
  # Empty = no public IP (must use Cloud IAP for SSH)
}
```

---

## Development Workflow

### Daily Developer Setup

```bash
# Morning: Start tunnel in one terminal
make db-tunnel
# (leave running)

# In another terminal: Connect and develop
make db-connect
# (disconnect with \q when done)

# Work on application code
# Database stays accessible in background
```

### Team Setup

**Share this guide:**
```bash
# Everyone does:
make db-tunnel

# Then code locally
psql -h localhost -U postgres -d graph_db
```

---

## Performance Considerations

| Aspect | Performance | Notes |
|--------|-------------|-------|
| **Latency** | ~50-100ms | Acceptable for development |
| **Bandwidth** | Unlimited | GCP internal network |
| **Connections** | Multiple | Each SSH tunnel = separate connection |
| **Cost** | Free | No egress charges (internal) |

**For production:** Direct VPC connectivity (already configured for Cloud Run).

---

## Reference: SSH Tunnel Command Breakdown

```bash
gcloud compute ssh db-vm \
  --zone=us-central1-a \
  --project=saas-app-001 \
  -- -L 5432:127.0.0.1:5432
   |   |  |     |         |
   |   |  |     |         +-- Remote port (PostgreSQL on VM)
   |   |  |     +-- Remote host (localhost on VM)
   |   |  +-- Local port (your machine)
   |   +-- SSH flag: L = local port forward
   +-- VM name
```

---

## Summary

**Recommended approach:** SSH Port Forwarding with `make db-tunnel`

**Setup time:** < 1 minute

**Connection time:** < 2 seconds

**Cost:** Free

**Security:** SSH encrypted

**Tools needed:** `gcloud` + `psql`

See `scripts/db-tunnel.sh` and Makefile additions for automation.

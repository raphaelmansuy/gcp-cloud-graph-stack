# Complete Developer Database Access Solution

## 🎯 Overview

This document provides a complete reference for accessing PostgreSQL database from your developer computer in the gcp-cloud-graph-stack project.

---

## ⚡ Quick Start (60 seconds)

### Step 1: Create SSH Tunnel
```bash
make db-tunnel
```
This keeps running in your terminal. Don't close it.

### Step 2: Connect in Another Terminal
```bash
make db-connect
```

✅ **You're connected!** You now have a PostgreSQL prompt.

---

## 🏗️ How It Works

### Architecture Diagram

```
┌─────────────────────────┐
│   Your Computer         │
│  (Developer Machine)    │
│                         │
│  localhost:5432 ◄──────┐│  psql client
│     ▲                   ││
│     │ SSH Tunnel        ││
│     │ (encrypted)       ││
└─────┼───────────────────┘│
      │                    │
      │ Internet           │
      │                    │
┌─────▼────────────────────┴─────┐
│   Google Cloud Platform (GCP)   │
│                                  │
│   ┌────────────────────────┐   │
│   │  PostgreSQL VM         │   │
│   │  (db-vm)               │   │
│   │                        │   │
│   │  127.0.0.1:5432        │   │
│   │  (PostgreSQL Server)   │   │
│   └────────────────────────┘   │
│                                  │
└──────────────────────────────────┘
```

**The tunnel:**
- Creates secure SSH connection to VM
- Forwards port 5432 on localhost → PostgreSQL on VM
- Automatic authentication via `gcloud`
- No passwords needed on your machine

---

## 📖 Detailed Setup

### Prerequisites

1. **Google Cloud SDK** (gcloud CLI)
   ```bash
   # Check if installed:
   gcloud --version
   
   # If not, install (macOS):
   brew install --cask google-cloud-sdk
   
   # Or Linux:
   curl https://sdk.cloud.google.com | bash
   ```

2. **Authenticate with GCP**
   ```bash
   gcloud auth login
   gcloud config set project saas-app-001
   ```

3. **PostgreSQL Client** (psql)
   ```bash
   # Check if installed:
   psql --version
   
   # If not, install (macOS):
   brew install postgresql
   
   # Or Linux:
   sudo apt install postgresql-client
   ```

### Method 1: Using Make Targets (Recommended)

#### Create Tunnel
```bash
make db-tunnel
```

**Output:**
```
🔌 Starting PostgreSQL SSH Tunnel...
   Local: localhost:5432
   Remote: us-central1-a (PostgreSQL VM)

Press Ctrl+C to stop the tunnel
```

Then stays running. Don't close this terminal.

#### Connect with psql
In **another terminal**:
```bash
make db-connect
```

**Output:**
```
📦 Connecting to PostgreSQL (ensure tunnel is running in another terminal)...
   Host: localhost
   Port: 5432
   Database: graph_db
   User: postgres

psql (15.1)
Type "help" for help.

graph_db=# _
```

#### Check PostgreSQL Status
```bash
make db-check
```

### Method 2: Manual SSH Tunnel Command

If you prefer direct gcloud command:

```bash
gcloud compute ssh db-vm \
  --zone=us-central1-a \
  --project=saas-app-001 \
  -- -L 5432:127.0.0.1:5432
```

Then connect with:
```bash
psql -h localhost -U postgres -d graph_db
```

### Method 3: Custom Port (Port Conflict)

If port 5432 is already in use:

```bash
# Create tunnel on port 5433 instead:
make db-tunnel-custom

# In another terminal, connect with custom port:
psql -h localhost -p 5433 -U postgres -d graph_db
```

---

## 🔧 Integration with Tools

### DBeaver (GUI Database Client)

1. **Download & Install** DBeaver Community Edition (free)

2. **Create new connection:**
   - Database: PostgreSQL
   - Host: localhost
   - Port: 5432
   - Database: graph_db
   - Username: postgres
   - Password: (leave blank or use your VM password)

3. **Start SSH tunnel first:**
   ```bash
   make db-tunnel
   ```

4. **Connect in DBeaver** - it will use the tunnel

### VSCode Remote-SSH

1. **Install VSCode SSH Extension**

2. **Create SSH tunnel:**
   ```bash
   make db-tunnel
   ```

3. **Connect via psql extension:**
   - Install "PostgreSQL" extension
   - Configure: localhost:5432, graph_db, postgres

### Python (psycopg2)

```python
import psycopg2

# Start tunnel first: make db-tunnel

# Then connect:
conn = psycopg2.connect(
    host="localhost",
    port=5432,
    database="graph_db",
    user="postgres",
    # password omitted if no auth needed in dev
)

cursor = conn.cursor()
cursor.execute("SELECT version();")
print(cursor.fetchone())
```

### Node.js (pg library)

```javascript
const { Client } = require('pg');

// Start tunnel first: make db-tunnel

const client = new Client({
  host: 'localhost',
  port: 5432,
  database: 'graph_db',
  user: 'postgres',
});

await client.connect();
const result = await client.query('SELECT version()');
console.log(result.rows[0]);
```

### Rust (sqlx)

```rust
use sqlx::postgres::PgPoolOptions;

// Start tunnel first: make db-tunnel

#[tokio::main]
async fn main() -> Result<()> {
    let database_url = 
        "postgresql://postgres@localhost:5432/graph_db";
    
    let pool = PgPoolOptions::new()
        .max_connections(5)
        .connect(database_url)
        .await?;
    
    Ok(())
}
```

---

## 🐛 Troubleshooting

### Port 5432 Already in Use

**Error:**
```
channel 0: open failed: administratively prohibited
Address already in use
```

**Solution:**
```bash
# Use alternate port:
make db-tunnel-custom  # Uses port 5433

# Then connect with:
psql -h localhost -p 5433 -U postgres -d graph_db
```

### "Permission denied (publickey)"

**Error:**
```
Permission denied (publickey).
ssh_exchange_identification: read: Connection reset by peer
```

**Solutions:**

1. **Check gcloud is authenticated:**
   ```bash
   gcloud auth list
   ```

2. **Re-authenticate:**
   ```bash
   gcloud auth login
   gcloud config set project saas-app-001
   ```

3. **Check VM exists and is running:**
   ```bash
   gcloud compute instances list \
     --project=saas-app-001 \
     --filter="name:db-vm"
   ```

### "gcloud: command not found"

**Error:**
```
bash: gcloud: command not found
```

**Solution:**

```bash
# Install Google Cloud SDK (macOS):
brew install --cask google-cloud-sdk

# Then authenticate:
gcloud auth login
```

### "psql: command not found"

**Error:**
```
bash: psql: command not found
```

**Solution:**

```bash
# Install PostgreSQL client (macOS):
brew install postgresql

# Or Linux:
sudo apt install postgresql-client

# Verify:
psql --version
```

### "Connection refused"

**Error:**
```
psql: error: could not translate host name "localhost" to address: Name or service not known
```

**Solutions:**

1. **Ensure tunnel is running:**
   ```bash
   # In another terminal, check:
   netstat -an | grep 5432
   ```

2. **Start tunnel:**
   ```bash
   make db-tunnel
   ```

3. **Check PostgreSQL is running on VM:**
   ```bash
   make db-check
   ```

### "too many connections"

**Error:**
```
FATAL: sorry, too many clients already connected
```

**Solution:**

```bash
# Close idle connections, or increase connection limit:
# In VM:
sudo -u postgres psql -c \
  "ALTER SYSTEM SET max_connections = 100;"
sudo systemctl restart postgresql
```

---

## 📊 Database Information

### Connection Details

| Setting | Value |
|---------|-------|
| **Host** | localhost (via tunnel) |
| **Port** | 5432 (default) or 5433 (custom) |
| **Database** | graph_db |
| **User** | postgres |
| **Password** | None (development) |
| **Version** | PostgreSQL 16 |

### Available Extensions

```sql
-- Check installed extensions:
\dx

-- Installed:
-- age: Graph databases (nodes and edges)
-- pgvector: Vector similarity search
-- uuid-ossp: UUID generation
```

### Default Schema

```sql
-- List tables:
\dt

-- Schema 'graph' contains:
-- CREATE TABLE graph.pg_graph_v1 (id, data)
```

---

## 🔐 Security Considerations

### Development
✅ SSH tunnel is encrypted (SSH protocol)  
✅ Only you can access the tunnel (localhost only)  
✅ Requires valid GCP authentication (gcloud)  
✅ No passwords stored in code  

### Production
⚠️ Never expose port 5432 to internet  
⚠️ Use Cloud SQL Auth Proxy for services  
⚠️ Enable VPC Service Controls  
⚠️ Use service accounts with minimal permissions  

---

## 📚 Additional Resources

| Topic | Location |
|-------|----------|
| Architecture | [docs/01-architecture.md](docs/01-architecture.md) |
| Database Setup | [docs/09-database-connection-config.md](docs/09-database-connection-config.md) |
| Configuration Examples | [docs/10-environment-configuration-examples.md](docs/10-environment-configuration-examples.md) |
| All Documentation | [docs/12-documentation-index.md](docs/12-documentation-index.md) |

---

## ✅ Validation Checklist

Before connecting, ensure:

- [ ] `gcloud --version` shows Google Cloud SDK installed
- [ ] `gcloud auth list` shows you're logged in
- [ ] `gcloud config get-value project` shows saas-app-001
- [ ] `psql --version` shows PostgreSQL client installed
- [ ] VM exists: `gcloud compute instances list --filter="name:db-vm"`
- [ ] SSH access works: `gcloud compute ssh db-vm --zone=us-central1-a`

---

## 🚀 Next Steps

1. **Set up tunnel:** `make db-tunnel`
2. **Connect to database:** `make db-connect` (in another terminal)
3. **Explore schema:** `\dt` in psql
4. **Configure your app:** See [environment configuration](docs/10-environment-configuration-examples.md)
5. **Deploy:** See [deployment guide](docs/15-edgequake-deployment-ready.md)

---

**Last Updated:** January 2025  
**Status:** Production Ready ✅

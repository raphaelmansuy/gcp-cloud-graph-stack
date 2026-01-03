# 🎯 Developer Database Access - Quick Reference

**Status**: ✅ Production Ready  
**Type**: SSH Port Forwarding  
**Setup Time**: 2 minutes  
**Cost**: Free  

---

## ⚡ 60-Second Quick Start

```bash
# Terminal 1: Start SSH tunnel (keep running)
make db-tunnel

# Terminal 2: Connect to database
make db-connect

# You're connected! Try:
# \dt         (list tables)
# SELECT version();  (check PostgreSQL version)
# \q          (quit)
```

---

## 📚 Documentation

| File | Purpose | Size |
|------|---------|------|
| [DATABASE_ACCESS.md](DATABASE_ACCESS.md) | Complete reference guide | 485 lines |
| [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md) | Quick start for new developers | 252 lines |
| [DATABASE_ACCESS_SUMMARY.md](DATABASE_ACCESS_SUMMARY.md) | Implementation summary | 395 lines |
| [docs/16-developer-database-access.md](docs/16-developer-database-access.md) | Detailed setup & integration | 545 lines |

---

## 🛠️ Available Make Targets

```bash
make db-tunnel          # SSH tunnel on port 5432
make db-tunnel-custom   # SSH tunnel on port 5433 (if 5432 busy)
make db-connect         # Connect with psql
make db-check           # Check PostgreSQL status
```

---

## 🔧 Tools Supported

- ✅ **psql** (CLI) - Standard PostgreSQL client
- ✅ **DBeaver** (GUI) - Popular database client
- ✅ **VSCode** (Remote-SSH) - VS Code SQL extension
- ✅ **Python** (psycopg2) - Python database library
- ✅ **Node.js** (pg) - JavaScript database library
- ✅ **Rust** (sqlx) - Rust async database library

---

## 🚀 Getting Started

### 1. Prerequisites
```bash
gcloud --version      # Should be installed
psql --version        # Should be installed
gcloud auth login     # Should be authenticated
```

### 2. Start Tunnel
```bash
make db-tunnel
```

Keep this terminal open. You'll see:
```
🔌 Starting PostgreSQL SSH Tunnel...
   Local: localhost:5432
   Remote: us-central1-a (PostgreSQL VM)

Press Ctrl+C to stop the tunnel
```

### 3. Connect in New Terminal
```bash
make db-connect
```

You'll see PostgreSQL prompt:
```
psql (15.1)
Type "help" for help.

graph_db=# _
```

### 4. Explore Database
```sql
-- List tables
\dt

-- Check PostgreSQL version
SELECT version();

-- List databases
\l

-- Quit
\q
```

---

## 🐛 Troubleshooting

| Problem | Solution |
|---------|----------|
| **Port 5432 already in use** | Use `make db-tunnel-custom` (port 5433) |
| **gcloud: command not found** | `brew install --cask google-cloud-sdk` |
| **psql: command not found** | `brew install postgresql` |
| **Permission denied** | Run `gcloud auth login` and authenticate |
| **Connection refused** | Ensure tunnel is running in another terminal |
| **Too many connections** | Check connection limit on VM |
| **VM not found** | Verify project ID and VM exists |

See [DATABASE_ACCESS.md](DATABASE_ACCESS.md#troubleshooting) for detailed solutions.

---

## 💻 Code Examples

### Python
```python
import psycopg2

# Start tunnel first: make db-tunnel
conn = psycopg2.connect(
    host="localhost",
    port=5432,
    database="graph_db",
    user="postgres"
)
cursor = conn.cursor()
```

### Node.js
```javascript
const { Client } = require('pg');

// Start tunnel first: make db-tunnel
const client = new Client({
  host: 'localhost',
  port: 5432,
  database: 'graph_db',
  user: 'postgres'
});
await client.connect();
```

### Rust
```rust
use sqlx::postgres::PgPoolOptions;

// Start tunnel first: make db-tunnel
let pool = PgPoolOptions::new()
    .connect("postgresql://postgres@localhost:5432/graph_db")
    .await?;
```

See [docs/10-environment-configuration-examples.md](docs/10-environment-configuration-examples.md) for more examples.

---

## 📊 Database Details

| Property | Value |
|----------|-------|
| **Host** | localhost (via SSH tunnel) |
| **Port** | 5432 (or 5433 with custom) |
| **Database** | graph_db |
| **User** | postgres |
| **Extensions** | age, pgvector, uuid-ossp |
| **Version** | PostgreSQL 16 |

---

## 🔐 Security

✅ **Encrypted**: SSH tunnel uses SSH protocol  
✅ **Local only**: Port 5432 not exposed to internet  
✅ **No passwords**: Uses gcloud authentication  
✅ **Per-connection**: Set up fresh tunnel each time  

---

## 📖 Full Documentation

| Document | Contents |
|----------|----------|
| [DATABASE_ACCESS.md](DATABASE_ACCESS.md) | Complete setup guide, troubleshooting, security |
| [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md) | Quick start, Make commands, code examples |
| [DATABASE_ACCESS_SUMMARY.md](DATABASE_ACCESS_SUMMARY.md) | Implementation details, deliverables, impact |
| [docs/16-developer-database-access.md](docs/16-developer-database-access.md) | Detailed setup, integrations, alternatives |

---

## 🚀 Next Steps

1. Read [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md) for quick start
2. Start SSH tunnel: `make db-tunnel`
3. Connect to database: `make db-connect`
4. See [DATABASE_ACCESS.md](DATABASE_ACCESS.md) for your tool integration
5. Check [docs/10-environment-configuration-examples.md](docs/10-environment-configuration-examples.md) for code examples

---

**Need Help?** Check [DATABASE_ACCESS.md](DATABASE_ACCESS.md#troubleshooting) for solutions.

**Last Updated**: January 3, 2025 ✅

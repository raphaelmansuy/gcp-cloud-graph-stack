# Developer Quick Start Guide

Welcome! This guide helps you get started developing with the gcp-cloud-graph-stack.

## 📚 Quick Links

| Topic | Location |
|-------|----------|
| Architecture Overview | [docs/01-architecture.md](docs/01-architecture.md) |
| Database Connection Setup | [docs/09-database-connection-config.md](docs/09-database-connection-config.md) |
| Environment Configuration | [docs/10-environment-configuration-examples.md](docs/10-environment-configuration-examples.md) |
| Edgequake Integration | [docs/11-edgequake-integration-summary.md](docs/11-edgequake-integration-summary.md) |
| Local Database Access | [docs/16-developer-database-access.md](docs/16-developer-database-access.md) |
| Complete Documentation Index | [docs/12-documentation-index.md](docs/12-documentation-index.md) |

---

## 🚀 Accessing PostgreSQL from Your Computer

### Option 1: Quick SSH Tunnel (Recommended)

```bash
# In one terminal, create SSH tunnel:
make db-tunnel

# In another terminal, connect with psql:
make db-connect
```

That's it! The tunnel forwards `localhost:5432` to the remote PostgreSQL server.

### Option 2: Custom Port (If 5432 is in use)

```bash
# Create tunnel on port 5433:
make db-tunnel-custom

# Connect with custom port:
psql -h localhost -p 5433 -U postgres -d graph_db
```

### Option 3: Using a GUI Tool

See [docs/16-developer-database-access.md](docs/16-developer-database-access.md) for setup instructions for:
- **DBeaver** (popular GUI database client)
- **VSCode Remote-SSH** (VS Code extension)
- **DataGrip** (JetBrains IDE plugin)

---

## 🔧 Available Make Commands

### Database Operations
```bash
make db-tunnel          # Create SSH tunnel (port 5432)
make db-tunnel-custom   # SSH tunnel on port 5433
make db-connect         # Connect with psql
make db-check           # Check PostgreSQL status on VM
```

### Infrastructure
```bash
make plan               # Plan Terraform changes
make apply              # Deploy infrastructure
make destroy            # Destroy all infrastructure
make ssh                # SSH into PostgreSQL VM
```

### Verification
```bash
make verify-infra       # Verify infrastructure
make verify-services    # Check Cloud Run services
make logs-cloud-run     # Show Cloud Run logs
```

### Docker
```bash
make docker-build       # Build Docker images
make docker-push        # Push to Artifact Registry
```

See `make help` for complete list of commands.

---

## 📖 Connecting from Your Application

### Python (psycopg2)

```python
import psycopg2

# When using SSH tunnel to localhost:5432
conn = psycopg2.connect(
    host="localhost",
    port=5432,
    database="graph_db",
    user="postgres",
    password="your_password"
)
```

### Node.js (pg)

```javascript
const { Client } = require('pg');

const client = new Client({
  host: 'localhost',
  port: 5432,
  database: 'graph_db',
  user: 'postgres',
  password: 'your_password',
});
```

### Rust (sqlx)

```rust
use sqlx::postgres::PgPoolOptions;

let database_url = "postgresql://postgres:password@localhost:5432/graph_db";
let pool = PgPoolOptions::new()
    .max_connections(5)
    .connect(database_url)
    .await?;
```

See [docs/10-environment-configuration-examples.md](docs/10-environment-configuration-examples.md) for more examples.

---

## 🔐 Important Security Notes

### Development
- SSH tunnel is encrypted (uses SSH protocol)
- Only you can access the tunnel (port 5432 is local only)
- Requires valid GCP credentials (gcloud auth)
- No passwords stored in code

### Production
- Never expose port 5432 to internet
- Use Cloud SQL Auth Proxy for production services
- Enable VPC Service Controls for additional security
- Use service accounts with limited permissions

---

## 🆘 Troubleshooting

### "Port 5432 already in use"
```bash
# Use alternate port:
make db-tunnel-custom  # Uses port 5433 instead
```

### "gcloud: command not found"
```bash
# Install Google Cloud SDK:
# macOS:
brew install --cask google-cloud-sdk

# Linux:
curl https://sdk.cloud.google.com | bash

# Then authenticate:
gcloud auth login
```

### "psql: command not found"
```bash
# Install PostgreSQL client:
# macOS:
brew install postgresql

# Linux:
sudo apt install postgresql-client
```

### "Permission denied (publickey)"
```bash
# Ensure you have SSH access to the VM:
gcloud compute ssh db-vm --zone=us-central1-a --project=saas-app-001

# If this fails, check your GCP project and IAM permissions
```

See [docs/16-developer-database-access.md](docs/16-developer-database-access.md#troubleshooting) for more solutions.

---

## 📊 Database Details

| Property | Value |
|----------|-------|
| **Host** | db-vm (in VPC) / localhost (via tunnel) |
| **Port** | 5432 |
| **Database** | graph_db |
| **User** | postgres |
| **Extensions** | age, pgvector, uuid-ossp |
| **Version** | PostgreSQL 16 |

---

## 🎯 Next Steps

1. **Set up SSH tunnel**: `make db-tunnel`
2. **Connect to database**: `make db-connect`
3. **Review database schema**: See startup-script output in VM logs
4. **Configure your app**: See [docs/10-environment-configuration-examples.md](docs/10-environment-configuration-examples.md)
5. **Deploy edgequake**: See [docs/15-edgequake-deployment-ready.md](docs/15-edgequake-deployment-ready.md)

---

## 📝 Documentation Structure

```
docs/
├── 01-architecture.md                    # System design & overview
├── 02-vm-setup.md                        # PostgreSQL VM configuration
├── 03-vpc-setup.md                       # Network configuration
├── 04-cloud-run-setup.md                 # Cloud Run services setup
├── 05-artifact-registry.md               # Container registry setup
├── 06-roadmap-costs.md                   # Cost analysis & roadmap
├── 07-db-disk-ops.md                     # Disk protection & snapshots
├── 08-github-actions-deploy-edgequake.md # CI/CD pipeline
├── 09-database-connection-config.md      # Database connection setup
├── 10-environment-configuration-examples.md  # Config examples & code
├── 11-edgequake-integration-summary.md   # Edgequake integration
├── 12-documentation-index.md             # Full documentation index
├── 13-pre-deployment-terraform-checklist.md # Deployment guide
├── 14-terraform-status-and-updates.md    # Terraform analysis
├── 15-edgequake-deployment-ready.md      # Deployment instructions
└── 16-developer-database-access.md       # This file's details
```

See [docs/12-documentation-index.md](docs/12-documentation-index.md) for full navigation guide.

---

## ❓ Questions?

1. Check the relevant documentation file (see Quick Links above)
2. Review the troubleshooting sections in docs
3. Check VM logs: `make logs-vm`
4. Check Cloud Run logs: `make logs-cloud-run`
5. SSH into VM for manual inspection: `make ssh`

---

**Last Updated**: January 2025  
**Status**: Ready for development ✅

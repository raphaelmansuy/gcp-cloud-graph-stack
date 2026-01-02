# Architecture: PostgreSQL + AGE + pgvector on GCP — concise, actionable

Target audience: solo dev or small team prototyping graph+vector features on GCP. Use managed products for production-grade reliability.

## Quick summary
- Goal: run graph (Apache AGE) and vector search (`pgvector`) together with minimal cost and clear ops responsibilities.
- Recommendation: If you need integrated graph+vector in one DB today, self-manage PostgreSQL 16+ on Compute Engine and install AGE + `pgvector`. If vectors-only is sufficient, prefer Cloud SQL for Postgres with `pgvector` (managed, lower ops).
- Networking: prefer Direct VPC egress from Cloud Run to your VPC; use Serverless VPC Access only if Direct VPC egress is not available (connectors incur compute charges and higher latency).
- Spot VMs: great for non-critical workloads, but Spot VMs can be stopped or deleted with short notice — do not run primary DB on Spot if you require availability.

Verified references:
- Cloud SQL supported extensions (includes `pgvector`): https://docs.cloud.google.com/sql/docs/postgres/extensions
- Direct VPC egress vs Serverless VPC Access (recommendation + pricing note): https://docs.cloud.google.com/run/docs/configuring/connecting-vpc
- Spot VMs preemption and guidance: https://docs.cloud.google.com/compute/docs/instances/spot
- Cloud Run pricing and free tier: https://cloud.google.com/run/pricing

## Decision checklist (pick one)
- Vectors + graphs, single DB, prototype: self-managed Postgres 16+ on Compute Engine (install AGE + `pgvector`).
- Vectors only, lower ops: Cloud SQL for Postgres (enable `pgvector`).
- Production reliability priority: split responsibilities — AlloyDB/Cloud SQL for vectors, managed graph DB for graph workloads.

## Minimal actionable design (prototype)

1) Database (self-managed path)
- Create a private Compute Engine VM (Ubuntu 22.04) in your VPC. Use a non-Spot VM for the primary database.
- Install PostgreSQL 16, build and install AGE (pin a tested tag), install `pgvector` and build HNSW indexes for vectors.
- Enable WAL archiving to a GCS bucket and schedule daily `pg_dump` snapshots.

Quick install snippet (startup script — test locally first):
```bash
apt update && apt install -y build-essential git postgresql-16 postgresql-server-dev-16
git clone https://github.com/apache/age.git && cd age && git checkout PG16 && make install
psql -d postgres -c "CREATE EXTENSION IF NOT EXISTS vector;"
psql -d postgres -c "CREATE EXTENSION IF NOT EXISTS age;"
```

Note: AGE builds can require >=4GB free RAM. Pin versions and test upgrades.

2) Database (managed path — lower ops)
- Use Cloud SQL for Postgres and enable the `pgvector` extension (Cloud SQL explicitly lists supported extensions).

3) Application
- Next.js frontend on Cloud Run; Rust API (Axum) on Cloud Run for DB interactions.
- Configure services to use Direct VPC egress to reach private DB IPs. If Direct VPC egress is not available, use a Serverless VPC Access connector but expect connector compute charges and potentially higher latency.
- Use Secret Manager and least-privilege service accounts.

4) Performance & reliability actions (must-do)
- Use connection pooling in Rust (deadpool-postgres) and set Cloud Run concurrency/min-instances to limit open connections.
- Build HNSW indexes for `pgvector` and use indexed graph queries for AGE.
- Backups: WAL archive to GCS + periodic base backups (pg_basebackup or pg_dump). Test restores.

5) Monitoring & alerts
- Install Cloud Ops agent on the VM (self-managed) and configure CPU, disk, connection-count alerts. Add alerts for preemption if you use Spot VMs.

## Costs (prototype ballpark)
- Self-managed minimal stack (one small VM, 50GB PD, 2 Cloud Run services): ~$15–40/month depending on VM size and traffic. Managed (Cloud SQL + Cloud Run) typically increases predictable cost but reduces ops.

## Short actionable roadmap (ordered)
1. Decide: self-managed (AGE+`pgvector`) or managed (Cloud SQL + `pgvector`).
2. Provision VPC, subnets, and Direct VPC egress for Cloud Run (recommended).
3. Provision DB (VM or Cloud SQL). If VM: bootstrap script to install PG, AGE, `pgvector`.
4. Containerize Next.js and Rust services; deploy to Cloud Run with service accounts and Secret Manager.
5. Add WAL archiving to GCS, configure Cloud Monitoring, and run integration + load tests.

## Risks & mitigations (summary)
- AGE compatibility/ops: build in CI, pin versions, prefer managed graph DB if operations become heavy.
- Spot VM preemption: do not run primary DB on Spot; if you use Spot for cost, ensure WAL to GCS and fast restore automation.
- Serverless VPC Access vs Direct VPC egress: prefer Direct VPC egress — connectors incur compute charges and add potential latency.

---
If you want, I can next:
- expand the chosen path into a deployable `terraform` + `cloudbuild.yaml` + `Dockerfile` set, or
- produce a short CI/CD playbook (GitHub Actions) that builds containers and deploys Cloud Run + VM bootstrap.


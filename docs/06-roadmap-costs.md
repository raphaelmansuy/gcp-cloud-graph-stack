# Roadmap & Cost Analysis

## Project Roadmap: Q1-Q4

### Phase 1: MVP (Weeks 1-4) — CURRENT
```
Week 1: Infrastructure
  [x] Set up Terraform configuration
  [x] Provision VPC, VM, Cloud Run
  [x] Deploy PostgreSQL 16 with AGE & pgvector
  [x] Create Artifact Registry

Week 2: CI/CD
  [x] Configure GitHub Actions or Cloud Build
  [x] Build and push Docker images
  [x] Deploy services to Cloud Run
  [x] Verify end-to-end flow

Week 3: Application Development
  [ ] Develop Next.js frontend (React UI)
  [ ] Develop Rust API (Axum service)
  [ ] Implement PostgreSQL + AGE schema
  [ ] Create sample graph and vector operations

Week 4: Testing & Hardening
  [ ] Integration tests (frontend ↔ API ↔ DB)
  [ ] Load testing (Cloud Load Testing)
  [ ] Security scanning (container images)
  [ ] Documentation & runbooks
```

### Phase 2: Production Ready (Weeks 5-8)
```
Week 5: Monitoring & Alerting
  [ ] Cloud Monitoring dashboards (CPU, memory, errors)
  [ ] Alert policies (error rate, latency, resource usage)
  [ ] Log aggregation and analysis
  [ ] Error tracking (Sentry or similar)

Week 6: Backup & Disaster Recovery
  [ ] WAL archiving to GCS
  [ ] Automated daily backups
  [ ] Test restore procedure
  [ ] RTO/RPO documentation

Week 7: Security Hardening
  [ ] VPC Service Controls
  [ ] Cloud Armor DDoS protection
  [ ] Container image scanning (Trivy)
  [ ] Binary Authorization
  [ ] Secrets rotation (Vault or Secret Manager)

Week 8: Performance Optimization
  [ ] Profile database queries
  [ ] Optimize indexes on graph tables
  [ ] Cache layer (Redis/Memorystore)
  [ ] CDN for static assets (Cloud CDN)
```

### Phase 3: Scale (Weeks 9-12)
```
Week 9: Multi-Region
  [ ] Replicate PostgreSQL to secondary region
  [ ] Deploy Cloud Run globally
  [ ] Global load balancing
  [ ] Cross-region failover

Week 10: Advanced Features
  [ ] Implement search (Cloud SQL Search, Elasticsearch)
  [ ] Real-time streaming (Pub/Sub)
  [ ] Vector similarity search at scale
  [ ] Graph traversal optimizations

Week 11: Cost Optimization
  [ ] Reserved instances for VM
  [ ] Committed use discounts
  [ ] Auto-scaling policies
  [ ] Spot VMs for batch jobs

Week 12: Documentation & Handoff
  [ ] Runbooks for common operations
  [ ] SOP for incident response
  [ ] Team training sessions
  [ ] Architecture decision records (ADRs)
```

---

## Cost Analysis

### Estimated Monthly Costs (Development)

| Component | Pricing | Usage | Monthly Cost |
|-----------|---------|-------|--------------|
| **Compute Engine VM** | $0.0347/hr (e2-standard-2) | 730 hrs/mo | ~$25 |
| **Cloud Run (Next.js)** | $0.40 per 1M requests | 100k requests | ~$5 |
| **Cloud Run (Rust API)** | $0.40 per 1M requests | 100k requests | ~$5 |
| **Cloud Run (vCPU-s)** | $0.0000250/s | 500k sec | ~$12.50 |
| **Cloud Run (Memory-GB-s)** | $0.0000050/s | 256 GB-sec | ~$1.28 |
| **Artifact Registry** | First 0.5 GB free, then $0.10/GB | 1 GB stored | ~$0.10 |
| **Cloud Storage (backups)** | $0.020/GB | 10 GB | ~$0.20 |
| **Cloud Logging** | First 50 GB/mo free | 20 GB | $0 |
| **Cloud Monitoring** | First 150 MB/mo free | 30 MB | $0 |
| **Secret Manager** | $0.06/secret/month | 5 secrets | ~$0.30 |
| **VPC Connector** (if used) | $0.125/vCPU-month + charges | Not used | $0 |
| **Networking** | Egress: $0.12/GB | 10 GB | ~$1.20 |
| **Cloud Build** | First 120 min/day free, then $0.01/min | 200 min/mo | ~$0 |
| **Cloud SQL (if used)** | $0.07/hour (db-f1-micro) | Not used | $0 |
| **Memorystore (optional)** | $0.083/GB/hour | Not used | $0 |
| | | **TOTAL** | **~$50/month** |

### Estimated Monthly Costs (Production)

| Component | Pricing | Usage | Monthly Cost |
|-----------|---------|-------|--------------|
| **Compute Engine VM** | $0.0347/hr (e2-standard-4, 2 replicas) | 1,460 hrs | ~$100 |
| **Cloud Run (Next.js)** | $0.40 per 1M requests | 5M requests | ~$2 |
| **Cloud Run (Rust API)** | $0.40 per 1M requests | 5M requests | ~$2 |
| **Cloud Run (vCPU-s)** | $0.0000250/s | 30M sec | ~$750 |
| **Cloud Run (Memory-GB-s)** | $0.0000050/s | 15 GB-sec | ~$75 |
| **Artifact Registry** | $0.10/GB | 50 GB | ~$5 |
| **Cloud Storage (backups)** | $0.020/GB | 500 GB (with redundancy) | ~$10 |
| **Cloud Logging** | $0.50/GB (after 50 GB free) | 500 GB | ~$225 |
| **Cloud Monitoring** | $0.257 per 150k MTS | 10k MTS | ~$17 |
| **Secret Manager** | $0.06/secret/month | 10 secrets | ~$0.60 |
| **VPC Connector** | $0.125/vCPU-month | Not used | $0 |
| **Cloud CDN** | $0.085/GB | 100 GB | ~$8.50 |
| **Networking** | $0.12/GB | 500 GB | ~$60 |
| **Cloud Build** | $0.01/min | 500 min | ~$5 |
| **Managed Redis (Memorystore)** | $0.083/GB/hour | 2 GB | ~$12 |
| **Cloud Armor** | $5/month + $0.75 per 1M requests | 5M | ~$8.75 |
| | | **TOTAL** | **~$1,280/month** |

### Cost Optimization Opportunities

#### 1. Use Spot VMs (70% discount)

```hcl
# In terraform/variables.tf
variable "use_spot_vm" {
  default = true
}

# In terraform/modules/compute/main.tf
scheduling {
  preemptible       = var.use_spot_vm
  automatic_restart = !var.use_spot_vm
}
```

**Savings**: $25 → $7.50/month per VM

#### 2. Reserved Instances (30% discount)

For production VM, purchase 1-year commitment:

```bash
gcloud compute instances create ... \
  --reservation-affinity=any
```

**Savings**: $100 → $70/month

#### 3. Committed Use Discounts (CUDs)

Purchase 1-year commitment for Cloud Run:

- vCPU: $0.0192/s (24% discount)
- Memory: $0.00408/GB-s (18% discount)

**Savings**: ~$600/month → $450/month

#### 4. Auto-Scaling (scale to zero)

Cloud Run automatically scales to 0 replicas when idle:

```hcl
# In terraform/modules/cloud_run/main.tf
traffic {
  latest_revision = true
  percent         = 100
}

service_config {
  min_instance_count = 0  # Scale to zero
  max_instance_count = 100
}
```

**Savings**: Eliminates idle compute costs

#### 5. Compress Logs

Configure log exclusion to reduce volume:

```bash
gcloud logging sinks create exclude_health_checks \
  storage.googleapis.com/logs \
  --log-filter='severity >= WARNING AND -protoPayload.methodName="compute.instances.setMetadata"'
```

**Savings**: 50% reduction in logging costs

#### 6. Use Cheaper Storage Class

For backups, use Nearline/Coldline:

```bash
gsutil lifecycle set - gs://saas-app-001-db-backups <<EOF
{
  "lifecycle": [
    {
      "action": {"type": "SetStorageClass", "storageClass": "NEARLINE"},
      "condition": {"age": 30}
    }
  ]
}
EOF
```

**Savings**: $0.020/GB → $0.010/GB

---

## ROI Analysis

### Scenario 1: Startup (MVP)

```
Investment (Setup):
- Developer Time: 4 weeks × 40 hrs = 160 hrs
  (Estimated $16k at $100/hr contractor rate, $0 if in-house)
- Infrastructure: $0 (GCP free tier covers MVP)

Monthly Operating Cost: $50
Annual Cost: $600

Break-even: Immediate (if in-house)
```

### Scenario 2: SaaS Product ($10k/month revenue)

```
Investment (Setup):
- Initial development: 2 engineers × 8 weeks = 64k (if contractor)
- Or in-house team cost amortized

Monthly Operating Cost: $300 (3x dev costs with Spot VMs + CUDs)
Annual Operating Cost: $3,600

Gross Margin: $10,000 - $300 = $9,700/month (97%)
Annual Gross Profit: $116,400

ROI: $116,400 / $64,000 = 1.8x in Year 1
```

### Scenario 3: Enterprise (1M API calls/month)

```
Estimated Monthly Operating Cost: $3,000-5,000
  (Assuming optimized with CUDs + Spot VMs)

Enterprise Customer Revenue: $50k-100k/month
Gross Margin: 95%+ (platform scales well)

Infrastructure represents <5% of revenue
```

---

## Decision Matrix: Cloud SQL vs Self-Managed PostgreSQL

| Criteria | Cloud SQL | Self-Managed VM |
|----------|-----------|-----------------|
| **Cost** | $7/day+ | $1/day |
| **AGE Support** | ❌ Not available | ✅ Available |
| **Backups** | ✅ Automated | ⚠️ Manual (WAL archiving) |
| **HA/Failover** | ✅ Regional replicas | ⚠️ Manual setup |
| **Patching** | ✅ Automatic | ❌ Manual |
| **Monitoring** | ✅ Native integration | ⚠️ Custom agents |
| **Scaling** | ✅ Vertical (limited) | ✅ Flexible |
| **Lock-in** | ⚠️ Proprietary backups | ✅ Standard PostgreSQL |

**Recommendation**: 
- **MVP**: Self-managed (AGE requirement, cost)
- **Production**: Hybrid (Cloud SQL primary + self-managed AGE read replicas)

---

## Path to Production Checklist

```
Cost Optimization:
  [ ] Enable Spot VMs for dev/test environments
  [ ] Purchase CUDs for production Cloud Run
  [ ] Set Cloud Run min instances to 0
  [ ] Configure log retention (30 days → 7 days)
  [ ] Use cheaper storage class for backups

Capacity Planning:
  [ ] Estimate peak QPS (queries per second)
  [ ] Load test with production-like data
  [ ] Calculate required vCPU/Memory
  [ ] Set auto-scaling thresholds
  [ ] Monitor and adjust monthly

Financial Controls:
  [ ] Set GCP budget alert ($500/month)
  [ ] Enable Cost Analysis dashboard
  [ ] Review costs weekly
  [ ] Document cost allocation (per customer/project)
  [ ] Set up chargeback process (if multi-team)

Forecasting:
  [ ] Project growth (10% MoM, 50% YoY)
  [ ] Calculate future costs at 10M API calls
  [ ] Identify cost reduction opportunities
  [ ] Plan for multi-region expansion
```

---

## References

- [GCP Pricing Calculator](https://cloud.google.com/products/calculator)
- [Cloud SQL Pricing](https://cloud.google.com/sql/pricing)
- [Cloud Run Pricing](https://cloud.google.com/run/pricing)
- [Compute Engine Pricing](https://cloud.google.com/compute/pricing)
- [Committed Use Discounts](https://cloud.google.com/docs/cuds)
- [Spot VMs Documentation](https://cloud.google.com/compute/docs/instances/spot)

# EdgeQuake Security Checklist

**Date**: 2026-01-05  
**Status**: Production Ready with Recommendations

## ✅ Current Security Posture

### Network Security

```
┌─────────────────────────────────────────┐
│      INTERNET (TLS 1.3)                 │
│   - Users                               │
│   - External APIs (OpenAI)              │
└───────────┬─────────────────────────────┘
            │
     ┌──────┴──────┐
     │             │
┌────▼────┐   ┌────▼────┐
│  WebUI  │   │   API   │  (Cloud Run - Public HTTPS)
│ Cloud   │   │ Cloud   │
│  Run    │   │  Run    │
└─────────┘   └────┬────┘
                   │
         ┌─────────▼──────────┐
         │  VPC Connector     │  (10.8.0.0/28)
         │  (Encrypted)       │
         └─────────┬──────────┘
                   │
         ┌─────────▼──────────┐
         │  VPC Network       │
         │  10.0.0.0/16       │
         │                    │
         │  ┌──────────────┐  │
         │  │  Cloud NAT   │──┼──→ Internet (Egress Only)
         │  └──────────────┘  │
         │                    │
         │  ┌──────────────┐  │
         │  │ PostgreSQL   │  │  (Private: 10.0.0.12)
         │  │   NO PUBLIC  │  │
         │  │      IP      │  │
         │  └──────────────┘  │
         └────────────────────┘
```

### ✅ Implemented Security Controls

| Control | Status | Details |
|---------|--------|---------|
| **TLS/HTTPS** | ✅ Enforced | All Cloud Run services use Google-managed TLS 1.3 |
| **Database Isolation** | ✅ Complete | PostgreSQL has NO public IP, VPC-only |
| **Network Segmentation** | ✅ Implemented | VPC Connector isolates Cloud Run → DB traffic |
| **Cloud NAT** | ✅ Configured | Internet egress for external APIs (OpenAI) |
| **Firewall Rules** | ⚠️ Partial | DB port restricted, SSH needs IP restriction |
| **Secret Management** | ✅ Configured | OpenAI API key in Secret Manager |
| **IAM** | ✅ Configured | Service accounts with least privilege |
| **Data Encryption** | ✅ Enabled | At-rest (disk) and in-transit (TLS) |

### Firewall Rules Audit

```bash
# Current firewall rules
edgequake-allow-cloud-run-to-db:
  - Source: 10.8.0.0/28 (VPC Connector only)
  - Target: postgresql
  - Ports: 5432
  - Status: ✅ SECURE (private network only)

edgequake-allow-ssh:
  - Source: 0.0.0.0/0 (ALL INTERNET)
  - Target: allow-ssh
  - Ports: 22
  - Status: ⚠️ NEEDS RESTRICTION (use secure-ssh-access.sh)
```

## ⚠️ Security Recommendations

### Priority 1: SSH Access Restriction

**Current State**: SSH accessible from anywhere (0.0.0.0/0)  
**Recommended**: Restrict to specific IPs only

```bash
# Run this script to restrict SSH to your current IP
./scripts/secure-ssh-access.sh

# Or manually update firewall rule:
MYIP=$(curl -s ifconfig.me)
gcloud compute firewall-rules update edgequake-allow-ssh \
  --source-ranges="${MYIP}/32"
```

**Why**: Reduces attack surface for SSH brute-force attempts

### Priority 2: Enable Cloud Armor (Optional)

For production with high traffic:

```bash
# Create Cloud Armor security policy
gcloud compute security-policies create edgequake-policy \
  --description="EdgeQuake WAF policy"

# Add rate limiting rule
gcloud compute security-policies rules create 1000 \
  --security-policy=edgequake-policy \
  --expression="true" \
  --action=rate-based-ban \
  --rate-limit-threshold-count=100 \
  --rate-limit-threshold-interval-sec=60 \
  --ban-duration-sec=600
```

### Priority 3: Database Backup Strategy

**Current**: Persistent disk attached to VM  
**Recommended**: Automated snapshots

```bash
# Create snapshot schedule
gcloud compute resource-policies create snapshot-schedule edgequake-db-backup \
  --region=us-central1 \
  --max-retention-days=7 \
  --on-source-disk-delete=keep-auto-snapshots \
  --daily-schedule \
  --start-time=03:00

# Attach to disk
gcloud compute disks add-resource-policies edgequake-db-data \
  --resource-policies=edgequake-db-backup \
  --zone=us-central1-a
```

## ✅ Security Validation Commands

```bash
# 1. Verify Cloud Run services use HTTPS only
gcloud run services list --format="table(name,url)" | grep https

# 2. Verify database has no public IP
gcloud compute instances describe edgequake-db-vm \
  --zone=us-central1-a \
  --format="get(networkInterfaces[0].accessConfigs)" 
# Should return: []

# 3. Verify firewall rules
gcloud compute firewall-rules list \
  --filter="network:edgequake-vpc" \
  --format="table(name,sourceRanges,allowed)"

# 4. Verify secrets are not in code
grep -r "sk-[a-zA-Z0-9]" . --exclude-dir=node_modules --exclude-dir=target
# Should return only placeholders like "sk-..."

# 5. Verify VPC Connector configuration
gcloud compute networks vpc-access connectors describe edgequake-vpc-connector \
  --region=us-central1
```

## 📋 Pre-Production Checklist

- [ ] SSH firewall rule restricted to known IPs (`./scripts/secure-ssh-access.sh`)
- [ ] Secrets stored in Secret Manager (not in code/env files)
- [ ] Database backups configured (snapshot schedule)
- [ ] Cloud Run services use IAM authentication (not just public)
- [ ] Monitoring and alerting configured
- [ ] Cloud NAT logging enabled (`ERRORS_ONLY` minimum)
- [ ] Review IAM permissions (principle of least privilege)
- [ ] Enable Cloud Audit Logs for compliance

## 🔐 Secret Management Best Practices

### ✅ Current Implementation

```terraform
# Secrets stored in Google Secret Manager
resource "google_secret_manager_secret" "openai_api_key" {
  secret_id = "openai-api-key"
  
  replication {
    auto {}
  }
}

# Cloud Run references secrets
env {
  name = "OPENAI_API_KEY"
  value_source {
    secret_key_ref {
      secret  = "openai-api-key"
      version = "latest"
    }
  }
}
```

### ⚠️ Never Commit

- ❌ `*.tfvars` (already in .gitignore)
- ❌ `.env` files with real keys
- ❌ Service account key JSON files
- ❌ Database credentials
- ❌ API keys (use Secret Manager)

## 📊 Security Monitoring

### Enable Cloud Logging

```bash
# View Cloud Run logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=edgequake-api" \
  --limit 20 --format json

# View Cloud NAT logs (errors only)
gcloud logging read "resource.type=nat_gateway" --limit 20

# View firewall logs
gcloud logging read "resource.type=gce_firewall" --limit 20
```

### Set Up Alerts

```bash
# Alert on failed authentication attempts
gcloud alpha monitoring policies create \
  --notification-channels=CHANNEL_ID \
  --display-name="Failed SSH Attempts" \
  --condition-display-name="High failed auth rate" \
  --condition-threshold-value=10 \
  --condition-threshold-duration=60s
```

## 🎯 Security Score

| Category | Score | Notes |
|----------|-------|-------|
| Network Isolation | 9/10 | ✅ VPC, Cloud NAT, private DB |
| Access Control | 7/10 | ⚠️ SSH needs IP restriction |
| Secret Management | 10/10 | ✅ Using Secret Manager |
| Encryption | 10/10 | ✅ TLS + at-rest |
| Monitoring | 6/10 | ⚠️ Basic logging only |
| Backup/DR | 4/10 | ⚠️ Manual snapshots only |
| **Overall** | **7.7/10** | **Production Ready** |

## 📖 Related Documentation

- [SSH Tunnel Security](../SSH_TUNNEL_CHALLENGE.md) - SSH hardening guide
- [Security Verification Report](22-security-verification-report.md) - Current deployment audit
- [Environment Configuration](18-edgequake-environment-config.md) - Secret Manager setup

---

**Last Updated**: 2026-01-05  
**Next Review**: After infrastructure changes or security incidents

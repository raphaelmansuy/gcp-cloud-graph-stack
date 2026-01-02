# Deployment Checklist

Use this checklist to ensure every step is completed before moving to the next phase.

## Phase 1: Pre-Deployment Setup (Day 1)

### Prerequisites
- [ ] GCP account with billing enabled
- [ ] `gcloud` CLI installed and authenticated
- [ ] Terraform 1.5+ installed
- [ ] Docker installed and running
- [ ] Git repository cloned locally
- [ ] GitHub account (if using GitHub Actions)

### GCP Configuration
- [ ] Set default project: `gcloud config set project saas-app-001`
- [ ] Verify authentication: `gcloud auth login`
- [ ] Set up application-default credentials: `gcloud auth application-default login`
- [ ] Verify APIs are enabled (or will be enabled by Terraform)
- [ ] Create GCS bucket for Terraform state: `gsutil mb gs://saas-app-001-tf-state`
- [ ] Enable versioning on state bucket
- [ ] Create GCS bucket for backups: `gsutil mb gs://saas-app-001-db-backups`

### Repository Setup
- [ ] Clone repository: `git clone <repo-url>`
- [ ] Copy Terraform variables: `cp terraform/terraform.tfvars.example terraform/terraform.tfvars`
- [ ] Edit `terraform/terraform.tfvars` with your settings:
  - [ ] `project_id = "saas-app-001"`
  - [ ] `region = "us-central1"`
  - [ ] `environment = "dev"`
  - [ ] `gcs_backup_bucket = "saas-app-001-db-backups"`
  - [ ] `enable_direct_vpc_egress = true` (recommended)
  - [ ] `enable_wal_archiving = true`
- [ ] Review all other variables
- [ ] Commit terraform.tfvars (or add to .gitignore if sensitive)

### Documentation Review
- [ ] Read [Architecture Overview](./docs/01-architecture.md)
- [ ] Read [Quick Start Guide](./docs/05-quick-start.md)
- [ ] Review [Cost Analysis](./docs/06-roadmap-costs.md)
- [ ] Understand cost implications (~$50/month for dev, ~$300/month for prod)

---

## Phase 2: Infrastructure Deployment (Day 1-2)

### Terraform Initialization
- [ ] `cd terraform && terraform init`
- [ ] Verify initialization successful (`.terraform/` directory created)
- [ ] Check state is empty: `terraform state list` (should be empty)

### Terraform Planning
- [ ] Run `terraform plan -out=tfplan`
- [ ] Review plan output carefully:
  - [ ] ~20 resources will be created (VPC, VM, Cloud Run, etc.)
  - [ ] No resources will be destroyed
  - [ ] No unexpected changes
- [ ] Check for any errors or warnings
- [ ] Verify plan matches expected infrastructure diagram

### Terraform Apply
- [ ] Run `terraform apply tfplan`
- [ ] Wait for apply to complete (10-15 minutes)
- [ ] Verify all resources created successfully
- [ ] Save outputs: `terraform output > outputs.txt`
- [ ] Note the following values from outputs:
  - [ ] VPC ID: `_______________________`
  - [ ] VM private IP: `_______________________`
  - [ ] VM external IP: `_______________________`
  - [ ] Artifact Registry URL: `_______________________`

### Infrastructure Verification
- [ ] List compute instances: `gcloud compute instances list`
  - [ ] edgequake-db-vm should be RUNNING
- [ ] List Cloud Run services: `gcloud run services list --region=us-central1`
  - [ ] nextjs-frontend should exist
  - [ ] rust-api should exist
- [ ] Check Artifact Registry: `gcloud artifacts repositories list --location=us-central1`
  - [ ] edgequake-images repository should exist
- [ ] Verify VPC: `gcloud compute networks list`
  - [ ] edgequake-vpc should exist
- [ ] Verify firewall rules: `gcloud compute firewall-rules list --filter="network:edgequake-vpc"`
  - [ ] Rules for Cloud Run → PostgreSQL should exist
  - [ ] SSH access rule should exist

---

## Phase 3: PostgreSQL Verification (Day 2)

### SSH into VM
- [ ] SSH into VM: `gcloud compute ssh edgequake-db-vm --zone=us-central1-a`
- [ ] VM is responsive and connection successful

### PostgreSQL Service
- [ ] Check PostgreSQL is running: `sudo systemctl status postgresql`
  - [ ] Status should be "active (running)"
- [ ] Check PostgreSQL version: `sudo -u postgres psql -c "SELECT version();"`
  - [ ] Should be PostgreSQL 16.x
- [ ] Verify database exists: `sudo -u postgres psql -l | grep graph_db`
  - [ ] graph_db should be listed

### Extensions Verification
- [ ] Check installed extensions:
  ```bash
  sudo -u postgres psql -d graph_db -c \
    "SELECT extname, extversion FROM pg_extension WHERE extname IN ('age', 'vector');"
  ```
  - [ ] age extension installed (version 1.3.0+)
  - [ ] vector extension installed (version 0.5.0+)

### Database Connectivity
- [ ] Connect to database: `sudo -u postgres psql -d graph_db`
- [ ] Run test query: `SELECT 1;`
  - [ ] Query executes successfully
- [ ] Exit psql: `\q`

### WAL Archiving (if enabled)
- [ ] Check WAL archiving enabled: `sudo -u postgres psql -d graph_db -c "SHOW archive_mode;"`
  - [ ] Should be 'on'
- [ ] Check archive command: `sudo -u postgres psql -d graph_db -c "SHOW archive_command;"`
  - [ ] Should contain `gs://saas-app-001-db-backups`

### Exit VM
- [ ] Exit SSH: `exit`

---

## Phase 4: Docker Image Building & Pushing (Day 2-3)

### Local Build (Development Only)

#### Next.js Image
- [ ] Prerequisites exist:
  - [ ] `dockerfiles/Dockerfile.nextjs` exists
  - [ ] `package.json` and `src/` (or equivalent) exist
- [ ] Build locally: `docker build -t nextjs:test -f dockerfiles/Dockerfile.nextjs .`
  - [ ] Build succeeds without errors
  - [ ] Image size is reasonable (~500MB)
- [ ] Test locally (optional): `docker run -p 8080:8080 nextjs:test`
  - [ ] Container starts successfully
  - [ ] Health check passes

#### Rust API Image
- [ ] Prerequisites exist:
  - [ ] `dockerfiles/Dockerfile.rust` exists
  - [ ] `Cargo.toml` and `src/` exist
- [ ] Build locally: `docker build -t rust-api:test -f dockerfiles/Dockerfile.rust .`
  - [ ] Build succeeds without errors
  - [ ] Image size is reasonable (~200MB)
- [ ] Test locally (optional): `docker run -p 8080:8080 rust-api:test`
  - [ ] Container starts successfully
  - [ ] Health check passes

### Artifact Registry Push

#### Configure Docker Auth
- [ ] Configure Docker auth: `gcloud auth configure-docker us-central1-docker.pkg.dev`
- [ ] Verify auth: `cat ~/.docker/config.json | grep us-central1-docker.pkg.dev`

#### Tag and Push Next.js
- [ ] Tag image: `docker tag nextjs:test us-central1-docker.pkg.dev/saas-app-001/edgequake-images/nextjs:latest`
- [ ] Push to registry: `docker push us-central1-docker.pkg.dev/saas-app-001/edgequake-images/nextjs:latest`
  - [ ] Push completes without errors
  - [ ] Image appears in Artifact Registry
- [ ] Verify: `gcloud artifacts docker images list us-central1-docker.pkg.dev/saas-app-001/edgequake-images`
  - [ ] nextjs:latest is listed

#### Tag and Push Rust API
- [ ] Tag image: `docker tag rust-api:test us-central1-docker.pkg.dev/saas-app-001/edgequake-images/rust-api:latest`
- [ ] Push to registry: `docker push us-central1-docker.pkg.dev/saas-app-001/edgequake-images/rust-api:latest`
  - [ ] Push completes without errors
  - [ ] Image appears in Artifact Registry
- [ ] Verify: `gcloud artifacts docker images list us-central1-docker.pkg.dev/saas-app-001/edgequake-images`
  - [ ] rust-api:latest is listed

---

## Phase 5: Cloud Run Deployment (Day 3)

### Update Terraform Variables
- [ ] Edit `terraform/terraform.tfvars`:
  - [ ] `nextjs_image = "us-central1-docker.pkg.dev/saas-app-001/edgequake-images/nextjs:latest"`
  - [ ] `rust_api_image = "us-central1-docker.pkg.dev/saas-app-001/edgequake-images/rust-api:latest"`
- [ ] Verify no other changes needed

### Terraform Reapply
- [ ] Run `terraform plan -out=tfplan`
  - [ ] Should show 2 resource updates (Cloud Run services with new images)
- [ ] Run `terraform apply tfplan`
  - [ ] Services update successfully
  - [ ] Wait for deployment to complete (~5-10 minutes)

### Cloud Run Service Verification
- [ ] Describe Next.js service:
  ```bash
  gcloud run services describe nextjs-frontend --region=us-central1
  ```
  - [ ] Status: Ready
  - [ ] Latest revision is ACTIVE
  - [ ] Container is healthy

- [ ] Describe Rust API service:
  ```bash
  gcloud run services describe rust-api --region=us-central1
  ```
  - [ ] Status: Ready
  - [ ] Latest revision is ACTIVE
  - [ ] Container is healthy

### Service URLs
- [ ] Get Next.js URL:
  ```bash
  gcloud run services describe nextjs-frontend --region=us-central1 --format='value(status.url)'
  ```
  - [ ] URL format: `https://nextjs-frontend-xxx.run.app`

- [ ] Get Rust API URL:
  ```bash
  gcloud run services describe rust-api --region=us-central1 --format='value(status.url)'
  ```
  - [ ] URL format: `https://rust-api-xxx.run.app`

---

## Phase 6: End-to-End Testing (Day 3-4)

### Test Next.js Frontend
- [ ] Access Next.js URL in browser: `https://nextjs-frontend-xxx.run.app`
  - [ ] Page loads successfully
  - [ ] No console errors
- [ ] Or test via curl:
  ```bash
  curl https://nextjs-frontend-xxx.run.app
  ```
  - [ ] Returns HTML (200 OK)

### Test Rust API
- [ ] Test health endpoint:
  ```bash
  curl https://rust-api-xxx.run.app/health
  ```
  - [ ] Returns 200 OK or JSON response

- [ ] Test API endpoint (customize based on your schema):
  ```bash
  curl -X POST https://rust-api-xxx.run.app/api/... \
    -H "Content-Type: application/json" \
    -d '{"key": "value"}'
  ```
  - [ ] Returns expected response

### Test Database Connectivity
- [ ] SSH into VM and run queries:
  ```bash
  gcloud compute ssh edgequake-db-vm --zone=us-central1-a
  sudo -u postgres psql -d graph_db
  ```

- [ ] Test AGE (graph) query:
  ```sql
  SELECT create_graph('test_graph');
  SELECT * FROM cypher('test_graph', $$ 
    CREATE (n:Node {name: 'Test'}) 
    RETURN n 
  $$) AS (node agtype);
  ```
  - [ ] Query executes successfully

- [ ] Test pgvector (vector search) query:
  ```sql
  CREATE TABLE IF NOT EXISTS test_vectors (
    id SERIAL PRIMARY KEY,
    embedding vector(3)
  );
  INSERT INTO test_vectors (embedding) VALUES ('[1,2,3]'::vector);
  SELECT * FROM test_vectors;
  ```
  - [ ] Query executes successfully

- [ ] Exit database: `\q` and VM: `exit`

### Test Inter-Service Communication
- [ ] (If services are designed to communicate)
- [ ] Deploy a test endpoint that calls the other service
- [ ] Verify both services can communicate via private VPC

---

## Phase 7: CI/CD Setup (Day 4-5)

### GitHub Actions Setup (if chosen)
- [ ] Follow [GitHub Actions Setup Guide](./docs/03-deployment-github-actions.md)
- [ ] Create GitHub Workload Identity Pool
- [ ] Create Workload Identity Provider
- [ ] Create service account: `github-actions-deployer`
- [ ] Grant required IAM roles:
  - [ ] `roles/run.admin` (Cloud Run Admin)
  - [ ] `roles/artifactregistry.writer` (Artifact Registry Writer)
- [ ] Configure service account impersonation
- [ ] Add GitHub secrets:
  - [ ] `GCP_PROJECT_ID`
  - [ ] `GCP_REGION`
  - [ ] `GCP_WORKLOAD_IDENTITY_PROVIDER`
  - [ ] `GCP_SERVICE_ACCOUNT`
- [ ] Test workflow by pushing to feature branch
  - [ ] GitHub Actions triggers
  - [ ] Build and push steps complete
  - [ ] No errors in logs
- [ ] Push to main branch
  - [ ] Full workflow (build, push, deploy) executes
  - [ ] Cloud Run services are updated
  - [ ] Verify new image deployed

### Cloud Build Setup (Alternative)
- [ ] Follow [Cloud Build Documentation](https://cloud.google.com/build/docs)
- [ ] Create Cloud Build trigger
- [ ] Configure substitutions:
  - [ ] `_REGION` = us-central1
  - [ ] `_REPO` = edgequake-images
- [ ] Test trigger:
  - [ ] Manually trigger build
  - [ ] Monitor build progress
  - [ ] Verify images pushed to Artifact Registry
- [ ] Configure automatic trigger on push
- [ ] Test automatic trigger:
  - [ ] Push to repository
  - [ ] Verify build triggered automatically
  - [ ] Check build success

---

## Phase 8: Monitoring & Alerts (Day 5)

### Cloud Logging
- [ ] View Cloud Run logs:
  ```bash
  gcloud logging read "resource.type=cloud_run_revision" \
    --limit=20 --format='table(timestamp, severity, textPayload)'
  ```
  - [ ] Logs are being collected
  - [ ] No error messages

- [ ] Set up log retention (30 days for prod; 7 days for dev):
  - [ ] Use a short retention bucket for dev to reduce storage costs (example: 7 days)
  - [ ] Configure conservative log exclusions (exclude DEBUG for Cloud Run / GCE / Cloud Build)
  ```bash
  # List sinks and exclusions
  gcloud logging sinks list
  gcloud logging exclusions list
  ```

### Cloud Monitoring
- [ ] Create monitoring dashboard:
  - [ ] CPU usage (VM)
  - [ ] Memory usage (VM)
  - [ ] Cloud Run request latency
  - [ ] Cloud Run error rate
  - [ ] Database connections
- [ ] Create alert policies:
  - [ ] VM CPU > 80% for 5 minutes
  - [ ] Cloud Run error rate > 1%
  - [ ] Database connections > 80
  - [ ] Disk usage > 80%

### Error Tracking (Optional)
- [ ] Set up Sentry or similar:
  - [ ] Create project
  - [ ] Add SDK to applications
  - [ ] Verify errors are captured

---

## Phase 9: Backup & Disaster Recovery (Day 6)

### WAL Archiving Verification (if enabled)
- [ ] Check WAL files are being archived:
  ```bash
  gsutil ls -r gs://saas-app-001-db-backups/
  ```
  - [ ] WAL files present
  - [ ] Files have recent timestamps

### Manual Backup Test
- [ ] Create manual backup:
  ```bash
  gcloud compute ssh edgequake-db-vm --zone=us-central1-a
  sudo -u postgres pg_basebackup -D /tmp/backup -Ft -z
  sudo tar czf backup.tar.gz /tmp/backup
  gsutil cp backup.tar.gz gs://saas-app-001-db-backups/manual/
  exit
  ```
  - [ ] Backup completes successfully
  - [ ] File appears in GCS

### Restore Procedure Documentation
- [ ] Document restore steps:
  - [ ] Restore from WAL archive
  - [ ] Restore from base backup
  - [ ] Point-in-time recovery
- [ ] Test restore (in dev environment only)
- [ ] Verify recovery works

---

## Phase 10: Security Hardening (Day 7)

### IAM Review
- [ ] Review service account permissions:
  - [ ] VM service account has minimal permissions
  - [ ] Cloud Run service account has minimal permissions
  - [ ] GitHub Actions service account has minimal permissions
- [ ] Remove any overly permissive roles
- [ ] Enable IAM audit logging

### Network Security
- [ ] Review firewall rules:
  - [ ] Cloud Run → PostgreSQL allowed
  - [ ] SSH access restricted (if applicable)
  - [ ] No unnecessary open ports
- [ ] Verify VPC is private (no public IPs for VM)
- [ ] Check that Direct VPC egress is enabled (Cloud Run)

### Container Image Security
- [ ] Enable image scanning:
  ```bash
  gcloud artifacts repositories update edgequake-images \\
    --location=us-central1 \
    --enable-analysis=true
  ```
- [ ] Scan existing images
- [ ] Review any vulnerabilities

### Secrets Management
- [ ] Store sensitive data in Google Secret Manager:
  - [ ] Database credentials
  - [ ] API keys
  - [ ] Service credentials
- [ ] Grant Cloud Run access to secrets
- [ ] Verify secrets are not in code

---

## Phase 11: Documentation & Knowledge Transfer (Day 7-8)

### Runbooks
- [ ] Create runbooks for:
  - [ ] Deployment procedure
  - [ ] Database backup and restore
  - [ ] Incident response
  - [ ] Scaling procedures
  - [ ] Rollback procedure

### Architecture Decision Records (ADRs)
- [ ] Document key decisions:
  - [ ] Why self-managed PostgreSQL vs Cloud SQL
  - [ ] Why Direct VPC egress vs VPC Connector
  - [ ] Why GitHub Actions vs Cloud Build
  - [ ] Why specific machine types/sizes

### Team Training
- [ ] Train team on:
  - [ ] How to deploy changes
  - [ ] How to check logs
  - [ ] How to respond to incidents
  - [ ] How to scale infrastructure
  - [ ] Cost monitoring

### Documentation Review
- [ ] Verify all documentation is accurate
- [ ] Ensure all links work
- [ ] Check code examples are valid
- [ ] Update with any custom configuration

---

## Phase 12: Production Readiness (Day 8+)

### Performance Testing
- [ ] Load test with expected traffic:
  - [ ] 100 concurrent users
  - [ ] 1000 RPS (requests per second)
  - [ ] Monitor resource usage
- [ ] Identify bottlenecks
- [ ] Optimize if needed

### Cost Review
- [ ] Review estimated costs
- [ ] Identify optimization opportunities
- [ ] Implement cost-saving measures:
  - [ ] Use Spot VMs for test environments
  - [ ] Purchase CUDs for production
  - [ ] Configure auto-scaling
  - [ ] Archive old logs

### Compliance Check
- [ ] Verify compliance requirements are met:
  - [ ] Data residency (us-central1)
  - [ ] Encryption at rest and in transit
  - [ ] Audit logging
  - [ ] Data retention policies
  - [ ] Access controls

### Final Sign-Off
- [ ] Stakeholder review and approval
- [ ] Document any agreed upon SLOs/SLAs
- [ ] Schedule post-deployment review
- [ ] Plan for future improvements

---

## Success Criteria Checklist

### Technical Success
- [x] Infrastructure deployed via Terraform
- [x] PostgreSQL 16 with AGE and pgvector installed
- [x] Cloud Run services running and responsive
- [x] Docker images built and pushed
- [x] CI/CD pipeline configured and tested
- [x] Database backups working
- [x] Monitoring and alerts configured
- [x] Security hardened
- [x] All tests passing
- [x] Documentation complete

### Operational Success
- [ ] Team trained on operational procedures
- [ ] On-call runbooks in place
- [ ] Incident response plan documented
- [ ] Cost monitoring configured
- [ ] Scaling procedures documented
- [ ] Disaster recovery tested

### Business Success
- [ ] Requirements met and validated
- [ ] Performance meets expectations
- [ ] Costs within budget
- [ ] Timeline met
- [ ] Stakeholders satisfied

---

## Post-Deployment (Ongoing)

### Weekly
- [ ] Review logs for errors
- [ ] Monitor costs
- [ ] Check backup completion
- [ ] Verify no security alerts

### Monthly
- [ ] Review performance metrics
- [ ] Analyze cost trends
- [ ] Update capacity planning
- [ ] Review and prioritize improvements
- [ ] Test disaster recovery

### Quarterly
- [ ] Major version updates (PostgreSQL, dependencies)
- [ ] Security audit
- [ ] Performance optimization review
- [ ] Architecture review and planning

### Annually
- [ ] Full disaster recovery test
- [ ] Security compliance review
- [ ] Cost optimization review
- [ ] Strategic planning for next year

---

**Deployment Status**: _______________
**Completed By**: _______________
**Date**: _______________
**Notes/Issues**: _______________

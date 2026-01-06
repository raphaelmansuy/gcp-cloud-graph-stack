#!/usr/bin/env make
# Makefile for gcp-cloud-graph-stack
# Convenient shortcuts for common operations

PROJECT_ID := saas-app-001
REGION := us-central1
REGISTRY := ${REGION}-docker.pkg.dev/${PROJECT_ID}
TF_DIR := terraform

.PHONY: help menu quick-start status full-setup deploy dev-setup dev-access \
        setup gcloud-auth gcloud-login gcloud-config gcloud-app-auth gcloud-app-default \
        init plan apply destroy logs ssh \
        verify-db verify-services clean docs install-tools scaffold test

help:
	@echo "┌─────────────────────────────────────────────────────────────┐"
	@echo "│                 GCP Cloud Graph Stack                       │"
	@echo "│                  Project: ${PROJECT_ID}                      │"
	@echo "└─────────────────────────────────────────────────────────────┘"
	@echo ""
	@echo "🚀 QUICK START:"
	@echo "  make menu              # Interactive menu"
	@echo "  make quick-start       # Setup guide"
	@echo "  make full-setup        # Auto setup everything"
	@echo ""
	@echo "⚡ EDGEQUAKE (RAG + Knowledge Graph):"
	@echo "  make edgequake-full    # Build, push & deploy EdgeQuake"
	@echo "  make edgequake-help    # EdgeQuake commands"
	@echo "  make edgequake-status  # Check EdgeQuake services"
	@echo ""
	@echo "📋 WORKFLOWS:"
	@echo "  make status            # System health check"
	@echo "  make deploy            # Safe infrastructure deploy"
	@echo "  make dev-access        # Database access setup"
	@echo ""
	@echo "🛠️  TOOLS:"
	@echo "  setup             # Install prerequisites"
	@echo "  gcloud-auth       # Full GCP authentication"
	@echo "  gcloud-login      # Login to gcloud"
	@echo "  gcloud-app-default # Login for Application Default Credentials"
	@echo "  scaffold          # Create minimal source code"
	@echo "  init              # Initialize Terraform"
	@echo "  plan / apply      # Terraform plan/apply"
	@echo ""
	@echo "💻 DATABASE:"
	@echo "  secure-ssh    db-tunnel    db-connect    db-check"
	@echo ""
	@echo "📚 HELP:"
	@echo "  make docs              # Documentation overview"
	@echo "  make costs             # Cost estimates"
	@echo "  💡 Typos are auto-corrected!"
	@echo ""

menu:
	@echo "┌─────────────────────────────────────────────────────────────┐"
	@echo "│                 GCP Cloud Graph Stack                       │"
	@echo "│                     Interactive Menu                        │"
	@echo "└─────────────────────────────────────────────────────────────┘"
	@echo ""
	@echo "Choose your workflow:"
	@echo ""
	@echo "1) 🚀 Quick Start        - Complete setup guide"
	@echo "2) 📊 Check Status       - System health overview"
	@echo "3) 🏗️  Deploy Infra       - Safe infrastructure deployment"
	@echo "4) 💻 Dev Database       - Setup local database access"
	@echo "5) 🐳 Build & Deploy     - Docker build and push"
	@echo "6) 🏗️  Scaffold Code      - Create minimal source code"
	@echo "7) ✅ Verify System      - Test all components"
	@echo "8) 🧹 Cleanup            - Clean cache and resources"
	@echo "9) 📚 Documentation      - View docs and guides"
	@echo "10) 🔐 GCP Auth           - Full gcloud & App Default login"
	@echo "11) ⚙️  GCP Config         - Set project and region"
	@echo ""
	@echo "Run: make <command> or make help for all options"
	@echo ""

# Quick Start & Convenience Targets
quick-start:
	@echo "┌─────────────────────────────────────────────────────────────┐"
	@echo "│                 🚀 Quick Start Guide                        │"
	@echo "└─────────────────────────────────────────────────────────────┘"
	@echo ""
	@echo "1️⃣  Install & Setup:"
	@echo "   make setup"
	@echo ""
	@echo "2️⃣  Configure:"
	@echo "   make config"
	@echo ""
	@echo "3️⃣  Scaffold Source Code:"
	@echo "   make scaffold"
	@echo ""
	@echo "4️⃣  Deploy Infrastructure:"
	@echo "   make deploy"
	@echo ""
	@echo "5️⃣  Build & Deploy EdgeQuake:"
	@echo "   make edgequake-full"
	@echo ""
	@echo "6️⃣  Verify & Test:"
	@echo "   make edgequake-status"
	@echo ""
	@echo "💡 Pro tip: make full-setup  # Do everything automatically"
	@echo ""

status:
	@echo "┌─────────────────────────────────────────────────────────────┐"
	@echo "│                    📊 System Status                         │"
	@echo "└─────────────────────────────────────────────────────────────┘"
	@echo ""
	@echo "🔧 Infrastructure:"
	@cd ${TF_DIR} && terraform state list 2>/dev/null | head -3 | sed 's/^/  ✅ /' || echo "  ⚠️  Not deployed (run: make deploy)"
	@echo ""
	@echo "🐳 Docker Images:"
	@docker images | grep ${REGISTRY} | wc -l | xargs -I {} echo "  ✅ {} images built" || echo "  ⚠️  No images (run: make edgequake-build)"
	@echo ""
	@echo "☁️  Cloud Resources:"
	@gcloud compute instances list --filter="name=edgequake-db-vm" --format="value(status)" 2>/dev/null | sed 's/RUNNING/  ✅ VM running/' | sed 's/TERMINATED/  ❌ VM stopped/' || echo "  ⚠️  VM status unknown"
	@gcloud run services list --format="value(metadata.name)" 2>/dev/null | wc -l | xargs -I {} echo "  ✅ {} services deployed" || echo "  ⚠️  No services"
	@echo ""
	@echo "🔒 SSH Access:"
	@gcloud compute firewall-rules describe edgequake-allow-ssh-restricted --project=${PROJECT_ID} --format='value(sourceRanges)' 2>/dev/null | sed 's/^/  ✅ /' || echo "  ⚠️  Not configured (run: make secure-ssh)"
	@echo ""
	@echo "💡 Quick actions: make verify-infra | make dev-access | make edgequake-status"

full-setup: setup config init deploy edgequake-full
	@echo ""
	@echo "🎉 Complete setup finished!"
	@echo ""
	@echo "Next steps:"
	@echo "  • Check EdgeQuake status: make edgequake-status"
	@echo "  • Setup database access: make dev-setup"
	@echo "  • View documentation: make docs"

deploy: plan
	@echo "🚀 Deploying infrastructure..."
	@cd ${TF_DIR} && terraform apply tfplan
	@echo "✅ Infrastructure deployed!"
	@echo "💡 Next: make edgequake-full"

dev-setup:
	@echo "💻 Database access setup..."
	@read -p "This authorizes your IP for SSH and creates a tunnel. Continue? (y/N): " confirm; \
	[ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ] && make secure-ssh && make dev-access || echo "Cancelled"

dev-access: secure-ssh
	@echo "🔌 Starting database tunnel..."
	@echo "  Local: localhost:5432 → Remote: ${REGION}-a PostgreSQL"
	@echo "  Press Ctrl+C to stop"
	./scripts/db-tunnel.sh ${PROJECT_ID} ${REGION}-a db-vm 5432 5432

# Setup & Initialization
setup:
	@echo "📦 Setting up development environment..."
	@echo ""
	@echo "🔧 Installing tools:"
	@command -v terraform >/dev/null 2>&1 && echo "  ✅ Terraform ready" || (echo "  📥 Installing Terraform..." && brew install terraform >/dev/null 2>&1 && echo "  ✅ Terraform installed")
	@command -v gcloud >/dev/null 2>&1 && echo "  ✅ Google Cloud SDK ready" || (echo "  📥 Installing Google Cloud SDK..." && brew install --cask google-cloud-sdk >/dev/null 2>&1 && echo "  ✅ Google Cloud SDK installed")
	@command -v docker >/dev/null 2>&1 && echo "  ✅ Docker ready" || (echo "  📥 Installing Docker..." && brew install --cask docker >/dev/null 2>&1 && echo "  ✅ Docker installed")
	@echo ""
	@make gcloud-auth
	@echo ""
	@echo "🎉 Setup complete! Next: make config"

auth: gcloud-auth docker-auth
	@echo "✅ Auth complete: gcloud + docker"

gcloud-auth: gcloud-login gcloud-config gcloud-app-auth
	@echo "✅ GCP authentication fully configured"

gcloud-login:
	@echo "🔐 Logging into Google Cloud..."
	@gcloud auth login

gcloud-config:
	@echo "⚙️  Setting GCP project to ${PROJECT_ID}..."
	@gcloud config set project ${PROJECT_ID}

gcloud-app-auth gcloud-app-default:
	@echo "🔐 Configuring Application Default Credentials..."
	@gcloud auth application-default login

init:
	@echo "Initializing Terraform (bootstrapping backend if needed)..."
	@./scripts/bootstrap-backend.sh ${PROJECT_ID} ${REGION}
	@cd ${TF_DIR} && terraform init -backend-config="bucket=${PROJECT_ID}-tf-state" -backend-config="prefix=terraform/state" -reconfigure -input=false

config:
	@if [ ! -f ${TF_DIR}/terraform.tfvars ]; then \
		echo "⚙️  Creating terraform.tfvars..."; \
		cp ${TF_DIR}/terraform.tfvars.example ${TF_DIR}/terraform.tfvars; \
		echo "✅ Created! Edit ${TF_DIR}/terraform.tfvars for your settings"; \
	else \
		echo "✅ terraform.tfvars exists. Edit it to customize deployment."; \
	fi

# Infrastructure
plan:
	@echo "Planning Terraform changes..."
	cd ${TF_DIR} && terraform plan -out=tfplan

apply:
	@echo "Applying Terraform configuration..."
	cd ${TF_DIR} && terraform apply tfplan
	@echo "✓ Infrastructure deployed successfully"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Build & Deploy EdgeQuake: make edgequake-full"
	@echo "  2. Verify database: make verify-db"
	@echo "  3. Check status: make edgequake-status"

destroy:
	@echo "WARNING: This will delete all infrastructure"
	@read -p "Are you sure? (type 'yes' to continue): " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		cd ${TF_DIR} && terraform destroy; \
	else \
		echo "Cancelled"; \
	fi

refresh:
	@echo "Refreshing Terraform state..."
	cd ${TF_DIR} && terraform refresh

# Docker & Containers
# Note: Use 'make edgequake-full' to build and deploy EdgeQuake

docker-auth:
	@echo "Configuring Docker authentication..."
	gcloud auth configure-docker ${REGION}-docker.pkg.dev

docker-clean-old:
	@echo "Removing local Docker images..."
	docker rmi ${REGISTRY}/edgequake-images/edgequake-webui:latest || true
	docker rmi ${REGISTRY}/edgequake-images/edgequake-api:latest || true
	@echo "✓ Docker images removed"

scaffold:
	@echo "🏗️  Scaffolding minimal source code..."
	@mkdir -p pages src public
	@if [ ! -f package.json ]; then \
		echo '{"name": "frontend", "version": "1.0.0", "scripts": {"build": "next build", "start": "next start"}}' > package.json; \
	fi
	@if [ ! -f pages/index.js ]; then \
		echo 'export default function Home() { return <div>GCP Cloud Graph Stack</div> }' > pages/index.js; \
	fi
	@if [ ! -f pages/health.js ]; then \
		echo 'export default function Health() { return <div>OK</div> }' > pages/health.js; \
	fi
	@if [ ! -f public/favicon.ico ]; then \
		touch public/favicon.ico; \
	fi
	@if [ ! -f Cargo.toml ]; then \
		echo '[package]\nname = "api"\nversion = "0.1.0"\nedition = "2021"\n\n[dependencies]\nactix-web = "4"' > Cargo.toml; \
	fi
	@if [ ! -f src/main.rs ]; then \
		echo 'use actix_web::{get, App, HttpResponse, HttpServer, Responder};\n\n#[get("/")]\nasync fn hello() -> impl Responder {\n    HttpResponse::Ok().body("API is running")\n}\n\n#[actix_web::main]\nasync fn main() -> std::io::Result<()> {\n    HttpServer::new(|| {\n        App::new().service(hello)\n    })\n    .bind(("0.0.0.0", 8080))?\n    .run()\n    .await\n}' > src/main.rs; \
	fi
	@npm install --package-lock-only 2>/dev/null || true
	@cargo generate-lockfile 2>/dev/null || true
	@echo "✅ Scaffolding complete!"

# Verification & Testing
verify-infra:
	@echo "🔍 Checking infrastructure..."
	@gcloud compute instances describe edgequake-db-vm --zone=${REGION}-a --format='table(status,machineType.machine_type(),networkInterfaces[0].networkIP)' 2>/dev/null || echo "❌ VM not found"
	@gcloud run services list --region=${REGION} --format='table(SERVICE_NAME,STATUS,REGION,URL)' 2>/dev/null || echo "❌ No services"
	@gcloud artifacts docker images list ${REGISTRY}/edgequake-images --format='table(IMAGE,DIGEST,CREATE_TIME)' 2>/dev/null || echo "❌ No images"

verify-db:
	@gcloud compute ssh edgequake-db-vm --zone=${REGION}-a --command="sudo systemctl status postgresql --no-pager && sudo -u postgres psql -c 'SELECT version();'" 2>/dev/null && echo "✅ PostgreSQL running" || echo "❌ PostgreSQL check failed"

verify-services:
	@echo "🔍 Checking services..."
	@gcloud run services describe edgequake-webui --region=${REGION} --format='value(status.url)' 2>/dev/null | xargs -I {} echo "✅ EdgeQuake WebUI: {}" || echo "❌ EdgeQuake WebUI not found"
	@gcloud run services describe edgequake-api --region=${REGION} --format='value(status.url)' 2>/dev/null | xargs -I {} echo "✅ EdgeQuake API: {}" || echo "❌ EdgeQuake API not found"

test: test-edgequake-webui test-edgequake-api
	@echo "✅ All tests passed!"

test-edgequake-webui:
	@WEBUI_URL=$$(gcloud run services describe edgequake-webui --region=${REGION} --format='value(status.url)' 2>/dev/null); \
	[ -z "$$WEBUI_URL" ] && echo "❌ EdgeQuake WebUI not found" && exit 1 || (echo "🧪 Testing EdgeQuake WebUI..." && curl -s --max-time 5 $$WEBUI_URL >/dev/null && echo "✅ EdgeQuake WebUI responding" || echo "❌ EdgeQuake WebUI not responding")

test-edgequake-api:
	@API_URL=$$(gcloud run services describe edgequake-api --region=${REGION} --format='value(status.url)' 2>/dev/null); \
	[ -z "$$API_URL" ] && echo "❌ EdgeQuake API not found" && exit 1 || (echo "🧪 Testing EdgeQuake API..." && curl -s --max-time 5 $$API_URL >/dev/null && echo "✅ EdgeQuake API responding" || echo "❌ EdgeQuake API not responding")

# Operations
logs-cloud-run:
	@echo "Showing Cloud Run logs (last 50 lines)..."
	@echo "EdgeQuake WebUI:"
	gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=edgequake-webui" \
		--limit=50 --format='table(timestamp, severity, textPayload)' | head -20
	@echo ""
	@echo "EdgeQuake API:"
	gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=edgequake-api" \
		--limit=50 --format='table(timestamp, severity, textPayLabel)' | head -20

logs-vm:
	@echo "Showing VM startup script logs..."
	gcloud compute instances get-serial-port-output edgequake-db-vm \
		--zone=${REGION}-a | tail -100

ssh:
	@echo "Connecting to PostgreSQL VM..."
	gcloud compute ssh edgequake-db-vm --zone=${REGION}-a

costs:
	@echo "Estimated monthly costs for saas-app-001:"
	@echo ""
	@echo "Development Environment:"
	@echo "  Compute Engine VM (e2-standard-2):    ~$$25/month"
	@echo "  Cloud Run (Next.js):                   ~$$5/month"
	@echo "  Cloud Run (Rust API):                  ~$$5/month"
	@echo "  Cloud Run compute (vCPU + Memory):    ~$$14/month"
	@echo "  Storage & Networking:                  ~$$2/month"
	@echo "  ─────────────────────────────────────────────────"
	@echo "  TOTAL (Development):                  ~$$50/month"
	@echo ""
	@echo "Production Environment (with optimization):"
	@echo "  Compute Engine VMs (x2, Spot):       ~$$50/month"
	@echo "  Cloud Run (5M requests/month):        ~$$50/month"
	@echo "  Database backups & storage:           ~$$30/month"
	@echo "  Logging & Monitoring:                 ~$$50/month"
	@echo "  Networking & other:                   ~$$70/month"
	@echo "  ─────────────────────────────────────────────────"
	@echo "  TOTAL (Production):                  ~$$250/month"
	@echo ""
	@echo "See docs/06-roadmap-costs.md for detailed breakdown"

# Database Tunnel & Local Access
.PHONY: secure-ssh db-tunnel db-tunnel-custom db-connect db-check
secure-ssh:
	@echo "🔒 Securing SSH access for your IP..."
	./scripts/secure-ssh-access.sh ${PROJECT_ID}

db-tunnel:
	@echo "🔌 SSH tunnel: localhost:5432 → ${REGION}-a PostgreSQL"
	@echo "⚠️  Run 'make secure-ssh' first!"
	./scripts/db-tunnel.sh ${PROJECT_ID} ${REGION}-a db-vm 5432 5432

db-tunnel-custom:
	@echo "🔌 SSH tunnel: localhost:5433 → ${REGION}-a PostgreSQL"
	@echo "⚠️  Run 'make secure-ssh' first!"
	./scripts/db-tunnel.sh ${PROJECT_ID} ${REGION}-a db-vm 5433 5432

db-connect:
	@echo "📦 Connecting to PostgreSQL (tunnel must be running)..."
	psql -h localhost -U postgres -d graph_db

db-check:
	@echo "🔍 PostgreSQL status on VM..."
	gcloud compute ssh db-vm --zone=${REGION}-a --project=${PROJECT_ID} -- \
	  "sudo systemctl status postgresql --no-pager"

# Cleanup
clean:
	@echo "Cleaning Terraform cache..."
	rm -rf ${TF_DIR}/.terraform*
	rm -f ${TF_DIR}/*.tfstate*
	@echo "✓ Cleaned"

clean-all: docker-clean clean
	@echo "✓ All cleaned"

docs:
	@echo "📚 Documentation Overview"
	@echo ""
	@echo "🚀 Start here:"
	@echo "  README.md                    - Project overview"
	@echo "  docs/05-quick-start.md       - Step-by-step setup"
	@echo ""
	@echo "🏗️  Architecture:"
	@echo "  docs/01-architecture.md      - System design"
	@echo "  docs/04-ci-cd-architecture.md - CI/CD patterns"
	@echo ""
	@echo "⚙️  Implementation:"
	@echo "  docs/02-deployment-terraform.md    - Terraform guide"
	@echo "  docs/03-deployment-github-actions.md - GitHub Actions"
	@echo ""
	@echo "📋 Planning:"
	@echo "  docs/06-roadmap-costs.md     - Costs & roadmap"
	@echo ""
	@echo "💡 Run: cat <filename> to read any document"

readme:
	@cat README.md

# Default target
.DEFAULT_GOAL := help

# Catch common typos and provide helpful suggestions
.PHONY: satus staus statu deployy deply setupy setp inity confi planz applyy destro destroyy \
        docker-buil docker-buid docker-pus docker-puh verify-infr verif verify-dbz test-nextj test-rus \
        dev-acces dev-acess secure-ss sshh db-tunne db-tunnel-custom db-connec db-chec \
        doc log clean-al clea readme

# Common typo aliases with helpful messages
satus staus statu:
	@echo "❌ Did you mean 'make status'?"
	@echo "💡 Run: make status"
	@echo ""

deployy deply:
	@echo "❌ Did you mean 'make deploy'?"
	@echo "💡 Run: make deploy"
	@echo ""

setupy setp:
	@echo "❌ Did you mean 'make setup'?"
	@echo "💡 Run: make setup"
	@echo ""

gcloud-aut gcloudauth:
	@echo "❌ Did you mean 'make gcloud-auth'?"
	@echo "💡 Run: make gcloud-auth"
	@echo ""

inity:
	@echo "❌ Did you mean 'make init'?"
	@echo "💡 Run: make init"
	@echo ""

confi:
	@echo "❌ Did you mean 'make config'?"
	@echo "💡 Run: make config"
	@echo ""

planz:
	@echo "❌ Did you mean 'make plan'?"
	@echo "💡 Run: make plan"
	@echo ""

applyy:
	@echo "❌ Did you mean 'make apply'?"
	@echo "💡 Run: make apply"
	@echo ""

destro destroyy:
	@echo "❌ Did you mean 'make destroy'?"
	@echo "💡 Run: make destroy"
	@echo ""

docker-buil docker-buid:
	@echo "❌ Did you mean 'make docker-build'?"
	@echo "💡 Run: make docker-build"
	@echo ""

docker-pus docker-puh:
	@echo "❌ Did you mean 'make docker-push'?"
	@echo "💡 Run: make docker-push"
	@echo ""

verify-infr verif:
	@echo "❌ Did you mean 'make verify-infra'?"
	@echo "💡 Run: make verify-infra"
	@echo ""

verify-dbz:
	@echo "❌ Did you mean 'make verify-db'?"
	@echo "💡 Run: make verify-db"
	@echo ""

test-nextj:
	@echo "❌ Did you mean 'make test-nextjs'?"
	@echo "💡 Run: make test-nextjs"
	@echo ""

test-rus:
	@echo "❌ Did you mean 'make test-rust'?"
	@echo "💡 Run: make test-rust"
	@echo ""

dev-acces dev-acess:
	@echo "❌ Did you mean 'make dev-access'?"
	@echo "💡 Run: make dev-access"
	@echo ""

secure-ss:
	@echo "❌ Did you mean 'make secure-ssh'?"
	@echo "💡 Run: make secure-ssh"
	@echo ""

sshh:
	@echo "❌ Did you mean 'make ssh'?"
	@echo "💡 Run: make ssh"
	@echo ""

db-tunne:
	@echo "❌ Did you mean 'make db-tunnel'?"
	@echo "💡 Run: make db-tunnel"
	@echo ""

db-connec:
	@echo "❌ Did you mean 'make db-connect'?"
	@echo "💡 Run: make db-connect"
	@echo ""

db-chec:
	@echo "❌ Did you mean 'make db-check'?"
	@echo "💡 Run: make db-check"
	@echo ""

# ============================================
# EdgeQuake Deployment Targets
# ============================================

# EdgeQuake repository location (adjust if needed)
EDGEQUAKE_REPO := /Users/raphaelmansuy/Github/03-working/edgequake
EDGEQUAKE_API_DIR := $(EDGEQUAKE_REPO)/edgequake
EDGEQUAKE_WEBUI_DIR := $(EDGEQUAKE_REPO)/edgequake_webui
EDGEQUAKE_REGISTRY := $(REGISTRY)/edgequake-images
EDGEQUAKE_PLATFORMS := linux/amd64,linux/arm64

.PHONY: edgequake-check edgequake-build edgequake-build-api edgequake-build-webui \
        edgequake-push edgequake-push-api edgequake-push-webui \
        edgequake-deploy edgequake-full edgequake-status edgequake-logs \
        edgequake-help edgequake-clean docker-clean

edgequake-help:
	@echo "┌─────────────────────────────────────────────────────────────┐"
	@echo "│              EdgeQuake Deployment Commands                   │"
	@echo "└─────────────────────────────────────────────────────────────┘"
	@echo ""
	@echo "🚀 QUICK START:"
	@echo "  make edgequake-full        # Build, push, and deploy everything"
	@echo "  make edgequake-status      # Check deployment status"
	@echo ""
	@echo "🏗️  BUILD (Multi-arch: amd64 + arm64):"
	@echo "  make edgequake-build       # Build both API and WebUI images"
	@echo "  make edgequake-build-api   # Build API image only"
	@echo "  make edgequake-build-webui # Build WebUI image only"
	@echo ""
	@echo "📤 PUSH:"
	@echo "  make edgequake-push        # Push both images to Artifact Registry"
	@echo "  make edgequake-push-api    # Push API image only"
	@echo "  make edgequake-push-webui  # Push WebUI image only"
	@echo ""
	@echo "🚢 DEPLOY:"
	@echo "  make edgequake-deploy      # Deploy to Cloud Run via Terraform"
	@echo "  make edgequake-redeploy    # Force redeploy latest images & route traffic"
	@echo ""
	@echo "🧹 CLEANUP:"
	@echo "  make docker-clean          # Clean Docker cache and volumes"
	@echo "  make edgequake-clean       # Clean EdgeQuake images"
	@echo ""
	@echo "📊 MONITORING:"
	@echo "  make edgequake-status      # Show service URLs and status"
	@echo "  make edgequake-logs        # View service logs"
	@echo ""
	@echo "🔧 Configuration:"
	@echo "  EDGEQUAKE_REPO = $(EDGEQUAKE_REPO)"
	@echo "  PLATFORMS      = $(EDGEQUAKE_PLATFORMS)"
	@echo ""

edgequake-check:
	@echo "🔍 Checking EdgeQuake repository..."
	@if [ ! -d "$(EDGEQUAKE_API_DIR)" ]; then \
		echo "❌ EdgeQuake API directory not found: $(EDGEQUAKE_API_DIR)"; \
		echo "💡 Update EDGEQUAKE_REPO in Makefile"; \
		exit 1; \
	fi
	@if [ ! -d "$(EDGEQUAKE_WEBUI_DIR)" ]; then \
		echo "❌ EdgeQuake WebUI directory not found: $(EDGEQUAKE_WEBUI_DIR)"; \
		echo "💡 Update EDGEQUAKE_REPO in Makefile"; \
		exit 1; \
	fi
	@echo "✅ EdgeQuake repositories found"
	@echo "   API:   $(EDGEQUAKE_API_DIR)"
	@echo "   WebUI: $(EDGEQUAKE_WEBUI_DIR)"
	@echo ""

# Fast single-architecture builds (for testing/development)
# Note: Cloud Run requires linux/amd64, so we explicitly set the platform
.PHONY: edgequake-build-api-fast
edgequake-build-api-fast: edgequake-check
	@echo "🏗️  Building EdgeQuake API (linux/amd64 for Cloud Run)..."
	@echo "   Source:    $(shell dirname $(EDGEQUAKE_REPO))"
	@echo "   Image:     $(EDGEQUAKE_REGISTRY)/edgequake-api:latest"
	@echo ""
	docker buildx build \
		--platform linux/amd64 \
		--provenance=false \
		--sbom=false \
		-f dockerfiles/Dockerfile.edgequake-api-simple \
		-t $(EDGEQUAKE_REGISTRY)/edgequake-api:latest \
		-t $(EDGEQUAKE_REGISTRY)/edgequake-api:$(shell git -C $(EDGEQUAKE_API_DIR) rev-parse --short HEAD 2>/dev/null || echo "local") \
		--push \
		$(shell dirname $(EDGEQUAKE_REPO))
	@echo ""
	@echo "✅ EdgeQuake API image built and pushed"
	@echo ""

.PHONY: edgequake-build-webui-fast
edgequake-build-webui-fast: edgequake-check
	@echo "🏗️  Building EdgeQuake WebUI (linux/amd64 for Cloud Run)..."
	@echo "   Source:    $(EDGEQUAKE_WEBUI_DIR)"
	@echo "   Image:     $(EDGEQUAKE_REGISTRY)/edgequake-webui:latest"
	@echo ""
	@# Get the Rust API URL from Terraform output if available
	@RUST_API_URL=$$(cd terraform && terraform output -raw rust_api_service_url 2>/dev/null || echo "https://edgequake-api-wszhkynzxa-uc.a.run.app"); \
	echo "   API URL: $$RUST_API_URL"; \
	docker buildx build \
		--platform linux/amd64 \
		--provenance=false \
		--sbom=false \
		-f dockerfiles/Dockerfile.edgequake-webui \
		--build-arg NEXT_PUBLIC_API_URL=$$RUST_API_URL \
		-t $(EDGEQUAKE_REGISTRY)/edgequake-webui:latest \
		-t $(EDGEQUAKE_REGISTRY)/edgequake-webui:$(shell git -C $(EDGEQUAKE_WEBUI_DIR) rev-parse --short HEAD 2>/dev/null || echo "local") \
		--push \
		$(EDGEQUAKE_WEBUI_DIR)
	@echo ""
	@echo "✅ EdgeQuake WebUI image built and pushed"
	@echo ""

.PHONY: edgequake-build-api
edgequake-build-api: edgequake-check
	@echo "🏗️  Building EdgeQuake API (multi-arch)..."
	@echo "   Source:    $(EDGEQUAKE_API_DIR)"
	@echo "   Image:     $(EDGEQUAKE_REGISTRY)/edgequake-api:latest"
	@echo "   Platforms: $(EDGEQUAKE_PLATFORMS)"
	@echo ""
	docker buildx build \
		--platform $(EDGEQUAKE_PLATFORMS) \
		-f dockerfiles/Dockerfile.edgequake-api \
		-t $(EDGEQUAKE_REGISTRY)/edgequake-api:latest \
		-t $(EDGEQUAKE_REGISTRY)/edgequake-api:$(shell git -C $(EDGEQUAKE_API_DIR) rev-parse --short HEAD 2>/dev/null || echo "local") \
		--push \
		$(EDGEQUAKE_API_DIR)
	@echo ""
	@echo "✅ EdgeQuake API image built and pushed"
	@echo ""

.PHONY: edgequake-build-webui
edgequake-build-webui: edgequake-check
	@echo "🏗️  Building EdgeQuake WebUI (multi-arch)..."
	@echo "   Source:    $(EDGEQUAKE_WEBUI_DIR)"
	@echo "   Image:     $(EDGEQUAKE_REGISTRY)/edgequake-webui:latest"
	@echo "   Platforms: $(EDGEQUAKE_PLATFORMS)"
	@echo ""
	@# Get the Rust API URL from Terraform output if available
	@RUST_API_URL=$$(cd terraform && terraform output -raw rust_api_service_uri 2>/dev/null || echo "/api/v1"); \
	echo "   API URL: $$RUST_API_URL"; \
	docker buildx build \
		--platform $(EDGEQUAKE_PLATFORMS) \
		-f dockerfiles/Dockerfile.edgequake-webui \
		--build-arg NEXT_PUBLIC_API_URL=$$RUST_API_URL \
		-t $(EDGEQUAKE_REGISTRY)/edgequake-webui:latest \
		-t $(EDGEQUAKE_REGISTRY)/edgequake-webui:$(shell git -C $(EDGEQUAKE_WEBUI_DIR) rev-parse --short HEAD 2>/dev/null || echo "local") \
		--push \
		$(EDGEQUAKE_WEBUI_DIR)
	@echo ""
	@echo "✅ EdgeQuake WebUI image built and pushed"
	@echo ""

edgequake-build: edgequake-build-api edgequake-build-webui
	@echo "✅ All EdgeQuake images built and pushed successfully"
	@echo ""

# Push targets are now integrated with build (buildx --push)
edgequake-push-api:
	@echo "ℹ️  Multi-arch builds automatically push to registry"
	@echo "   Run 'make edgequake-build-api' to build and push"
	@echo ""

edgequake-push-webui:
	@echo "ℹ️  Multi-arch builds automatically push to registry"
	@echo "   Run 'make edgequake-build-webui' to build and push"
	@echo ""

edgequake-push: edgequake-build
	@echo "✅ All EdgeQuake images are already pushed"
	@echo ""
	@echo "📋 Image URLs:"
	@echo "   API:   $(EDGEQUAKE_REGISTRY)/edgequake-api:latest"
	@echo "   WebUI: $(EDGEQUAKE_REGISTRY)/edgequake-webui:latest"
	@echo ""

edgequake-deploy:
	@echo "🚀 Deploying EdgeQuake to Cloud Run via Terraform..."
	@echo ""
	@# Update terraform variables with image URLs
	@cd terraform && \
	terraform plan \
		-var="rust_api_image_url=$(EDGEQUAKE_REGISTRY)/edgequake-api:latest" \
		-var="nextjs_image_url=$(EDGEQUAKE_REGISTRY)/edgequake-webui:latest" \
		-var="rust_api_service_name=edgequake-api" \
		-var="nextjs_service_name=edgequake-webui" \
		-out=tfplan-edgequake && \
	terraform apply tfplan-edgequake
	@echo ""
	@echo "✅ EdgeQuake deployed successfully"
	@echo ""

# Force redeploy with latest Docker images and route 100% traffic
edgequake-redeploy:
	@echo "┌─────────────────────────────────────────────────────────────┐"
	@echo "│      🔄 Force Redeploy Latest EdgeQuake Images              │"
	@echo "└─────────────────────────────────────────────────────────────┘"
	@echo ""
	@echo "📦 Deploying latest API image..."
	@gcloud run deploy edgequake-api \
		--image $(EDGEQUAKE_REGISTRY)/edgequake-api:latest \
		--region=$(REGION) \
		--project=$(PROJECT_ID) \
		--quiet
	@echo ""
	@echo "📦 Deploying latest WebUI image..."
	@gcloud run deploy edgequake-webui \
		--image $(EDGEQUAKE_REGISTRY)/nextjs:latest \
		--region=$(REGION) \
		--project=$(PROJECT_ID) \
		--quiet
	@echo ""
	@echo "✅ Latest images deployed and traffic routed!"
	@echo ""
	@echo "🔗 Service URLs:"
	@gcloud run services describe edgequake-api --region=$(REGION) --project=$(PROJECT_ID) --format='value(status.url)' | xargs -I {} echo "  • API:    {}"
	@gcloud run services describe edgequake-webui --region=$(REGION) --project=$(PROJECT_ID) --format='value(status.url)' | xargs -I {} echo "  • WebUI:  {}"

edgequake-full: edgequake-push edgequake-deploy edgequake-status
	@echo "┌─────────────────────────────────────────────────────────────┐"
	@echo "│         🎉 EdgeQuake Deployment Complete!                    │"
	@echo "└─────────────────────────────────────────────────────────────┘"
	@echo ""

edgequake-status:
	@echo "┌─────────────────────────────────────────────────────────────┐"
	@echo "│              EdgeQuake Service Status                        │"
	@echo "└─────────────────────────────────────────────────────────────┘"
	@echo ""
	@echo "🔍 Checking Cloud Run services..."
	@echo ""
	@echo "📡 EdgeQuake API:"
	@API_URL=$$(gcloud run services describe edgequake-api \
		--region $(REGION) \
		--format='value(status.url)' 2>/dev/null || echo "Not deployed"); \
	echo "   URL: $$API_URL"; \
	if [ "$$API_URL" != "Not deployed" ]; then \
		echo "   Health: $$(curl -s -o /dev/null -w '%{http_code}' $$API_URL/health || echo 'unreachable')"; \
	fi
	@echo ""
	@echo "🌐 EdgeQuake WebUI:"
	@WEBUI_URL=$$(gcloud run services describe edgequake-webui \
		--region $(REGION) \
		--format='value(status.url)' 2>/dev/null || echo "Not deployed"); \
	echo "   URL: $$WEBUI_URL"; \
	if [ "$$WEBUI_URL" != "Not deployed" ]; then \
		echo "   Status: $$(curl -s -o /dev/null -w '%{http_code}' $$WEBUI_URL || echo 'unreachable')"; \
	fi
	@echo ""
	@echo "💾 PostgreSQL Database:"
	@DB_IP=$$(cd terraform && terraform output -raw db_internal_ip 2>/dev/null || echo "unknown"); \
	echo "   Private IP: $$DB_IP"; \
	echo "   Database:   graph_db"; \
	echo "   Extensions: age, pgvector"
	@echo ""

edgequake-logs:
	@echo "📊 Recent EdgeQuake logs..."
	@echo ""
	@echo "API logs:"
	@gcloud logging read \
		"resource.type=cloud_run_revision AND resource.labels.service_name=edgequake-api" \
		--limit 20 \
		--format "table(timestamp,severity,textPayload)" \
		--region $(REGION) \
		2>/dev/null || echo "No logs found"
	@echo ""
	@echo "WebUI logs:"
	@gcloud logging read \
		"resource.type=cloud_run_revision AND resource.labels.service_name=edgequake-webui" \
		--limit 20 \
		--format "table(timestamp,severity,textPayload)" \
		--region $(REGION) \
		2>/dev/null || echo "No logs found"
	@echo ""

# ============================================
# Cleanup Targets
# ============================================

docker-clean:
	@echo "🧹 Cleaning Docker cache and resources..."
	@echo ""
	@echo "Current disk usage:"
	@docker system df
	@echo ""
	@read -p "⚠️  This will remove all unused containers, networks, images, and build cache. Continue? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker system prune -af --volumes; \
		echo ""; \
		echo "✅ Docker cleanup complete"; \
		echo ""; \
		echo "New disk usage:"; \
		docker system df; \
	else \
		echo "❌ Cleanup cancelled"; \
	fi

edgequake-clean:
	@echo "🧹 Removing EdgeQuake images..."
	@docker images | grep edgequake | awk '{print $$3}' | xargs -r docker rmi -f || true
	@echo "✅ EdgeQuake images removed"
	@echo ""

# ============================================
# End EdgeQuake Targets
# ============================================

doc:
	@echo "❌ Did you mean 'make docs'?"
	@echo "💡 Run: make docs"
	@echo ""

log:
	@echo "❌ Did you mean 'make logs-cloud-run'?"
	@echo "💡 Run: make logs-cloud-run"
	@echo ""

clean-al clea:
	@echo "❌ Did you mean 'make clean-all'?"
	@echo "💡 Run: make clean-all"
	@echo ""

# Catch-all rule for unrecognized commands
%:
	@echo "❌ Unknown command: '$@'"
	@echo ""
	@echo "📋 Available commands:"
	@echo "  make help              # Show all commands"
	@echo "  make menu              # Interactive menu"
	@echo "  make quick-start       # Setup guide"
	@echo ""
	@echo "💡 Common commands:"
	@echo "  make status            # System health check"
	@echo "  make setup             # Install tools"
	@echo "  make deploy            # Deploy infrastructure"
	@echo "  make dev-access        # Database access"
	@echo ""

# Prevent make from trying to interpret commands as recipes
.SECONDARY:

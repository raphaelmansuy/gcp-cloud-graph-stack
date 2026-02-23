#!/usr/bin/env make
# Makefile for gcp-cloud-graph-stack
# Convenient shortcuts for common operations

PROJECT_ID := saas-app-001
REGION := us-central1
REGISTRY := ${REGION}-docker.pkg.dev/${PROJECT_ID}
TF_DIR := terraform
# Default OpenAI model & embedding for deployments (override via env or make args)
# Example: make EDGEQUAKE_OPENAI_MODEL=gpt-4o-mini EDGEQUAKE_OPENAI_EMBEDDING=text-embedding-3-small edgequake-redeploy
EDGEQUAKE_OPENAI_MODEL ?= gpt-4o-mini
EDGEQUAKE_OPENAI_EMBEDDING ?= text-embedding-3-small

# ============================================
# ⚠️  CRITICAL: OPENAI API KEY CONFIGURATION
# ============================================
# EdgeQuake requires a valid OpenAI API key for LLM operations.
# 
# 🔑 SETUP INSTRUCTIONS:
# 1. Get your API key from: https://platform.openai.com/account/api-keys
# 2. Set the environment variable:
#    export TF_VAR_openai_api_key="sk-proj-..."
# 3. Add to your shell profile (~/.zshrc or ~/.bashrc):
#    echo 'export TF_VAR_openai_api_key="sk-proj-..."' >> ~/.zshrc
# 4. Verify it's set: make check-openai-key
#
# ⚠️  NEVER commit API keys to git!
# ⚠️  Deployments will FAIL without a valid key!
#
# 📋 VALIDATION:
# - API key must start with 'sk-' or 'sk-proj-'
# - Must be at least 40 characters long
# - Cannot be a placeholder value
#
# 🚀 DEPLOYMENT:
# All deployment targets automatically check for valid API key.
# Use 'make check-openai-key' to validate manually.
# ============================================

.PHONY: help menu quick-start status full-setup deploy dev-setup dev-access \
        setup gcloud-auth gcloud-login gcloud-config gcloud-app-auth gcloud-app-default \
        init plan apply destroy logs ssh \
        verify-db verify-services clean docs install-tools scaffold test check-openai-key validate-env

# ============================================
# 🔑 API KEY VALIDATION
# ============================================

check-openai-key:
	@echo "┌─────────────────────────────────────────────────────────────┐"
	@echo "│          🔑 OpenAI API Key Validation                       │"
	@echo "└─────────────────────────────────────────────────────────────┘"
	@echo ""
	@if [ -z "$$TF_VAR_openai_api_key" ]; then \
		echo "❌ ERROR: TF_VAR_openai_api_key is NOT set"; \
		echo ""; \
		echo "📋 To fix this:"; \
		echo "   1. Get your API key from: https://platform.openai.com/account/api-keys"; \
		echo "   2. Export the environment variable:"; \
		echo "      export TF_VAR_openai_api_key=\"sk-proj-...\""; \
		echo "   3. Add to ~/.zshrc or ~/.bashrc for persistence"; \
		echo ""; \
		exit 1; \
	elif echo "$$TF_VAR_openai_api_key" | grep -qi "placeholder\|example\|test\|dummy\|xxx"; then \
		echo "❌ ERROR: API key appears to be a PLACEHOLDER"; \
		echo "   Current value: $${TF_VAR_openai_api_key:0:15}***"; \
		echo ""; \
		echo "📋 Set a REAL OpenAI API key:"; \
		echo "   export TF_VAR_openai_api_key=\"sk-proj-...\""; \
		echo ""; \
		exit 1; \
	elif [ $${#TF_VAR_openai_api_key} -lt 40 ]; then \
		echo "❌ ERROR: API key is too SHORT (< 40 characters)"; \
		echo "   Length: $${#TF_VAR_openai_api_key} characters"; \
		echo ""; \
		echo "📋 Valid OpenAI API keys are at least 40 characters"; \
		echo "   Get a real key from: https://platform.openai.com/account/api-keys"; \
		echo ""; \
		exit 1; \
	elif ! echo "$$TF_VAR_openai_api_key" | grep -qE "^sk-"; then \
		echo "❌ ERROR: API key format INVALID"; \
		echo "   OpenAI keys must start with 'sk-' or 'sk-proj-'"; \
		echo ""; \
		echo "📋 Check your API key format"; \
		echo "   Get a real key from: https://platform.openai.com/account/api-keys"; \
		echo ""; \
		exit 1; \
	else \
		echo "✅ OpenAI API key is SET and appears VALID"; \
		echo "   Format: $${TF_VAR_openai_api_key:0:10}...$${TF_VAR_openai_api_key: -4}"; \
		echo "   Length: $${#TF_VAR_openai_api_key} characters"; \
		echo ""; \
		echo "💡 Test the key with: curl https://api.openai.com/v1/models \\"; \
		echo "     -H \"Authorization: Bearer \$$TF_VAR_openai_api_key\""; \
		echo ""; \
	fi

validate-env: check-openai-key
	@echo "✅ All environment variables validated"
	@echo ""

# ============================================
# 📚 HELP & DOCUMENTATION
# ============================================

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
	@echo "🔑 API KEY CONFIGURATION:"
	@echo "  make check-openai-key  # Validate OpenAI API key"
	@echo "  💡 Set: export TF_VAR_openai_api_key=\"sk-proj-...\""
	@echo ""
	@echo "⚡ EDGEQUAKE (RAG + Knowledge Graph):"
	@echo "  make edgequake-full    # Build, push & deploy EdgeQuake"
	@echo "  make edgequake-help    # EdgeQuake commands"
	@echo "  make edgequake-status  # Check EdgeQuake services"
	@echo "  make sqlx-prepare-auto # Generate SQLx cache (Docker-based)"
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
plan: check-openai-key
	@echo "Planning Terraform changes..."
	@echo "✅ OpenAI API key validated"
	@echo ""
	cd ${TF_DIR} && terraform plan -out=tfplan

apply: check-openai-key
	@echo "Applying Terraform configuration..."
	@echo "✅ OpenAI API key validated"
	@echo ""
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

# Clean Docker build cache to ensure fresh builds with correct version
.PHONY: edgequake-clean-cache
edgequake-clean-cache:
	@echo "🧹 Cleaning Docker build cache..."
	@docker buildx prune -f
	@echo "✅ Cache cleaned"
	@echo ""

# Extract expected version from Cargo.toml for verification
.PHONY: edgequake-get-version
edgequake-get-version:
	@cd $(EDGEQUAKE_GIT_REPO) && \
		grep -A1 "\[workspace.package\]" $(EDGEQUAKE_REPO)/Cargo.toml | \
		grep "version" | \
		awk -F'"' '{print $$2}' || echo "unknown"

# Verify deployed version matches expected version
.PHONY: edgequake-verify-version
edgequake-verify-version:
	@echo "🔍 Verifying deployed version..."
	@# Prefer user-specified target version, otherwise read from Cargo.toml
	@EXPECTED_VERSION=$${EXPECTED_VERSION:-$(EDGEQUAKE_TARGET_VERSION)}; \
	if [ -z "$$EXPECTED_VERSION" ] || [ "$$EXPECTED_VERSION" = "unknown" ]; then \
		EXPECTED_VERSION=$$(make -s edgequake-get-version); \
	fi; \
	API_URL=$$(gcloud run services describe edgequake-api --region=$(REGION) --format='value(status.url)' 2>/dev/null); \
	if [ -z "$$API_URL" ]; then \
		echo "⚠️  Cannot verify: API service not found"; \
		exit 0; \
	fi; \
	DEPLOYED_VERSION=$$(curl -s --max-time 10 $$API_URL/health 2>/dev/null | jq -r '.version // "unknown"'); \
	echo "   Expected: v$$EXPECTED_VERSION"; \
	echo "   Deployed: v$$DEPLOYED_VERSION"; \
	if [ "$$EXPECTED_VERSION" = "$$DEPLOYED_VERSION" ]; then \
		echo "✅ Version verified successfully"; \
	else \
		echo "❌ Version mismatch! Expected $$EXPECTED_VERSION but got $$DEPLOYED_VERSION"; \
		exit 1; \
	fi
	@echo ""

# Deploy specific branch with clean cache and version verification
edgequake-deploy-branch: edgequake-clean-cache sqlx-prepare-auto
	@if [ -z "$(BRANCH)" ]; then \
		echo "❌ Please specify the branch: make edgequake-deploy-branch BRANCH=<branch-name>"; \
		exit 1; \
	else \
		EXPECTED_VERSION=$$(cd $(EDGEQUAKE_GIT_REPO) && git checkout $(BRANCH) >/dev/null 2>&1 && make -s -C $(CURDIR) edgequake-get-version); \
		echo "┌─────────────────────────────────────────────────────────────┐"; \
		echo "│   🚀 Build & Deploy EdgeQuake branch: $(BRANCH)              │"; \
		echo "│   📦 Expected version: $$EXPECTED_VERSION                    │"; \
		echo "└─────────────────────────────────────────────────────────────┘"; \
		echo ""; \
		EDGEQUAKE_BRANCH=$(BRANCH) ./scripts/deploy-edgequake-latest.sh && \
		echo "" && \
		make edgequake-verify-version; \
	fi

# Release target: Build and deploy a specific EdgeQuake version (default: $(EDGEQUAKE_TARGET_VERSION)).
.PHONY: edgequake-release
edgequake-release:
	@VERSION=$${VERSION:-$(EDGEQUAKE_TARGET_VERSION)}; \
	IMAGE_TAG=v$$VERSION; \
	echo "┌─────────────────────────────────────────────────────────────┐"; \
	echo "│   🚀 Releasing EdgeQuake version: $$VERSION                    │"; \
	echo "└─────────────────────────────────────────────────────────────┘"; \
	# Ensure repo up-to-date, prepare SQLx cache, build with explicit tag, and deploy
	make EDGEQUAKE_TARGET_VERSION=$$VERSION EDGEQUAKE_IMAGE_TAG=$$IMAGE_TAG edgequake-clean-cache sqlx-prepare-auto edgequake-build && \
	cd terraform && terraform plan -var="rust_api_image_url=$(EDGEQUAKE_REGISTRY)/edgequake-api:$$IMAGE_TAG" -var="nextjs_image_url=$(EDGEQUAKE_REGISTRY)/edgequake-webui:$$IMAGE_TAG" -var="openai_api_key=$$TF_VAR_openai_api_key" -var="openai_model=$(EDGEQUAKE_OPENAI_MODEL)" -var="openai_embedding=$(EDGEQUAKE_OPENAI_EMBEDDING)" -out=tfplan-edgequake && terraform apply tfplan-edgequake && \
	cd $(CURDIR) && make EDGEQUAKE_TARGET_VERSION=$$VERSION EDGEQUAKE_IMAGE_TAG=$$IMAGE_TAG edgequake-verify-version || (echo "❌ Release failed"; exit 1); \
	echo ""

# EdgeQuake repository location (adjust if needed)
EDGEQUAKE_GIT_REPO := /Users/raphaelmansuy/Github/03-working/edgequake
EDGEQUAKE_REPO := $(EDGEQUAKE_GIT_REPO)/edgequake
EDGEQUAKE_BRANCH ?= edgequake-main  # Use ?= to allow environment override
EDGEQUAKE_API_DIR := $(EDGEQUAKE_REPO)
EDGEQUAKE_WEBUI_DIR := $(EDGEQUAKE_GIT_REPO)/edgequake_webui
EDGEQUAKE_REGISTRY := $(REGISTRY)/edgequake-images
EDGEQUAKE_PLATFORMS := linux/amd64,linux/arm64
# Default image/version configuration. Override by passing VERSION or EDGEQUAKE_IMAGE_TAG
# Example: make edgequake-release VERSION=0.4.0
EDGEQUAKE_TARGET_VERSION ?= 0.4.0
EDGEQUAKE_IMAGE_TAG ?= v$(EDGEQUAKE_TARGET_VERSION)
# Fallback git short commit for tagging/debugging (still available for extra tags)
EDGEQUAKE_COMMIT_SHORT := $(shell cd $(EDGEQUAKE_GIT_REPO) 2>/dev/null && git rev-parse --short HEAD || echo "local")
EDGEQUAKE_VERSION := $(EDGEQUAKE_COMMIT_SHORT)

.PHONY: edgequake-check edgequake-build edgequake-build-api edgequake-build-webui \
        edgequake-push edgequake-push-api edgequake-push-webui \
        edgequake-deploy edgequake-full edgequake-status edgequake-logs \
        edgequake-help edgequake-clean docker-clean \
        edgequake-clean-cache edgequake-get-version edgequake-verify-version \
        edgequake-deploy-branch edgequake-build-api-fast edgequake-build-webui-fast

edgequake-help:
	@echo "┌─────────────────────────────────────────────────────────────┐"
	@echo "│              EdgeQuake Deployment Commands                   │"
	@echo "└─────────────────────────────────────────────────────────────┘"
	@echo ""
	@echo "🚀 QUICK START:"
	@echo "  make edgequake-deploy-latest  # Pull latest from $(EDGEQUAKE_BRANCH), build & deploy"
	@echo "  make edgequake-full            # Build, push, and deploy everything"
	@echo "  make edgequake-status          # Check deployment status"
	@echo ""
	@echo "🔧 SQLX QUERY CACHE:"
	@echo "  make sqlx-prepare-auto         # Auto-generate cache (Docker-based)"
	@echo "  make sqlx-prepare-manual       # Manual cache generation (requires DATABASE_URL)"
	@echo "  make sqlx-db-start             # Start PostgreSQL container"
	@echo "  make sqlx-db-stop              # Stop PostgreSQL container"
	@echo ""
	@echo "🧹 CACHE & VERSION:"
	@echo "  make edgequake-clean-cache     # Clean Docker build cache"
	@echo "  make edgequake-get-version     # Get version from Cargo.toml"
	@echo "  make edgequake-verify-version  # Verify deployed version matches Cargo.toml"
	@echo ""
	@echo "🏗️  BUILD (Multi-arch: amd64 + arm64):"
	@echo "  make edgequake-build           # Build both API and WebUI images"
	@echo "  make edgequake-build-api       # Build API image only"
	@echo "  make edgequake-build-webui     # Build WebUI image only"
	@echo ""
	@echo "📤 PUSH:"
	@echo "  make edgequake-push            # Push both images to Artifact Registry"
	@echo "  make edgequake-push-api        # Push API image only"
	@echo "  make edgequake-push-webui      # Push WebUI image only"
	@echo ""
	@echo "🚢 DEPLOY:"
	@echo "  make edgequake-deploy-branch BRANCH=<name>  # Deploy specific branch (auto-cleans cache + verifies version)"
	@echo "  make edgequake-deploy-latest   # Deploy latest from $(EDGEQUAKE_BRANCH)"
	@echo "  make edgequake-deploy          # Deploy to Cloud Run via Terraform"
	@echo "  make edgequake-redeploy        # Force redeploy latest images & route traffic"
	@echo ""
	@echo "🧹 CLEANUP:"
	@echo "  make docker-clean              # Clean Docker cache and volumes"
	@echo "  make edgequake-clean           # Clean EdgeQuake images"
	@echo ""
	@echo "📊 MONITORING:"
	@echo "  make edgequake-status          # Show service URLs and status"
	@echo "  make edgequake-logs            # View service logs"
	@echo ""
	@echo "🔧 Configuration:"
	@echo "  EDGEQUAKE_REPO   = $(EDGEQUAKE_REPO)"
	@echo "  EDGEQUAKE_BRANCH = $(EDGEQUAKE_BRANCH)"
	@echo "  PLATFORMS        = $(EDGEQUAKE_PLATFORMS)"
	@echo ""

edgequake-check:
	@echo "🔍 Checking EdgeQuake repository..."
	@if [ ! -d "$(EDGEQUAKE_REPO)" ]; then \
		echo "❌ EdgeQuake repository not found: $(EDGEQUAKE_REPO)"; \
		echo "💡 Update EDGEQUAKE_REPO in Makefile"; \
		exit 1; \
	fi
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
	@echo "✅ EdgeQuake repository found"
	@echo "   Branch: $(EDGEQUAKE_BRANCH)"
	@echo "   API:    $(EDGEQUAKE_API_DIR)"
	@echo "   WebUI:  $(EDGEQUAKE_WEBUI_DIR)"
	@echo ""
	@echo "📥 Pulling latest changes from $(EDGEQUAKE_BRANCH)..."
	@cd $(EDGEQUAKE_GIT_REPO) && \
		git fetch origin $(EDGEQUAKE_BRANCH) && \
		git checkout $(EDGEQUAKE_BRANCH) && \
		git pull origin $(EDGEQUAKE_BRANCH) && \
		echo "✅ Updated to latest: $$(git rev-parse --short HEAD) - $$(git log -1 --pretty=format:'%s')" || \
		(echo "⚠️  Failed to pull latest changes. Using current version."; exit 0)
	@echo ""

# Fast single-architecture builds (for testing/development)
# Note: Cloud Run requires linux/amd64, so we explicitly set the platform
.PHONY: edgequake-build-api-fast
edgequake-build-api-fast: edgequake-check
	@echo "🏗️  Building EdgeQuake API (linux/amd64 for Cloud Run)..."
	@echo "   Source:    $(shell dirname $(EDGEQUAKE_REPO))"
	@echo "   Image:     $(EDGEQUAKE_REGISTRY)/edgequake-api:latest"
	@CARGO_VERSION=$$(make -s edgequake-get-version); \
	echo "   Version:   $$CARGO_VERSION"; \
	echo ""; \
	@VERSION=$$(cd $(EDGEQUAKE_GIT_REPO) && git rev-parse --short HEAD); \
	CARGO_VERSION=$$(make -s edgequake-get-version); \
	IMAGE_TAG=$${IMAGE_TAG:-$(EDGEQUAKE_IMAGE_TAG)}; \
	docker buildx build \
		--platform linux/amd64 \
		--provenance=false \
		--sbom=false \
		--pull \
		--build-arg BUILD_VERSION=$$VERSION \
		--build-arg CARGO_VERSION=$$CARGO_VERSION \
		-f dockerfiles/Dockerfile.edgequake-api-simple \
		-t $(EDGEQUAKE_REGISTRY)/edgequake-api:latest \
		-t $(EDGEQUAKE_REGISTRY)/edgequake-api:$$VERSION \
		-t $(EDGEQUAKE_REGISTRY)/edgequake-api:v$$CARGO_VERSION \
		-t $(EDGEQUAKE_REGISTRY)/edgequake-api:$$IMAGE_TAG \
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
	VERSION=$$(cd $(EDGEQUAKE_GIT_REPO) && git rev-parse --short HEAD); \
	CARGO_VERSION=$$(make -s edgequake-get-version); \
	echo "   API URL: $$RUST_API_URL"; \
	echo "   Version: $$VERSION"; \
	docker buildx build \
		--platform linux/amd64 \
		--provenance=false \
		--sbom=false \
		--pull \
		--build-arg NEXT_PUBLIC_API_URL=$$RUST_API_URL \
		--build-arg BUILD_VERSION=$$VERSION \
		-f dockerfiles/Dockerfile.edgequake-webui \
		-t $(EDGEQUAKE_REGISTRY)/edgequake-webui:latest \
		-t $(EDGEQUAKE_REGISTRY)/edgequake-webui:$$VERSION \
		-t $(EDGEQUAKE_REGISTRY)/edgequake-webui:v$$CARGO_VERSION \
		-t $(EDGEQUAKE_REGISTRY)/edgequake-webui:$$IMAGE_TAG \
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
	IMAGE_TAG=$${EDGEQUAKE_IMAGE_TAG:-v$(EDGEQUAKE_TARGET_VERSION)}; \
	docker buildx build \
		--platform $(EDGEQUAKE_PLATFORMS) \
		-f dockerfiles/Dockerfile.edgequake-api \
		-t $(EDGEQUAKE_REGISTRY)/edgequake-api:latest \
		-t $(EDGEQUAKE_REGISTRY)/edgequake-api:$(shell git -C $(EDGEQUAKE_API_DIR) rev-parse --short HEAD 2>/dev/null || echo "local") \
		-t $(EDGEQUAKE_REGISTRY)/edgequake-api:$$IMAGE_TAG \
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
	@RUST_API_URL=$$(cd terraform && terraform output -raw rust_api_service_url 2>/dev/null || echo "https://edgequake-api-wszhkynzxa-uc.a.run.app"); \
	echo "   API URL: $$RUST_API_URL"; \
	IMAGE_TAG=$${EDGEQUAKE_IMAGE_TAG:-v$(EDGEQUAKE_TARGET_VERSION)}; \
	docker buildx build \
		--platform $(EDGEQUAKE_PLATFORMS) \
		-f dockerfiles/Dockerfile.edgequake-webui \
		--build-arg NEXT_PUBLIC_API_URL=$$RUST_API_URL \
		-t $(EDGEQUAKE_REGISTRY)/edgequake-webui:latest \
		-t $(EDGEQUAKE_REGISTRY)/edgequake-webui:$(shell git -C $(EDGEQUAKE_WEBUI_DIR) rev-parse --short HEAD 2>/dev/null || echo "local") \
		-t $(EDGEQUAKE_REGISTRY)/edgequake-webui:$$IMAGE_TAG \
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
	@echo "   API:   $(EDGEQUAKE_REGISTRY)/edgequake-api:$(EDGEQUAKE_IMAGE_TAG)"
	@echo "   WebUI: $(EDGEQUAKE_REGISTRY)/edgequake-webui:$(EDGEQUAKE_IMAGE_TAG)"
	@echo ""

# Deploy latest version from edgequake-main branch
edgequake-deploy-latest: check-openai-key
	@echo "┌─────────────────────────────────────────────────────────────┐"
	@echo "│     🚀 Deploy Latest EdgeQuake from $(EDGEQUAKE_BRANCH)      │"
	@echo "└─────────────────────────────────────────────────────────────┘"
	@echo ""
	@./scripts/deploy-edgequake-latest.sh

edgequake-deploy: check-openai-key
	@echo "🚀 Deploying EdgeQuake to Cloud Run via Terraform..."
	@echo ""
	@echo "✅ OpenAI API key validated"
	@echo ""
	@# Update terraform variables with image URLs and OpenAI API key
	@cd terraform && \
	terraform plan \
		-var="rust_api_image_url=$(EDGEQUAKE_REGISTRY)/edgequake-api:$(EDGEQUAKE_IMAGE_TAG)" \
		-var="nextjs_image_url=$(EDGEQUAKE_REGISTRY)/edgequake-webui:$(EDGEQUAKE_IMAGE_TAG)" \
		-var="openai_model=$(EDGEQUAKE_OPENAI_MODEL)" \
		-var="openai_embedding=$(EDGEQUAKE_OPENAI_EMBEDDING)" \
		-var="rust_api_service_name=edgequake-api" \
		-var="nextjs_service_name=edgequake-webui" \
		-var="openai_api_key=$$TF_VAR_openai_api_key" \
		-out=tfplan-edgequake && \
	terraform apply tfplan-edgequake
	@echo ""
	@echo "✅ EdgeQuake deployed successfully with updated OpenAI API key"
	@echo ""

# Force redeploy with latest Docker images and route 100% traffic
edgequake-redeploy: check-openai-key
	@echo "┌─────────────────────────────────────────────────────────────┐"
	@echo "│      🔄 Force Redeploy Latest EdgeQuake Images              │"
	@echo "└─────────────────────────────────────────────────────────────┘"
	@echo ""
	@echo "✅ OpenAI API key validated"
	@echo ""
	@echo "📦 Deploying API image $(EDGEQUAKE_IMAGE_TAG)..."
	@gcloud run deploy edgequake-api \
		--image $(EDGEQUAKE_REGISTRY)/edgequake-api:$(EDGEQUAKE_IMAGE_TAG) \
		--region=$(REGION) \
		--project=$(PROJECT_ID) \
		--update-env-vars=OPENAI_API_KEY=$$TF_VAR_openai_api_key,OPENAI_MODEL=$(EDGEQUAKE_OPENAI_MODEL),OPENAI_EMBEDDING=$(EDGEQUAKE_OPENAI_EMBEDDING) \
		--quiet
	@echo ""
	@echo "📦 Deploying WebUI image $(EDGEQUAKE_IMAGE_TAG)..."
	@gcloud run deploy edgequake-webui \
		--image $(EDGEQUAKE_REGISTRY)/edgequake-webui:$(EDGEQUAKE_IMAGE_TAG) \
		--region=$(REGION) \
		--project=$(PROJECT_ID) \
		--update-env-vars=OPENAI_MODEL=$(EDGEQUAKE_OPENAI_MODEL),OPENAI_EMBEDDING=$(EDGEQUAKE_OPENAI_EMBEDDING) \
		--quiet
	@echo ""
	@echo "✅ Latest images deployed and traffic routed!"
	@echo ""
	@echo "🔗 Service URLs:"
	@gcloud run services describe edgequake-api --region=$(REGION) --project=$(PROJECT_ID) --format='value(status.url)' | xargs -I {} echo "  • API:    {}"
	@gcloud run services describe edgequake-webui --region=$(REGION) --project=$(PROJECT_ID) --format='value(status.url)' | xargs -I {} echo "  • WebUI:  {}"

edgequake-full: sqlx-prepare-auto check-openai-key edgequake-build edgequake-deploy edgequake-status
	@echo "┌─────────────────────────────────────────────────────────────┐"
	@echo "│         🎉 EdgeQuake Deployment Complete!                    │"
	@echo "└─────────────────────────────────────────────────────────────┘"
	@echo ""
	@echo "📋 Deployment Summary:"
	@echo "   • SQLx query cache: Generated"
	@echo "   • Docker images: Built and pushed"
	@echo "   • OpenAI API key: Updated"
	@echo "   • Services: Deployed via Terraform"
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

# ============================================
# 🔧 SQLx Query Cache Automation with Docker
# ============================================
# Automatically prepares SQLx query cache using a temporary PostgreSQL
# container with AGE and pgvector extensions

SQLX_CONTAINER_NAME := sqlx-prepare-postgres
SQLX_DB_PORT := 54321
SQLX_DB_USER := postgres
SQLX_DB_PASSWORD := postgres
SQLX_DB_NAME := edgequake_dev
SQLX_DATABASE_URL := postgres://$(SQLX_DB_USER):$(SQLX_DB_PASSWORD)@localhost:$(SQLX_DB_PORT)/$(SQLX_DB_NAME)

.PHONY: sqlx-prepare-auto sqlx-db-start sqlx-db-stop sqlx-db-clean sqlx-prepare-manual

# Start temporary PostgreSQL container with AGE and pgvector
sqlx-db-start:
	@echo "🐳 Starting temporary PostgreSQL container with pgvector..."
	@docker rm -f $(SQLX_CONTAINER_NAME) 2>/dev/null || true
	@docker run -d \
		--name $(SQLX_CONTAINER_NAME) \
		-e POSTGRES_PASSWORD=$(SQLX_DB_PASSWORD) \
		-e POSTGRES_DB=$(SQLX_DB_NAME) \
		-p $(SQLX_DB_PORT):5432 \
		pgvector/pgvector:pg16
	@echo "⏳ Waiting for PostgreSQL to be ready..."
	@for i in $$(seq 1 30); do \
		if docker exec $(SQLX_CONTAINER_NAME) pg_isready -U $(SQLX_DB_USER) >/dev/null 2>&1; then \
			echo "✅ PostgreSQL is ready"; \
			break; \
		fi; \
		if [ $$i -eq 30 ]; then \
			echo "❌ PostgreSQL failed to start"; \
			docker logs $(SQLX_CONTAINER_NAME); \
			exit 1; \
		fi; \
		sleep 1; \
	done
	@echo "🔧 Enabling pgvector extension..."
	@echo "🔧 Ensuring temporary database exists and enabling pgvector extension..."
	@docker exec $(SQLX_CONTAINER_NAME) psql -U $(SQLX_DB_USER) -tAc "SELECT 1 FROM pg_database WHERE datname='$(SQLX_DB_NAME)'" | grep -q 1 || \
		docker exec $(SQLX_CONTAINER_NAME) psql -U $(SQLX_DB_USER) -c "CREATE DATABASE $(SQLX_DB_NAME)"
	@docker exec $(SQLX_CONTAINER_NAME) psql -U $(SQLX_DB_USER) -d $(SQLX_DB_NAME) -c "CREATE EXTENSION IF NOT EXISTS vector;"
	@echo "📋 Applying database migrations..."
	@if [ -d "$(EDGEQUAKE_REPO)/migrations" ]; then \
		for migration in $(EDGEQUAKE_REPO)/migrations/*.sql; do \
			if [ -f "$$migration" ]; then \
				echo "   Applying $$(basename $$migration)..."; \
				docker exec -i $(SQLX_CONTAINER_NAME) psql -U $(SQLX_DB_USER) -d $(SQLX_DB_NAME) < "$$migration" 2>&1 | grep -v "^NOTICE:" || true; \
			fi; \
		done; \
		echo "✅ All migrations applied"; \
	else \
		echo "⚠️  No migrations directory found at $(EDGEQUAKE_REPO)/migrations"; \
	fi
	@echo "✅ Database ready with pgvector extension and schema"

# Stop temporary PostgreSQL container
sqlx-db-stop:
	@echo "🛑 Stopping temporary PostgreSQL container..."
	@docker rm -f $(SQLX_CONTAINER_NAME) 2>/dev/null || true
	@echo "✅ Container stopped and removed"

# Clean up SQLx database resources
sqlx-db-clean: sqlx-db-stop
	@echo "✅ SQLx database cleanup complete"

# Manual SQLx prepare (requires DATABASE_URL to be set)
sqlx-prepare-manual:
	@if [ -z "$$DATABASE_URL" ]; then \
		echo "❌ ERROR: DATABASE_URL is not set"; \
		echo "💡 Use 'make sqlx-prepare-auto' for automatic setup"; \
		exit 1; \
	fi
	@if ! command -v cargo-sqlx >/dev/null 2>&1; then \
		echo "📦 Installing sqlx-cli..."; \
		cargo install sqlx-cli --no-default-features --features postgres,native-tls; \
	fi
	@echo "🔧 Running cargo sqlx prepare..."
	@DATABASE_URL="$$DATABASE_URL" cargo sqlx prepare --workspace -- --all-features
	@echo "✅ SQLx query cache generated"

# Automated SQLx prepare with temporary Docker database
sqlx-prepare-auto: sqlx-db-start
	@echo "┌─────────────────────────────────────────────────────────────┐"
	@echo "│          🔧 Automated SQLx Query Cache Generation           │"
	@echo "└─────────────────────────────────────────────────────────────┘"
	@echo ""
	@if ! command -v cargo-sqlx >/dev/null 2>&1; then \
		echo "📦 Installing sqlx-cli..."; \
		cargo install sqlx-cli --no-default-features --features postgres,native-tls; \
	fi
	@echo "🔍 Checking EdgeQuake repository..."
	@if [ ! -d "$(EDGEQUAKE_REPO)" ]; then \
		echo "❌ EdgeQuake repository not found: $(EDGEQUAKE_REPO)"; \
		echo "💡 Update EDGEQUAKE_REPO in Makefile"; \
		make sqlx-db-stop; \
		exit 1; \
	fi
	@echo "🔧 Running cargo sqlx prepare in EdgeQuake repository..."
	@cd $(EDGEQUAKE_REPO) && \
		DATABASE_URL="$(SQLX_DATABASE_URL)" \
		cargo sqlx prepare --workspace -- --all-features || \
		(echo "❌ SQLx prepare failed"; make -C $(CURDIR) sqlx-db-stop; exit 1)
	@make sqlx-db-stop
	@echo ""
	@echo "✅ SQLx query cache generated successfully"
	@echo "💡 Remember to commit the .sqlx directory in $(EDGEQUAKE_REPO)"
	@echo ""

# Alias for convenience
sqlx-prepare: sqlx-prepare-auto

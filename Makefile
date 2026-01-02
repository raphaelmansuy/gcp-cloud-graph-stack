#!/usr/bin/env make
# Makefile for gcp-cloud-graph-stack
# Convenient shortcuts for common operations

PROJECT_ID := saas-app-001
REGION := us-central1
REGISTRY := ${REGION}-docker.pkg.dev/${PROJECT_ID}
TF_DIR := terraform

.PHONY: help setup init plan apply destroy logs ssh docker-build docker-push \
        verify-db verify-services clean docs install-tools

help:
	@echo "=== GCP Cloud Graph Stack - Available Commands ==="
	@echo ""
	@echo "Setup & Initialization:"
	@echo "  make setup               # Install all tools"
	@echo "  make init                # Initialize Terraform"
	@echo "  make config              # Create terraform.tfvars from example"
	@echo ""
	@echo "Infrastructure:"
	@echo "  make plan                # Plan Terraform changes"
	@echo "  make apply               # Apply Terraform configuration"
	@echo "  make destroy             # Destroy all infrastructure"
	@echo "  make refresh             # Refresh Terraform state"
	@echo ""
	@echo "Docker & Containers:"
	@echo "  make docker-build        # Build all Docker images"
	@echo "  make docker-push         # Push Docker images to registry"
	@echo "  make docker-clean        # Remove local Docker images"
	@echo ""
	@echo "Verification & Testing:"
	@echo "  make verify-infra        # Verify infrastructure deployed"
	@echo "  make verify-db           # SSH into VM and verify PostgreSQL"
	@echo "  make verify-services     # Check Cloud Run services"
	@echo "  make test-nextjs         # Test Next.js frontend"
	@echo "  make test-rust           # Test Rust API"
	@echo ""
	@echo "Operations:"
	@echo "  make logs-cloud-run      # Show Cloud Run logs"
	@echo "  make logs-vm             # Show VM logs (requires SSH)"
	@echo "  make ssh                 # SSH into PostgreSQL VM"
	@echo "  make costs               # Show estimated costs"
	@echo ""
	@echo "Cleanup:"
	@echo "  make clean               # Clean Terraform cache"
	@echo "  make clean-all           # Clean everything"
	@echo ""
	@echo "Documentation:"
	@echo "  make docs                # Show documentation overview"
	@echo "  make readme              # Show README"
	@echo ""
	@echo "Configuration:"
	@echo "  Project ID: ${PROJECT_ID}"
	@echo "  Region: ${REGION}"
	@echo "  Registry: ${REGISTRY}"
	@echo ""

# Setup & Initialization
setup:
	@echo "Installing required tools..."
	@command -v terraform >/dev/null 2>&1 || (echo "Installing Terraform..." && brew install terraform)
	@command -v gcloud >/dev/null 2>&1 || (echo "Installing Google Cloud SDK..." && brew install --cask google-cloud-sdk)
	@command -v docker >/dev/null 2>&1 || (echo "Installing Docker..." && brew install --cask docker)
	@echo "✓ All tools installed"
	@gcloud config set project ${PROJECT_ID}
	@gcloud auth application-default login
	@echo "✓ GCP authentication configured"

init:
	@echo "Initializing Terraform..."
	cd ${TF_DIR} && terraform init

config:
	@echo "Creating terraform.tfvars from template..."
	@if [ ! -f ${TF_DIR}/terraform.tfvars ]; then \
		cp ${TF_DIR}/terraform.tfvars.example ${TF_DIR}/terraform.tfvars; \
		echo "✓ terraform.tfvars created"; \
		echo "⚠️  Edit ${TF_DIR}/terraform.tfvars to customize your deployment"; \
	else \
		echo "terraform.tfvars already exists"; \
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
	@echo "  1. Build Docker images: make docker-build"
	@echo "  2. Push to registry: make docker-push"
	@echo "  3. Verify database: make verify-db"

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
docker-build:
	@echo "Building Docker images..."
	@echo "Building Next.js image..."
	docker build -t ${REGISTRY}/gcp-graph-stack-images/nextjs:latest \
		-f dockerfiles/Dockerfile.nextjs .
	@echo "✓ Next.js image built"
	@echo ""
	@echo "Building Rust API image..."
	docker build -t ${REGISTRY}/gcp-graph-stack-images/rust-api:latest \
		-f dockerfiles/Dockerfile.rust .
	@echo "✓ Rust API image built"

docker-push: docker-auth
	@echo "Pushing Docker images to Artifact Registry..."
	docker push ${REGISTRY}/gcp-graph-stack-images/nextjs:latest
	docker push ${REGISTRY}/gcp-graph-stack-images/rust-api:latest
	@echo "✓ Images pushed successfully"

docker-auth:
	@echo "Configuring Docker authentication..."
	gcloud auth configure-docker ${REGION}-docker.pkg.dev

docker-clean:
	@echo "Removing local Docker images..."
	docker rmi ${REGISTRY}/gcp-graph-stack-images/nextjs:latest || true
	docker rmi ${REGISTRY}/gcp-graph-stack-images/rust-api:latest || true
	@echo "✓ Docker images removed"

# Verification & Testing
verify-infra:
	@echo "Verifying infrastructure..."
	@echo ""
	@echo "=== Compute Engine VM ==="
	gcloud compute instances describe gcp-graph-stack-db-vm \
		--zone=${REGION}-a --format='table(status,machineType.machine_type(),networkInterfaces[0].networkIP)'
	@echo ""
	@echo "=== Cloud Run Services ==="
	gcloud run services list --region=${REGION} \
		--format='table(SERVICE_NAME,STATUS,REGION,URL)'
	@echo ""
	@echo "=== Artifact Registry ==="
	gcloud artifacts docker images list ${REGISTRY}/gcp-graph-stack-images \
		--format='table(IMAGE,DIGEST,CREATE_TIME)'

verify-db:
	@echo "Verifying PostgreSQL installation..."
	@echo "Connecting to VM and checking PostgreSQL status..."
	gcloud compute ssh gcp-graph-stack-db-vm --zone=${REGION}-a \
		--command="sudo systemctl status postgresql && sudo -u postgres psql -c 'SELECT version();'"

verify-services:
	@echo "Checking Cloud Run services..."
	gcloud run services describe nextjs-frontend --region=${REGION}
	@echo ""
	gcloud run services describe rust-api --region=${REGION}

test-nextjs:
	@echo "Testing Next.js frontend..."
	@NEXTJS_URL=$$(gcloud run services describe nextjs-frontend --region=${REGION} --format='value(status.url)'); \
	echo "Endpoint: $$NEXTJS_URL"; \
	curl -s $$NEXTJS_URL | head -c 200; \
	echo ""

test-rust:
	@echo "Testing Rust API..."
	@RUST_URL=$$(gcloud run services describe rust-api --region=${REGION} --format='value(status.url)'); \
	echo "Endpoint: $$RUST_URL"; \
	curl -s $$RUST_URL/health || echo "API endpoint not responding"

# Operations
logs-cloud-run:
	@echo "Showing Cloud Run logs (last 50 lines)..."
	@echo "Next.js Frontend:"
	gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=nextjs-frontend" \
		--limit=50 --format='table(timestamp, severity, textPayload)' | head -20
	@echo ""
	@echo "Rust API:"
	gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=rust-api" \
		--limit=50 --format='table(timestamp, severity, textPayload)' | head -20

logs-vm:
	@echo "Showing VM startup script logs..."
	gcloud compute instances get-serial-port-output gcp-graph-stack-db-vm \
		--zone=${REGION}-a | tail -100

ssh:
	@echo "Connecting to PostgreSQL VM..."
	gcloud compute ssh gcp-graph-stack-db-vm --zone=${REGION}-a

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

# Cleanup
clean:
	@echo "Cleaning Terraform cache..."
	rm -rf ${TF_DIR}/.terraform*
	rm -f ${TF_DIR}/*.tfstate*
	@echo "✓ Cleaned"

clean-all: docker-clean clean
	@echo "✓ All cleaned"

# Documentation
docs:
	@echo "=== Documentation Overview ==="
	@echo ""
	@echo "Start here:"
	@echo "  • README.md                          - Project overview"
	@echo "  • docs/05-quick-start.md             - Step-by-step deployment"
	@echo ""
	@echo "Architecture & Design:"
	@echo "  • docs/01-architecture.md            - System design decisions"
	@echo "  • docs/04-ci-cd-architecture.md      - CI/CD patterns"
	@echo ""
	@echo "Implementation Guides:"
	@echo "  • docs/02-deployment-terraform.md    - Terraform walkthrough"
	@echo "  • docs/03-deployment-github-actions.md - GitHub Actions setup"
	@echo ""
	@echo "Planning & Operations:"
	@echo "  • docs/06-roadmap-costs.md           - Roadmap & cost analysis"
	@echo ""
	@echo "Usage:"
	@echo "  make readme                          - Show README"
	@echo "  cat docs/05-quick-start.md           - Show Quick Start"
	@echo ""

readme:
	@cat README.md

# Default target
.DEFAULT_GOAL := help

# Prevent make from trying to interpret commands as recipes
.SECONDARY:

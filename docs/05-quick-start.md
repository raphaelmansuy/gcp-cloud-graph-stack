# Quick Start Guide: Deploy gcp-cloud-graph-stack

This guide walks you through deploying the complete infrastructure and application to the `saas-app-001` GCP project using the automated Makefile.

## Prerequisites

### 🔑 CRITICAL: OpenAI API Key (Required)

**EdgeQuake requires a valid OpenAI API key to function. Deployment will fail without it.**

```bash
# 1. Get your key from: https://platform.openai.com/account/api-keys
# 2. Set environment variable:
export TF_VAR_openai_api_key="sk-proj-YOUR-ACTUAL-KEY-HERE"

# 3. Verify it's set correctly:
make check-openai-key
```

📚 **Complete Setup Guide:** [27-openai-api-key-setup.md](27-openai-api-key-setup.md)

---

### Local Tools
- **GNU Make** (standard on macOS/Linux)
- **Terraform 1.5+** ([install](https://www.terraform.io/downloads))
- **Google Cloud SDK** (`gcloud` CLI) ([install](https://cloud.google.com/sdk/docs/install))
- **Docker** ([install](https://docs.docker.com/get-docker))

## The 1-Command Setup (Recommended)

The fastest way to get started is to use the `full-setup` command. This will:
1. Authenticate with GCP
2. Configure your project
3. Initialize Terraform
4. Scaffold minimal source code (Next.js & Rust)
5. Deploy infrastructure
6. Build and push Docker images

```bash
make full-setup
```

---

## Step-by-Step Path

If you prefer to run steps manually or need to troubleshoot:

### 1. Authentication & Setup
```bash
make setup
```
This installs the GCP SDK (if missing) and performs `gcloud auth login` and `gcloud auth application-default login`.

### 2. Configuration
```bash
make config
```
Creates your `terraform.tfvars` from the example template.

### 3. Initialize & Scaffold
```bash
make init
make scaffold
```
Initializes Terraform backend and creates the minimal application source code required for the Docker builds.

### 4. Deploy Infrastructure
```bash
make deploy
```
Runs `terraform plan` and `terraform apply` to create the VPC, VM (Postgres+AGE), and Cloud Run services.

### 5. Build & Push Images
```bash
make docker-build
make docker-push
```
Builds the Next.js and Rust API containers and pushes them to the GCP Artifact Registry.

### 6. Verify Status
```bash
make status
```
Provides a comprehensive health check of your VM, Cloud Run services, and firewall rules.

---

## Interactive Menu

For a guided experience, use the interactive menu:

```bash
make menu
```

## Common Operations

| Task | Command |
|------|---------|
| **Check Health** | `make status` |
| **SSH to DB** | `make ssh` |
| **Database Tunnel** | `make db-tunnel` |
| **View Logs** | `make logs` |
| **Cleanup** | `make clean` |

---

## Troubleshooting

If `make docker-build` fails, ensure you have run `make scaffold` first. The Dockerfiles require a `package.json` and `Cargo.toml` to exist in the root directory.

## Additional Resources

- [📘 Architecture Overview](./01-architecture.md)
- [🚀 Terraform Deployment Guide](./02-deployment-terraform.md)
- [🔄 GitHub Actions Setup](./03-deployment-github-actions.md)
- [🏗️ CI/CD Architecture](./04-ci-cd-architecture.md)
- [Terraform Registry: Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [GCP Cloud Run Documentation](https://cloud.google.com/run/docs)
- [PostgreSQL on Compute Engine](https://cloud.google.com/solutions/postgresql-on-compute-engine)

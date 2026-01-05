#!/bin/bash
# Build and push PostgreSQL Docker image to Artifact Registry
# Run this once to pre-build the image, then update terraform to use it

set -euo pipefail

PROJECT_ID="${GCP_PROJECT:-saas-app-001}"
REGION="${GCP_REGION:-us-central1}"
REGISTRY_REPO="edgequake-images"
IMAGE_NAME="postgres-age-vector"
IMAGE_TAG="16-latest"

FULL_IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REGISTRY_REPO}/${IMAGE_NAME}:${IMAGE_TAG}"

echo "=== Building PostgreSQL Image for Artifact Registry ==="
echo "Image: $FULL_IMAGE"
echo ""

# Verify we have docker installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found. Install Docker and try again."
    exit 1
fi

# Configure Docker authentication for Artifact Registry
echo "Configuring Docker authentication..."
gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet

# Create Dockerfile locally
echo "Creating Dockerfile..."
cat > /tmp/Dockerfile.postgres << 'DOCKERFILE'
FROM postgres:16-bookworm

# Install build dependencies for AGE and pgvector
RUN apt-get update && apt-get install -y \
    build-essential \
    flex \
    bison \
    git \
    postgresql-server-dev-16 \
    && rm -rf /var/lib/apt/lists/*

# Install pgvector
RUN cd /tmp && \
    git clone --branch v0.5.1 https://github.com/pgvector/pgvector.git && \
    cd pgvector && \
    make && \
    make install && \
    cd / && \
    rm -rf /tmp/pgvector

# Install Apache AGE
RUN cd /tmp && \
    git clone https://github.com/apache/age.git && \
    cd age && \
    (git checkout PG16/v1.6.0-rc0 || git checkout master) && \
    make install && \
    cd / && \
    rm -rf /tmp/age

# Clean up build dependencies
RUN apt-get remove -y build-essential flex bison git postgresql-server-dev-16 && \
    apt-get autoremove -y && \
    apt-get clean

# Health check
HEALTHCHECK --interval=10s --timeout=5s --retries=5 \
    CMD pg_isready -U postgres -d postgres

DOCKERFILE

# Build image
echo "Building Docker image..."
docker build \
    -t "${FULL_IMAGE}" \
    -f /tmp/Dockerfile.postgres \
    /tmp/

# Push to Artifact Registry
echo "Pushing to Artifact Registry..."
docker push "${FULL_IMAGE}"

echo ""
echo "✅ Image pushed successfully!"
echo ""
echo "Update your terraform.tfvars:"
echo "  postgres_image_url = \"${FULL_IMAGE}\""
echo ""
echo "Or set environment variable:"
echo "  export TF_VAR_postgres_image_url=\"${FULL_IMAGE}\""

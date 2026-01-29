#!/usr/bin/env bash
# Deploy EdgeQuake latest version from edgequake-main branch
#
# This script ensures we always deploy the latest version by:
# 1. Pulling latest changes from edgequake-main
# 2. Building with version tagging from git SHA
# 3. Deploying to Cloud Run with version labels

set -euo pipefail

# Configuration
EDGEQUAKE_REPO="${EDGEQUAKE_REPO:-/Users/raphaelmansuy/Github/03-working/edgequake}"
EDGEQUAKE_BRANCH="${EDGEQUAKE_BRANCH:-edgequake-main}"
PROJECT_ID="${PROJECT_ID:-saas-app-001}"
REGION="${REGION:-us-central1}"
REGISTRY="${REGISTRY:-${REGION}-docker.pkg.dev/${PROJECT_ID}/edgequake-images}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}ℹ️  ${1}${NC}"
}

log_success() {
    echo -e "${GREEN}✅ ${1}${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  ${1}${NC}"
}

log_error() {
    echo -e "${RED}❌ ${1}${NC}"
}

# Check if EdgeQuake repository exists
if [ ! -d "$EDGEQUAKE_REPO" ]; then
    log_error "EdgeQuake repository not found: $EDGEQUAKE_REPO"
    log_info "Please update EDGEQUAKE_REPO environment variable"
    exit 1
fi

cd "$EDGEQUAKE_REPO"

# Get current version before pull
CURRENT_VERSION=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
CURRENT_BRANCH=$(git branch --show-current)

log_info "Current state:"
log_info "  Repository: $EDGEQUAKE_REPO"
log_info "  Branch:     $CURRENT_BRANCH"
log_info "  Version:    $CURRENT_VERSION"
echo ""

# Pull latest changes from edgequake-main
log_info "Pulling latest changes from $EDGEQUAKE_BRANCH..."
if git fetch origin "$EDGEQUAKE_BRANCH" && \
   git checkout "$EDGEQUAKE_BRANCH" && \
   git pull origin "$EDGEQUAKE_BRANCH"; then
    
    NEW_VERSION=$(git rev-parse --short HEAD)
    COMMIT_MSG=$(git log -1 --pretty=format:'%s')
    
    log_success "Updated to latest version"
    log_info "  Version: $NEW_VERSION"
    log_info "  Commit:  $COMMIT_MSG"
    echo ""
    
    if [ "$CURRENT_VERSION" = "$NEW_VERSION" ]; then
        log_info "Already at latest version"
    else
        log_success "Updated from $CURRENT_VERSION to $NEW_VERSION"
    fi
else
    log_warning "Failed to pull latest changes. Using current version: $CURRENT_VERSION"
fi

# Get final version for deployment
DEPLOY_VERSION=$(git rev-parse --short HEAD)
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

log_info "Deployment version: $DEPLOY_VERSION"
log_info "Timestamp:          $TIMESTAMP"
echo ""

# Return to deployment directory
cd - > /dev/null

# Build and deploy using Makefile
log_info "Building EdgeQuake images with version $DEPLOY_VERSION..."
echo ""

if make edgequake-build-api-fast; then
    log_success "API image built and pushed"
else
    log_error "API build failed"
    exit 1
fi

echo ""

if make edgequake-build-webui-fast; then
    log_success "WebUI image built and pushed"
else
    log_error "WebUI build failed"
    exit 1
fi

echo ""

# Deploy to Cloud Run
log_info "Deploying to Cloud Run with version labels..."
echo ""

# Deploy API with version label
if gcloud run deploy edgequake-api \
    --image "${REGISTRY}/edgequake-api:latest" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --update-labels="version=${DEPLOY_VERSION},deployed-at=${TIMESTAMP}" \
    --quiet; then
    log_success "API deployed with version ${DEPLOY_VERSION}"
else
    log_error "API deployment failed"
    exit 1
fi

echo ""

# Deploy WebUI with version label
if gcloud run deploy edgequake-webui \
    --image "${REGISTRY}/edgequake-webui:latest" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --update-labels="version=${DEPLOY_VERSION},deployed-at=${TIMESTAMP}" \
    --quiet; then
    log_success "WebUI deployed with version ${DEPLOY_VERSION}"
else
    log_error "WebUI deployment failed"
    exit 1
fi

echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│         🎉 EdgeQuake Deployment Complete!                   │"
echo "└─────────────────────────────────────────────────────────────┘"
echo ""

# Show service URLs
API_URL=$(gcloud run services describe edgequake-api --region="$REGION" --project="$PROJECT_ID" --format='value(status.url)' 2>/dev/null || echo "Not deployed")
WEBUI_URL=$(gcloud run services describe edgequake-webui --region="$REGION" --project="$PROJECT_ID" --format='value(status.url)' 2>/dev/null || echo "Not deployed")

echo "🔗 Service URLs:"
echo "  • API:    $API_URL"
echo "  • WebUI:  $WEBUI_URL"
echo ""
echo "📦 Version:  $DEPLOY_VERSION"
echo "📅 Deployed: $TIMESTAMP"
echo ""

# Verify deployment
log_info "Verifying deployment..."
sleep 5

API_STATUS=$(curl -s -o /dev/null -w '%{http_code}' "${API_URL}/health" 2>/dev/null || echo "000")
WEBUI_STATUS=$(curl -s -o /dev/null -w '%{http_code}' "${WEBUI_URL}" 2>/dev/null || echo "000")

if [ "$API_STATUS" = "200" ]; then
    log_success "API health check passed (HTTP $API_STATUS)"
else
    log_warning "API health check returned HTTP $API_STATUS"
fi

if [ "$WEBUI_STATUS" = "200" ]; then
    log_success "WebUI health check passed (HTTP $WEBUI_STATUS)"
else
    log_warning "WebUI health check returned HTTP $WEBUI_STATUS"
fi

echo ""
log_success "Deployment complete! 🚀"

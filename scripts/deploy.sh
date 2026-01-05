#!/bin/bash
# EdgeQuake Complete Deployment Script
# Deploys EdgeQuake stack with all fixesset -e

echo "========================================="
echo "EdgeQuake Complete Deployment"
echo "========================================="
echo ""

# Check prerequisites
echo "=== Checking Prerequisites ==="
echo ""

if ! command -v gcloud &> /dev/null; then
    echo "❌ gcloud CLI not found. Please install it first."
    exit 1
fi

if ! command -v docker &> /dev/null; then
    echo "❌ docker not found. Please install it first."
    exit 1
fi

if ! command -v terraform &> /dev/null; then
    echo "❌ terraform not found. Please install it first."
    exit 1
fi

echo "✅ All prerequisites installed"
echo ""

# Check authentication
echo "=== Checking Authentication ==="
echo ""

if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
    echo "❌ Not authenticated to gcloud. Run: gcloud auth login"
    exit 1
fi

ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
PROJECT=$(gcloud config get-value project)

echo "✅ Authenticated as: $ACCOUNT"
echo "✅ Project: $PROJECT"
echo ""

# Check if OPENAI_API_KEY is set
if [ -z "$TF_VAR_openai_api_key" ]; then
    echo "⚠️  WARNING: OPENAI_API_KEY not set"
    echo "   The API will use a placeholder key."
    echo "   To set it, export TF_VAR_openai_api_key='your-key'"
    echo ""
    read -p "Continue without OPENAI_API_KEY? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo "✅ OPENAI_API_KEY is set"
fi
echo ""

# Build images
echo "=== Building Docker Images ==="
echo ""

echo "Building EdgeQuake API..."
if ! make edgequake-build-api-fast; then
    echo "❌ API build failed"
    exit 1
fi

echo ""
echo "Building EdgeQuake WebUI..."
if ! make edgequake-build-webui-fast; then
    echo "❌ WebUI build failed"
    exit 1
fi

echo ""
echo "✅ All images built successfully"
echo ""

# Deploy with Terraform
echo "=== Deploying with Terraform ==="
echo ""

cd terraform

echo "Running terraform plan..."
if ! terraform plan -out=tfplan-deploy; then
    echo "❌ Terraform plan failed"
    exit 1
fi

echo ""
read -p "Apply this plan? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled"
    exit 1
fi

echo "Applying terraform configuration..."
if ! terraform apply tfplan-deploy; then
    echo "❌ Terraform apply failed"
    exit 1
fi

cd ..

echo ""
echo "✅ Deployment complete"
echo ""

# Run tests
echo "=== Running Deployment Tests ==="
echo ""

if [ -f scripts/test-deployment.sh ]; then
    chmod +x scripts/test-deployment.sh
    if ./scripts/test-deployment.sh; then
        echo ""
        echo "✅ All tests passed!"
    else
        echo ""
        echo "⚠️  Some tests failed. Please review the output above."
        exit 1
    fi
else
    echo "⚠️  Test script not found, skipping tests"
fi

echo ""
echo "========================================="
echo "Deployment Complete!"
echo "========================================="
echo ""

# Get service URLs
API_URL=$(cd terraform && terraform output -raw rust_api_service_url)
WEBUI_URL=$(cd terraform && terraform output -raw nextjs_service_url)

echo "Your EdgeQuake deployment is ready:"
echo ""
echo "  WebUI: $WEBUI_URL"
echo "  API:   $API_URL"
echo ""
echo "Next steps:"
echo "  1. Access the WebUI and verify connectivity"
echo "  2. Upload test documents"
echo "  3. Run queries to test the knowledge graph"
echo ""

if [ -z "$TF_VAR_openai_api_key" ]; then
    echo "⚠️  Remember to set OPENAI_API_KEY for LLM features:"
    echo "   export TF_VAR_openai_api_key='your-key'"
    echo "   cd terraform && terraform apply"
    echo ""
fi

#!/bin/bash
# EdgeQuake Deployment Test Suite
# Tests all components to ensure proper deployment

set -e

echo "========================================="
echo "EdgeQuake Deployment Test Suite"
echo "========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

FAILURES=0
WARNINGS=0

# Test function
test_endpoint() {
    local name=$1
    local url=$2
    local expected_code=$3
    local description=$4
    
    echo -n "Testing: $name... "
    response=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>&1)
    
    if [ "$response" == "$expected_code" ]; then
        echo -e "${GREEN}✓ PASS${NC} (HTTP $response)"
        return 0
    else
        echo -e "${RED}✗ FAIL${NC} (Expected HTTP $expected_code, got $response)"
        echo "  URL: $url"
        FAILURES=$((FAILURES + 1))
        return 1
    fi
}

# Test JSON response
test_json() {
    local name=$1
    local url=$2
    local jq_filter=$3
    local expected=$4
    local description=$5
    
    echo -n "Testing: $name... "
    response=$(curl -s "$url" 2>&1)
    
    if echo "$response" | jq -e "$jq_filter" > /dev/null 2>&1; then
        actual=$(echo "$response" | jq -r "$jq_filter")
        if [ "$actual" == "$expected" ]; then
            echo -e "${GREEN}✓ PASS${NC} ($jq_filter = $actual)"
            return 0
        else
            echo -e "${RED}✗ FAIL${NC} ($jq_filter = $actual, expected $expected)"
            echo "  URL: $url"
            FAILURES=$((FAILURES + 1))
            return 1
        fi
    else
        echo -e "${RED}✗ FAIL${NC} (Invalid JSON or filter failed)"
        echo "  URL: $url"
        echo "  Response: $response"
        FAILURES=$((FAILURES + 1))
        return 1
    fi
}

# Warning function
warn() {
    echo -e "${YELLOW}⚠ WARNING${NC}: $1"
    WARNINGS=$((WARNINGS + 1))
}

echo "=== 1. Cloud Run Services ==="
echo ""

# Get the script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Get service URLs from Terraform
API_URL=$(cd "$PROJECT_ROOT/terraform" && terraform output -raw rust_api_service_url 2>/dev/null || echo "")
WEBUI_URL=$(cd "$PROJECT_ROOT/terraform" && terraform output -raw nextjs_service_url 2>/dev/null || echo "")

if [ -z "$API_URL" ] || [ -z "$WEBUI_URL" ]; then
    echo -e "${RED}✗ FAIL${NC}: Could not get service URLs from Terraform"
    echo "Run: cd terraform && terraform output"
    exit 1
fi

echo "API URL:   $API_URL"
echo "WebUI URL: $WEBUI_URL"
echo ""

echo "=== 2. API Health Checks ==="
echo ""

test_endpoint "API Root" "$API_URL/" "404" "API should return 404 for root (expected)"
test_endpoint "API Health" "$API_URL/health" "200" "Health check should return 200"
test_json "API Storage Mode" "$API_URL/health" ".storage_mode" "postgresql" "API should use PostgreSQL"
test_json "API Status" "$API_URL/health" ".status" "healthy" "API should report healthy"
test_json "API Components" "$API_URL/health" ".components.kv_storage" "true" "KV storage should be enabled"
test_json "API Vector Storage" "$API_URL/health" ".components.vector_storage" "true" "Vector storage should be enabled"
test_json "API Graph Storage" "$API_URL/health" ".components.graph_storage" "true" "Graph storage should be enabled"

echo ""
echo "=== 3. API Endpoints ==="
echo ""

test_endpoint "API Documents" "$API_URL/api/v1/documents" "200" "Documents endpoint should be accessible"

# Check if documents response is valid (may have existing documents)
DOC_COUNT=$(curl -s "$API_URL/api/v1/documents" | jq -r '.total' 2>/dev/null || echo "error")
if [ "$DOC_COUNT" = "error" ]; then
    echo -n "Testing: API Documents Response... "
    echo -e "${RED}✗ FAIL${NC}: Could not parse documents response"
    FAILURES=$((FAILURES + 1))
elif [ "$DOC_COUNT" -ge 0 ] 2>/dev/null; then
    echo -n "Testing: API Documents Response... "
    echo -e "${GREEN}✓ PASS${NC} (Found $DOC_COUNT documents)"
else
    echo -n "Testing: API Documents Response... "
    echo -e "${RED}✗ FAIL${NC}: Invalid document count: $DOC_COUNT"
    FAILURES=$((FAILURES + 1))
fi

echo ""
echo "=== 4. WebUI Tests ==="
echo ""

test_endpoint "WebUI Root" "$WEBUI_URL/" "200" "WebUI should be accessible"
test_endpoint "WebUI Documents" "$WEBUI_URL/documents" "200" "WebUI documents page"

# Dashboard might not exist in all versions
DASH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$WEBUI_URL/dashboard")
if [ "$DASH_STATUS" = "200" ]; then
    echo -n "Testing: WebUI Dashboard... "
    echo -e "${GREEN}✓ PASS${NC} (HTTP $DASH_STATUS)"
else
    echo -n "Testing: WebUI Dashboard... "
    echo -e "${YELLOW}⚠ WARNING${NC}: Dashboard page returned HTTP $DASH_STATUS (may not exist)"
    WARNINGS=$((WARNINGS + 1))
fi

echo ""
echo "=== 5. CORS Tests ==="
echo ""

echo -n "Testing: CORS preflight from WebUI to API... "
cors_response=$(curl -s -H "Origin: $WEBUI_URL" \
    -H "Access-Control-Request-Method: GET" \
    -H "Access-Control-Request-Headers: Content-Type" \
    -X OPTIONS \
    -I "$API_URL/health" 2>&1 | grep -i "access-control-allow-origin")

if echo "$cors_response" | grep -q "\*"; then
    echo -e "${GREEN}✓ PASS${NC} (CORS allows all origins)"
else
    echo -e "${RED}✗ FAIL${NC} (CORS not configured correctly)"
    echo "  Response: $cors_response"
    FAILURES=$((FAILURES + 1))
fi

echo ""
echo "=== 6. Database Connection ==="
echo ""

VM_IP=$(cd "$PROJECT_ROOT/terraform" && terraform output -raw vm_private_ip 2>/dev/null || echo "")
if [ -n "$VM_IP" ]; then
    echo "Database Private IP: $VM_IP"
    
    echo -n "Testing: Database VM accessible via SSH... "
    if gcloud compute ssh edgequake-db-vm --zone=us-central1-a --command="echo 'SSH OK'" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}"
        
        echo -n "Testing: PostgreSQL container running... "
        if gcloud compute ssh edgequake-db-vm --zone=us-central1-a --command="sudo docker ps | grep -q postgres" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ PASS${NC}"
        else
            echo -e "${RED}✗ FAIL${NC}"
            FAILURES=$((FAILURES + 1))
        fi
        
        echo -n "Testing: graph_db exists... "
        if gcloud compute ssh edgequake-db-vm --zone=us-central1-a --command="sudo docker exec postgres-age-vector psql -U postgres -lqt | cut -d \| -f 1 | grep -qw graph_db" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ PASS${NC}"
        else
            echo -e "${RED}✗ FAIL${NC}"
            FAILURES=$((FAILURES + 1))
        fi
    else
        echo -e "${RED}✗ FAIL${NC}"
        echo "  Cannot SSH to database VM"
        FAILURES=$((FAILURES + 1))
    fi
else
    warn "Could not get database VM IP from Terraform"
fi

echo ""
echo "=== 7. Infrastructure Tests ==="
echo ""

echo -n "Testing: VPC Connector status... "
vpc_state=$(gcloud compute networks vpc-access connectors describe edgequake-vpc-connector \
    --region=us-central1 --format="get(state)" 2>/dev/null || echo "UNKNOWN")

if [ "$vpc_state" == "READY" ]; then
    echo -e "${GREEN}✓ PASS${NC} (State: READY)"
else
    echo -e "${RED}✗ FAIL${NC} (State: $vpc_state)"
    FAILURES=$((FAILURES + 1))
fi

echo -n "Testing: API IAM policy allows public access... "
iam_policy=$(gcloud run services get-iam-policy edgequake-api --region=us-central1 \
    --format=json 2>/dev/null | jq -r '.bindings[] | select(.role=="roles/run.invoker") | .members[]' || echo "")

if echo "$iam_policy" | grep -q "allUsers"; then
    echo -e "${GREEN}✓ PASS${NC}"
else
    echo -e "${RED}✗ FAIL${NC}"
    echo "  API should allow allUsers as invoker"
    FAILURES=$((FAILURES + 1))
fi

echo -n "Testing: WebUI IAM policy allows public access... "
webui_iam=$(gcloud run services get-iam-policy edgequake-webui --region=us-central1 \
    --format=json 2>/dev/null | jq -r '.bindings[] | select(.role=="roles/run.invoker") | .members[]' || echo "")

if echo "$webui_iam" | grep -q "allUsers"; then
    echo -e "${GREEN}✓ PASS${NC}"
else
    echo -e "${RED}✗ FAIL${NC}"
    echo "  WebUI should allow allUsers as invoker"
    FAILURES=$((FAILURES + 1))
fi

echo ""
echo "=== 8. Security Tests ==="
echo ""

echo -n "Testing: Database has no public IP on port 5432... "
# Try to connect to VM external IP on port 5432 (should fail/timeout)
VM_EXTERNAL_IP=$(cd "$PROJECT_ROOT/terraform" && terraform output -raw vm_external_ip 2>/dev/null || echo "")
if [ -n "$VM_EXTERNAL_IP" ]; then
    if timeout 3 nc -z "$VM_EXTERNAL_IP" 5432 2>/dev/null; then
        echo -e "${RED}✗ FAIL${NC}"
        echo "  Database port 5432 is publicly accessible!"
        FAILURES=$((FAILURES + 1))
    else
        echo -e "${GREEN}✓ PASS${NC} (Port 5432 not accessible externally)"
    fi
else
    warn "Could not get VM external IP"
fi

echo -n "Testing: Data disk has lifecycle protection... "
disk_lifecycle=$(cd "$PROJECT_ROOT/terraform" && terraform state show 'module.compute.google_compute_disk.data_disk_protected[0]' 2>/dev/null | grep "prevent_destroy" || echo "")
if echo "$disk_lifecycle" | grep -q "prevent_destroy.*=.*true"; then
    echo -e "${GREEN}✓ PASS${NC}"
else
    warn "Data disk lifecycle protection not confirmed in Terraform state"
fi

echo ""
echo "========================================="
echo "Test Results"
echo "========================================="
echo ""

if [ $FAILURES -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ ALL TESTS PASSED${NC}"
    echo ""
    echo "EdgeQuake is fully deployed and operational!"
    echo ""
    echo "Access your deployment:"
    echo "  WebUI: $WEBUI_URL"
    echo "  API:   $API_URL"
    exit 0
elif [ $FAILURES -eq 0 ]; then
    echo -e "${YELLOW}⚠ PASSED WITH WARNINGS${NC}"
    echo ""
    echo "Failures: $FAILURES"
    echo "Warnings: $WARNINGS"
    echo ""
    echo "EdgeQuake is deployed but some checks produced warnings."
    exit 0
else
    echo -e "${RED}✗ TESTS FAILED${NC}"
    echo ""
    echo "Failures: $FAILURES"
    echo "Warnings: $WARNINGS"
    echo ""
    echo "Please review the failures above and fix the issues."
    exit 1
fi

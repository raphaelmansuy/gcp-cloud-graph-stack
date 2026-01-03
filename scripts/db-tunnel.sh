#!/bin/bash
# SSH Tunnel Script for PostgreSQL Database Access
# Usage: ./scripts/db-tunnel.sh [PROJECT_ID] [ZONE] [VM_NAME] [LOCAL_PORT] [REMOTE_PORT]
#
# Examples:
#   ./scripts/db-tunnel.sh                          # Uses defaults
#   ./scripts/db-tunnel.sh saas-app-001             # Custom project
#   ./scripts/db-tunnel.sh saas-app-001 us-central1-a db-vm 5433  # Custom port

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration (with defaults)
PROJECT_ID="${1:-saas-app-001}"
ZONE="${2:-us-central1-a}"
VM_NAME="${3:-db-vm}"
LOCAL_PORT="${4:-5432}"
REMOTE_PORT="${5:-5432}"

# Function to print headers
print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_section() {
    echo -e "${YELLOW}$1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Validate inputs
validate_inputs() {
    print_section "Validating configuration..."
    
    # Check if gcloud is installed
    if ! command -v gcloud &> /dev/null; then
        print_error "gcloud not found. Please install Google Cloud SDK."
        exit 1
    fi
    print_success "gcloud CLI found"
    
    # Check if psql is installed (optional, just for convenience)
    if ! command -v psql &> /dev/null; then
        print_info "psql not found. You can still use the tunnel, but you'll need a PostgreSQL client to connect."
    else
        print_success "psql found"
    fi
    
    # Check if project exists and user has access
    if ! gcloud projects describe "${PROJECT_ID}" --quiet &> /dev/null; then
        print_error "Project '${PROJECT_ID}' not found or not accessible."
        echo "Available projects:"
        gcloud projects list --format='value(project_id)' | head -5
        exit 1
    fi
    print_success "Project '${PROJECT_ID}' accessible"
    
    # Check if VM exists
    if ! gcloud compute instances describe "${VM_NAME}" --zone="${ZONE}" --project="${PROJECT_ID}" &> /dev/null; then
        print_error "VM '${VM_NAME}' not found in zone '${ZONE}'."
        echo "Available VMs:"
        gcloud compute instances list --zones="${ZONE}" --project="${PROJECT_ID}" --format='value(name)' 2>/dev/null || echo "  (none)"
        exit 1
    fi
    print_success "VM '${VM_NAME}' found in zone '${ZONE}'"
    
    # Check if local port is available
    if netstat -tuln 2>/dev/null | grep -q ":${LOCAL_PORT} "; then
        print_error "Local port ${LOCAL_PORT} is already in use."
        echo "Use a different port: ./scripts/db-tunnel.sh ${PROJECT_ID} ${ZONE} ${VM_NAME} 5433"
        exit 1
    fi
    print_success "Local port ${LOCAL_PORT} is available"
}

# Print connection information
print_connection_info() {
    print_header "🚀 SSH Tunnel Configuration"
    
    echo ""
    echo -e "   ${BLUE}Local Machine${NC}"
    echo "   └─ localhost:${LOCAL_PORT}"
    echo ""
    echo -e "   ${BLUE}SSH Tunnel${NC}"
    echo "   └─ gcloud compute ssh (encrypted)"
    echo ""
    echo -e "   ${BLUE}Remote Server${NC}"
    echo "   ├─ Project: ${PROJECT_ID}"
    echo "   ├─ Zone: ${ZONE}"
    echo "   ├─ VM: ${VM_NAME}"
    echo "   └─ PostgreSQL: 127.0.0.1:${REMOTE_PORT}"
    echo ""
}

# Print usage instructions
print_usage_instructions() {
    print_header "📚 How to Use"
    
    echo ""
    print_section "Step 1: Keep this tunnel running"
    echo "   This terminal will stay open as long as the tunnel is active."
    echo "   Press Ctrl+C to stop."
    echo ""
    
    print_section "Step 2: Open another terminal and connect"
    if [ "${LOCAL_PORT}" = "5432" ]; then
        echo "   ${BLUE}psql -h localhost -U postgres -d graph_db${NC}"
    else
        echo "   ${BLUE}psql -h localhost -p ${LOCAL_PORT} -U postgres -d graph_db${NC}"
    fi
    echo ""
    
    print_section "Step 3: Use PostgreSQL normally"
    echo "   Once connected, you have full access to the database:"
    echo "   ${BLUE}graph_db=> SELECT * FROM graph.sample_graph;${NC}"
    echo "   ${BLUE}graph_db=> \\dx${NC}  (list extensions)"
    echo "   ${BLUE}graph_db=> \\dt${NC}  (list tables)"
    echo ""
}

# Create the tunnel
create_tunnel() {
    print_header "Establishing SSH Tunnel..."
    echo ""
    
    # Show what's about to happen
    echo "Command:"
    echo "  gcloud compute ssh ${VM_NAME} \\"
    echo "    --zone=${ZONE} \\"
    echo "    --project=${PROJECT_ID} \\"
    echo "    -- -L ${LOCAL_PORT}:127.0.0.1:${REMOTE_PORT}"
    echo ""
    
    # Create the tunnel
    print_info "Connecting to ${VM_NAME}..."
    echo ""
    
    gcloud compute ssh "${VM_NAME}" \
        --zone="${ZONE}" \
        --project="${PROJECT_ID}" \
        -- -L "${LOCAL_PORT}:127.0.0.1:${REMOTE_PORT}"
}

# Handle script interruption
cleanup() {
    echo ""
    echo ""
    print_header "Tunnel Closed"
    echo "SSH tunnel to PostgreSQL has been closed."
    echo "The connection from your local machine is no longer available."
    echo ""
}

trap cleanup EXIT

# Main flow
main() {
    print_header "🔌 PostgreSQL SSH Tunnel Setup"
    echo ""
    
    # Validate everything before starting
    validate_inputs
    print_success "All checks passed!"
    
    echo ""
    
    # Show connection details
    print_connection_info
    
    # Show usage instructions
    print_usage_instructions
    
    # Create the tunnel
    create_tunnel
}

# Run main function
main "$@"

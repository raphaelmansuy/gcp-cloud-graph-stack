#!/bin/bash
# secure-ssh-access.sh - Authorize only current public IP for SSH access
# Usage: ./scripts/secure-ssh-access.sh [PROJECT_ID] [FIREWALL_NAME]
#
# This script detects your current public IP and updates the GCP firewall
# to allow SSH access ONLY from that IP address (single IP authorization).
#
# Security Benefits:
# - Only your current IP can access SSH to the database VM
# - Dynamic: Run whenever your IP changes
# - Audit trail: Firewall description includes timestamp
# - Zero-trust: No permanent access granted

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration (with defaults)
PROJECT_ID="${1:-saas-app-001}"
FIREWALL_NAME="${2:-edgequake-allow-ssh-restricted}"

# Function to print colored output
print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Validate gcloud authentication
validate_gcloud() {
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        print_error "Not authenticated with gcloud. Run: gcloud auth login"
        exit 1
    fi

    if ! gcloud projects describe "$PROJECT_ID" &>/dev/null; then
        print_error "Cannot access project: $PROJECT_ID"
        print_info "Available projects:"
        gcloud projects list --format="value(projectId)"
        exit 1
    fi
}

# Get public IP address
get_public_ip() {
    print_info "Detecting your public IP address..."

    # Try multiple services for redundancy
    for service in "https://api.ipify.org" "https://ipv4.icanhazip.com" "https://checkip.amazonaws.com"; do
        if PUBLIC_IP=$(curl -s --max-time 5 "$service" 2>/dev/null); then
            # Validate IP format
            if [[ $PUBLIC_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                print_success "Your public IP: $PUBLIC_IP"
                return 0
            fi
        fi
    done

    print_error "Could not detect public IP address"
    print_info "Check your internet connection and try again"
    exit 1
}

# Check if firewall exists
check_firewall() {
    if ! gcloud compute firewall-rules describe "$FIREWALL_NAME" --project="$PROJECT_ID" &>/dev/null; then
        print_error "Firewall rule '$FIREWALL_NAME' not found"
        print_info "Available firewall rules:"
        gcloud compute firewall-rules list --project="$PROJECT_ID" --format="value(name)"
        print_info "Create the firewall rule first or specify correct name"
        exit 1
    fi
}

# Update firewall with new IP
update_firewall() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S UTC')

    print_info "Updating GCP firewall to allow SSH only from $PUBLIC_IP..."

    gcloud compute firewall-rules update "$FIREWALL_NAME" \
        --source-ranges="$PUBLIC_IP/32" \
        --project="$PROJECT_ID" \
        --description="SSH access restricted to $PUBLIC_IP - Updated $timestamp" \
        --quiet

    print_success "SSH access now restricted to: $PUBLIC_IP/32"
}

# Verify the change
verify_firewall() {
    print_info "Verifying firewall configuration..."

    local current_ranges
    current_ranges=$(gcloud compute firewall-rules describe "$FIREWALL_NAME" \
        --project="$PROJECT_ID" \
        --format="value(sourceRanges)")

    if [[ "$current_ranges" == *"$PUBLIC_IP/32"* ]]; then
        print_success "Firewall successfully updated"
    else
        print_error "Firewall update verification failed"
        print_info "Current source ranges: $current_ranges"
        exit 1
    fi
}

# Main execution
main() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}🔒 Secure SSH Access - Single IP Authorization${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo

    validate_gcloud
    get_public_ip
    check_firewall
    update_firewall
    verify_firewall

    echo
    print_success "SSH access security updated successfully!"
    echo
    print_warning "WARNING: Only IP $PUBLIC_IP can now access SSH"
    print_warning "If your IP changes (travel, network change), re-run this script"
    echo
    print_info "To check current rules: gcloud compute firewall-rules describe $FIREWALL_NAME --project=$PROJECT_ID"
    print_info "To test SSH access: gcloud compute ssh edgequake-db-vm --zone=us-central1-a -- 'echo \"SSH working\"'"
}

# Run main function
main "$@"
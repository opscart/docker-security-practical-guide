#!/bin/bash

# CAP Privileged Production Audit Script
# Scans Docker containers for --privileged mode

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_found() {
    echo -e "${RED}🚨 FOUND:${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠️  WARNING:${NC} $1"
}

print_ok() {
    echo -e "${GREEN}✅ OK:${NC} $1"
}

# Check prerequisites
if ! docker ps &>/dev/null; then
    echo -e "${RED}Error: Docker is not running or not accessible${NC}"
    echo "Please ensure:"
    echo "  1. Docker is installed"
    echo "  2. Docker daemon is running"
    echo "  3. User has Docker permissions"
    exit 1
fi

if ! command -v jq &>/dev/null; then
    echo -e "${RED}Error: jq is not installed (required for JSON report)${NC}"
    echo "Install with:"
    echo "  macOS:          brew install jq"
    echo "  Ubuntu/Debian:  sudo apt install jq"
    echo "  CentOS/RHEL:    sudo yum install jq"
    exit 1
fi

print_header "Privileged Container Audit (Docker)"
echo "Scanning Docker host: $(hostname)"
echo "Timestamp: $(date)"
echo

# Initialize counters
TOTAL=0
PRIVILEGED_CONTAINERS=0
NEAR_PRIVILEGED=0

echo "Scanning all running containers..."
echo

while read container_id; do
    TOTAL=$((TOTAL + 1))

    CONTAINER_NAME=$(docker inspect --format='{{.Name}}' "$container_id" 2>/dev/null | sed 's|/||')
    CONTAINER_IMAGE=$(docker inspect --format='{{.Config.Image}}' "$container_id" 2>/dev/null)
    PRIVILEGED=$(docker inspect --format='{{.HostConfig.Privileged}}' "$container_id" 2>/dev/null)
    CAPS=$(docker inspect --format='{{.HostConfig.CapAdd}}' "$container_id" 2>/dev/null)

    if [ "$PRIVILEGED" = "true" ]; then
        print_found "$CONTAINER_NAME - PRIVILEGED MODE"
        echo "  Image: $CONTAINER_IMAGE"
        echo "  Risk: CRITICAL - Full host access"
        echo
        PRIVILEGED_CONTAINERS=$((PRIVILEGED_CONTAINERS + 1))
    elif echo "$CAPS" | grep -qi "SYS_ADMIN"; then
        print_found "$CONTAINER_NAME - Has CAP_SYS_ADMIN (near-privileged)"
        echo "  Image: $CONTAINER_IMAGE"
        echo "  Capabilities: $CAPS"
        echo "  Risk: HIGH - Near-privileged access"
        echo
        NEAR_PRIVILEGED=$((NEAR_PRIVILEGED + 1))
    fi
done < <(docker ps -q)

# Summary
echo
print_header "Audit Summary"
echo
echo "Total containers scanned: $TOTAL"
echo "Privileged containers: $PRIVILEGED_CONTAINERS"
echo "Near-privileged (CAP_SYS_ADMIN): $NEAR_PRIVILEGED"
echo

if [ "$PRIVILEGED_CONTAINERS" -eq 0 ] && [ "$NEAR_PRIVILEGED" -eq 0 ]; then
    print_ok "No privileged or near-privileged containers found"
    echo "Your Docker host follows security best practices!"
else
    TOTAL_DANGEROUS=$((PRIVILEGED_CONTAINERS + NEAR_PRIVILEGED))
    print_warning "Found $TOTAL_DANGEROUS container(s) with dangerous access"
    echo
    echo "Recommended Actions:"
    echo
    echo "  1. Review each container to determine if --privileged is truly necessary"
    echo "     docker inspect <container-name>"
    echo
    echo "  2. Replace --privileged with specific capabilities:"
    echo "     - VPN containers → Use NET_ADMIN only"
    echo "     - Monitoring agents → Use DAC_READ_SEARCH + host-mounted /proc"
    echo "     - Build containers → Use Kaniko or Buildah (rootless)"
    echo
    echo "  3. Recreate containers with secure configuration:"
    echo "     docker run --cap-drop=ALL --cap-add=NET_BIND_SERVICE myapp"
    echo
    echo "  4. Use secure Docker Compose templates:"
    echo "     See: artifacts/docker-compose-secure.yml"
    echo
    echo "  5. Apply Seccomp profiles to block dangerous syscalls:"
    echo "     docker run --security-opt seccomp=./artifacts/seccomp-no-privileged.json myapp"
    echo
fi

# Additional checks
echo
print_header "Additional Security Checks"
echo

echo "Checking Docker daemon configuration..."
if [ -f /etc/docker/daemon.json ]; then
    if grep -q "no-new-privileges" /etc/docker/daemon.json 2>/dev/null; then
        print_ok "Docker daemon has 'no-new-privileges' configured"
    else
        print_warning "Docker daemon missing 'no-new-privileges' setting"
        echo "    Add to /etc/docker/daemon.json: \"no-new-privileges\": true"
    fi

    if grep -q "userns-remap" /etc/docker/daemon.json 2>/dev/null; then
        print_ok "Docker daemon has 'userns-remap' configured"
    else
        print_warning "Docker daemon missing 'userns-remap' setting"
        echo "    Add to /etc/docker/daemon.json: \"userns-remap\": \"default\""
    fi
else
    print_warning "No /etc/docker/daemon.json found"
    echo "    Create one with recommended security settings"
fi

# Export detailed report
REPORT_FILE="/tmp/docker-privileged-audit-$(date +%Y%m%d-%H%M%S).json"
echo
echo "Exporting detailed report to: $REPORT_FILE"

docker ps -q | while read container_id; do
    docker inspect "$container_id"
done | jq '[.[] | {
    name: .Name,
    id: .Id,
    image: .Config.Image,
    created: .Created,
    privileged: .HostConfig.Privileged,
    capabilities: .HostConfig.CapAdd,
    security_opt: .HostConfig.SecurityOpt
}]' > "$REPORT_FILE" 2>/dev/null || echo "[]" > "$REPORT_FILE"

print_ok "Report exported"

echo
echo "Next audit recommended: $(date -d '+30 days' '+%Y-%m-%d' 2>/dev/null || date -v +30d '+%Y-%m-%d' 2>/dev/null || echo 'in 30 days')"
echo
#!/bin/bash

# Scenario 3: CAP_SYS_ADMIN Cleanup Script
# Removes demo containers + generated artifacts
# Preserves only: artifacts/audit-sys-admin.sh (pre-committed)

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Scenario 3: Cleanup${NC}"
echo -e "${BLUE}========================================${NC}"
echo

print_step "Cleaning up demo containers..."

# Cleanup Docker containers created by demo.sh
DEMO_CONTAINERS="sys-admin-escape namespace-escape cgroup-escape audit-test"
for container in $DEMO_CONTAINERS; do
    if docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
        docker rm -f "$container" 2>/dev/null && echo "  Removed: $container" || true
    fi
done

# Cleanup host artifacts from demos
print_step "Removing temporary host artifacts..."
rm -f /tmp/escape-proof.txt /tmp/shadow-stolen /tmp/admission-test.log 2>/dev/null || true

# Cleanup any Docker audit reports
rm -f /tmp/docker-sys-admin-audit-*.json 2>/dev/null || true

# Remove generated artifacts (defense.sh recreates these on next run)
# Keep only audit-sys-admin.sh — pre-committed, not generated
print_step "Removing generated artifacts..."
for file in \
    ./artifacts/docker-compose-secure.yml \
    ./artifacts/seccomp-no-sys-admin.json \
    ./artifacts/docker-no-sys-admin-apparmor \
    ./artifacts/falco-docker-sys-admin-rules.yaml; do
    if [ -f "$file" ]; then
        rm -f "$file" && echo "  Removed: $file"
    fi
done

echo
print_step "Cleanup complete!"
echo
echo -e "${BLUE}Preserved:${NC}  artifacts/audit-sys-admin.sh (pre-committed)"
echo -e "${BLUE}Recreate:${NC}   ./defense.sh"
echo -e "${BLUE}Run demo:${NC}   ./demo.sh"
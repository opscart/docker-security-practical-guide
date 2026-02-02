#!/bin/bash

# Lab 09 - Scenario 2: Cleanup
# Removes demo containers + generated artifacts
# Preserves only: artifacts/audit-privileged.sh (pre-committed)

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() {
    echo -e "${GREEN}[✓]${NC} $1"
}

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Scenario 2: Cleanup${NC}"
echo -e "${BLUE}========================================${NC}"
echo

print_step "Cleaning up demo containers..."

# Containers created by demo.sh
DEMO_CONTAINERS="priv-escape priv-netns priv-cgroup audit-test"
for container in $DEMO_CONTAINERS; do
    if docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
        docker rm -f "$container" 2>/dev/null && echo "  Removed: $container" || true
    fi
done

# Cleanup temporary host artifacts
print_step "Removing temporary host artifacts..."
rm -f /tmp/escape-proof.txt /tmp/payload.sh 2>/dev/null || true
rm -f /tmp/docker-privileged-audit-*.json 2>/dev/null || true

# Remove generated artifacts (defense.sh recreates these on next run)
# Keep only audit-privileged.sh — pre-committed, not generated
print_step "Removing generated artifacts..."
for file in \
    ./artifacts/docker-compose-secure.yml \
    ./artifacts/seccomp-no-privileged.json \
    ./artifacts/docker-no-privileged-apparmor \
    ./artifacts/falco-docker-privileged-rules.yaml; do
    if [ -f "$file" ]; then
        rm -f "$file" && echo "  Removed: $file"
    fi
done

echo
print_step "Cleanup complete!"
echo
echo -e "${BLUE}Preserved:${NC}  artifacts/audit-privileged.sh (pre-committed)"
echo -e "${BLUE}Recreate:${NC}   ./defense.sh"
echo -e "${BLUE}Run demo:${NC}   ./demo.sh"
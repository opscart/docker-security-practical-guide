#!/bin/bash

# Lab 09 - Scenario 5: /proc and /sys Exposure Cleanup Script
# Removes all containers and artifacts created by demo.sh and defense.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_step() {
    echo -e "${GREEN}[STEP]${NC} $1"
}

print_header "Scenario 5: /proc and /sys Exposure — Cleanup"

# Demo containers
DEMO_CONTAINERS=(
    "proc-recon"
    "sys-recon"
    "audit-proc"
    "audit-sys"
    "audit-clean"
)

print_step "Removing demo containers..."
for container in "${DEMO_CONTAINERS[@]}"; do
    if docker ps -a --format '{{.Names}}' | grep -qx "$container" 2>/dev/null; then
        docker rm -f "$container" &>/dev/null
        echo "  Removed: $container"
    fi
done

# Catch any remaining scenario 5 containers
print_step "Checking for any remaining scenario 5 containers..."
docker ps -a --format '{{.Names}}' | grep -E "^(proc-|sys-|audit-)" | while read name; do
    docker rm -f "$name" &>/dev/null
    echo "  Removed: $name"
done

# Generated artifact files
print_step "Cleaning generated artifacts..."
GENERATED_FILES=(
    "artifacts/falco-proc-sys-rules.yaml"
    "artifacts/audit-proc-sys-mounts.sh"
    "artifacts/kyverno-block-proc-sys.yaml"
)

for file in "${GENERATED_FILES[@]}"; do
    if [ -f "$file" ]; then
        rm -f "$file"
        echo "  Removed: $file"
    fi
done

print_header "Cleanup Complete"
echo "All scenario 5 containers and generated artifacts have been removed."
echo
echo "To re-run the demos:"
echo "  ./demo.sh"
echo
echo "To re-implement defenses:"
echo "  ./defense.sh"
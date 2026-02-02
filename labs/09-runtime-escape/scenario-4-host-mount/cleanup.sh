#!/bin/bash

# Lab 09 - Scenario 4: Host Path Mount Cleanup Script
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

print_header "Scenario 4: Host Path Mount — Cleanup"

# Demo containers
DEMO_CONTAINERS=(
    "mount-etc"
    "mount-sock"
    "audit-etc"
    "audit-var"
    "audit-normal"
)

print_step "Removing demo containers..."
for container in "${DEMO_CONTAINERS[@]}"; do
    if docker ps -a --format '{{.Names}}' | grep -qx "$container" 2>/dev/null; then
        docker rm -f "$container" &>/dev/null
        echo "  Removed: $container"
    fi
done

# Also catch any containers we might have missed
print_step "Checking for any remaining scenario 4 containers..."
docker ps -a --format '{{.Names}}' | grep -E "^(mount-|audit-)" | while read name; do
    docker rm -f "$name" &>/dev/null
    echo "  Removed: $name"
done

# Generated artifact files (keep the directory structure, remove generated files)
print_step "Cleaning generated artifacts..."
GENERATED_FILES=(
    "artifacts/falco-host-mount-rules.yaml"
    "artifacts/audit-host-mounts.sh"
    "artifacts/kyverno-block-host-mounts.yaml"
)

for file in "${GENERATED_FILES[@]}"; do
    if [ -f "$file" ]; then
        rm -f "$file"
        echo "  Removed: $file"
    fi
done

print_header "Cleanup Complete"
echo "All scenario 4 containers and generated artifacts have been removed."
echo
echo "To re-run the demos:"
echo "  ./demo.sh"
echo
echo "To re-implement defenses:"
echo "  ./defense.sh"
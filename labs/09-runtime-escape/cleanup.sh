#!/bin/bash

# Lab 09: Docker Runtime Escape - Complete Cleanup
# Removes ALL traces from all scenarios

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}"
cat << "EOF"
╔══════════════════════════════════════════════════════╗
║                                                      ║
║   Lab 09: Docker Runtime Escape - Full Cleanup      ║
║                                                      ║
║   Removing all containers and artifacts             ║
║                                                      ║
╚══════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${YELLOW}⚠️  This will remove ALL containers created during Lab 09${NC}"
read -p "Continue? [y/N]: " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cleanup cancelled"
    exit 0
fi

# Stop and remove all lab containers
echo -e "${GREEN}[+]${NC} Stopping containers..."

declare -a CONTAINERS=(
    "vulnerable-container"
    "escape-container"
    "privileged-container"
    "sysadmin-container"
    "hostmount-container"
    "proc-container"
)

for container in "${CONTAINERS[@]}"; do
    if docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
        docker stop "${container}" 2>/dev/null || true
        docker rm -f "${container}" 2>/dev/null || true
        echo "  - Removed: ${container}"
    fi
done

# Remove any containers with lab label
echo -e "${GREEN}[+]${NC} Removing labeled containers..."
docker ps -a --filter "label=lab=09-runtime-escape" -q | xargs -r docker rm -f 2>/dev/null || true

# Clean up proof files
echo -e "${GREEN}[+]${NC} Removing proof files..."
sudo rm -f /root/PWNED_PROOF.txt 2>/dev/null || true
sudo rm -f /tmp/PWNED_PROOF.txt 2>/dev/null || true
rm -f /tmp/PWNED_PROOF.txt 2>/dev/null || true

# Clean up artifacts (FIXED - preserves directory structure)
echo -e "${GREEN}[+]${NC} Handling artifacts..."
read -p "Remove artifact files (keeps directory structure)? [y/N]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Remove artifact files but preserve directories with .gitkeep
    rm -f scenario-*/artifacts/*.log 2>/dev/null || true
    rm -f scenario-*/artifacts/*.txt 2>/dev/null || true
    rm -f scenario-*/artifacts/*.json 2>/dev/null || true
    
    # Recreate .gitkeep files to preserve directory structure for Git
    touch scenario-1-docker-socket/artifacts/.gitkeep 2>/dev/null || true
    touch artifacts/.gitkeep 2>/dev/null || true
    
    echo "  - Artifact files removed (directories preserved)"
else
    echo "  - Artifacts preserved"
fi

# Verify cleanup
echo -e "${GREEN}[+]${NC} Verifying cleanup..."
remaining=$(docker ps -a --filter "label=lab=09-runtime-escape" --format '{{.Names}}' | wc -l)
if [ "$remaining" -eq 0 ]; then
    echo "  ✅ All lab containers removed"
else
    echo -e "  ${YELLOW}⚠️  Some containers may remain${NC}"
    docker ps -a --filter "label=lab=09-runtime-escape"
fi

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Cleanup Complete!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo ""
echo "Lab 09 environment has been cleaned up."
echo ""
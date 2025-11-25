#!/bin/bash

# Cleanup script for Lab 07: Supply Chain Security with SBOM
# Removes generated files, Docker images, and temporary artifacts

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}       Lab 07 Cleanup${NC}"
echo -e "${BLUE}==================================================${NC}"
echo ""

# Function to safely remove files/directories
safe_remove() {
    if [ -e "$1" ]; then
        rm -rf "$1"
        echo -e "${GREEN}✅ Removed: $1${NC}"
    fi
}

# Function to remove Docker images
remove_image() {
    if docker image inspect "$1" &> /dev/null; then
        docker rmi "$1" 2>/dev/null || docker rmi -f "$1"
        echo -e "${GREEN}✅ Removed image: $1${NC}"
    fi
}

# Clean up generated SBOM files
echo -e "${YELLOW}Cleaning up SBOM files...${NC}"
safe_remove "output/"
safe_remove "sbom.json"
safe_remove "sbom.txt"
safe_remove "sbom.spdx.json"
safe_remove "sbom.cyclonedx.json"
safe_remove "*.sig"
safe_remove "*.pem"

# Clean up vulnerability reports
echo ""
echo -e "${YELLOW}Cleaning up vulnerability reports...${NC}"
safe_remove "vulnerability-report.json"
safe_remove "vulnerability-report.txt"
safe_remove "*-scan-results.json"

# Clean up temporary Docker artifacts
echo ""
echo -e "${YELLOW}Cleaning up Docker artifacts...${NC}"
safe_remove "Dockerfile.sample"
safe_remove "package.json"
safe_remove "server.js"

# Remove Docker images
echo ""
echo -e "${YELLOW}Removing Docker images...${NC}"
remove_image "myapp:latest"
remove_image "nginx:latest"
remove_image "nginx:1.24-alpine"
remove_image "nginx:1.25-alpine"

# Clean up installed tools (optional - uncomment if you want to remove)
# echo ""
# echo -e "${YELLOW}Removing installed tools...${NC}"
# if [ -f "./bin/syft" ]; then
#     rm -rf ./bin
#     echo -e "${GREEN}✅ Removed local tool binaries${NC}"
# fi

# Docker system cleanup (optional)
echo ""
read -p "Do you want to run 'docker system prune' to clean up unused Docker resources? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    docker system prune -f
    echo -e "${GREEN}✅ Docker system cleaned${NC}"
fi

echo ""
echo -e "${BLUE}==================================================${NC}"
echo -e "${GREEN}✅ Cleanup complete!${NC}"
echo -e "${BLUE}==================================================${NC}"
echo ""
echo -e "${BLUE}Lab environment has been reset.${NC}"
echo -e "${BLUE}To run the lab again: ./run-demo.sh${NC}"
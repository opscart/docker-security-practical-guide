#!/bin/bash

# Lab 09: Docker Runtime Escape - Setup Script
# Prepares environment for all scenarios

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}"
cat << "EOF"
╔══════════════════════════════════════════════════════╗
║                                                      ║
║   Lab 09: Docker Runtime Escape - Setup             ║
║                                                      ║
║   Preparing environment for attack scenarios        ║
║                                                      ║
╚══════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check prerequisites
echo -e "${GREEN}[+]${NC} Checking prerequisites..."

if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}[!]${NC} Docker is not installed"
    exit 1
fi

if ! docker ps &> /dev/null; then
    echo -e "${YELLOW}[!]${NC} Docker daemon is not running"
    exit 1
fi

echo -e "${GREEN}[+]${NC} Docker is ready"

# Pull required images
echo -e "${GREEN}[+]${NC} Pulling required images..."
docker pull ubuntu:22.04
docker pull alpine:latest

echo -e "${GREEN}[+]${NC} Images ready"

# Create artifacts directories
echo -e "${GREEN}[+]${NC} Creating artifact directories..."
mkdir -p scenario-1-docker-socket/artifacts
mkdir -p scenario-2-privileged/artifacts
mkdir -p scenario-3-sys-admin/artifacts
mkdir -p scenario-4-host-mount/artifacts
mkdir -p scenario-5-proc-sys/artifacts
mkdir -p artifacts

echo -e "${GREEN}[+]${NC} Directories created"

# Make scripts executable
echo -e "${GREEN}[+]${NC} Setting script permissions..."
find . -name "*.sh" -exec chmod +x {} \;

echo -e "${GREEN}[+]${NC} Permissions set"

# Display scenario menu
echo ""
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Setup Complete!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo ""
echo "Available scenarios:"
echo "  1. Docker Socket Escape (scenario-1-docker-socket/)"
echo "  2. Privileged Container Escape (scenario-2-privileged/)"
echo "  3. CAP_SYS_ADMIN Abuse (scenario-3-sys-admin/)"
echo "  4. Host Path Mount Abuse (scenario-4-host-mount/)"
echo "  5. /proc Manipulation (scenario-5-proc-sys/)"
echo ""
echo "To start:"
echo "  cd scenario-1-docker-socket"
echo "  ./exploit.sh          # Automated"
echo "  # OR"
echo "  cat manual-steps.md   # Manual walkthrough"
echo ""
echo -e "${YELLOW}⚠️  Warning: These are real attacks. Use only in test environments!${NC}"
echo ""
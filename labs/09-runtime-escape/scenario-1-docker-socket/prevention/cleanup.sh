#!/bin/bash

# Cleanup script for Scenario 1: Prevention Tests

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Cleaning up prevention tests...${NC}"
echo ""

# Test 1: Socket Proxy
if [ -d "test-1-socket-proxy" ]; then
    echo "Cleaning up Socket Proxy test..."
    cd test-1-socket-proxy
    docker-compose down -v 2>/dev/null || true
    docker rm -f socket-proxy test-app-proxy 2>/dev/null || true
    rm -rf artifacts
    rm -f test-results.txt
    cd ..
    echo -e "${GREEN}✓ Socket Proxy test cleaned${NC}"
fi

# Test 2: Kaniko
if [ -d "test-2-kaniko" ]; then
    echo "Cleaning up Kaniko test..."
    cd test-2-kaniko
    rm -f kaniko-test.tar
    rm -f Dockerfile
    docker rmi kaniko-test:latest 2>/dev/null || true
    rm -rf artifacts
    rm -f test-results.txt
    cd ..
    echo -e "${GREEN}✓ Kaniko test cleaned${NC}"
fi

# Test 3: Rootless
if [ -d "test-3-rootless" ]; then
    echo "Cleaning up Rootless test..."
    cd test-3-rootless
    rm -rf artifacts
    rm -f test-results.txt
    cd ..
    echo -e "${GREEN}✓ Rootless test cleaned${NC}"
fi

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Cleanup Complete!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo ""

#!/bin/bash

# Scenario 1: Prevention Methods Testing
# Tests three different approaches to prevent docker socket escape

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
cat << "EOF"
╔══════════════════════════════════════════════════════╗
║                                                      ║
║   Scenario 1: Prevention Testing                     ║
║                                                      ║
║   Testing three approaches to prevent socket escape  ║
║                                                      ║
╚══════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${YELLOW}This scenario tests prevention methods against the socket escape attack.${NC}"
echo -e "${YELLOW}We'll test three approaches:${NC}"
echo ""
echo -e "  1. ${GREEN}Socket Proxy${NC} - Restricted API access"
echo -e "  2. ${GREEN}Kaniko${NC} - Build without Docker daemon"
echo -e "  3. ${GREEN}Rootless Docker${NC} - Limit blast radius"
echo ""

# Check if we're in the right directory
if [ ! -f "test-1-socket-proxy/docker-compose.yml" ]; then
    echo -e "${RED}Error: Please run this from scenario-6-prevention directory${NC}"
    exit 1
fi

echo -e "${BLUE}[INFO]${NC} Choose which test to run:"
echo ""
echo "  1) Socket Proxy Test (recommended first)"
echo "  2) Kaniko Build Test"
echo "  3) Rootless Docker Test"
echo "  4) Run all tests"
echo ""
read -p "Enter choice [1-4]: " choice

case $choice in
    1)
        echo -e "${GREEN}Running Socket Proxy Test...${NC}"
        cd test-1-socket-proxy
        ./run-test.sh
        ;;
    2)
        echo -e "${GREEN}Running Kaniko Test...${NC}"
        cd test-2-kaniko
        ./run-test.sh
        ;;
    3)
        echo -e "${GREEN}Running Rootless Docker Test...${NC}"
        cd test-3-rootless
        ./run-test.sh
        ;;
    4)
        echo -e "${GREEN}Running all tests...${NC}"
        cd test-1-socket-proxy && ./run-test.sh && cd ..
        cd test-2-kaniko && ./run-test.sh && cd ..
        cd test-3-rootless && ./run-test.sh && cd ..
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Prevention Testing Complete!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo ""
echo "Check the results in each test directory."
echo ""

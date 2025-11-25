#!/bin/bash

# Lab 08: Network Security - Cleanup Script
# Removes all containers, networks, and generated files

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Lab 08: Network Security - Cleanup${NC}"
echo -e "${BLUE}================================================${NC}\n"

# Stop and remove containers
echo -e "${YELLOW}Stopping and removing containers...${NC}"
docker rm -f \
    web-frontend web-backend \
    api-frontend api-backend \
    web api app db \
    nginx-tls nginx-basic \
    insecure-web insecure-api insecure-db \
    2>/dev/null || true

echo -e "${GREEN}✓ Containers removed${NC}"

# Remove networks
echo -e "${YELLOW}Removing networks...${NC}"
docker network rm \
    frontend-net backend-net database-net \
    secure-db-net internal-net \
    public-net app-net \
    insecure-net \
    2>/dev/null || true

echo -e "${GREEN}✓ Networks removed${NC}"

# Remove generated certificates
echo -e "${YELLOW}Removing generated certificates...${NC}"
rm -f certs/*.pem certs/*.key certs/*.crt certs/*.srl 2>/dev/null || true
echo -e "${GREEN}✓ Certificates removed${NC}"

# Remove built images
echo -e "${YELLOW}Removing built images...${NC}"
docker rmi -f \
    lab08-api:latest \
    lab08-web:latest \
    2>/dev/null || true

echo -e "${GREEN}✓ Images removed${NC}"

# Remove Docker Compose resources
if [ -f "docker-compose.yml" ]; then
    echo -e "${YELLOW}Removing Docker Compose resources...${NC}"
    docker-compose down -v 2>/dev/null || true
    echo -e "${GREEN}✓ Docker Compose resources removed${NC}"
fi

echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}Cleanup Complete!${NC}"
echo -e "${GREEN}================================================${NC}\n"

echo -e "${BLUE}All lab resources have been removed.${NC}"
echo -e "${BLUE}You can now re-run any scenario with a clean slate.${NC}\n"
#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Lab 10 - Scenario 1: Anti-Patterns${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo "This demo shows 5 ways secrets LEAK in Docker containers."
echo "Each example demonstrates a common mistake."
echo ""

# Anti-Pattern 1: Hardcoded secrets in Dockerfile
echo -e "${YELLOW}[1/5] Anti-Pattern: Hardcoded Secrets in Dockerfile${NC}"
echo "Building image with hardcoded database password..."
echo ""

cd examples/1-hardcoded-dockerfile
docker build -t lab10-hardcoded:latest . 2>&1 | tail -5
echo ""

echo -e "${RED}LEAKED:${NC} Checking docker history for secrets..."
docker history lab10-hardcoded:latest | grep -i "DB_PASSWORD" || echo "Secret found in layer history!"
echo ""

echo "Press ENTER to continue..."
read

# Anti-Pattern 2: Environment variables
echo -e "${YELLOW}[2/5] Anti-Pattern: Secrets in Environment Variables${NC}"
echo "Starting container with secrets as ENV vars..."
echo ""

cd ../2-env-vars
docker compose up -d
sleep 2
echo ""

echo -e "${RED}LEAKED:${NC} Checking docker inspect for secrets..."
docker inspect lab10-envvars | jq '.[].Config.Env' | grep -E "PASSWORD|API_KEY"
echo ""

echo "Press ENTER to continue..."
read

# Anti-Pattern 3: Build arguments
echo -e "${YELLOW}[3/5] Anti-Pattern: Secrets Passed as Build Arguments${NC}"
echo "Building image with secret passed as ARG..."
echo ""

cd ../3-build-args
docker build --build-arg SECRET_TOKEN=ghp_1234567890abcdefghij -t lab10-buildargs:latest . 2>&1 | tail -5
echo ""

echo -e "${RED}LEAKED:${NC} Checking docker history for ARG values..."
docker history lab10-buildargs:latest | grep -i "ARG SECRET" || echo "Secret found in build args!"
echo ""

echo "Press ENTER to continue..."
read

# Anti-Pattern 4: Mounted files with wrong permissions
echo -e "${YELLOW}[4/5] Anti-Pattern: Mounted Secret Files (World-Readable)${NC}"
echo "Starting container with mounted secret file..."
echo ""

cd ../4-volume-files
echo "sk-prod-9876543210fedcba" > secrets/api_key.txt
chmod 644 secrets/api_key.txt  # Wrong permissions!
docker compose up -d
sleep 2
echo ""

echo -e "${RED}LEAKED:${NC} Reading secret from mounted volume..."
docker exec lab10-volumes cat /run/secrets/api_key.txt
echo ""

echo "File permissions (world-readable):"
ls -la secrets/api_key.txt
echo ""

echo "Press ENTER to continue..."
read

# Anti-Pattern 5: Secrets in git history
echo -e "${YELLOW}[5/5] Anti-Pattern: Secrets Committed to Git${NC}"
echo "Demonstrating secrets leaked through git history..."
echo ""

cd ../5-git-history
if [ ! -d .git ]; then
    git init
    echo "API_SECRET=super_secret_key_123" > leaked_secret.txt
    git add leaked_secret.txt
    git commit -m "Add API credentials for testing"
    
    # Developer "fixes" the mistake
    rm leaked_secret.txt
    git add leaked_secret.txt
    git commit -m "Remove sensitive file"
fi
echo ""

echo -e "${RED}LEAKED:${NC} Secret still visible in git history even after deletion..."
git log --all --full-history --oneline -- leaked_secret.txt
echo ""
echo "Content from old commit:"
git show HEAD~1:leaked_secret.txt
echo ""

# Summary
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Summary: All 5 Anti-Patterns Demonstrated${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "${RED}1. Hardcoded Dockerfile:${NC} Secrets in image layers (docker history)"
echo -e "${RED}2. Environment Variables:${NC} Secrets in docker inspect"
echo -e "${RED}3. Build Arguments:${NC} Secrets in docker history"
echo -e "${RED}4. Mounted Files:${NC} Secrets visible with wrong permissions"
echo -e "${RED}5. Git History:${NC} Secrets permanent even after deletion"
echo ""
echo -e "${YELLOW}Next:${NC} See Scenario 2 for the CORRECT way to handle secrets."
echo ""
echo "Run ./cleanup.sh to remove all demo artifacts."
#!/bin/bash

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

PASS=0
FAIL=0

echo "Validating Lab 10 - Scenario 1..."
echo ""

# Check 1: Hardcoded image exists
if docker images | grep -q "lab10-hardcoded"; then
    echo -e "${GREEN}✓${NC} Check 1: Hardcoded image exists"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗${NC} Check 1: Hardcoded image not found"
    FAIL=$((FAIL + 1))
fi

# Check 2: Secret visible in docker history
if docker history lab10-hardcoded:latest 2>/dev/null | grep -q "DB_PASSWORD"; then
    echo -e "${GREEN}✓${NC} Check 2: Secret visible in docker history"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗${NC} Check 2: Secret not found in docker history"
    FAIL=$((FAIL + 1))
fi

# Check 3: Env var container running
if docker ps | grep -q "lab10-envvars-app"; then
    echo -e "${GREEN}✓${NC} Check 3: Env var container running"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗${NC} Check 3: Env var container not running"
    FAIL=$((FAIL + 1))
fi

# Check 4: Secret visible in docker inspect
if docker inspect lab10-envvars-app-1 2>/dev/null | grep -q "DATABASE_PASSWORD"; then
    echo -e "${GREEN}✓${NC} Check 4: Secret visible in docker inspect"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗${NC} Check 4: Secret not found in docker inspect"
    FAIL=$((FAIL + 1))
fi

# Check 5: Mounted secret file exists
if [ -f examples/4-volume-files/secrets/api_key.txt ]; then
    echo -e "${GREEN}✓${NC} Check 5: Mounted secret file exists"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗${NC} Check 5: Mounted secret file not found"
    FAIL=$((FAIL + 1))
fi

echo ""
echo "Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}"

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}All checks passed!${NC}"
    exit 0
else
    echo -e "${RED}Some checks failed. Run ./demo.sh first.${NC}"
    exit 1
fi
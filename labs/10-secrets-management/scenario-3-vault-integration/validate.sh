#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

PASS=0
FAIL=0

echo "Validating Scenario 3: Vault Integration..."
echo ""

# Check 1: Vault container running
if docker ps | grep -q "vault-dev"; then
    echo -e "${GREEN}✓${NC} Check 1: Vault container running"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗${NC} Check 1: Vault container not running"
    FAIL=$((FAIL + 1))
fi

# Check 2: Vault API accessible
if curl -s http://localhost:8200/v1/sys/health > /dev/null; then
    echo -e "${GREEN}✓${NC} Check 2: Vault API accessible"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗${NC} Check 2: Vault API not accessible"
    FAIL=$((FAIL + 1))
fi

# Check 3: Secrets stored
RESPONSE=$(curl -s -H "X-Vault-Token: myroot" http://localhost:8200/v1/secret/data/db)
if echo "$RESPONSE" | jq -e '.data.data.username' > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Check 3: Database secret stored"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗${NC} Check 3: Database secret not found"
    FAIL=$((FAIL + 1))
fi

# Check 4: App container exists
if docker ps -a | grep -q "vault-demo-app"; then
    echo -e "${GREEN}✓${NC} Check 4: Demo app container exists"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗${NC} Check 4: Demo app container not found"
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
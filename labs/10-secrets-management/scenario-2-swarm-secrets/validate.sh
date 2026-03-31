#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

PASS=0
FAIL=0

echo "Validating Scenario 2: Swarm Secrets..."
echo ""

# Check 1: Swarm active
if docker info | grep -q "Swarm: active"; then
    echo -e "${GREEN}✓${NC} Check 1: Swarm mode active"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗${NC} Check 1: Swarm mode not active"
    FAIL=$((FAIL + 1))
fi

# Check 2: Secrets exist
if docker secret ls | grep -q "db_password"; then
    echo -e "${GREEN}✓${NC} Check 2: db_password secret exists"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗${NC} Check 2: db_password secret not found"
    FAIL=$((FAIL + 1))
fi

# Check 3: Service running
if docker service ls | grep -q "secrets-demo_app"; then
    echo -e "${GREEN}✓${NC} Check 3: Service deployed"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗${NC} Check 3: Service not deployed"
    FAIL=$((FAIL + 1))
fi

# Check 4: Container has secrets
CONTAINER_ID=$(docker ps --filter "name=secrets-demo_app" --format "{{.ID}}" | head -1)
if [ ! -z "$CONTAINER_ID" ]; then
    if docker exec $CONTAINER_ID test -f /run/secrets/db_password; then
        echo -e "${GREEN}✓${NC} Check 4: Secret mounted in container"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}✗${NC} Check 4: Secret not mounted"
        FAIL=$((FAIL + 1))
    fi
else
    echo -e "${RED}✗${NC} Check 4: Container not running"
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
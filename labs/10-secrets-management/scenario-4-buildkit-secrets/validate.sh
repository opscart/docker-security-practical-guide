# File: validate.sh
#!/bin/bash
 
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
 
PASS=0
FAIL=0
 
echo "Validating Scenario 4: BuildKit Secrets..."
echo ""
 
# Check 1: BuildKit available
if docker buildx version > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Check 1: BuildKit available"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗${NC} Check 1: BuildKit not available"
    FAIL=$((FAIL + 1))
fi
 
# Check 2: Basic image exists
if docker images | grep -q "buildkit-basic"; then
    echo -e "${GREEN}✓${NC} Check 2: Basic secret image built"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗${NC} Check 2: Basic secret image not found"
    FAIL=$((FAIL + 1))
fi
 
# Check 3: Secret not in history
if ! docker history buildkit-basic:latest | grep -q "1234567890"; then
    echo -e "${GREEN}✓${NC} Check 3: Secret value not in docker history"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗${NC} Check 3: Secret leaked in docker history"
    FAIL=$((FAIL + 1))
fi
 
# Check 4: Multi-stage image clean
if docker images | grep -q "buildkit-multistage"; then
    echo -e "${GREEN}✓${NC} Check 4: Multi-stage image exists"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗${NC} Check 4: Multi-stage image not found"
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
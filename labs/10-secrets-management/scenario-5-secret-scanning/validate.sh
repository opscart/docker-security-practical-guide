#!/bin/bash
 
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
 
PASS=0
FAIL=0
 
echo "Validating Scenario 5: Secret Scanning..."
echo ""
 
# Check 1: GitLeaks image available
if docker images | grep -q "gitleaks"; then
    echo -e "${GREEN}✓${NC} Check 1: GitLeaks image available"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗${NC} Check 1: GitLeaks image not found"
    FAIL=$((FAIL + 1))
fi
 
# Check 2: Test repo exists
if [ -d examples/1-gitleaks/test-repo ]; then
    echo -e "${GREEN}✓${NC} Check 2: Test repository exists"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗${NC} Check 2: Test repository not found"
    FAIL=$((FAIL + 1))
fi
 
# Check 3: GitLeaks can run
if docker run --rm zricethezav/gitleaks:latest version > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Check 3: GitLeaks executable"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗${NC} Check 3: GitLeaks not working"
    FAIL=$((FAIL + 1))
fi
 
# Check 4: Example configs exist
if [ -f examples/3-ci-cd/github-actions.yml ]; then
    echo -e "${GREEN}✓${NC} Check 4: CI/CD examples exist"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗${NC} Check 4: CI/CD examples missing"
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
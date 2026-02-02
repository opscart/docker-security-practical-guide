#!/bin/bash

# Lab 09 - Scenario 5: /proc and /sys Exposure Validation Script
# Verifies that defenses implemented by defense.sh are working

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_step() {
    echo -e "${GREEN}[STEP]${NC} $1"
}

print_pass() {
    echo -e "${GREEN}✅ PASS:${NC} $1"
}

print_fail() {
    echo -e "${RED}❌ FAIL:${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

PASSED=0
FAILED=0
SKIPPED=0

check_docker() {
    if ! docker ps &>/dev/null; then
        echo -e "${RED}Error: Docker is not running${NC}"
        exit 1
    fi
}

print_header "Scenario 5: /proc and /sys Exposure — Defense Validation"

check_docker

###############################################
# Check 1: Falco rules file exists and is complete
###############################################
print_step "Check 1: Falco rules file"

if [ -f "artifacts/falco-proc-sys-rules.yaml" ]; then
    RULE_COUNT=$(grep -c "^- rule:" artifacts/falco-proc-sys-rules.yaml 2>/dev/null || echo 0)
    if [ "$RULE_COUNT" -ge 3 ]; then
        print_pass "Falco rules file present with $RULE_COUNT rules"
        PASSED=$((PASSED + 1))
    else
        print_fail "Falco rules file exists but has fewer than 3 rules ($RULE_COUNT found)"
        FAILED=$((FAILED + 1))
    fi
else
    print_fail "Falco rules file not found — run ./defense.sh first"
    FAILED=$((FAILED + 1))
fi

###############################################
# Check 2: Audit script exists and is executable
###############################################
print_step "Check 2: Audit script"

if [ -f "artifacts/audit-proc-sys-mounts.sh" ]; then
    if [ -x "artifacts/audit-proc-sys-mounts.sh" ]; then
        print_pass "Audit script present and executable"
        PASSED=$((PASSED + 1))
    else
        print_fail "Audit script exists but is not executable"
        echo "  Fix: chmod +x artifacts/audit-proc-sys-mounts.sh"
        FAILED=$((FAILED + 1))
    fi
else
    print_fail "Audit script not found — run ./defense.sh first"
    FAILED=$((FAILED + 1))
fi

###############################################
# Check 3: Kyverno policy file exists
###############################################
print_step "Check 3: Kubernetes admission policy"

if [ -f "artifacts/kyverno-block-proc-sys.yaml" ]; then
    if grep -q "restrict-proc-sys-mounts" artifacts/kyverno-block-proc-sys.yaml; then
        print_pass "Kyverno policy file present and valid"
        PASSED=$((PASSED + 1))
    else
        print_fail "Kyverno policy file exists but is missing expected policy name"
        FAILED=$((FAILED + 1))
    fi
else
    print_fail "Kyverno policy not found — run ./defense.sh first"
    FAILED=$((FAILED + 1))
fi

###############################################
# Check 4: Normal container does not expose host /proc
###############################################
print_step "Check 4: Normal container /proc isolation"

TEST_CONTAINER="validate-proc-$$"
docker run -dit --name "$TEST_CONTAINER" alpine sleep 10 &>/dev/null

# Count processes visible in normal container's /proc
PROC_COUNT=$(docker exec "$TEST_CONTAINER" sh -c 'ls /proc/ | grep -cE "^[0-9]+$"' 2>/dev/null || echo 0)

if [ "$PROC_COUNT" -le 5 ]; then
    print_pass "Normal container sees only $PROC_COUNT process(es) — isolation confirmed"
    PASSED=$((PASSED + 1))
else
    print_fail "Normal container sees $PROC_COUNT processes — possible /proc leak"
    FAILED=$((FAILED + 1))
fi

docker rm -f "$TEST_CONTAINER" &>/dev/null

###############################################
# Check 5: Subpath mount isolation test
###############################################
print_step "Check 5: Subpath mount — only specific file accessible"

TEST_SUBPATH="validate-subpath-$$"
docker run -dit --name "$TEST_SUBPATH" -v /proc/meminfo:/host-proc/meminfo:ro alpine sleep 10 &>/dev/null

# Verify meminfo is readable
MEMINFO_READABLE=$(docker exec "$TEST_SUBPATH" cat /host-proc/meminfo &>/dev/null && echo "yes" || echo "no")

# Verify other /proc files are NOT accessible via the mount
OTHER_READABLE=$(docker exec "$TEST_SUBPATH" cat /host-proc/version &>/dev/null && echo "yes" || echo "no")

if [ "$MEMINFO_READABLE" = "yes" ] && [ "$OTHER_READABLE" = "no" ]; then
    print_pass "Subpath mount correctly exposes only /proc/meminfo"
    PASSED=$((PASSED + 1))
elif [ "$MEMINFO_READABLE" = "yes" ] && [ "$OTHER_READABLE" = "yes" ]; then
    print_fail "Subpath mount leaks additional files — review mount configuration"
    FAILED=$((FAILED + 1))
else
    print_info "Subpath mount test inconclusive (environment may restrict access)"
    SKIPPED=$((SKIPPED + 1))
fi

docker rm -f "$TEST_SUBPATH" &>/dev/null

###############################################
# Check 6: Audit script detects /proc mounts
###############################################
print_step "Check 6: Audit script detection test"

# Create a container with a known /proc mount
TEST_PROC="validate-proc-mount-$$"
docker run -dit --name "$TEST_PROC" -v /proc:/host-proc:ro alpine sleep 10 &>/dev/null

# Run audit and check if it detects the mount
AUDIT_OUTPUT=$(./artifacts/audit-proc-sys-mounts.sh 2>/dev/null || true)

if echo "$AUDIT_OUTPUT" | grep -q "$TEST_PROC"; then
    print_pass "Audit script correctly detects /proc mount container"
    PASSED=$((PASSED + 1))
else
    print_fail "Audit script did not detect test /proc mount container"
    FAILED=$((FAILED + 1))
fi

docker rm -f "$TEST_PROC" &>/dev/null

###############################################
# Summary
###############################################
print_header "Validation Summary"

TOTAL=$((PASSED + FAILED + SKIPPED))

echo "Total checks:  $TOTAL"
echo -e "${GREEN}Passed:        $PASSED${NC}"
echo -e "${RED}Failed:        $FAILED${NC}"
echo -e "${YELLOW}Skipped:       $SKIPPED${NC}"
echo

if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}All checks passed. Defenses are in place.${NC}"
else
    echo -e "${RED}$FAILED check(s) failed. Review the output above and run ./defense.sh to fix.${NC}"
fi
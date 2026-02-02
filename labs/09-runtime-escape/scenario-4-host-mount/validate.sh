#!/bin/bash

# Lab 09 - Scenario 4: Host Path Mount Validation Script
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

print_header "Scenario 4: Host Path Mount — Defense Validation"

check_docker

###############################################
# Check 1: Falco rules file exists
###############################################
print_step "Check 1: Falco rules file"

if [ -f "artifacts/falco-host-mount-rules.yaml" ]; then
    # Verify it has the expected rules
    RULE_COUNT=$(grep -c "^- rule:" artifacts/falco-host-mount-rules.yaml 2>/dev/null || echo 0)
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

if [ -f "artifacts/audit-host-mounts.sh" ]; then
    if [ -x "artifacts/audit-host-mounts.sh" ]; then
        print_pass "Audit script present and executable"
        PASSED=$((PASSED + 1))
    else
        print_fail "Audit script exists but is not executable"
        echo "  Fix: chmod +x artifacts/audit-host-mounts.sh"
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

if [ -f "artifacts/kyverno-block-host-mounts.yaml" ]; then
    if grep -q "restrict-host-path-mounts" artifacts/kyverno-block-host-mounts.yaml; then
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
# Check 4: Docker daemon configuration
###############################################
print_step "Check 4: Docker daemon hardening"

DAEMON_CONFIG="/etc/docker/daemon.json"
if [ -f "$DAEMON_CONFIG" ]; then
    NO_NEW_PRIV=$(grep -c "no-new-privileges" "$DAEMON_CONFIG" 2>/dev/null || echo 0)
    USERNS=$(grep -c "userns-remap" "$DAEMON_CONFIG" 2>/dev/null || echo 0)

    if [ "$NO_NEW_PRIV" -gt 0 ] && [ "$USERNS" -gt 0 ]; then
        print_pass "Daemon config has no-new-privileges and userns-remap"
        PASSED=$((PASSED + 1))
    else
        print_info "Daemon config exists but may be missing recommended settings"
        [ "$NO_NEW_PRIV" -eq 0 ] && echo "  Missing: no-new-privileges"
        [ "$USERNS" -eq 0 ] && echo "  Missing: userns-remap"
        SKIPPED=$((SKIPPED + 1))
    fi
else
    print_info "No /etc/docker/daemon.json (expected on Docker Desktop)"
    print_info "On a Linux host, apply the daemon config from defense.sh output"
    SKIPPED=$((SKIPPED + 1))
fi

###############################################
# Check 5: Functional test — clean container starts without bind mounts
###############################################
print_step "Check 5: Functional test — container without bind mounts"

TEST_CONTAINER="validate-no-bind-$$"
docker run -dit --name "$TEST_CONTAINER" alpine sleep 10 &>/dev/null

MOUNT_COUNT=$(docker inspect --format='{{len .Mounts}}' "$TEST_CONTAINER" 2>/dev/null)
if [ "$MOUNT_COUNT" -eq 0 ]; then
    print_pass "Container starts cleanly with no bind mounts"
    PASSED=$((PASSED + 1))
else
    print_info "Container has $MOUNT_COUNT mount(s) — verifying none are bind mounts"
    BIND_COUNT=$(docker inspect --format='{{json .Mounts}}' "$TEST_CONTAINER" | grep -c '"Type":"bind"' || echo 0)
    if [ "$BIND_COUNT" -eq 0 ]; then
        print_pass "No bind mounts present (other mount types are acceptable)"
        PASSED=$((PASSED + 1))
    else
        print_fail "Unexpected bind mounts in clean container"
        FAILED=$((FAILED + 1))
    fi
fi
docker rm -f "$TEST_CONTAINER" &>/dev/null

###############################################
# Check 6: Audit script detects bind mounts correctly
###############################################
print_step "Check 6: Audit script detection test"

# Create a container with a known high-risk bind mount
TEST_BIND="validate-bind-$$"
docker run -dit --name "$TEST_BIND" -v /etc:/host-etc alpine sleep 10 &>/dev/null

# Run audit and check if it detects the mount
AUDIT_OUTPUT=$(./artifacts/audit-host-mounts.sh 2>/dev/null || true)

if echo "$AUDIT_OUTPUT" | grep -q "$TEST_BIND"; then
    print_pass "Audit script correctly detects bind mount container"
    PASSED=$((PASSED + 1))
else
    print_fail "Audit script did not detect test bind mount container"
    FAILED=$((FAILED + 1))
fi

docker rm -f "$TEST_BIND" &>/dev/null

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
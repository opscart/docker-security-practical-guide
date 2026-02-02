#!/bin/bash

# Scenario 3: CAP_SYS_ADMIN Defense Validation
# Validates that all defenses are working correctly

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
SKIP=0
ARTIFACTS_DIR="./artifacts"

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    PASS=$((PASS + 1))
}

fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    FAIL=$((FAIL + 1))
}

skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
    SKIP=$((SKIP + 1))
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"

    if ! docker ps &>/dev/null; then
        echo -e "${RED}Docker is not running. Cannot proceed.${NC}"
        exit 1
    fi
    pass "Docker is available"

    # Check artifacts exist
    for file in \
        "$ARTIFACTS_DIR/audit-sys-admin.sh" \
        "$ARTIFACTS_DIR/docker-compose-secure.yml" \
        "$ARTIFACTS_DIR/seccomp-no-sys-admin.json" \
        "$ARTIFACTS_DIR/docker-no-sys-admin-apparmor" \
        "$ARTIFACTS_DIR/falco-docker-sys-admin-rules.yaml"; do
        if [ -f "$file" ]; then
            pass "Found: $file"
        else
            fail "Missing: $file"
        fi
    done
}

# Test 1: Seccomp blocks mount syscall
test_seccomp() {
    print_header "Test 1: Seccomp Profile Blocks mount Syscall"

    if [ ! -f "$ARTIFACTS_DIR/seccomp-no-sys-admin.json" ]; then
        skip "Seccomp profile not found"
        return
    fi

    # Validate JSON is well-formed
    if ! jq . "$ARTIFACTS_DIR/seccomp-no-sys-admin.json" &>/dev/null; then
        fail "seccomp-no-sys-admin.json is not valid JSON"
        return
    fi
    pass "seccomp-no-sys-admin.json is valid JSON"

    # Run container with SYS_ADMIN + seccomp, try mount
    OUTPUT=$(docker run --rm \
        --cap-add=SYS_ADMIN \
        --security-opt "seccomp=$ARTIFACTS_DIR/seccomp-no-sys-admin.json" \
        alpine mount 2>&1)
    EXIT_CODE=$?

    if [ $EXIT_CODE -ne 0 ]; then
        pass "Mount blocked by seccomp profile"
    else
        # Docker Desktop (Mac/Windows) does not fully enforce seccomp
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo -e "  ${YELLOW}Note: Docker Desktop on Mac does not fully enforce seccomp${NC}"
            echo "  Seccomp will block mount on Linux production environments"
            skip "Seccomp enforcement (requires Linux Docker host)"
        else
            fail "Mount succeeded - seccomp did not block it"
        fi
    fi
}

# Test 2: Secure container runs successfully
test_secure_container() {
    print_header "Test 2: Secure Container Configuration"

    OUTPUT=$(docker run --rm \
        --cap-drop=ALL \
        --cap-add=NET_BIND_SERVICE \
        --security-opt no-new-privileges=true \
        --read-only \
        --user 1000:1000 \
        alpine echo "secure container works" 2>&1)

    if echo "$OUTPUT" | grep -q "secure container works"; then
        pass "Secure container runs correctly"
    else
        fail "Secure container failed: $OUTPUT"
    fi
}

# Test 3: Docker Compose file is valid
test_docker_compose() {
    print_header "Test 3: Docker Compose Template Validation"

    if [ ! -f "$ARTIFACTS_DIR/docker-compose-secure.yml" ]; then
        skip "docker-compose-secure.yml not found"
        return
    fi

    # Check cap_drop ALL is present
    if grep -q "cap_drop" "$ARTIFACTS_DIR/docker-compose-secure.yml" && \
       grep -A1 "cap_drop" "$ARTIFACTS_DIR/docker-compose-secure.yml" | grep -q "ALL"; then
        pass "cap_drop: ALL is configured"
    else
        fail "cap_drop: ALL is missing"
    fi

    # Check SYS_ADMIN is NOT in cap_add (ignore comment lines)
    if grep -A5 "cap_add" "$ARTIFACTS_DIR/docker-compose-secure.yml" | grep -v "^.*#" | grep -q "SYS_ADMIN"; then
        fail "SYS_ADMIN found in cap_add"
    else
        pass "SYS_ADMIN is not in cap_add"
    fi

    # Check no-new-privileges is set
    if grep -q "no-new-privileges" "$ARTIFACTS_DIR/docker-compose-secure.yml"; then
        pass "no-new-privileges is configured"
    else
        fail "no-new-privileges is missing"
    fi
}

# Test 4: AppArmor profile is valid
test_apparmor() {
    print_header "Test 4: AppArmor Profile Validation"

    if [ ! -f "$ARTIFACTS_DIR/docker-no-sys-admin-apparmor" ]; then
        skip "AppArmor profile not found"
        return
    fi

    # Check deny mount is present
    if grep -q "deny mount" "$ARTIFACTS_DIR/docker-no-sys-admin-apparmor"; then
        pass "AppArmor denies mount operations"
    else
        fail "AppArmor missing deny mount"
    fi

    # Check deny sys_admin capability
    if grep -q "deny capability sys_admin" "$ARTIFACTS_DIR/docker-no-sys-admin-apparmor"; then
        pass "AppArmor denies capability sys_admin"
    else
        fail "AppArmor missing deny capability sys_admin"
    fi

    # AppArmor can only be loaded on Linux
    if [[ "$OSTYPE" == "linux"* ]]; then
        if apparmor_parser -p "$ARTIFACTS_DIR/docker-no-sys-admin-apparmor" &>/dev/null; then
            pass "AppArmor profile parses successfully"
        else
            fail "AppArmor profile has syntax errors"
        fi
    else
        skip "AppArmor parse check (requires Linux)"
    fi
}

# Test 5: Audit script runs and detects correctly
test_audit() {
    print_header "Test 5: Audit Script"

    if [ ! -f "$ARTIFACTS_DIR/audit-sys-admin.sh" ]; then
        skip "audit-sys-admin.sh not found"
        return
    fi

    chmod +x "$ARTIFACTS_DIR/audit-sys-admin.sh"

    # Create a known SYS_ADMIN container for audit to find
    docker run -dit --name validate-sys-admin-test --cap-add=SYS_ADMIN alpine sleep 60 &>/dev/null

    # Run audit and capture output
    OUTPUT=$("$ARTIFACTS_DIR/audit-sys-admin.sh" 2>&1) || true

    # Should detect the test container
    if echo "$OUTPUT" | grep -q "validate-sys-admin-test"; then
        pass "Audit detected CAP_SYS_ADMIN container"
    else
        fail "Audit missed the CAP_SYS_ADMIN test container"
    fi

    # Cleanup test container
    docker rm -f validate-sys-admin-test &>/dev/null

    # Run again - should show clean (excluding minikube/other privileged)
    OUTPUT=$("$ARTIFACTS_DIR/audit-sys-admin.sh" 2>&1) || true
    if ! echo "$OUTPUT" | grep -q "validate-sys-admin-test"; then
        pass "Audit correctly shows container removed"
    else
        fail "Audit still showing removed container"
    fi
}

# Test 6: Falco rules file is valid YAML
test_falco_rules() {
    print_header "Test 6: Falco Rules Validation"

    if [ ! -f "$ARTIFACTS_DIR/falco-docker-sys-admin-rules.yaml" ]; then
        skip "falco-docker-sys-admin-rules.yaml not found"
        return
    fi

    # Check required rules exist
    REQUIRED_RULES=(
        "Container Mount Operation Detected"
        "Container Namespace Manipulation"
        "Cgroup Release Agent Modification"
        "Container Accessing Host Block Devices"
    )

    for rule in "${REQUIRED_RULES[@]}"; do
        if grep -q "$rule" "$ARTIFACTS_DIR/falco-docker-sys-admin-rules.yaml"; then
            pass "Falco rule found: $rule"
        else
            fail "Falco rule missing: $rule"
        fi
    done

    # Falco can only run on Linux
    if [[ "$OSTYPE" == "linux"* ]]; then
        if command -v falco &>/dev/null; then
            pass "Falco is installed"
        else
            skip "Falco not installed (optional)"
        fi
    else
        skip "Falco runtime check (requires Linux)"
    fi
}

# Final summary
print_summary() {
    print_header "Validation Summary"

    TOTAL=$((PASS + FAIL + SKIP))

    echo "Total tests: $TOTAL"
    echo -e "${GREEN}Passed:  $PASS${NC}"
    echo -e "${RED}Failed:  $FAIL${NC}"
    echo -e "${YELLOW}Skipped: $SKIP${NC}"
    echo

    if [ $FAIL -eq 0 ]; then
        echo -e "${GREEN}All tests passed! Scenario 3 defenses are working correctly.${NC}"
    else
        echo -e "${RED}$FAIL test(s) failed. Review the output above.${NC}"
    fi
    echo
}

# Main
main() {
    clear

    cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║    Lab 09 - Scenario 3: Defense Validation                    ║
║                                                               ║
║  Validates all CAP_SYS_ADMIN defenses are working            ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF

    check_prerequisites
    test_seccomp
    test_secure_container
    test_docker_compose
    test_apparmor
    test_audit
    test_falco_rules
    print_summary

    # Exit with failure code if any test failed
    [ $FAIL -eq 0 ]
}

main "$@"
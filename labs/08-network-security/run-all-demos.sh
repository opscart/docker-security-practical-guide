#!/bin/bash

# Lab 08 - Run All Demos
# Executes all 5 network security scenarios in sequence

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo -e "\n${CYAN}================================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}================================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

print_info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

print_error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

# Banner
clear
echo -e "${CYAN}"
cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║           Lab 08: Docker Network Security                     ║
║              Complete Demonstration Suite                     ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${BLUE}This will run all 5 scenarios:${NC}"
echo ""
echo "1. Network Isolation          (3-4 min)"
echo "2. Multi-Tier Segmentation    (4-5 min)"
echo "3. Internal Networks          (3-4 min)"
echo "4. TLS Encryption             (4-5 min)"
echo "5. Common Misconfigurations   (3-4 min)"
echo ""
echo -e "${YELLOW}Total estimated time: 18-22 minutes${NC}"
echo ""
read -p "Press Enter to start, or Ctrl+C to cancel..."

# Track results
declare -a RESULTS
TOTAL_SCENARIOS=5
PASSED=0
FAILED=0

# Run scenario function
run_scenario() {
    local num=$1
    local name="$2"
    local script="$3"
    
    print_header "Scenario ${num}: ${name}"
    
    if [ ! -f "${SCRIPT_DIR}/${script}" ]; then
        print_error "Script not found: ${script}"
        RESULTS[$num]="FAIL"
        ((FAILED++))
        return 1
    fi
    
    if bash "${SCRIPT_DIR}/${script}"; then
        RESULTS[$num]="PASS"
        ((PASSED++))
        print_success "Scenario ${num} completed successfully"
    else
        RESULTS[$num]="FAIL"
        ((FAILED++))
        print_error "Scenario ${num} failed"
    fi
    
    echo ""
    read -p "Press Enter to continue to next scenario..."
    echo ""
}

# Cleanup before starting
print_info "Cleaning up any existing resources..."
if [ -f "${SCRIPT_DIR}/cleanup.sh" ]; then
    bash "${SCRIPT_DIR}/cleanup.sh" >/dev/null 2>&1 || true
fi

# Run all scenarios
START_TIME=$(date +%s)

run_scenario 1 "Network Isolation" "demo-isolation.sh"
run_scenario 2 "Multi-Tier Segmentation" "demo-segmentation.sh"
run_scenario 3 "Internal Networks" "demo-internal-network.sh"
run_scenario 4 "TLS Encryption" "demo-tls-encryption.sh"
run_scenario 5 "Common Misconfigurations" "demo-misconfigurations.sh"

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

# Final summary
clear
print_header "Lab 08 Complete - Summary"

echo -e "${CYAN}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║           Scenario Results                    ║${NC}"
echo -e "${CYAN}╠═══════════════════════════════════════════════╣${NC}"

for i in {1..5}; do
    if [ "${RESULTS[$i]}" == "PASS" ]; then
        echo -e "${CYAN}║${NC}  Scenario $i: ${GREEN}✓ PASSED${NC}                           ${CYAN}║${NC}"
    else
        echo -e "${CYAN}║${NC}  Scenario $i: ${RED}✗ FAILED${NC}                           ${CYAN}║${NC}"
    fi
done

echo -e "${CYAN}╠═══════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║${NC}  Total: ${PASSED}/${TOTAL_SCENARIOS} passed                             ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  Duration: ${MINUTES}m ${SECONDS}s                              ${CYAN}║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════╝${NC}"

echo ""

if [ $PASSED -eq $TOTAL_SCENARIOS ]; then
    print_success "All scenarios passed! Excellent work! 🎉"
    echo ""
    echo -e "${GREEN}You've mastered Docker network security:${NC}"
    echo "✓ Network isolation and segmentation"
    echo "✓ Internal networks for databases"
    echo "✓ TLS encryption between containers"
    echo "✓ Identifying and fixing misconfigurations"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "- Review the README.md for detailed documentation"
    echo "- Try the Docker Compose examples"
    echo "- Apply these patterns to your own projects"
    echo "- Check out the other labs (01-07, 09)"
    echo ""
elif [ $PASSED -gt 0 ]; then
    print_warning "Some scenarios passed, but there were failures."
    echo ""
    echo "Review the failed scenarios and ensure:"
    echo "- All required files are present"
    echo "- Docker is running properly"
    echo "- Ports are available (8080, 8443, 5000-5002)"
    echo "- No resource constraints"
    echo ""
else
    print_error "All scenarios failed. Please check your setup."
    echo ""
    echo "Common issues:"
    echo "- Docker not running"
    echo "- Missing demo scripts"
    echo "- Port conflicts"
    echo "- Insufficient permissions"
    echo ""
fi

# Final cleanup
print_info "Running final cleanup..."
if [ -f "${SCRIPT_DIR}/cleanup.sh" ]; then
    bash "${SCRIPT_DIR}/cleanup.sh" >/dev/null 2>&1 || true
fi

print_success "Lab 08 demonstration complete!"
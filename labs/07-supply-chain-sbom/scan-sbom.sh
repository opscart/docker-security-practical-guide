#!/bin/bash

# Scan SBOM or Docker image for vulnerabilities using Grype
# Usage: ./scan-sbom.sh <image-or-sbom> [severity]

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if Grype is installed
if ! command -v grype &> /dev/null; then
    echo -e "${YELLOW}Grype is not installed. Installing...${NC}"
    curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin 2>/dev/null || {
        echo "Installing to local bin directory..."
        curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b ./bin
        export PATH="./bin:$PATH"
    }
fi

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <image-or-sbom> [severity]"
    echo ""
    echo "Target types:"
    echo "  Image:     nginx:latest"
    echo "  SBOM file: output/nginx-sbom.json"
    echo "            (prefix with 'sbom:' like: sbom:output/nginx-sbom.json)"
    echo ""
    echo "Severity levels (optional):"
    echo "  negligible, low, medium, high, critical"
    echo "  Example: $0 nginx:latest high (fails on high or above)"
    echo ""
    echo "Examples:"
    echo "  $0 nginx:latest"
    echo "  $0 sbom:output/nginx-sbom.json"
    echo "  $0 nginx:latest critical"
    exit 1
fi

TARGET=$1
SEVERITY=${2:-none}

# Determine if target is an SBOM file or image
if [[ "$TARGET" == *.json ]] && [ -f "$TARGET" ]; then
    # It's a local SBOM file, add sbom: prefix if not present
    if [[ ! "$TARGET" == sbom:* ]]; then
        TARGET="sbom:$TARGET"
    fi
    echo -e "${BLUE}Scanning SBOM file for vulnerabilities...${NC}"
elif [[ "$TARGET" == sbom:* ]]; then
    echo -e "${BLUE}Scanning SBOM file for vulnerabilities...${NC}"
else
    echo -e "${BLUE}Scanning Docker image for vulnerabilities...${NC}"
    # Check if image exists locally
    if ! docker image inspect "$TARGET" &> /dev/null; then
        echo -e "${YELLOW}Image not found locally. Pulling...${NC}"
        docker pull "$TARGET"
    fi
fi

echo -e "${BLUE}Target: ${TARGET}${NC}"
if [ "$SEVERITY" != "none" ]; then
    echo -e "${BLUE}Fail-on severity: ${SEVERITY}${NC}"
fi
echo ""

# Create output directory
mkdir -p output

# Generate output filename
OUTPUT_BASE=$(echo "$TARGET" | sed 's/sbom://g' | sed 's/:/-/g' | sed 's/\//-/g' | sed 's/.json//g')
SCAN_OUTPUT="output/${OUTPUT_BASE}-scan-results.json"

# Run Grype scan
echo -e "${YELLOW}Running vulnerability scan (this may take a minute)...${NC}"
echo ""

SCAN_CMD="grype \"$TARGET\" -o table"

if [ "$SEVERITY" != "none" ]; then
    SCAN_CMD="$SCAN_CMD --fail-on $SEVERITY"
fi

# Run scan and capture exit code
set +e
eval $SCAN_CMD
SCAN_EXIT_CODE=$?
set -e

echo ""

# Generate JSON report
echo -e "${BLUE}Generating detailed report...${NC}"
grype "$TARGET" -o json > "$SCAN_OUTPUT" 2>/dev/null

echo -e "${GREEN}Scan complete!${NC}"
echo -e "${BLUE}Detailed report saved to: ${SCAN_OUTPUT}${NC}"

# Parse and display summary if jq is available
if command -v jq &> /dev/null; then
    echo ""
    echo -e "${BLUE}=== Vulnerability Summary ===${NC}"
    
    CRITICAL=$(jq '[.matches[] | select(.vulnerability.severity == "Critical")] | length' "$SCAN_OUTPUT" 2>/dev/null || echo "0")
    HIGH=$(jq '[.matches[] | select(.vulnerability.severity == "High")] | length' "$SCAN_OUTPUT" 2>/dev/null || echo "0")
    MEDIUM=$(jq '[.matches[] | select(.vulnerability.severity == "Medium")] | length' "$SCAN_OUTPUT" 2>/dev/null || echo "0")
    LOW=$(jq '[.matches[] | select(.vulnerability.severity == "Low")] | length' "$SCAN_OUTPUT" 2>/dev/null || echo "0")
    NEGLIGIBLE=$(jq '[.matches[] | select(.vulnerability.severity == "Negligible")] | length' "$SCAN_OUTPUT" 2>/dev/null || echo "0")
    TOTAL=$(jq '.matches | length' "$SCAN_OUTPUT" 2>/dev/null || echo "0")
    
    echo -e "  ${RED}Critical:   $CRITICAL${NC}"
    echo -e "  ${RED}High:       $HIGH${NC}"
    echo -e "  ${YELLOW}Medium:     $MEDIUM${NC}"
    echo -e "  ${BLUE}Low:        $LOW${NC}"
    echo -e "  Negligible: $NEGLIGIBLE"
    echo -e "  ${BLUE}────────────────${NC}"
    echo -e "  Total:      $TOTAL"
    
    # Show top 5 vulnerabilities
    if [ "$TOTAL" -gt 0 ]; then
        echo ""
        echo -e "${BLUE}=== Top 5 Critical/High Vulnerabilities ===${NC}"
        jq -r '.matches[] | select(.vulnerability.severity == "Critical" or .vulnerability.severity == "High") | 
               "\(.artifact.name) (\(.artifact.version)): \(.vulnerability.id) - \(.vulnerability.severity)"' \
               "$SCAN_OUTPUT" 2>/dev/null | head -5 | nl -w2 -s'. '
    fi
    
    # Check for fixable vulnerabilities
    FIXABLE=$(jq '[.matches[] | select(.vulnerability.fix.state == "fixed")] | length' "$SCAN_OUTPUT" 2>/dev/null || echo "0")
    if [ "$FIXABLE" -gt 0 ]; then
        echo ""
        echo -e "${GREEN}$FIXABLE vulnerabilities have fixes available${NC}"
        echo "   Consider updating base image or dependencies"
    fi
fi

echo ""
echo -e "${BLUE}View detailed report:${NC}"
echo "  cat $SCAN_OUTPUT | jq"

# Exit with scan exit code
if [ $SCAN_EXIT_CODE -ne 0 ]; then
    echo ""
    if [ "$SEVERITY" != "none" ]; then
        echo -e "${RED}Scan failed: Vulnerabilities at or above '$SEVERITY' severity found${NC}"
    else
        echo -e "${YELLOW}Vulnerabilities found but scan passed (no severity threshold set)${NC}"
    fi
    exit $SCAN_EXIT_CODE
else
    echo ""
    echo -e "${GREEN}Scan passed: No vulnerabilities above threshold${NC}"
    exit 0
fi
#!/bin/bash

# Compare two SBOMs to identify changes
# Usage: ./compare-sboms.sh <sbom1.json> <sbom2.json>

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check arguments
if [ $# -ne 2 ]; then
    echo "Usage: $0 <sbom1.json> <sbom2.json>"
    echo ""
    echo "Compare two SBOM files to identify:"
    echo "  - New packages added"
    echo "  - Packages removed"
    echo "  - Package version changes"
    echo "  - New vulnerabilities introduced"
    echo ""
    echo "Example:"
    echo "  $0 output/nginx-1.24-sbom.json output/nginx-1.25-sbom.json"
    exit 1
fi

SBOM1=$1
SBOM2=$2

# Check if files exist
if [ ! -f "$SBOM1" ]; then
    echo -e "${RED}Error: File not found: $SBOM1${NC}"
    exit 1
fi

if [ ! -f "$SBOM2" ]; then
    echo -e "${RED}Error: File not found: $SBOM2${NC}"
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is required for SBOM comparison${NC}"
    echo "Install with: brew install jq (macOS) or apt-get install jq (Linux)"
    exit 1
fi

echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}       SBOM Comparison Report${NC}"
echo -e "${BLUE}==================================================${NC}"
echo ""
echo -e "${BLUE}Comparing:${NC}"
echo "  SBOM 1: $SBOM1"
echo "  SBOM 2: $SBOM2"
echo ""

# Create temporary files for package lists
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

# Extract package information (handle both Syft and SPDX formats)
extract_packages() {
    local sbom=$1
    local output=$2
    
    # Try Syft format first
    if jq -e '.artifacts' "$sbom" > /dev/null 2>&1; then
        jq -r '.artifacts[] | "\(.name)|\(.version)|\(.type)"' "$sbom" | sort > "$output"
    # Try SPDX format
    elif jq -e '.packages' "$sbom" > /dev/null 2>&1; then
        jq -r '.packages[] | "\(.name)|\(.versionInfo)|\(.downloadLocation)"' "$sbom" | sort > "$output"
    # Try CycloneDX format
    elif jq -e '.components' "$sbom" > /dev/null 2>&1; then
        jq -r '.components[] | "\(.name)|\(.version)|\(.type)"' "$sbom" | sort > "$output"
    else
        echo -e "${RED}Error: Unrecognized SBOM format${NC}"
        exit 1
    fi
}

extract_packages "$SBOM1" "$TMP_DIR/packages1.txt"
extract_packages "$SBOM2" "$TMP_DIR/packages2.txt"

# Extract just package names for comparison
cut -d'|' -f1 "$TMP_DIR/packages1.txt" | sort -u > "$TMP_DIR/names1.txt"
cut -d'|' -f1 "$TMP_DIR/packages2.txt" | sort -u > "$TMP_DIR/names2.txt"

# Find added, removed, and common packages
comm -13 "$TMP_DIR/names1.txt" "$TMP_DIR/names2.txt" > "$TMP_DIR/added.txt"
comm -23 "$TMP_DIR/names1.txt" "$TMP_DIR/names2.txt" > "$TMP_DIR/removed.txt"
comm -12 "$TMP_DIR/names1.txt" "$TMP_DIR/names2.txt" > "$TMP_DIR/common.txt"

# Count statistics
ADDED_COUNT=$(wc -l < "$TMP_DIR/added.txt" | tr -d ' ')
REMOVED_COUNT=$(wc -l < "$TMP_DIR/removed.txt" | tr -d ' ')
COMMON_COUNT=$(wc -l < "$TMP_DIR/common.txt" | tr -d ' ')
TOTAL1=$(wc -l < "$TMP_DIR/names1.txt" | tr -d ' ')
TOTAL2=$(wc -l < "$TMP_DIR/names2.txt" | tr -d ' ')

# Display summary
echo -e "${BLUE}=== Package Count Summary ===${NC}"
echo "  SBOM 1 total packages: $TOTAL1"
echo "  SBOM 2 total packages: $TOTAL2"
echo ""
echo -e "  ${GREEN}Packages added:   $ADDED_COUNT${NC}"
echo -e "  ${RED}Packages removed: $REMOVED_COUNT${NC}"
echo -e "  ${BLUE}Packages common:  $COMMON_COUNT${NC}"
echo ""

# Show added packages
if [ "$ADDED_COUNT" -gt 0 ]; then
    echo -e "${GREEN}=== Packages Added ===${NC}"
    while IFS= read -r pkg; do
        # Get version from SBOM2
        version=$(grep "^$pkg|" "$TMP_DIR/packages2.txt" | cut -d'|' -f2)
        echo -e "  ${GREEN}+${NC} $pkg ($version)"
    done < "$TMP_DIR/added.txt" | head -10
    
    if [ "$ADDED_COUNT" -gt 10 ]; then
        echo "  ... and $((ADDED_COUNT - 10)) more"
    fi
    echo ""
fi

# Show removed packages
if [ "$REMOVED_COUNT" -gt 0 ]; then
    echo -e "${RED}=== Packages Removed ===${NC}"
    while IFS= read -r pkg; do
        # Get version from SBOM1
        version=$(grep "^$pkg|" "$TMP_DIR/packages1.txt" | cut -d'|' -f2)
        echo -e "  ${RED}-${NC} $pkg ($version)"
    done < "$TMP_DIR/removed.txt" | head -10
    
    if [ "$REMOVED_COUNT" -gt 10 ]; then
        echo "  ... and $((REMOVED_COUNT - 10)) more"
    fi
    echo ""
fi

# Check for version changes in common packages
echo -e "${YELLOW}=== Packages Updated (Version Changes) ===${NC}"
UPDATED_COUNT=0
while IFS= read -r pkg; do
    ver1=$(grep "^$pkg|" "$TMP_DIR/packages1.txt" | cut -d'|' -f2)
    ver2=$(grep "^$pkg|" "$TMP_DIR/packages2.txt" | cut -d'|' -f2)
    
    if [ "$ver1" != "$ver2" ]; then
        echo -e "  ${YELLOW}~${NC} $pkg: $ver1 → $ver2"
        UPDATED_COUNT=$((UPDATED_COUNT + 1))
    fi
done < "$TMP_DIR/common.txt" | head -10

if [ "$UPDATED_COUNT" -eq 0 ]; then
    echo "  No version changes detected"
else
    echo ""
    echo -e "  ${BLUE}Total packages updated: $UPDATED_COUNT${NC}"
fi
echo ""

# Vulnerability comparison (if Grype is available)
if command -v grype &> /dev/null; then
    echo -e "${BLUE}=== Vulnerability Analysis ===${NC}"
    echo "  Running vulnerability scans..."
    
    # Scan both SBOMs
    grype "sbom:$SBOM1" -o json > "$TMP_DIR/vuln1.json" 2>/dev/null || true
    grype "sbom:$SBOM2" -o json > "$TMP_DIR/vuln2.json" 2>/dev/null || true
    
    if [ -f "$TMP_DIR/vuln1.json" ] && [ -f "$TMP_DIR/vuln2.json" ]; then
        VULN1_COUNT=$(jq '.matches | length' "$TMP_DIR/vuln1.json" 2>/dev/null || echo "0")
        VULN2_COUNT=$(jq '.matches | length' "$TMP_DIR/vuln2.json" 2>/dev/null || echo "0")
        
        CRITICAL1=$(jq '[.matches[] | select(.vulnerability.severity == "Critical")] | length' "$TMP_DIR/vuln1.json" 2>/dev/null || echo "0")
        CRITICAL2=$(jq '[.matches[] | select(.vulnerability.severity == "Critical")] | length' "$TMP_DIR/vuln2.json" 2>/dev/null || echo "0")
        
        HIGH1=$(jq '[.matches[] | select(.vulnerability.severity == "High")] | length' "$TMP_DIR/vuln1.json" 2>/dev/null || echo "0")
        HIGH2=$(jq '[.matches[] | select(.vulnerability.severity == "High")] | length' "$TMP_DIR/vuln2.json" 2>/dev/null || echo "0")
        
        echo ""
        echo "  SBOM 1 vulnerabilities: $VULN1_COUNT (Critical: $CRITICAL1, High: $HIGH1)"
        echo "  SBOM 2 vulnerabilities: $VULN2_COUNT (Critical: $CRITICAL2, High: $HIGH2)"
        echo ""
        
        VULN_DIFF=$((VULN2_COUNT - VULN1_COUNT))
        if [ $VULN_DIFF -gt 0 ]; then
            echo -e "  ${RED}⚠️  $VULN_DIFF new vulnerabilities introduced${NC}"
        elif [ $VULN_DIFF -lt 0 ]; then
            echo -e "  ${GREEN}✅ $((VULN_DIFF * -1)) vulnerabilities fixed${NC}"
        else
            echo -e "  ${BLUE}No change in vulnerability count${NC}"
        fi
    else
        echo "  Unable to complete vulnerability analysis"
    fi
else
    echo -e "${YELLOW}Note: Install Grype for vulnerability comparison${NC}"
fi

echo ""
echo -e "${BLUE}==================================================${NC}"
echo -e "${GREEN}Comparison complete!${NC}"
echo ""

# Summary recommendation
if [ "$ADDED_COUNT" -gt 0 ] || [ "$UPDATED_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}📋 Recommendation:${NC}"
    echo "  Review the changes before deploying SBOM 2"
    if [ "$VULN_DIFF" -gt 0 ] 2>/dev/null; then
        echo "  ⚠️  New vulnerabilities detected - review security impact"
    fi
fi
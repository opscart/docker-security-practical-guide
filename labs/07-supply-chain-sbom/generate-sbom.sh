#!/bin/bash

# Generate SBOM for a Docker image in specified format
# Usage: ./generate-sbom.sh <image> [format]
# Formats: table, json, spdx-json, cyclonedx-json, cyclonedx-xml

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if Syft is installed
if ! command -v syft &> /dev/null; then
    echo -e "${YELLOW}Syft is not installed. Installing...${NC}"
    curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin 2>/dev/null || {
        echo "Installing to local bin directory..."
        curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b ./bin
        export PATH="./bin:$PATH"
    }
fi

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <image> [format]"
    echo ""
    echo "Available formats:"
    echo "  table           - Human-readable table (default)"
    echo "  json            - Syft native JSON format"
    echo "  spdx-json       - SPDX 2.3 JSON format (ISO standard)"
    echo "  cyclonedx-json  - CycloneDX JSON format (OWASP standard)"
    echo "  cyclonedx-xml   - CycloneDX XML format"
    echo ""
    echo "Examples:"
    echo "  $0 nginx:latest"
    echo "  $0 nginx:latest spdx-json"
    echo "  $0 myapp:v1.0 cyclonedx-json"
    exit 1
fi

IMAGE=$1
FORMAT=${2:-table}

# Create output directory
mkdir -p output

echo -e "${BLUE}Generating SBOM for: ${IMAGE}${NC}"
echo -e "${BLUE}Format: ${FORMAT}${NC}"
echo ""

# Generate output filename based on format
OUTPUT_FILE=""
if [ "$FORMAT" != "table" ]; then
    # Sanitize image name for filename
    SAFE_NAME=$(echo "$IMAGE" | sed 's/:/-/g' | sed 's/\//-/g')
    
    case $FORMAT in
        json)
            OUTPUT_FILE="output/${SAFE_NAME}-sbom.json"
            ;;
        spdx-json)
            OUTPUT_FILE="output/${SAFE_NAME}-spdx.json"
            ;;
        cyclonedx-json)
            OUTPUT_FILE="output/${SAFE_NAME}-cyclonedx.json"
            ;;
        cyclonedx-xml)
            OUTPUT_FILE="output/${SAFE_NAME}-cyclonedx.xml"
            ;;
        *)
            OUTPUT_FILE="output/${SAFE_NAME}-sbom.${FORMAT}"
            ;;
    esac
fi

# Generate SBOM
if [ "$FORMAT" = "table" ]; then
    # Display to stdout for table format
    syft "$IMAGE" -o table
else
    # Write to file for structured formats
    syft "$IMAGE" -o "$FORMAT" > "$OUTPUT_FILE"
    
    echo -e "${GREEN}✅ SBOM generated successfully!${NC}"
    echo -e "${BLUE}Output file: ${OUTPUT_FILE}${NC}"
    
    # Show file size and basic stats
    FILE_SIZE=$(ls -lh "$OUTPUT_FILE" | awk '{print $5}')
    echo -e "${BLUE}File size: ${FILE_SIZE}${NC}"
    
    # If jq is available, show some stats
    if command -v jq &> /dev/null && [[ "$FORMAT" == *"json"* ]]; then
        echo ""
        echo -e "${BLUE}SBOM Statistics:${NC}"
        
        case $FORMAT in
            json|spdx-json)
                PACKAGE_COUNT=$(jq '.artifacts | length' "$OUTPUT_FILE" 2>/dev/null || echo "N/A")
                echo "  Packages: $PACKAGE_COUNT"
                
                # Show top package types
                if [ "$PACKAGE_COUNT" != "N/A" ]; then
                    echo ""
                    echo "  Package types:"
                    jq -r '.artifacts[].type' "$OUTPUT_FILE" 2>/dev/null | sort | uniq -c | sort -rn | head -5 | awk '{print "    " $2 ": " $1}'
                fi
                ;;
            cyclonedx-json)
                COMPONENT_COUNT=$(jq '.components | length' "$OUTPUT_FILE" 2>/dev/null || echo "N/A")
                echo "  Components: $COMPONENT_COUNT"
                ;;
        esac
    fi
    
    echo ""
    echo -e "${BLUE}View the SBOM:${NC}"
    if [[ "$FORMAT" == *"json"* ]]; then
        echo "  cat $OUTPUT_FILE | jq"
    else
        echo "  cat $OUTPUT_FILE"
    fi
fi

echo ""
echo -e "${GREEN}Done!${NC}"
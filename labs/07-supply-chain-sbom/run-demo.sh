#!/bin/bash

# Lab 07: Supply Chain Security with SBOM - Automated Demo
# This script walks through SBOM generation, scanning, and verification

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check for auto mode
AUTO_MODE=false
if [ "$1" = "--auto" ] || [ "$INTERACTIVE" = "false" ]; then
    AUTO_MODE=true
fi

# Function to print colored output
print_header() {
    echo -e "\n${BLUE}================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

print_error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

print_info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Function to pause for user to read output (only in interactive mode)
pause() {
    if [ "$AUTO_MODE" = false ]; then
        echo ""
        read -p "Press Enter to continue..."
        echo ""
    else
        sleep 1
    fi
}

# Check prerequisites
print_header "Checking Prerequisites"

if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi
print_success "Docker is installed"

# Create output directory
mkdir -p output

print_header "Welcome to Lab 07: Supply Chain Security with SBOM"
cat << EOF
This demo will guide you through:

1. Installing SBOM tools (Syft, Grype)
2. Generating SBOMs in multiple formats
3. Scanning for vulnerabilities
4. Building and scanning a custom application
5. Comparing SBOMs across versions
6. CI/CD integration examples

Starting in 2 seconds...
EOF
sleep 2

# Step 1: Install tools
print_header "Step 1: Installing Syft and Grype"

if ! command -v syft &> /dev/null; then
    print_info "Installing Syft..."
    curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin 2>/dev/null || {
        print_warning "Failed to install to /usr/local/bin, trying local installation..."
        curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b ./bin
        export PATH="./bin:$PATH"
    }
    print_success "Syft installed successfully"
else
    print_success "Syft is already installed"
fi

if ! command -v grype &> /dev/null; then
    print_info "Installing Grype..."
    curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin 2>/dev/null || {
        print_warning "Failed to install to /usr/local/bin, trying local installation..."
        curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b ./bin
        export PATH="./bin:$PATH"
    }
    print_success "Grype installed successfully"
else
    print_success "Grype is already installed"
fi

# Display versions
print_info "Syft version: $(syft version | head -n1)"
print_info "Grype version: $(grype version | head -n1)"
pause

# Step 2: Pull test image
print_header "Step 2: Pulling Test Image (nginx:latest)"
docker pull nginx:latest > /dev/null 2>&1
print_success "Image pulled successfully"
sleep 1

# Step 3: Generate SBOM in table format
print_header "Step 3: Generating SBOM (Table Format)"
print_info "This shows a human-readable list of all packages in the image..."
echo ""

syft nginx:latest -o table | head -n 20
echo ""
print_info "(Showing first 20 packages... full list has 100+ packages)"
sleep 2

# Step 4: Generate SBOM in SPDX JSON format
print_header "Step 4: Generating SBOM (SPDX JSON Format)"
print_info "SPDX is an ISO standard format used for compliance and licensing..."

syft nginx:latest -o spdx-json > output/nginx-spdx.json 2>/dev/null
print_success "SBOM generated: output/nginx-spdx.json"

# Show sample of the JSON
print_info "Sample SBOM data:"
cat output/nginx-spdx.json | jq '.packages[:3] | .[] | {name: .name, versionInfo: .versionInfo}' 2>/dev/null || {
    echo "(Install 'jq' to view formatted JSON: brew install jq)"
}
sleep 2

# Step 5: Generate SBOM in CycloneDX format
print_header "Step 5: Generating SBOM (CycloneDX Format)"
print_info "CycloneDX is an OWASP standard optimized for security use cases..."

syft nginx:latest -o cyclonedx-json > output/nginx-cyclonedx.json 2>/dev/null
print_success "SBOM generated: output/nginx-cyclonedx.json"

print_info "File sizes:"
ls -lh output/nginx-*.json | awk '{print $9, ":", $5}'
sleep 2

# Step 6: Vulnerability scanning
print_header "Step 6: Scanning for Vulnerabilities"
print_info "Grype will check the image against known CVE databases..."
echo ""

# Run Grype and show results
print_info "Running vulnerability scan (this may take a minute)..."
grype nginx:latest --fail-on critical 2>/dev/null || {
    print_warning "Critical vulnerabilities found (this is expected for demo)"
}

pause

# Step 7: Scan using SBOM
print_header "Step 7: Scanning SBOM Directly"
print_info "Instead of scanning the image, we can scan the SBOM file..."
print_info "This is faster and works with air-gapped environments!"
echo ""

grype sbom:./output/nginx-spdx.json -o table 2>/dev/null | head -n 15
echo ""
print_info "(Showing first 15 vulnerabilities...)"
sleep 2

# Step 8: Build sample application
print_header "Step 8: Building Custom Application"
print_info "Building a sample Node.js application..."

# Check if Dockerfile exists, if not create a simple one
if [ ! -f "Dockerfile.sample" ]; then
    cat > Dockerfile.sample << 'EOF'
FROM node:18.20.5-alpine3.20
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 3000
CMD ["node", "server.js"]
EOF
fi

if [ ! -f "package.json" ]; then
    cat > package.json << 'EOF'
{
  "name": "sample-app",
  "version": "1.0.0",
  "description": "Sample app for SBOM demo",
  "main": "server.js",
  "dependencies": {
    "express": "4.18.2"
  }
}
EOF
fi

if [ ! -f "server.js" ]; then
    cat > server.js << 'EOF'
const express = require('express');
const app = express();
const port = 3000;

app.get('/', (req, res) => {
  res.send('Hello from SBOM Demo App!');
});

app.listen(port, () => {
  console.log(`App listening on port ${port}`);
});
EOF
fi

docker build -t myapp:latest -f Dockerfile.sample . > /dev/null 2>&1
print_success "Application built: myapp:latest"
pause

# Step 9: Generate SBOM for custom app
print_header "Step 9: Generating SBOM for Custom Application"

syft myapp:latest -o spdx-json > output/myapp-sbom.json 2>/dev/null
print_success "SBOM generated: output/myapp-sbom.json"

print_info "Application dependencies found:"
syft myapp:latest -o table | grep -E "express|node" | head -n 10
sleep 2

# Step 10: Scan custom app
print_header "Step 10: Scanning Custom Application"
print_info "Checking our application for vulnerabilities..."
echo ""

grype myapp:latest --fail-on high 2>/dev/null || {
    print_warning "Vulnerabilities found (expected - dependencies may have known issues)"
}
sleep 2

# Step 11: Compare different nginx versions
print_header "Step 11: Comparing SBOM Versions"
print_info "Comparing nginx:1.24 vs nginx:1.25 to see what changed..."

# Pull and generate SBOMs for two versions
docker pull nginx:1.24-alpine > /dev/null 2>&1
docker pull nginx:1.25-alpine > /dev/null 2>&1

syft nginx:1.24-alpine -o json > output/nginx-1.24-sbom.json 2>/dev/null
syft nginx:1.25-alpine -o json > output/nginx-1.25-sbom.json 2>/dev/null

print_success "SBOMs generated for both versions"

# Simple comparison
print_info "Package count comparison:"
echo "nginx:1.24-alpine: $(cat output/nginx-1.24-sbom.json | jq '.artifacts | length' 2>/dev/null || echo 'N/A') packages"
echo "nginx:1.25-alpine: $(cat output/nginx-1.25-sbom.json | jq '.artifacts | length' 2>/dev/null || echo 'N/A') packages"
sleep 2

# Step 12: CI/CD Integration Examples
print_header "Step 12: CI/CD Integration"

print_info "Sample Azure DevOps pipeline YAML:"
cat << 'EOF'

trigger:
  - main

pool:
  vmImage: 'ubuntu-latest'

steps:
- task: Docker@2
  displayName: 'Build Image'
  inputs:
    command: build
    Dockerfile: '**/Dockerfile'
    tags: $(Build.BuildId)

- script: |
    # Install tools
    curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin
    curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin
    
    # Generate SBOM
    syft myapp:$(Build.BuildId) -o spdx-json > sbom.json
    
    # Scan for vulnerabilities
    grype sbom:./sbom.json --fail-on high
  displayName: 'SBOM Generation & Security Scan'

- task: PublishBuildArtifacts@1
  displayName: 'Publish SBOM'
  inputs:
    pathToPublish: 'sbom.json'
    artifactName: 'sbom'

EOF

print_info "See azure-pipelines.yml for complete example"
sleep 2

# Step 13: Summary
print_header "Lab Complete! Summary"

cat << EOF
${GREEN}[COMPLETE] Congratulations! You've completed Lab 07${NC}

${BLUE}What you've learned:${NC}
1. Installed Syft and Grype
2. Generated SBOMs in multiple formats (SPDX, CycloneDX)
3. Scanned images for vulnerabilities
4. Built and scanned a custom application
5. Compared SBOMs across versions
6. Reviewed CI/CD integration examples

${BLUE}Generated artifacts:${NC}
$(ls -lh output/ 2>/dev/null | tail -n +2 | awk '{print "  - " $9 " (" $5 ")"}')

${BLUE}Next steps:${NC}
1. Review the generated SBOMs in output/ directory
2. Try the individual scripts (generate-sbom.sh, scan-sbom.sh)
3. Integrate SBOM generation into your CI/CD pipeline
4. Set up automated vulnerability scanning
5. Move to Lab 08: Kubernetes Security (coming soon)

${YELLOW}Production tips:${NC}
- Generate SBOMs for ALL images (not just production)
- Store SBOMs in artifact repository alongside images
- Scan SBOMs daily for new vulnerabilities
- Sign SBOMs with Cosign for integrity
- Use SBOM data for incident response planning

${BLUE}Cleanup:${NC}
Run ./cleanup.sh to remove all generated files and images

EOF

print_success "Thank you for completing Lab 07!"
print_info "Star the repository: https://github.com/opscart/docker-security-practical-guide"
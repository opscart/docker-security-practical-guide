#!/bin/bash

# Build the sample application and generate SBOM
# This script builds the Docker image and immediately generates its SBOM

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

IMAGE_NAME="myapp"
IMAGE_TAG="latest"

echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}  Building Sample Application${NC}"
echo -e "${BLUE}==================================================${NC}"
echo ""

# Create necessary files if they don't exist
if [ ! -f "package.json" ]; then
    echo -e "${YELLOW}Creating package.json...${NC}"
    cat > package.json << 'EOF'
{
  "name": "sbom-demo-app",
  "version": "1.0.0",
  "description": "Sample application for SBOM demonstration",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "keywords": ["docker", "sbom", "security"],
  "author": "OpscartLabs",
  "license": "MIT",
  "dependencies": {
    "express": "^4.18.2"
  }
}
EOF
    echo -e "${GREEN}✅ Created package.json${NC}"
fi

if [ ! -f "server.js" ]; then
    echo -e "${YELLOW}Creating server.js...${NC}"
    cat > server.js << 'EOF'
const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

// Middleware
app.use(express.json());

// Routes
app.get('/', (req, res) => {
  res.json({
    message: 'Hello from SBOM Demo App!',
    version: '1.0.0',
    timestamp: new Date().toISOString()
  });
});

app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    uptime: process.uptime()
  });
});

app.get('/sbom', (req, res) => {
  res.json({
    message: 'SBOM provides transparency into software dependencies',
    benefits: [
      'Vulnerability management',
      'License compliance',
      'Supply chain security',
      'Incident response'
    ]
  });
});

// Start server
app.listen(port, () => {
  console.log(`✅ Server running on port ${port}`);
  console.log(`📊 Health check: http://localhost:${port}/health`);
  console.log(`📋 SBOM info: http://localhost:${port}/sbom`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully...');
  process.exit(0);
});
EOF
    echo -e "${GREEN}✅ Created server.js${NC}"
fi

# Build Docker image
echo ""
echo -e "${BLUE}Building Docker image: ${IMAGE_NAME}:${IMAGE_TAG}${NC}"
docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .

echo ""
echo -e "${GREEN}✅ Image built successfully!${NC}"

# Display image info
echo ""
echo -e "${BLUE}Image Information:${NC}"
docker images ${IMAGE_NAME}:${IMAGE_TAG} --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"

# Generate SBOM automatically
echo ""
echo -e "${BLUE}Generating SBOM...${NC}"

if command -v syft &> /dev/null; then
    mkdir -p output
    syft ${IMAGE_NAME}:${IMAGE_TAG} -o spdx-json > output/${IMAGE_NAME}-sbom.json
    echo -e "${GREEN}✅ SBOM generated: output/${IMAGE_NAME}-sbom.json${NC}"
    
    # Show package count
    if command -v jq &> /dev/null; then
        PACKAGE_COUNT=$(jq '.artifacts | length' output/${IMAGE_NAME}-sbom.json 2>/dev/null || echo "N/A")
        echo -e "${BLUE}Total packages: ${PACKAGE_COUNT}${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Syft not installed. Run ./run-demo.sh to install tools.${NC}"
fi

echo ""
echo -e "${BLUE}==================================================${NC}"
echo -e "${GREEN}Build Complete!${NC}"
echo -e "${BLUE}==================================================${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  1. Generate SBOM: ./generate-sbom.sh ${IMAGE_NAME}:${IMAGE_TAG}"
echo "  2. Scan for vulnerabilities: ./scan-sbom.sh ${IMAGE_NAME}:${IMAGE_TAG}"
echo "  3. Run the application: docker run -p 3000:3000 ${IMAGE_NAME}:${IMAGE_TAG}"
echo ""
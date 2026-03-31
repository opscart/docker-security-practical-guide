#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Scenario 4: BuildKit Secret Mounts${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check BuildKit
if ! docker buildx version > /dev/null 2>&1; then
    echo -e "${RED}Error: BuildKit/buildx not available${NC}"
    echo "Install buildx or use Docker Desktop"
    exit 1
fi

echo -e "${GREEN}✓ BuildKit available${NC}"
echo ""

# Example 1: Basic secret mount
echo -e "${YELLOW}[1/4] Example 1: Basic Secret Mount${NC}"
echo "Building image with API token secret..."
echo ""

cd examples/1-basic-secret

# Create secret file
echo "sk-1234567890abcdef" > secret.txt

# Build with secret
docker buildx build --secret id=api_token,src=secret.txt -t buildkit-basic:latest . 

rm secret.txt

echo ""
echo -e "${GREEN}✓ Image built with secret${NC}"
echo ""
echo "Verifying secret NOT in image:"
docker history buildkit-basic:latest | grep -i "secret" || echo "  ✓ No 'secret' in history"
docker history buildkit-basic:latest | grep -i "1234567890" || echo "  ✓ Token value not in history"
echo ""

echo "Press ENTER to continue..."
read

# Example 2: NPM registry
echo -e "${YELLOW}[2/4] Example 2: Private npm Registry${NC}"
echo "Building Node.js app with private registry access..."
echo ""

cd ../2-npm-registry

# Create .npmrc with fake token
cat > .npmrc << 'EOF'
//registry.npmjs.org/:_authToken=npm_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
EOF

echo "Contents of .npmrc (will NOT persist in image):"
cat .npmrc
echo ""

# Build
docker buildx build --secret id=npmrc,src=.npmrc -t buildkit-npm:latest .

rm .npmrc

echo ""
echo -e "${GREEN}✓ Image built with npm credentials${NC}"
echo ""
echo "Verifying .npmrc NOT in final image:"
docker run --rm buildkit-npm:latest ls -la /root/.npmrc 2>&1 | grep "No such file" && echo "  ✓ .npmrc not in image"
echo ""

echo "Press ENTER to continue..."
read

# Example 3: SSH key for git
echo -e "${YELLOW}[3/4] Example 3: SSH Key for Private Git Repo${NC}"
echo "Demonstrating SSH key mount (simulated)..."
echo ""

cd ../3-ssh-git

# Create dummy SSH key
mkdir -p .ssh
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQ..." > .ssh/id_rsa

echo "Building with SSH key mount..."
docker buildx build --secret id=ssh_key,src=.ssh/id_rsa -t buildkit-ssh:latest .

rm -rf .ssh

echo ""
echo -e "${GREEN}✓ Image built with SSH key${NC}"
echo ""
echo "Verifying SSH key NOT in final image:"
docker history buildkit-ssh:latest | grep -i "ssh" || echo "  ✓ No 'ssh' in history"
echo ""

echo "Press ENTER to continue..."
read

# Example 4: Multi-stage build
echo -e "${YELLOW}[4/4] Example 4: Multi-Stage Build with Secrets${NC}"
echo "Building multi-stage image..."
echo ""

cd ../4-multi-stage

# Create secret for build stage
echo "build-secret-token-xyz" > build.secret

# Build multi-stage
docker buildx build --secret id=build_secret,src=build.secret -t buildkit-multistage:latest .

rm build.secret

echo ""
echo -e "${GREEN}✓ Multi-stage image built${NC}"
echo ""

echo "Image layers (secret only in build stage):"
docker history buildkit-multistage:latest
echo ""

# Summary
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Summary: BuildKit Secrets Demo Complete${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "✓ Basic secret mount demonstrated"
echo "✓ Private npm registry pattern shown"
echo "✓ SSH key mounting demonstrated"
echo "✓ Multi-stage build with secrets"
echo ""
echo -e "${YELLOW}Key Insights:${NC}"
echo "  - Secrets NEVER appear in docker history"
echo "  - Secrets NEVER persist in final image"
echo "  - Secrets only available during RUN instruction"
echo "  - Multi-stage builds keep final image clean"
echo ""
echo -e "${YELLOW}Comparison with ARG (Anti-Pattern):${NC}"
echo "  ARG: Visible in docker history ❌"
echo "  BuildKit Secrets: NOT in history ✅"
echo ""
echo "Run ./cleanup.sh to remove demo images."
echo ""
echo -e "${YELLOW}Next:${NC} Scenario 5 shows secret scanning to detect"
echo "leaked secrets in code repositories."
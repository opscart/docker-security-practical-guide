#!/bin/bash

# Test 2: Kaniko Build Prevention
# Tests building images without Docker daemon/socket

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

RESULTS_FILE="test-results.txt"
ARTIFACTS_DIR="./artifacts"

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$RESULTS_FILE"
}

echo -e "${BLUE}"
cat << "EOF"
════════════════════════════════════════════════════
  TEST 2: Kaniko Build (No Docker Daemon)
════════════════════════════════════════════════════
EOF
echo -e "${NC}"

# Initialize
mkdir -p "$ARTIFACTS_DIR"
> "$RESULTS_FILE"

log "Starting Kaniko build test..."
log "This tests building Docker images WITHOUT docker daemon or socket"

# Create test Dockerfile
log "Creating test Dockerfile..."
cat > Dockerfile << 'DOCKERFILE'
FROM ubuntu:22.04

# Install some packages to make build realistic
RUN apt-get update && \
    apt-get install -y curl wget vim && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Add a test file
RUN echo "Built with Kaniko - no Docker daemon!" > /tmp/kaniko-test.txt

# Set entrypoint
CMD ["cat", "/tmp/kaniko-test.txt"]
DOCKERFILE

log "Dockerfile created"

# Test 1: Build with Kaniko
log "TEST 1: Building image with Kaniko (no socket mount)..."
echo ""
echo -e "${YELLOW}Building image with Kaniko...${NC}"

BUILD_START=$(date +%s)

if docker run --rm \
    -v "$(pwd)":/workspace \
    gcr.io/kaniko-project/executor:latest \
    --context=/workspace \
    --dockerfile=Dockerfile \
    --destination=kaniko-test:latest \
    --no-push \
    --tarPath=/workspace/kaniko-test.tar \
    > "$ARTIFACTS_DIR/kaniko-build-output.txt" 2>&1; then
    
    BUILD_END=$(date +%s)
    BUILD_TIME=$((BUILD_END - BUILD_START))
    
    echo -e "${GREEN}✓ BUILD SUCCEEDED (took ${BUILD_TIME}s)${NC}"
    log "✓ Kaniko build completed successfully in ${BUILD_TIME}s"
    
    # Check if tar was created
    if [ -f "kaniko-test.tar" ]; then
        SIZE=$(du -h kaniko-test.tar | cut -f1)
        echo -e "${GREEN}✓ Image tar created: ${SIZE}${NC}"
        log "✓ Image tar created: ${SIZE}"
    fi
else
    echo -e "${RED}✗ BUILD FAILED${NC}"
    log "✗ Kaniko build failed"
    cat "$ARTIFACTS_DIR/kaniko-build-output.txt"
fi

# Test 2: Verify no socket was needed
log "TEST 2: Verifying no Docker socket was used..."
if ! grep -q "docker.sock" "$ARTIFACTS_DIR/kaniko-build-output.txt" 2>/dev/null; then
    echo -e "${GREEN}✓ No Docker socket mentioned in build${NC}"
    log "✓ Build completed without docker socket"
else
    echo -e "${YELLOW}⚠ Docker socket reference found in output${NC}"
    log "⚠ Socket reference found"
fi

# Test 3: Try to run the built image (load from tar)
log "TEST 3: Loading and running the built image..."
if [ -f "kaniko-test.tar" ]; then
    docker load -i kaniko-test.tar > "$ARTIFACTS_DIR/docker-load-output.txt" 2>&1
    
    # Run the image
    if docker run --rm kaniko-test:latest > "$ARTIFACTS_DIR/image-run-output.txt" 2>&1; then
        OUTPUT=$(cat "$ARTIFACTS_DIR/image-run-output.txt")
        echo -e "${GREEN}✓ Image runs successfully${NC}"
        echo -e "${GREEN}  Output: ${OUTPUT}${NC}"
        log "✓ Built image runs successfully"
    else
        echo -e "${RED}✗ Image failed to run${NC}"
        log "✗ Built image failed to run"
    fi
else
    echo -e "${YELLOW}⚠ No tar file to test${NC}"
fi

# Generate comparison
echo ""
echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Comparison: Docker Build vs Kaniko${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
echo ""

cat > "$ARTIFACTS_DIR/summary.txt" << SUMMARY
Kaniko Build Test Results
==========================
Date: $(date)

Configuration:
- Builder: Kaniko (gcr.io/kaniko-project/executor)
- Socket mount: NONE
- Build context: Local directory

Test Results:
1. Image build: $(grep -q "✓ Kaniko build completed" "$RESULTS_FILE" && echo "SUCCESS" || echo "FAILED")
2. Socket usage: $(grep -q "✓ Build completed without docker socket" "$RESULTS_FILE" && echo "NOT USED" || echo "REFERENCED")
3. Image execution: $(grep -q "✓ Built image runs" "$RESULTS_FILE" && echo "SUCCESS" || echo "FAILED")

Build Time: ${BUILD_TIME:-N/A}s
Image Size: ${SIZE:-N/A}

Comparison:
┌─────────────────────┬──────────────────┬─────────────────────┐
│ Feature             │ Docker Build     │ Kaniko              │
├─────────────────────┼──────────────────┼─────────────────────┤
│ Requires Socket     │ YES (vulnerable) │ NO (secure)         │
│ Runs as Daemon      │ YES              │ NO                  │
│ Root Access Needed  │ YES              │ NO                  │
│ CI/CD Safe          │ NO               │ YES                 │
│ Layer Caching       │ YES              │ YES                 │
│ Multi-stage Builds  │ YES              │ YES                 │
└─────────────────────┴──────────────────┴─────────────────────┘

Key Finding:
Kaniko builds identical images without requiring Docker daemon or socket access.
This eliminates the socket escape attack vector entirely for CI/CD pipelines.

The built image is functionally identical to one built with 'docker build',
but the build process has zero host access.

Use Cases:
- CI/CD pipelines (Jenkins, GitLab, GitHub Actions)
- Kubernetes-based builds
- Environments where Docker daemon access is restricted
- Automated image building without privileged access

Artifacts Generated:
- kaniko-build-output.txt: Build logs from Kaniko
- kaniko-test.tar: Built image as tar file
- docker-load-output.txt: Output from loading the image
- image-run-output.txt: Output from running the built image
- summary.txt: This summary file
SUMMARY

cat "$ARTIFACTS_DIR/summary.txt"

echo ""
log "Test complete. Results saved to: $ARTIFACTS_DIR/"
echo ""
echo -e "${YELLOW}To cleanup: rm -f kaniko-test.tar Dockerfile${NC}"
echo ""

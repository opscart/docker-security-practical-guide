#!/bin/bash

# Test 1: Socket Proxy Prevention
# Tests if socket proxy can block container creation attacks

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
  TEST 1: Socket Proxy Prevention
════════════════════════════════════════════════════
EOF
echo -e "${NC}"

# Initialize
mkdir -p "$ARTIFACTS_DIR"
> "$RESULTS_FILE"

log "Starting socket proxy test..."
log "This tests if restricting Docker API access prevents the escape attack"

# Start services
log "Starting socket proxy and test application..."
docker-compose up -d

# Wait for services
sleep 5

# Test 1: Verify proxy is working
log "TEST 1: Checking if proxy allows read operations..."
docker exec test-app-proxy sh -c "apt-get update -qq && apt-get install -y -qq docker.io curl" > /dev/null 2>&1

# Try docker ps (should work - read operation)
log "Attempting: docker ps (should SUCCEED - read operation allowed)"
if docker exec test-app-proxy docker ps > "$ARTIFACTS_DIR/docker-ps-output.txt" 2>&1; then
    echo -e "${GREEN}✓ docker ps SUCCEEDED (expected - read allowed)${NC}"
    log "✓ docker ps worked - read operations allowed"
else
    echo -e "${RED}✗ docker ps FAILED (unexpected)${NC}"
    log "✗ docker ps failed - proxy may not be working"
fi

# Try docker info (should work - read operation)
log "Attempting: docker info (should SUCCEED - read operation allowed)"
if docker exec test-app-proxy docker info > "$ARTIFACTS_DIR/docker-info-output.txt" 2>&1; then
    echo -e "${GREEN}✓ docker info SUCCEEDED (expected)${NC}"
    log "✓ docker info worked"
else
    echo -e "${RED}✗ docker info FAILED${NC}"
    log "✗ docker info failed"
fi

# Test 2: Try the attack (should fail - write operation)
log "TEST 2: Attempting the escape attack..."
log "Attempting: docker run --privileged (should FAIL - write blocked)"

cat > /tmp/attack-script.sh << 'ATTACK_EOF'
#!/bin/bash
docker run -d --rm \
  --privileged \
  --pid=host \
  --net=host \
  -v /:/host \
  --name escape-attempt \
  ubuntu:22.04 \
  sleep 30
ATTACK_EOF

chmod +x /tmp/attack-script.sh

# Copy attack script to container
docker cp /tmp/attack-script.sh test-app-proxy:/tmp/attack.sh

# Try to run the attack
echo ""
echo -e "${YELLOW}Attempting escape attack through proxy...${NC}"
if docker exec test-app-proxy /tmp/attack.sh > "$ARTIFACTS_DIR/attack-attempt.txt" 2>&1; then
    echo -e "${RED}✗ ATTACK SUCCEEDED - Proxy did NOT block it!${NC}"
    echo -e "${RED}✗ PREVENTION FAILED${NC}"
    log "✗ CRITICAL: Attack succeeded through proxy"
    
    # Cleanup the escape container if it was created
    docker stop escape-attempt 2>/dev/null || true
else
    echo -e "${GREEN}✓ ATTACK BLOCKED - Proxy prevented container creation!${NC}"
    echo -e "${GREEN}✓ PREVENTION SUCCESSFUL${NC}"
    log "✓ SUCCESS: Proxy blocked the attack"
fi

# Save error message
docker exec test-app-proxy cat /tmp/attack.sh > "$ARTIFACTS_DIR/attack-script.sh" 2>&1 || true

# Test 3: Try docker exec (should fail)
log "TEST 3: Attempting docker exec (should FAIL - exec blocked)"
if docker exec test-app-proxy docker exec test-app-proxy echo "test" > "$ARTIFACTS_DIR/exec-attempt.txt" 2>&1; then
    echo -e "${RED}✗ docker exec SUCCEEDED (should have failed)${NC}"
    log "✗ docker exec worked - exec should be blocked"
else
    echo -e "${GREEN}✓ docker exec BLOCKED (expected)${NC}"
    log "✓ docker exec blocked as expected"
fi

# Generate summary
echo ""
echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Test Summary${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
echo ""

cat > "$ARTIFACTS_DIR/summary.txt" << SUMMARY
Socket Proxy Prevention Test Results
=====================================
Date: $(date)

Configuration:
- Proxy: tecnativa/docker-socket-proxy
- Read operations: ALLOWED (ps, info, images, etc.)
- Write operations: BLOCKED (run, create, delete, exec)

Test Results:
1. docker ps (read): $(grep -q "✓ docker ps worked" "$RESULTS_FILE" && echo "PASS" || echo "FAIL")
2. docker info (read): $(grep -q "✓ docker info worked" "$RESULTS_FILE" && echo "PASS" || echo "FAIL")
3. Container creation (write): $(grep -q "✓ SUCCESS: Proxy blocked" "$RESULTS_FILE" && echo "BLOCKED" || echo "ALLOWED")
4. docker exec (write): $(grep -q "✓ docker exec blocked" "$RESULTS_FILE" && echo "BLOCKED" || echo "ALLOWED")

Conclusion:
$(grep -q "✓ SUCCESS: Proxy blocked" "$RESULTS_FILE" && echo "Socket proxy successfully prevents the escape attack while allowing read operations." || echo "Socket proxy did NOT prevent the attack - configuration may need adjustment.")

Key Finding:
The socket proxy acts as a gatekeeper, allowing monitoring/visibility (read operations)
while blocking dangerous operations (container creation, exec, etc.). This enables
use cases like monitoring tools and dashboards without exposing the full Docker API.

Artifacts Generated:
- docker-ps-output.txt: Output from docker ps command
- docker-info-output.txt: Output from docker info command
- attack-attempt.txt: Error from blocked attack attempt
- attack-script.sh: The attack script that was blocked
- summary.txt: This summary file
SUMMARY

cat "$ARTIFACTS_DIR/summary.txt"

echo ""
log "Test complete. Results saved to: $ARTIFACTS_DIR/"
echo ""
echo -e "${YELLOW}To cleanup: docker-compose down${NC}"
echo ""

# Cleanup temp file
rm -f /tmp/attack-script.sh

#!/bin/bash

# Lab 08 - Scenario 5: Common Network Misconfigurations
# Demonstrates security anti-patterns and how to fix them

set -e

# Get script directory for absolute paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================================${NC}\n"
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

pause() {
    echo ""
    read -p "Press Enter to continue..."
    echo ""
}

# Cleanup function
cleanup() {
    print_info "Cleaning up resources..."
    docker rm -f bad-web bad-db bad-healthcheck good-web good-db good-healthcheck test-container 2>/dev/null || true
    docker network rm bad-net good-net 2>/dev/null || true
    print_success "Cleanup complete"
}

trap cleanup EXIT

# Initial cleanup to ensure clean slate
print_info "Ensuring clean environment..."
cleanup 2>/dev/null || true
echo ""

print_header "Scenario 5: Common Network Misconfigurations"

echo -e "${BLUE}What You'll Learn:${NC}"
echo "- Identify common Docker network security mistakes"
echo "- Understand the security implications of each mistake"
echo "- Learn how to fix these misconfigurations"
echo "- Apply security best practices"
echo ""
echo -e "${BLUE}Security Principle:${NC}"
echo "Many breaches happen not from sophisticated attacks, but from"
echo "simple misconfigurations. Understanding common mistakes helps"
echo "you avoid them in production."
echo ""
echo -e "${RED}WARNING:${NC}"
echo "This scenario demonstrates INSECURE configurations for educational"
echo "purposes. NEVER use these patterns in production!"
echo ""

pause

# Mistake 1: Default Bridge Network
print_header "Mistake 1: Using Default Bridge Network"

echo -e "${RED}The Problem:${NC}"
echo "Many developers use the default bridge network because it's easy."
echo "However, it has serious limitations:"
echo ""
echo "1. No automatic DNS resolution (containers can't find each other by name)"
echo "2. All containers can see each other"
echo "3. No network isolation"
echo "4. Legacy mode with fewer features"
echo ""

print_info "Demonstrating the problem..."
echo ""

print_info "Starting containers on default bridge..."
docker run -d --name bad-web nginx:alpine
docker run -d --name bad-db postgres:15-alpine -e POSTGRES_PASSWORD=secret

sleep 2

echo ""
print_info "Attempting DNS resolution on default bridge:"
echo "$ docker exec bad-web ping -c 1 bad-db"
if docker exec bad-web ping -c 1 bad-db 2>&1 | grep -q "bad address"; then
    print_error "✗ DNS resolution FAILED - containers can't find each other by name"
else
    print_success "DNS worked (unexpected)"
fi

echo ""
print_warning "You would need to use IP addresses, which change on restart!"

echo ""
echo -e "${GREEN}The Fix:${NC}"
echo "✓ Create custom bridge networks"
echo "✓ Automatic DNS resolution"
echo "✓ Network isolation"
echo "✓ Better security controls"
echo ""

print_info "Creating custom network and restarting..."
docker network create good-net
docker rm -f bad-web bad-db
docker run -d --name good-web --network good-net nginx:alpine
docker run -d --name good-db --network good-net -e POSTGRES_PASSWORD=secret postgres:15-alpine

sleep 2

echo ""
print_info "Testing DNS on custom network:"
echo "$ docker exec good-web ping -c 1 good-db"
if docker exec good-web ping -c 1 good-db 2>&1 | grep -q "1 packets received"; then
    print_success "✓ DNS resolution WORKS - containers can find each other"
fi

pause

# Mistake 2: Using --network host
print_header "Mistake 2: Using --network host"

echo -e "${RED}The Problem:${NC}"
echo "Using --network host bypasses ALL Docker networking:"
echo ""
echo "1. Container shares host's network namespace"
echo "2. No network isolation"
echo "3. Container can access ALL host network interfaces"
echo "4. Port conflicts with host services"
echo "5. Makes container breakout easier"
echo ""

echo -e "${BLUE}Why people use it:${NC}"
echo "- 'Better performance' (rarely true in practice)"
echo "- Avoids port mapping complexity"
echo "- Lazy configuration"
echo ""

print_warning "Let's see how dangerous this is..."
echo ""

print_info "Starting container with host networking..."
docker run -d --name bad-web --network host nginx:alpine

sleep 2

echo ""
print_info "Container network configuration:"
docker exec bad-web ip addr show | grep -E "inet " | head -5

echo ""
print_error "✗ Container can see ALL host network interfaces!"
print_error "✗ If compromised, attacker has direct host network access"

echo ""
echo -e "${GREEN}The Fix:${NC}"
echo "✓ Use bridge networks"
echo "✓ Explicitly map only needed ports (-p)"
echo "✓ Never use host networking in production"
echo ""

docker rm -f bad-web

pause

# Mistake 3: Exposing Unnecessary Ports
print_header "Mistake 3: Exposing Unnecessary Ports"

echo -e "${RED}The Problem:${NC}"
echo "Exposing ports that don't need external access increases attack surface."
echo ""

print_info "BAD Example: Exposing database port to host"
echo "$ docker run -p 5432:5432 postgres"
echo ""
print_error "✗ Database directly accessible from internet/host"
print_error "✗ Attackers can attempt brute force attacks"
print_error "✗ Larger attack surface"

echo ""
echo -e "${GREEN}The Fix:${NC}"
echo "✓ Only expose web/API tier ports"
echo "✓ Databases should be on internal networks only"
echo "✓ Use principle of least privilege"
echo ""

print_info "GOOD Example:"
echo "Web tier:     -p 80:80 -p 443:443    ✓ (needs external access)"
echo "App tier:     (no -p flags)          ✓ (internal only)"
echo "Database:     (no -p flags)          ✓ (internal only)"

pause

# Mistake 4: No Resource Limits
print_header "Mistake 4: No Resource Limits"

echo -e "${RED}The Problem:${NC}"
echo "Containers without resource limits can:"
echo ""
echo "1. Consume all host CPU (DoS)"
echo "2. Consume all host memory (OOM killer)"
echo "3. One container affects others"
echo "4. Security issue: resource exhaustion attacks"
echo ""

print_info "Starting container WITHOUT limits (dangerous)..."
docker run -d --name bad-web nginx:alpine

echo ""
print_info "Container can use unlimited resources:"
docker inspect bad-web | grep -A 10 "Memory"

echo ""
print_error "✗ No memory limit - can crash the host"
print_error "✗ No CPU limit - can starve other containers"

echo ""
echo -e "${GREEN}The Fix:${NC}"
echo "✓ Always set memory limits"
echo "✓ Set CPU limits for critical containers"
echo "✓ Use resource reservations"
echo ""

print_info "Starting container WITH limits (secure)..."
docker rm -f bad-web good-web 2>/dev/null || true  # Clean up first
docker run -d --name good-web \
    --memory="256m" \
    --memory-swap="256m" \
    --cpus="1.0" \
    nginx:alpine

echo ""
print_success "✓ Container has resource limits"
docker stats --no-stream good-web

pause

# Mistake 5: Running as Root
print_header "Mistake 5: Running Containers as Root"

echo -e "${RED}The Problem:${NC}"
echo "Most containers run as root by default:"
echo ""
echo "1. If container is compromised, attacker has root"
echo "2. Can potentially escape to host"
echo "3. Violates principle of least privilege"
echo "4. Unnecessary permissions"
echo ""

print_info "Checking default user..."
docker run --rm alpine:latest id

echo ""
print_error "✗ Running as uid=0 (root)"

echo ""
echo -e "${GREEN}The Fix:${NC}"
echo "✓ Run as non-root user"
echo "✓ Use USER directive in Dockerfile"
echo "✓ Use --user flag"
echo ""

print_info "Running as non-root user..."
docker run --rm --user 1000:1000 alpine:latest id

echo ""
print_success "✓ Running as uid=1000 (non-root)"

pause

# Mistake 6: Privileged Mode
print_header "Mistake 6: Using Privileged Mode"

echo -e "${RED}The Problem:${NC}"
echo "Privileged mode (--privileged) is extremely dangerous:"
echo ""
echo "1. Disables ALL security features"
echo "2. Full access to host devices"
echo "3. Can load kernel modules"
echo "4. Easy container escape"
echo "5. Root on container = root on host"
echo ""

echo -e "${BLUE}Why people use it:${NC}"
echo "- Docker-in-Docker (DinD)"
echo "- Needed specific device access"
echo "- Laziness / didn't understand implications"
echo ""

print_warning "This is how most container escapes work!"

echo ""
echo -e "${GREEN}The Fix:${NC}"
echo "✓ NEVER use --privileged in production"
echo "✓ Use specific capabilities instead (--cap-add)"
echo "✓ Mount only needed devices (--device)"
echo "✓ Use rootless Docker if possible"
echo ""

print_info "Example: Instead of --privileged for device access:"
echo ""
echo "BAD:  docker run --privileged ..."
echo "GOOD: docker run --device=/dev/video0 ..."

pause

# Mistake 7: Flat Network Architecture
print_header "Mistake 7: Flat Network Architecture"

echo -e "${RED}The Problem:${NC}"
echo "Putting all containers on one network:"
echo ""
echo "┌─────────────────────────────────────┐"
echo "│      All on 'app-network'           │"
echo "│                                     │"
echo "│  [Web] ←→ [API] ←→ [DB] ←→ [Cache] │"
echo "│                                     │"
echo "│  Problem: Everyone can reach DB     │"
echo "└─────────────────────────────────────┘"
echo ""
print_error "✗ Web tier can directly access database"
print_error "✗ No defense in depth"
print_error "✗ Single compromise = full access"

echo ""
echo -e "${GREEN}The Fix:${NC}"
echo "✓ Use multi-tier segmentation"
echo "✓ Create separate networks per tier"
echo "✓ Only gateways span networks"
echo ""
echo "┌──────────┐   ┌──────────┐   ┌──────────┐"
echo "│ Public   │   │ App      │   │ Database │"
echo "│          │   │          │   │          │"
echo "│  [Web] ──┼──→│  [API] ──┼──→│  [DB]    │"
echo "└──────────┘   └──────────┘   └──────────┘"
echo ""
print_success "✓ Web cannot reach database directly"
print_success "✓ Defense in depth"

pause

# Mistake 8: No Health Checks
print_header "Mistake 8: No Health Checks"

echo -e "${RED}The Problem:${NC}"
echo "Containers without health checks:"
echo ""
echo "1. Docker thinks container is healthy even when app crashed"
echo "2. Can't automatically restart failed containers"
echo "3. Load balancers send traffic to dead containers"
echo "4. Harder to detect security issues (app tampering)"
echo ""

print_info "Starting container WITHOUT health check..."
docker run -d --name bad-healthcheck nginx:alpine

sleep 2
docker ps --format "table {{.Names}}\t{{.Status}}" | grep bad-healthcheck

print_warning "Status shows 'Up' but doesn't verify nginx is actually working"

echo ""
echo -e "${GREEN}The Fix:${NC}"
echo "✓ Add HEALTHCHECK to Dockerfile"
echo "✓ Use --health-cmd in docker run"
echo "✓ Monitor health status"
echo ""

print_info "Starting container WITH health check..."
docker run -d --name good-healthcheck \
    --health-cmd="wget --quiet --tries=1 --spider http://localhost/ || exit 1" \
    --health-interval=10s \
    --health-timeout=3s \
    --health-retries=3 \
    nginx:alpine

sleep 2
echo ""
print_success "Container has health check"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep good-healthcheck

pause

# Summary
print_header "Scenario 5 Complete!"

echo -e "${GREEN}Common Mistakes Covered:${NC}"
echo ""
echo "1. ${RED}✗${NC} Using default bridge network"
echo "   ${GREEN}✓${NC} Use custom bridge networks"
echo ""
echo "2. ${RED}✗${NC} Using --network host"
echo "   ${GREEN}✓${NC} Use bridge networks with port mapping"
echo ""
echo "3. ${RED}✗${NC} Exposing unnecessary ports"
echo "   ${GREEN}✓${NC} Only expose what's needed (web tier)"
echo ""
echo "4. ${RED}✗${NC} No resource limits"
echo "   ${GREEN}✓${NC} Set memory and CPU limits"
echo ""
echo "5. ${RED}✗${NC} Running as root"
echo "   ${GREEN}✓${NC} Use non-root users"
echo ""
echo "6. ${RED}✗${NC} Using --privileged mode"
echo "   ${GREEN}✓${NC} Use specific capabilities or devices"
echo ""
echo "7. ${RED}✗${NC} Flat network architecture"
echo "   ${GREEN}✓${NC} Multi-tier network segmentation"
echo ""
echo "8. ${RED}✗${NC} No health checks"
echo "   ${GREEN}✓${NC} Add health checks to all containers"
echo ""

echo -e "${BLUE}Security Checklist:${NC}"
echo ""
echo "Before deploying containers to production, verify:"
echo "□ Using custom networks (not default bridge)"
echo "□ Not using host networking"
echo "□ Only necessary ports exposed"
echo "□ Resource limits configured"
echo "□ Running as non-root user"
echo "□ Not using privileged mode"
echo "□ Networks properly segmented"
echo "□ Health checks implemented"
echo "□ Internal networks for databases"
echo "□ TLS for sensitive communications"
echo ""

echo -e "${BLUE}Key Takeaway:${NC}"
echo ""
echo "Security is not about one perfect control, but many"
echo "layers working together (defense in depth). Avoid these"
echo "common mistakes, and your containers will be much more secure."
echo ""

echo -e "${BLUE}Resources:${NC}"
echo "- Docker security best practices: https://docs.docker.com/engine/security/"
echo "- CIS Docker Benchmark: https://www.cisecurity.org/benchmark/docker"
echo "- OWASP Container Security: https://owasp.org/www-project-docker-top-10/"
echo ""

print_info "All scenarios complete! Run './run-all-demos.sh' to see everything together."
print_info "Cleaning up will happen automatically on exit..."
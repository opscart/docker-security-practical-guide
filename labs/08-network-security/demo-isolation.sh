#!/bin/bash

# Lab 08 - Scenario 1: Network Isolation
# Demonstrates how containers on different networks cannot communicate

set -e

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
    docker rm -f web-frontend web-backend api-frontend api-backend 2>/dev/null || true
    docker network rm frontend-net backend-net 2>/dev/null || true
    print_success "Cleanup complete"
}

# Trap errors and cleanup
trap cleanup EXIT

print_header "Scenario 1: Network Isolation"

cat << EOF
${BLUE}What You'll Learn:${NC}
- How to create custom Docker networks
- Why containers on different networks cannot communicate
- How to verify network isolation
- When and how to connect containers across networks

${BLUE}Security Principle:${NC}
Network isolation is the foundation of container security. By default,
containers on different networks cannot communicate, providing natural
segmentation and reducing attack surface.

EOF

pause

# Step 1: Create two isolated networks
print_header "Step 1: Creating Isolated Networks"

print_info "Creating frontend-net (for web tier)..."
docker network create frontend-net

print_info "Creating backend-net (for application tier)..."
docker network create backend-net

print_success "Networks created successfully"

# Show network details
echo ""
print_info "Network configuration:"
docker network ls | grep -E "frontend-net|backend-net"

pause

# Step 2: Launch containers on different networks
print_header "Step 2: Launching Containers on Separate Networks"

print_info "Starting web-frontend on frontend-net..."
docker run -d --name web-frontend \
    --network frontend-net \
    nginx:alpine

print_info "Starting web-backend on backend-net..."
docker run -d --name web-backend \
    --network backend-net \
    nginx:alpine

print_success "Containers launched"

# Show container network info
echo ""
print_info "Container network assignments:"
echo "  web-frontend  → frontend-net ($(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' web-frontend))"
echo "  web-backend   → backend-net  ($(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' web-backend))"

pause

# Step 3: Demonstrate isolation
print_header "Step 3: Demonstrating Network Isolation"

print_info "Attempting to ping web-backend from web-frontend..."
echo ""

if docker exec web-frontend ping -c 2 web-backend 2>&1 | grep -q "bad address"; then
    print_success "Network isolation VERIFIED: web-frontend CANNOT reach web-backend"
    echo ""
    print_info "This is the expected behavior - containers on different networks"
    print_info "cannot communicate unless explicitly connected."
else
    print_error "Unexpected: Containers can communicate across networks"
fi

pause

# Step 4: Show DNS resolution works within same network
print_header "Step 4: DNS Resolution Within Same Network"

print_info "Starting api-frontend on frontend-net (same network as web-frontend)..."
docker run -d --name api-frontend \
    --network frontend-net \
    nginx:alpine

print_info "Testing connectivity between containers on SAME network..."
echo ""

if docker exec web-frontend ping -c 2 api-frontend 2>&1 | grep -q "2 packets transmitted"; then
    print_success "DNS and connectivity WORK within same network"
    echo ""
    print_info "web-frontend CAN reach api-frontend (both on frontend-net)"
else
    print_warning "Connectivity issue within same network"
fi

pause

# Step 5: Controlled multi-network access
print_header "Step 5: Controlled Multi-Network Access"

cat << EOF
${BLUE}Real-world scenario:${NC}
Sometimes a container needs access to multiple networks.
For example, an API gateway needs to:
- Accept requests from frontend (frontend-net)
- Forward requests to backend services (backend-net)

Solution: Connect one container to multiple networks
EOF

echo ""
print_info "Creating api-backend container connected to BOTH networks..."

docker run -d --name api-backend \
    --network frontend-net \
    nginx:alpine

print_info "Connecting api-backend to backend-net as well..."
docker network connect backend-net api-backend

print_success "api-backend now connected to both networks"

echo ""
print_info "Verifying multi-network connectivity:"
echo ""

# Test frontend connectivity
if docker exec api-backend ping -c 2 web-frontend 2>&1 | grep -q "2 packets transmitted"; then
    print_success "✓ api-backend can reach web-frontend (frontend-net)"
fi

# Test backend connectivity  
if docker exec api-backend ping -c 2 web-backend 2>&1 | grep -q "2 packets transmitted"; then
    print_success "✓ api-backend can reach web-backend (backend-net)"
fi

echo ""
print_info "api-backend IP addresses:"
docker inspect api-backend --format '{{range $net, $config := .NetworkSettings.Networks}}  {{$net}}: {{$config.IPAddress}}{{"\n"}}{{end}}'

pause

# Step 6: Security implications
print_header "Step 6: Security Implications"

cat << EOF
${GREEN}Key Takeaways:${NC}

1. ${BLUE}Default Isolation${NC}
   - Containers on different networks cannot communicate
   - This is a security feature, not a bug
   - Reduces blast radius if one container is compromised

2. ${BLUE}DNS-Based Service Discovery${NC}
   - Containers on same network can find each other by name
   - No need to hardcode IP addresses
   - Automatic load balancing across replicas

3. ${BLUE}Controlled Connectivity${NC}
   - Use 'docker network connect' for cross-network access
   - Only connect containers that truly need to communicate
   - Principle of least privilege

4. ${BLUE}Production Best Practice${NC}
   - Create separate networks for each tier (web/app/db)
   - Only API gateways should span multiple networks
   - Never put everything on the default bridge network

${YELLOW}Common Mistakes to Avoid:${NC}
- Using default bridge network (no DNS, less secure)
- Connecting all containers to all networks (defeats isolation)
- Using --network host (bypasses all isolation)

EOF

pause

print_header "Scenario 1 Complete!"

cat << EOF
${GREEN}What you learned:${NC}
✓ Created custom Docker networks
✓ Verified network isolation between containers
✓ Tested DNS-based service discovery
✓ Connected containers to multiple networks
✓ Understood security implications

${BLUE}Network Architecture Created:${NC}

frontend-net:
  - web-frontend (isolated)
  - api-frontend (isolated)
  - api-backend (gateway)

backend-net:
  - web-backend (isolated)
  - api-backend (gateway)

${BLUE}Next Steps:${NC}
- Run Scenario 2: Multi-Tier Network Segmentation
- See how to build production 3-tier architectures
- Learn internal networks for database security

EOF

print_info "Cleaning up will happen automatically on exit..."
